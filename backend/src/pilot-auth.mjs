import {randomBytes,scrypt as scryptCallback,timingSafeEqual,createHash} from 'node:crypto';
import {promisify} from 'node:util';
import {Timestamp} from 'firebase-admin/firestore';
import {ApiError} from './households.mjs';
const scrypt=promisify(scryptCallback),digest=value=>createHash('sha256').update(value).digest('hex');
export function username(value){if(typeof value!=='string'||!/^[a-zA-Z0-9_]{3,24}$/.test(value))throw new ApiError(400,'Username must contain 3–24 letters, numbers or underscores');return value.toLowerCase();}
function password(value){if(typeof value!=='string'||value.length<12||value.length>128)throw new ApiError(400,'Use a password of 12–128 characters');return value;}
export async function passwordHash(value,salt=randomBytes(16).toString('hex')){return {salt,hash:Buffer.from(await scrypt(password(value),salt,64,{N:32768,r:8,p:1,maxmem:64*1024*1024})).toString('hex')};}
const sessionHash=token=>digest(token);
export function pilotAuth(db){
 const accounts=db.collection('pilotAccounts'),sessions=db.collection('pilotSessions');
 const admin=user=>{if(user?.pilotAdmin!==true)throw new ApiError(403,'Pilot administrator required');};
 async function issue(accountId,expectedVersion){
  const token=randomBytes(32).toString('base64url');
  await db.runTransaction(async tx=>{const ref=accounts.doc(accountId),account=await tx.get(ref);if(!account.exists||account.data().disabled||account.data().sessionVersion!==expectedVersion)throw new ApiError(401,'Account changed; sign in again');tx.create(sessions.doc(sessionHash(token)),{uid:accountId,sessionVersion:expectedVersion,expiresAt:Timestamp.fromMillis(Date.now()+8*60*60*1000)});});return {token,expiresInSeconds:28800};
 }
 return {
  async login(input){
   const key=username(input?.username),snap=await accounts.doc(key).get();
   const supplied=typeof input.password==='string'&&input.password.length<=128?input.password:'';
   // Hash even for a missing account; never disclose whether a username exists.
   const salt=snap.exists?snap.data().salt:'00000000000000000000000000000000';
   const computed=Buffer.from(await scrypt(supplied,salt,64,{N:32768,r:8,p:1,maxmem:64*1024*1024}));
   const stored=snap.exists?Buffer.from(snap.data().hash,'hex'):Buffer.alloc(64);
   if(!snap.exists||snap.data().disabled||stored.length!==computed.length||!timingSafeEqual(stored,computed))throw new ApiError(401,'Invalid username or password');
   const session=await issue(key,snap.data().sessionVersion);return {...session,mustChangePassword:snap.data().mustChangePassword===true};
  },
  async verifyIdToken(token){
   if(typeof token!=='string'||!/^[A-Za-z0-9_-]{43}$/.test(token))throw new ApiError(401,'Invalid session');
   const session=await sessions.doc(sessionHash(token)).get();if(!session.exists||session.data().expiresAt.toMillis()<=Date.now())throw new ApiError(401,'Session expired');
   const record=await accounts.doc(session.data().uid).get();if(!record.exists||record.data().disabled||record.data().sessionVersion!==session.data().sessionVersion)throw new ApiError(401,'Session revoked');
   const a=record.data();return {uid:record.id,username:record.id,name:a.displayName,authenticated:true,pilotAdmin:a.pilotAdmin===true,mustChangePassword:a.mustChangePassword===true};
  },
  async logout(token){await sessions.doc(sessionHash(token)).delete();return {ok:true};},
  async create(user,input){
   admin(user);const key=username(input.username);if(typeof input.displayName!=='string'||!input.displayName.trim()||input.displayName.length>80)throw new ApiError(400,'Invalid display name');
   const hashed=await passwordHash(input.password),ref=accounts.doc(key);
   await db.runTransaction(async tx=>{if((await tx.get(ref)).exists)throw new ApiError(409,'Username unavailable');tx.create(ref,{...hashed,displayName:input.displayName.trim(),pilotAdmin:false,disabled:false,mustChangePassword:true,sessionVersion:1,createdAt:Timestamp.now()});});return {username:key};
  },
  async reset(user,input){
   admin(user);const key=username(input.username),hashed=await passwordHash(input.temporaryPassword),ref=accounts.doc(key);
   await db.runTransaction(async tx=>{const prior=await tx.get(ref);if(!prior.exists)throw new ApiError(404,'Account unavailable');tx.update(ref,{...hashed,sessionVersion:prior.data().sessionVersion+1,mustChangePassword:true});});return {ok:true};
  },
  async change(user,input){
   if(typeof input.currentPassword!=='string')throw new ApiError(400,'Current password required');
   const ref=accounts.doc(user.uid),prior=await ref.get();if(!prior.exists)throw new ApiError(401,'Account unavailable');
   const old=await passwordHash(input.currentPassword,prior.data().salt);
   if(!timingSafeEqual(Buffer.from(old.hash,'hex'),Buffer.from(prior.data().hash,'hex')))throw new ApiError(401,'Current password incorrect');
   const hashed=await passwordHash(input.newPassword);
   await db.runTransaction(async tx=>{const current=await tx.get(ref);if(current.data().sessionVersion!==prior.data().sessionVersion)throw new ApiError(409,'Account changed; sign in again');tx.update(ref,{...hashed,mustChangePassword:false,sessionVersion:current.data().sessionVersion+1});});return {ok:true,signInAgain:true};
  },
  async caregiver(user,hid,input){
   admin(user);if(!/^[A-Za-z0-9_-]{1,128}$/.test(hid))throw new ApiError(400,'Invalid household');const uid=username(input.username);if(typeof input.enabled!=='boolean')throw new ApiError(400,'Invalid role setting');
   const ref=db.doc(`households/${hid}/members/${uid}`);
   await db.runTransaction(async tx=>{const member=await tx.get(ref);if(!member.exists||member.data().status!=='active'||member.data().role==='owner')throw new ApiError(409,'Choose an active non-owner member');tx.update(ref,{role:input.enabled?'caregiver':'member'});tx.create(db.collection(`households/${hid}/audit`).doc(),{schemaVersion:1,actorUid:user.uid,command:'caregiver.assigned',targetId:uid,timestamp:Timestamp.now()});});return {ok:true};
  }
 };
}
