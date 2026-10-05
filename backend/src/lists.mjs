import {createHash} from 'node:crypto';
import {Timestamp} from 'firebase-admin/firestore';
import {ApiError} from './households.mjs';
import {retentionDeadline} from './retention.mjs';
const fail=(code,msg)=>{throw new ApiError(code,msg);};
const id=value=>{if(typeof value!=='string'||!/^[a-zA-Z0-9_-]{1,128}$/.test(value))fail(400,'Invalid ID');return value;};
const integer=(value,min,max)=>{if(!Number.isSafeInteger(value)||value<min||value>max)fail(400,'Invalid number');return value;};
const str=(value,max)=>{if(typeof value!=='string'||!value.trim()||value.trim().length>max)fail(400,'Invalid text');return value.trim();};
function shape(input,allowed){if(!input||typeof input!=='object'||Array.isArray(input)||Object.keys(input).some(k=>!allowed.includes(k)))fail(400,'Unexpected request fields');}
function canonical(value){return value&&typeof value==='object'&&!Array.isArray(value)?Object.fromEntries(Object.keys(value).sort().map(k=>[k,canonical(value[k])])):value;}
export function listService(db) {
 async function command(user,hid,input,action,manager,work){
  if(!user?.uid||(user.authenticated!==true&&user.email_verified!==true))fail(403,'Verified account required');
  id(hid);id(input.requestId);if(input.requestId.length<16)fail(400,'Use a unique request ID');
  const home=db.collection('households').doc(hid),receipt=home.collection('receipts').doc(input.requestId);
  const digest=createHash('sha256').update(JSON.stringify(canonical({action,input,uid:user.uid}))).digest('hex');
  return db.runTransaction(async tx=>{
   const membership=await tx.get(home.collection('members').doc(user.uid));
   const allowed=manager?['owner','caregiver']:['owner','caregiver','member'];
   if(!membership.exists||membership.data().status!=='active'||!allowed.includes(membership.data().role))fail(403,'Household permission required');
   const previous=await tx.get(receipt);
   if(previous.exists){if(previous.data().payloadHash!==digest)fail(409,'Request ID already used');return previous.data().response;}
   const now=Timestamp.now(),result=await work(tx,home,now);
   tx.create(receipt,{schemaVersion:1,actorUid:user.uid,payloadHash:digest,response:result,createdAt:now,expiresAt:Timestamp.fromDate(retentionDeadline(now.toDate()))});
   tx.create(home.collection('audit').doc(),{schemaVersion:1,actorUid:user.uid,command:action,targetId:result.itemId||result.listId||result.productKey,timestamp:now});
   return result;
  });
 }
 async function list(tx,home,lid,revision){
  const snap=await tx.get(home.collection('lists').doc(id(lid)));if(!snap.exists)fail(404,'List unavailable');
  if(snap.data().archived)fail(409,'List is archived');
  if(snap.data().revision!==integer(revision,1,Number.MAX_SAFE_INTEGER))fail(409,'List changed; reload before retrying');return snap;
 }
 async function limit(tx,home,lid,productKey,quantity,except,purchased,input){
  const rule=await tx.get(home.collection('safetyRules').doc(productKey));
  if(integer(input.ruleRevision,0,Number.MAX_SAFE_INTEGER)!==(rule.exists?rule.data().revision:0))fail(409,'Safety rule changed; review it before retrying');
  const rows=await tx.get(home.collection('lists').doc(lid).collection('items'));
  if(!except&&rows.docs.filter(d=>!d.data().deleted).length>=500)fail(409,'List item limit reached');
  if(purchased||!rule.exists||rule.data().deleted)return;
  const total=rows.docs.filter(d=>d.id!==except&&!d.data().deleted&&!d.data().purchased&&d.data().productKey===productKey).reduce((sum,d)=>sum+d.data().quantity,0)+quantity;
  if(total>rule.data().maximum){
   if(rule.data().mode==='block')fail(409,'Safety limit blocks this quantity');
   if(input.confirmed!==true)fail(409,'Quantity warning requires confirmation');
  }
 }
 return {
  async create(user,hid,input){
   shape(input,['requestId','name']);const name=str(input.name,80),ref=db.collection('households').doc(id(hid)).collection('lists').doc();
   return command(user,hid,input,'list.created',false,async(tx,home,now)=>{
    const rows=await tx.get(home.collection('lists').where('archived','==',false));if(rows.size>=50)fail(409,'Household list limit reached');
    tx.create(ref,{schemaVersion:1,name,archived:false,createdBy:user.uid,createdAt:now,updatedAt:now,revision:1});return {listId:ref.id,revision:1};
   });
  },
  async save(user,hid,lid,input){
   shape(input,['requestId','expectedRevision','ruleRevision','itemId','productKey','quantity','purchased','favourite','notes','assigneeUid','confirmed']);
   const productKey=id(input.productKey),quantity=integer(input.quantity,1,999);
   for(const key of ['purchased','favourite'])if(typeof input[key]!=='boolean')fail(400,'Invalid item flag');
   if(input.confirmed!==undefined&&typeof input.confirmed!=='boolean')fail(400,'Invalid confirmation');
   if(typeof input.notes!=='string'||input.notes.length>1000)fail(400,'Invalid notes');
   if(input.assigneeUid!==null)id(input.assigneeUid);
   const itemId=input.itemId===undefined?db.collection('unused').doc().id:id(input.itemId);
   return command(user,hid,input,`item.saved:${id(lid)}`,false,async(tx,home,now)=>{
    const snapshot=await list(tx,home,lid,input.expectedRevision),ref=snapshot.ref.collection('items').doc(itemId),existing=await tx.get(ref);
    if(input.itemId!==undefined&&!existing.exists)fail(404,'Item unavailable');
    if(existing.exists&&existing.data().deleted)fail(409,'Restore the deleted item first');
    const product=await tx.get(db.collection('catalogue').doc(productKey));if(!product.exists||product.data().active!==true)fail(400,'Product unavailable');
    if(input.assigneeUid!==null){const assignee=await tx.get(home.collection('members').doc(input.assigneeUid));if(!assignee.exists||assignee.data().status!=='active')fail(400,'Assignee must be an active household member');}
    await limit(tx,home,lid,productKey,quantity,existing.exists?itemId:null,input.purchased,input);
    const revision=snapshot.data().revision+1;
    tx.set(ref,{schemaVersion:1,productKey,name:product.data().name,category:product.data().category,quantity,unit:'items',notes:input.notes,purchased:input.purchased,favourite:input.favourite,assigneeUid:input.assigneeUid,deleted:false,createdBy:existing.exists?existing.data().createdBy:user.uid,createdAt:existing.exists?existing.data().createdAt:now,updatedAt:now,revision:existing.exists?existing.data().revision+1:1});
    tx.update(snapshot.ref,{revision,updatedAt:now});return {listId:lid,itemId,revision};
   });
  },
  async remove(user,hid,lid,iid,input){
   shape(input,['requestId','expectedRevision']);id(iid);
   return command(user,hid,input,`item.deleted:${id(lid)}:${iid}`,false,async(tx,home,now)=>{
    const snapshot=await list(tx,home,lid,input.expectedRevision),ref=snapshot.ref.collection('items').doc(iid),item=await tx.get(ref);
    if(!item.exists||item.data().deleted)fail(404,'Item unavailable');
    const revision=snapshot.data().revision+1;
    tx.update(ref,{deleted:true,deletedAt:now,expiresAt:Timestamp.fromDate(retentionDeadline(now.toDate())),updatedAt:now,revision:item.data().revision+1});
    tx.update(snapshot.ref,{revision,updatedAt:now});return {listId:lid,itemId:iid,revision};
   });
  },
  async restore(user,hid,lid,iid,input){
   shape(input,['requestId','expectedRevision','ruleRevision','confirmed']);id(iid);
   return command(user,hid,input,`item.restored:${id(lid)}:${iid}`,false,async(tx,home,now)=>{
    const snapshot=await list(tx,home,lid,input.expectedRevision),ref=snapshot.ref.collection('items').doc(iid),item=await tx.get(ref);
    if(!item.exists||!item.data().deleted||item.data().expiresAt.toMillis()<=now.toMillis())fail(409,'Recovery period expired or item not deleted');
    const value=item.data();await limit(tx,home,lid,value.productKey,value.quantity,null,value.purchased,input);
    const revision=snapshot.data().revision+1;
    const {deletedAt,expiresAt,...rest}=value;
    tx.set(ref,{...rest,deleted:false,updatedAt:now,revision:value.revision+1});tx.update(snapshot.ref,{revision,updatedAt:now});return {listId:lid,itemId:iid,revision};
   });
  },
  async deleteRule(user,hid,key,input){
   shape(input,['requestId','expectedRevision']);id(key);
   return command(user,hid,input,'rule.deleted:'+key,true,async(tx,home,now)=>{
    const ref=home.collection('safetyRules').doc(key),prior=await tx.get(ref);
    if(!prior.exists||prior.data().revision!==integer(input.expectedRevision,1,Number.MAX_SAFE_INTEGER))fail(409,'Rule changed; reload before retrying');
    const revision=prior.data().revision+1;tx.update(ref,{deleted:true,revision,updatedAt:now,updatedBy:user.uid});return {productKey:key,revision};
   });
  },
  async rule(user,hid,key,input){
   shape(input,['requestId','expectedRevision','maximum','mode']);id(key);integer(input.maximum,1,999);if(!['warn','block'].includes(input.mode))fail(400,'Invalid safety mode');
   return command(user,hid,input,`rule.saved:${key}`,true,async(tx,home,now)=>{
    const ref=home.collection('safetyRules').doc(key),prior=await tx.get(ref),product=await tx.get(db.collection('catalogue').doc(key));
    if(!product.exists||!product.data().active)fail(400,'Product unavailable');
    if(integer(input.expectedRevision,0,Number.MAX_SAFE_INTEGER)!==(prior.exists?prior.data().revision:0))fail(409,'Rule changed; reload before retrying');
    const revision=input.expectedRevision+1;tx.set(ref,{schemaVersion:1,maximum:input.maximum,mode:input.mode,deleted:false,revision,updatedAt:now,updatedBy:user.uid});return {productKey:key,revision};
   });
  }
 };
}
