import {randomBytes,createHash} from 'node:crypto';
import {Timestamp} from 'firebase-admin/firestore';
export class ApiError extends Error { constructor(status,message){super(message);this.status=status;} }
function reject(status,message){throw new ApiError(status,message);}
function text(value,max,label){if(typeof value!=='string'||!value.trim()||value.trim().length>max)reject(400,`Invalid ${label}`);return value.trim();}
function fields(input,names){if(!input||typeof input!=='object'||Array.isArray(input)||Object.keys(input).some(k=>!names.includes(k)))reject(400,'Unexpected request fields');}
const hash=value=>createHash('sha256').update(value).digest('hex');
const roles=['member','viewer'];
export function householdService(db) {
 const household=id=>db.collection('households').doc(text(id,128,'household ID'));
 const identity=user=>{if(!user?.uid||(user.authenticated!==true&&user.email_verified!==true))reject(403,'Authenticated account required');};
 function requireOwner(member){if(!member.exists||member.data().status!=='active'||member.data().role!=='owner')reject(403,'Household owner access required');}
 const projection=(uid,hid)=>db.doc(`users/${uid}/households/${hid}`);
 return {
  async create(user,input){
   identity(user);fields(input,['name','requestId']);const name=text(input.name,80,'household name');
   const requestId=text(input.requestId,100,'request ID');if(!/^[a-zA-Z0-9_-]{16,100}$/.test(requestId))reject(400,'Invalid request ID');
   const receipt=db.doc(`users/${user.uid}/commands/${requestId}`),ref=db.collection('households').doc(),digest=hash(JSON.stringify({name}));
   return db.runTransaction(async tx=>{
    const prior=await tx.get(receipt);if(prior.exists){if(prior.data().payloadHash!==digest)reject(409,'Request ID already used for different data');return prior.data().result;}
    const owned=await tx.get(db.collection('users').doc(user.uid).collection('households'));if(owned.size>=20)reject(409,'Household limit reached');
    const now=Timestamp.now(),result={householdId:ref.id};
    tx.create(ref,{schemaVersion:1,name,ownerUid:user.uid,createdAt:now,updatedAt:now,revision:1});
    tx.create(ref.collection('members').doc(user.uid),{schemaVersion:1,displayName:user.name||'Household owner',role:'owner',status:'active',joinedAt:now});
    tx.set(db.doc(`users/${user.uid}`),{schemaVersion:1,displayName:user.name||'Household owner',createdAt:now},{merge:true});
    tx.set(projection(user.uid,ref.id),{schemaVersion:1,name});
    tx.create(receipt,{payloadHash:digest,result,createdAt:now});
    tx.create(ref.collection('audit').doc(),{schemaVersion:1,actorUid:user.uid,command:'household.created',timestamp:now});
    return result;
   });
  },
  async invite(user,hid,input){
   identity(user);fields(input,user.username?['username','role']:['email','role']);const email=user.username?text(input.username,24,'username').toLowerCase():text(input.email,254,'email').toLowerCase();if(user.username&&!/^[a-z0-9_]{3,24}$/.test(email))reject(400,'Invalid username');
   if(!roles.includes(input.role))reject(400,'Invalid invitation role');
   const ref=household(hid),token=randomBytes(32).toString('base64url'),invite=db.collection('invitations').doc(hash(token));
   const expiresAt=Timestamp.fromMillis(Date.now()+24*60*60*1000);
   await db.runTransaction(async tx=>{
    requireOwner(await tx.get(ref.collection('members').doc(user.uid)));
    const home=await tx.get(ref);if(!home.exists)reject(404,'Household unavailable');
    const members=await tx.get(ref.collection('members').where('status','==','active'));if(members.size>=20)reject(409,'Member limit reached');
    tx.create(invite,{schemaVersion:1,householdId:hid,invitedEmail:email,role:input.role,createdBy:user.uid,expiresAt,usedAt:null});
    tx.create(ref.collection('audit').doc(),{schemaVersion:1,actorUid:user.uid,command:'invitation.created',timestamp:Timestamp.now()});
   });return {token,expiresAt:expiresAt.toDate().toISOString()};
  },
  async redeem(user,input){
   identity(user);fields(input,['token']);if(typeof input.token!=='string'||!/^[a-zA-Z0-9_-]{43}$/.test(input.token))reject(400,'Invalid invitation');
   const invitation=db.collection('invitations').doc(hash(input.token));
   return db.runTransaction(async tx=>{
    const snapshot=await tx.get(invitation);if(!snapshot.exists)reject(404,'Invitation unavailable');const data=snapshot.data();
    if(data.usedAt||data.expiresAt.toMillis()<=Date.now())reject(409,'Invitation expired or already used');
    if(data.invitedEmail!==(user.username||user.email).toLowerCase())reject(403,'Invitation belongs to another account');
    const ref=household(data.householdId),home=await tx.get(ref),own=await tx.get(ref.collection('members').doc(user.uid));
    const inviter=await tx.get(ref.collection('members').doc(data.createdBy));requireOwner(inviter);
    if(!home.exists)reject(404,'Household unavailable');if(own.exists&&own.data().status==='active')reject(409,'Already a household member');
    const members=await tx.get(ref.collection('members').where('status','==','active'));if(members.size>=20)reject(409,'Member limit reached');
    const now=Timestamp.now();
    tx.set(ref.collection('members').doc(user.uid),{schemaVersion:1,displayName:user.name||'Household member',role:data.role,status:'active',joinedAt:now});
    tx.set(projection(user.uid,ref.id),{schemaVersion:1,name:home.data().name});
    tx.update(invitation,{usedAt:now,usedBy:user.uid});
    tx.create(ref.collection('audit').doc(),{schemaVersion:1,actorUid:user.uid,command:'member.joined',targetId:user.uid,timestamp:now});
    return {householdId:ref.id,role:data.role};
   });
  },
  async member(user,hid,uid,input){
   identity(user);fields(input,['role','status']);text(uid,128,'member ID');
   if(!roles.includes(input.role)||!['active','revoked'].includes(input.status))reject(400,'Invalid membership');
   const ref=household(hid);
   await db.runTransaction(async tx=>{
    requireOwner(await tx.get(ref.collection('members').doc(user.uid)));
    const target=await tx.get(ref.collection('members').doc(uid));if(!target.exists)reject(404,'Member unavailable');
    if(target.data().role==='caregiver' && input.status==='active')reject(403,'Pilot administrator manages caregiver roles');
    if(target.data().role==='owner')reject(409,'Transfer ownership before changing the owner');
    if(target.data().status==='revoked'&&input.status==='active')reject(409,'Send a new invitation to restore access');
    tx.update(target.ref,{role:input.role,status:input.status});
    if(input.status==='revoked')tx.delete(projection(uid,hid));
    tx.create(ref.collection('audit').doc(),{schemaVersion:1,actorUid:user.uid,command:'member.changed',targetId:uid,timestamp:Timestamp.now()});
   });return {ok:true};
  },
  async transfer(user,hid,input){
   identity(user);fields(input,['newOwnerUid']);const uid=text(input.newOwnerUid,128,'new owner');if(uid===user.uid)reject(400,'Choose another member');const ref=household(hid);
   await db.runTransaction(async tx=>{
    const old=await tx.get(ref.collection('members').doc(user.uid));requireOwner(old);
    const target=await tx.get(ref.collection('members').doc(uid));if(!target.exists||target.data().status!=='active')reject(409,'New owner must be an active member');
    const home=await tx.get(ref);if(home.data()?.ownerUid!==user.uid)reject(409,'Ownership changed');
    tx.update(old.ref,{role:'member'});tx.update(target.ref,{role:'owner'});tx.update(ref,{ownerUid:uid,updatedAt:Timestamp.now(),revision:home.data().revision+1});
    tx.create(ref.collection('audit').doc(),{schemaVersion:1,actorUid:user.uid,command:'ownership.transferred',targetId:uid,timestamp:Timestamp.now()});
   });return {ok:true};
  }
 };
}
