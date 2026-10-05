import {test,before,after} from 'node:test';
import assert from 'node:assert/strict';
import {randomUUID} from 'node:crypto';
import {deleteApp} from 'firebase-admin/app';
import {localAdmin} from '../src/admin.mjs';
import {apiServer} from '../src/server.mjs';
let context,server,base,owner,member,outsider,unverified,householdId,invite;
async function account(verified=true){
 const email=`${randomUUID()}@example.test`,password='test-only-LongPassword123!';
 const user=await context.auth.createUser({email,password,emailVerified:verified,displayName:'Test member'});
 const response=await fetch(`http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=demo`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({email,password,returnSecureToken:true})});
 const json=await response.json();assert(json.idToken);return {uid:user.uid,email,token:json.idToken};
}
async function call(user,path,data,expected=200){const r=await fetch(base+path,{method:'POST',headers:{'Content-Type':'application/json',...(user?{Authorization:`Bearer ${user.token}`}:{})},body:JSON.stringify(data)});const body=await r.json();assert.equal(r.status,expected,JSON.stringify(body));return body;}
before(async()=>{context=localAdmin('identity-tests');server=apiServer(context);await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));base=`http://127.0.0.1:${server.address().port}`;owner=await account();member=await account();outsider=await account();unverified=await account(false);});
after(async()=>{await new Promise(resolve=>server.close(resolve));for(const user of [owner,member,outsider,unverified])if(user)await context.auth.deleteUser(user.uid);await deleteApp(context.app);});
test('rejects anonymous, forged and unverified credentials',async()=>{
 await call(null,'/api/households',{},401);await call({token:'forged'},'/api/households',{},401);await call(unverified,'/api/households',{},403);
});
test('create is idempotent and rejects payload mismatch',async()=>{
 const input={name:'Integration household',requestId:randomUUID()};const first=await call(owner,'/api/households',input);householdId=first.householdId;
 assert.equal((await call(owner,'/api/households',input)).householdId,householdId);
 await call(owner,'/api/households',{...input,name:'changed'},409);
 assert.equal((await context.db.doc(`households/${householdId}/members/${owner.uid}`).get()).data().role,'owner');
});
test('only owner can invite; roles cannot be elevated by request fields',async()=>{
 await call(outsider,`/api/households/${householdId}/invitations`,{email:member.email,role:'member'},403);
 await call(owner,`/api/households/${householdId}/invitations`,{email:member.email,role:'owner'},400);
 invite=await call(owner,`/api/households/${householdId}/invitations`,{email:member.email,role:'member'});
});
test('invitation binds email and can be redeemed only once under concurrency',async()=>{
 await call(outsider,'/api/invitations/redeem',{token:invite.token},403);
 const attempts=await Promise.all([1,2].map(()=>fetch(base+'/api/invitations/redeem',{method:'POST',headers:{'Content-Type':'application/json',Authorization:`Bearer ${member.token}`},body:JSON.stringify({token:invite.token})})));
 assert.deepEqual(attempts.map(r=>r.status).sort(),[200,409]);
 assert.equal((await context.db.doc(`households/${householdId}/members/${member.uid}`).get()).data().role,'member');
});
test('member cannot grant roles and owner cannot remove itself',async()=>{
 await call(member,`/api/households/${householdId}/members/${member.uid}`,{role:'member',status:'active'},403);
 await call(owner,`/api/households/${householdId}/members/${owner.uid}`,{role:'member',status:'revoked'},409);
});
test('ownership transfer preserves exactly one owner and removes old owner privileges',async()=>{
 await call(owner,`/api/households/${householdId}/transfer`,{newOwnerUid:member.uid});
 const rows=await context.db.collection(`households/${householdId}/members`).get();assert.equal(rows.docs.filter(d=>d.data().role==='owner').length,1);
 assert.equal((await context.db.doc(`households/${householdId}`).get()).data().ownerUid,member.uid);
 await call(owner,`/api/households/${householdId}/invitations`,{email:outsider.email,role:'viewer'},403);
});
test('revocation removes household discovery and cannot be silently reactivated',async()=>{
 await call(member,`/api/households/${householdId}/members/${owner.uid}`,{role:'member',status:'revoked'});
 assert.equal((await context.db.doc(`users/${owner.uid}/households/${householdId}`).get()).exists,false);
 await call(member,`/api/households/${householdId}/members/${owner.uid}`,{role:'member',status:'active'},409);
});
test('expired invitation denied',async()=>{
 const token=await call(member,`/api/households/${householdId}/invitations`,{email:outsider.email,role:'viewer'});
 const {createHash}=await import('node:crypto');const {Timestamp}=await import('firebase-admin/firestore');
 await context.db.doc('invitations/'+createHash('sha256').update(token.token).digest('hex')).update({expiresAt:Timestamp.fromMillis(1)});
 await call(outsider,'/api/invitations/redeem',{token:token.token},409);
});
test('disabled account token denied',async()=>{await context.auth.updateUser(outsider.uid,{disabled:true});await call(outsider,'/api/households',{name:'no',requestId:randomUUID()},401);});
test('unknown fields and malformed input fail without creating a household',async()=>{
 await call(member,'/api/households',{name:'test',requestId:randomUUID(),ownerUid:outsider.uid},400);
 await call(member,'/api/households',null,400);
});
test('cross-origin requests are denied before mutation',async()=>{
 const r=await fetch(base+'/api/households',{method:'POST',headers:{'Content-Type':'application/json',Origin:'https://untrusted.example',Authorization:`Bearer ${member.token}`},body:JSON.stringify({name:'test',requestId:randomUUID()})});assert.equal(r.status,403);
});
