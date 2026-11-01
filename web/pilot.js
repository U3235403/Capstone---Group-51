(() => {
 let token=null,selected=null,snapshot=null,pending=null;
 const ids=new Map();let next=1;
 async function api(path,body={}) {
  let response;try{response=await fetch(path,{method:'POST',headers:{'Content-Type':'application/json',...(token?{Authorization:'Bearer '+token}:{})},body:JSON.stringify(body),cache:'no-store'});}catch{throw Error('Connection unavailable. Reconnect and press Retry.');}
  const data=await response.json();if(!response.ok){if(response.status===401){token=null;snapshot=null;}const error=Error(data.error||'Request failed');error.status=response.status;throw error;}return data;
 }
 async function load(){
  if(!selected)throw Error('Choose a shared list first');
  snapshot=await api(`/api/households/${selected.householdId}/snapshot`,{listId:selected.listId});
  const items=snapshot.items.filter(x=>!x.deleted).map(x=>{if(!ids.has(x.id))ids.set(x.id,next++);return {id:ids.get(x.id),name:x.name,quantity:x.quantity,notes:x.notes,purchased:x.purchased,favourite:x.favourite,category:x.category,assignee:x.assigneeUid||'',unit:x.unit};});
  const rules=Object.fromEntries(snapshot.rules.filter(x=>!x.deleted).map(x=>[selected.catalogue.find(p=>p.id===x.id)?.name||x.id,{maximum:x.maximum,block:x.mode==='block'}]));
  return {items,rules,revision:snapshot.list.revision,role:snapshot.role};
 }
 async function write(path,body){
  if(pending)throw Error('Resolve the previous save with Retry before editing again.');
  pending={path,body:{...body,requestId:crypto.randomUUID()}};return retry();
 }
 async function retry(){
  if(pending){try{await api(pending.path,pending.body);pending=null;}catch(e){if(e.status){pending=null;try{await load();}catch{}}throw e;}}
  return load();
 }
 async function execute(action,input){
  if(action==='login'){const r=await api('/api/login',input);token=r.token;return r;}
  if(action==='logout'){try{if(token)await api('/api/logout');}finally{token=null;selected=null;snapshot=null;pending=null;ids.clear();}return {};}
  if(action==='request')return api(input.path,input.body);
  if(action==='select'){selected=input;ids.clear();next=1;pending=null;return load();}
  if(action==='load')return load();
  if(action==='retry')return retry();
  const base=`/api/households/${selected.householdId}`;
  if(action==='put'||action==='toggle'){
      const existing = input.id === undefined ? undefined : snapshot.items.find(x => !x.deleted && ids.get(x.id) === input.id);
      const product = selected.catalogue.find(x => x.name === input.name || x.id === existing?.productKey); if (!product) throw Error('Product unavailable');
      const rule = snapshot.rules.find(x => x.id === product.id);
   return write(`${base}/lists/${selected.listId}/items`,{expectedRevision:snapshot.list.revision,ruleRevision:rule?.revision||0,productKey:product.id,quantity:input.quantity??existing.quantity,purchased:action==='toggle'?!existing.purchased:existing?.purchased||false,favourite:existing?.favourite||false,notes:existing?.notes||'',assigneeUid:existing?.assigneeUid||null,confirmed:input.confirmed===true,...(existing?{itemId:existing.id}:{})});
  }
  if(action==='delete'){
   const existing=snapshot.items.find(x=>ids.get(x.id)===input.id);
   if(!existing||existing.deleted)throw Error('Item unavailable');
   return write(`${base}/lists/${selected.listId}/items/${existing.id}/delete`,{expectedRevision:snapshot.list.revision});
  }
  if(action==='rule'){
   const product=selected.catalogue.find(x=>x.name===input.name);if(!product)throw Error('Product unavailable');
   const rule=snapshot.rules.find(x=>x.id===product.id);
   return write(`${base}/safety-rules/${product.id}${input.remove?'/delete':''}`,{expectedRevision:rule?.revision||0,...(input.remove?{}:{maximum:input.maximum,mode:input.block?'block':'warn'})});
  }
  throw Error('Unknown pilot operation');
 }
 window.pilotServices=async(action,json)=>{try{return JSON.stringify({ok:true,...await execute(action,JSON.parse(json))});}catch(e){return JSON.stringify({ok:false,error:e.message});}};
})();
