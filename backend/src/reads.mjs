import {ApiError} from './households.mjs';
const serial=value=>value?.toDate?value.toDate().toISOString():Array.isArray(value)?value.map(serial):value&&typeof value==='object'?Object.fromEntries(Object.entries(value).map(([k,v])=>[k,serial(v)])):value;
const rows=snapshot=>snapshot.docs.map(d=>({id:d.id,...serial(d.data())}));
export function readService(db){return {
 async lists(user,hid){
  const member=await db.doc('households/'+hid+'/members/'+user.uid).get();
  if(!member.exists||member.data().status!=='active'||!['owner','caregiver','member','viewer'].includes(member.data().role))throw new ApiError(403,'Household permission required');
  const lists=await db.collection('households/'+hid+'/lists').where('archived','==',false).get();
  const catalogue=await db.collection('catalogue').where('active','==',true).get();
  return {lists:rows(lists),catalogue:rows(catalogue)};
 },
 async me(user){
  const homes=await db.collection(`users/${user.uid}/households`).get(),active=[];
  for(const home of homes.docs){const member=await db.doc(`households/${home.id}/members/${user.uid}`).get();if(member.exists&&member.data().status==='active')active.push({id:home.id,name:home.data().name,role:member.data().role});}
  return {username:user.username||null,displayName:user.name||'',pilotAdmin:user.pilotAdmin===true,households:active};
 },
 async snapshot(user,hid,input){
  if(!/^[A-Za-z0-9_-]{1,128}$/.test(hid)||!input||typeof input.listId!=='string'||!/^[A-Za-z0-9_-]{1,128}$/.test(input.listId))throw new ApiError(400,'Invalid list');
  return db.runTransaction(async tx=>{
   const home=db.doc(`households/${hid}`),membership=await tx.get(home.collection('members').doc(user.uid));
   if(!membership.exists||membership.data().status!=='active'||!['owner','caregiver','member','viewer'].includes(membership.data().role))throw new ApiError(403,'Household permission required');
   const list=await tx.get(home.collection('lists').doc(input.listId));if(!list.exists)throw new ApiError(404,'List unavailable');
   const items=await tx.get(list.ref.collection('items')),rules=await tx.get(home.collection('safetyRules'));
   return {list:{id:list.id,...serial(list.data())},items:rows(items).filter(i=>!i.deleted||Date.parse(i.expiresAt)>Date.now()),rules:rows(rules),role:membership.data().role};
  },{readOnly:true});
 }
};}
