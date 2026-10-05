// Local pilot bootstrap only. Supply JSON on stdin; passwords are never printed.
import {deleteApp} from 'firebase-admin/app';
import {Timestamp} from 'firebase-admin/firestore';
import {localAdmin} from '../src/admin.mjs';
import {passwordHash,username} from '../src/pilot-auth.mjs';
let text='';for await(const part of process.stdin){text+=part;if(Buffer.byteLength(text)>4096)throw Error('Input too large');}
const input=JSON.parse(text),key=username(input.username);
if(typeof input.displayName!=='string'||!input.displayName.trim()||input.displayName.length>80)throw Error('Invalid display name');
const context=localAdmin('bootstrap-admin');
try{
 const hashed=await passwordHash(input.password);
 await context.db.runTransaction(async tx=>{
  const marker=context.db.doc('pilotConfiguration/bootstrap');
  if((await tx.get(marker)).exists)throw Error('Pilot administrator already bootstrapped');
  const account=context.db.doc('pilotAccounts/'+key);if((await tx.get(account)).exists)throw Error('Username unavailable');
  tx.create(account,{...hashed,displayName:input.displayName.trim(),pilotAdmin:true,disabled:false,mustChangePassword:false,sessionVersion:1,createdAt:Timestamp.now()});
  tx.create(marker,{adminUid:key,createdAt:Timestamp.now()});
 });console.log('Local pilot administrator created.');
}finally{await deleteApp(context.app);}
