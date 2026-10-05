import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import vm from 'node:vm';
import {randomBytes,webcrypto} from 'node:crypto';
import {deleteApp} from 'firebase-admin/app';
import {localAdmin} from '../src/admin.mjs';
import {pilotAuth,passwordHash} from '../src/pilot-auth.mjs';
import {apiServer} from '../src/server.mjs';
test('browser bridge signs in, selects shared list, writes, refreshes and deletes safety rule',async()=>{
 const context=localAdmin('bridge-test'),auth=pilotAuth(context.db),username='bridge_'+randomBytes(4).toString('hex'),password='Bridge test only passphrase';
 await context.db.doc('pilotAccounts/'+username).set({...await passwordHash(password),displayName:'Bridge test',pilotAdmin:false,disabled:false,mustChangePassword:false,sessionVersion:1});
 await context.db.doc('catalogue/fresh-whole-milk').set({name:'Fresh Whole Milk',category:'Dairy & Eggs',active:true});
 const server=apiServer({db:context.db,auth});await new Promise(r=>server.listen(0,'127.0.0.1',r));const base='http://127.0.0.1:'+server.address().port;
 try{
  const window={};vm.runInNewContext(await readFile(new URL('../../web/pilot.js',import.meta.url),'utf8'),{window,crypto:webcrypto,fetch:(p,o)=>fetch(base+p,o)});
  const call=async(action,input={})=>{const r=JSON.parse(await window.pilotServices(action,JSON.stringify(input)));assert.equal(r.ok,true,JSON.stringify(r));return r;};
  await call('login',{username,password});
  const home=await call('request',{path:'/api/households',body:{name:'Bridge home',requestId:webcrypto.randomUUID()}});
  const list=await call('request',{path:`/api/households/${home.householdId}/lists`,body:{name:'Shared list',requestId:webcrypto.randomUUID()}});
  const discovery=await call('request',{path:`/api/households/${home.householdId}/lists/read`,body:{}});assert.equal(discovery.lists.length,1);
  let state=await call('select',{householdId:home.householdId,listId:list.listId,catalogue:discovery.catalogue});assert.equal(state.items.length,0);
  state=await call('put',{name:'Fresh Whole Milk',quantity:2});assert.equal(state.items[0].quantity,2);
  state=await call('toggle',{id:state.items[0].id});assert.equal(state.items[0].purchased,true);
  state=await call('rule',{name:'Fresh Whole Milk',maximum:2,block:true,remove:false});assert.equal(state.rules['Fresh Whole Milk'].block,true);
  state=await call('rule',{name:'Fresh Whole Milk',remove:true});assert.equal(state.rules['Fresh Whole Milk'],undefined);
  state=await call('load');assert.equal(state.items[0].name,'Fresh Whole Milk');
  await call('logout');const denied=JSON.parse(await window.pilotServices('load','{}'));assert.equal(denied.ok,false);
 }finally{await new Promise(r=>server.close(r));await deleteApp(context.app);}
});
