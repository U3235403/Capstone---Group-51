import {before,after,test} from 'node:test';
import {readFile} from 'node:fs/promises';
import {initializeTestEnvironment,assertFails,assertSucceeds} from '@firebase/rules-unit-testing';
import {doc,setDoc,getDoc,getDocs,collection,updateDoc,deleteDoc,writeBatch,query,where,collectionGroup} from 'firebase/firestore';
let env;
const path='households/home-a',item=path+'/lists/list-a/items/milk';
const db=(uid,verified=true)=>env.authenticatedContext(uid,{email_verified:verified}).firestore();
before(async()=>{
 env=await initializeTestEnvironment({projectId:'demo-stage1',firestore:{rules:await readFile(new URL('../firestore.rules',import.meta.url),'utf8')}});
 await env.clearFirestore();
 await env.withSecurityRulesDisabled(async ctx=>{
  const store=ctx.firestore();
  const data={
   'users/owner':{displayName:'Owner'},'users/member':{displayName:'Member'},
   'users/owner/households/home-a':{name:'Household A'},
   [path]:{name:'Household A',ownerUid:'owner'},
   [path+'/members/owner']:{role:'owner',status:'active'},
   [path+'/members/caregiver']:{role:'caregiver',status:'active'},
   [path+'/members/member']:{role:'member',status:'active'},
   [path+'/members/viewer']:{role:'viewer',status:'active'},
   [path+'/members/revoked']:{role:'member',status:'revoked'},
   [path+'/members/unknown']:{role:'superadmin',status:'active'},
   [path+'/lists/list-a']:{name:'My Shopping List',archived:false},
   [item]:{name:'Fresh Whole Milk',productKey:'fresh-whole-milk',quantity:2,purchased:false},
   [path+'/safetyRules/fresh-whole-milk']:{maximum:2,mode:'block'},
   [path+'/audit/event']:{action:'rule.changed'},
   [path+'/invites/secret']:{tokenHash:'not-public'},
   [path+'/receipts/request']:{result:{ok:true}},
   'households/home-b':{name:'Other household',ownerUid:'outsider'},
   'households/home-b/members/outsider':{role:'owner',status:'active'},
   'catalogue/fresh-whole-milk':{name:'Fresh Whole Milk'}
  };
  const batch=writeBatch(store);for(const [p,v]of Object.entries(data))batch.set(doc(store,p),v);await batch.commit();
 });
});
after(async()=>{await env?.cleanup();});
for(const role of ['owner','caregiver','member','viewer'])test(role+' can read own household lists',async()=>{
 await assertSucceeds(getDoc(doc(db(role),item)));
 await assertSucceeds(getDocs(query(collection(db(role),path+'/lists/list-a/items'),where('purchased','==',false))));
});
for(const uid of ['outsider','revoked','unknown'])test(uid+' cannot read another or inactive household',async()=>{
 await assertFails(getDoc(doc(db(uid),path)));await assertFails(getDoc(doc(db(uid),item)));
});
test('unauthenticated and unverified accounts denied',async()=>{
 await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(),item)));
 await assertFails(getDoc(doc(db('owner',false),item)));
});
test('cannot enumerate all households or collection-group items',async()=>{
 await assertFails(getDocs(collection(db('owner'),'households')));
 await assertFails(getDocs(collectionGroup(db('owner'),'items')));
});
test('self profile and household discovery only',async()=>{
 await assertSucceeds(getDoc(doc(db('owner'),'users/owner')));
 await assertSucceeds(getDocs(collection(db('owner'),'users/owner/households')));
 await assertFails(getDoc(doc(db('member'),'users/owner')));
 await assertFails(getDocs(collection(db('member'),'users/owner/households')));
});
test('owner and caregiver audit access, ordinary members denied',async()=>{
 for(const uid of ['owner','caregiver'])await assertSucceeds(getDoc(doc(db(uid),path+'/audit/event')));
 for(const uid of ['member','viewer'])await assertFails(getDoc(doc(db(uid),path+'/audit/event')));
});
test('invitations, receipts and unknown paths are server-only',async()=>{
 for(const suffix of ['invites/secret','receipts/request','unknown/path'])await assertFails(getDoc(doc(db('owner'),path+'/'+suffix)));
});
test('no direct item write can bypass validation or safety limits',async()=>{
 for(const uid of ['owner','caregiver','member','viewer']){
  const ref=doc(db(uid),item);await assertFails(updateDoc(ref,{quantity:999}));await assertFails(deleteDoc(ref));
 }
 await assertFails(setDoc(doc(db('member'),path+'/lists/list-a/items/new'),{quantity:-1}));
});
test('clients cannot grant roles, join households or remove owner',async()=>{
 await assertFails(updateDoc(doc(db('member'),path+'/members/member'),{role:'owner'}));
 await assertFails(setDoc(doc(db('outsider'),path+'/members/outsider'),{role:'owner',status:'active'}));
 await assertFails(deleteDoc(doc(db('owner'),path+'/members/owner')));
});
test('client cannot disable safety rules, forge audit, or alter profile',async()=>{
 for(const suffix of ['safetyRules/fresh-whole-milk','audit/event'])await assertFails(updateDoc(doc(db('owner'),path+'/'+suffix),{maximum:999}));
 await assertFails(updateDoc(doc(db('owner'),'users/owner'),{role:'admin'}));
});
test('authenticated catalogue reads but no client writes',async()=>{
 await assertSucceeds(getDocs(collection(db('owner'),'catalogue')));
 await assertFails(getDocs(collection(env.unauthenticatedContext().firestore(),'catalogue')));
 await assertFails(updateDoc(doc(db('owner'),'catalogue/fresh-whole-milk'),{name:'tampered'}));
});
test('revocation immediately removes subsequent reads',async()=>{
 await assertSucceeds(getDoc(doc(db('member'),item)));
 await env.withSecurityRulesDisabled(ctx=>updateDoc(doc(ctx.firestore(),path+'/members/member'),{status:'revoked'}));
 await assertFails(getDoc(doc(db('member'),item)));
});
