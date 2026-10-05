import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import vm from 'node:vm';
import {webcrypto} from 'node:crypto';

const source=await readFile(new URL('../web/local_services.js',import.meta.url),'utf8');
const storage=new Map();
let quota=false;
let transaction=Promise.resolve();
const locks={request:(_name,fn)=>{const next=transaction.then(fn);transaction=next.catch(()=>{});return next;}};
function runtime(extra={}) {
  const context={crypto:webcrypto,TextEncoder,TextDecoder,Uint8Array,atob,btoa,setTimeout,clearTimeout,
    navigator:{locks},localStorage:{
      getItem:k=>storage.get(k)??null,
      setItem:(k,v)=>{if(quota)throw Error('Storage full');storage.set(k,v);},
    },...extra};
  context.window=context;
  vm.runInNewContext(source,context);
  return async(action,input={})=>JSON.parse(await context.localServices(action,JSON.stringify(input)));
}
const call=runtime();
const pass='test-only long passphrase';
assert.equal((await call('status')).exists,false);
assert.equal((await call('create',{password:'short',data:'{}'})).ok,false);
assert.equal((await call('create',{password:pass,data:JSON.stringify({item:'Private milk'})})).ok,true);
const raw=[...storage.values()][0];
assert(!raw.includes('Private milk'));assert(!raw.includes(pass));
assert.equal((await call('create',{password:pass,data:'{}'})).ok,false);
await call('lock');
assert.equal((await call('save',{data:'{}'})).ok,false);
assert.equal((await call('login',{password:'wrong password'})).ok,false);
assert.equal(JSON.parse((await call('login',{password:pass})).data).item,'Private milk');
await call('save',{data:JSON.stringify({item:'Apples'})});
const reload=runtime();
assert.equal(JSON.parse((await reload('login',{password:pass})).data).item,'Apples');
quota=true;
assert.equal((await reload('save',{data:'lost'})).ok,false);
quota=false;
assert.equal(JSON.parse((await runtime()('login',{password:pass})).data).item,'Apples');
await reload('save',{data:JSON.stringify({item:'Newer tab'})});
assert.equal((await call('save',{data:'stale overwrite'})).ok,false);
assert.match((await reload('voice')).error,/Offline voice entry is unavailable/);
assert.equal((await reload('enableDevice')).ok,false);
const key=[...storage.keys()][0];
const saved=storage.get(key);const tampered=JSON.parse(saved);
tampered.data.cipher=tampered.data.cipher.slice(0,-4)+'AAAA';
storage.set(key,JSON.stringify(tampered));
assert.equal((await runtime()('login',{password:pass})).ok,false);
storage.set(key,saved);
// Simulated PRF authenticator verifies key wrapping; not a hardware biometric test.
const prf=new Uint8Array(32).fill(7);
const cred={rawId:new Uint8Array([1,2,3]),getClientExtensionResults:()=>({prf:{results:{first:prf.buffer}}})};
const device=runtime({PublicKeyCredential:{},navigator:{locks,credentials:{
  create:async()=>cred,get:async()=>cred}}});
await device('login',{password:pass});
assert.equal((await device('enableDevice')).ok,true);
await device('lock');
assert.equal((await device('deviceLogin')).ok,true);
assert.equal((await device('disableDevice')).ok,true);
await device('lock');
assert.equal((await device('deviceLogin')).ok,false);
console.log('PASS: encrypted creation, password unlock, refresh persistence, locked writes, tamper rejection, quota failure, stale-tab rejection, unsupported voice/device, simulated PRF wrap/unwrap.');

// Concurrent origin transactions must not silently overwrite another tab.
const a=runtime(), b=runtime();
await a('login',{password:pass}); await b('login',{password:pass});
const concurrent=await Promise.all([a('save',{data:'first'}),b('save',{data:'second'})]);
assert.equal(concurrent.filter(r=>r.ok).length,1);
assert.equal((await b('disableDevice')).ok,false);
assert.equal((await runtime({navigator:{}})('login',{password:pass})).ok,false);
let releaseAvailability;
let starts=0;
class Speech {start(){starts++;}}
Speech.prototype.processLocally=false;
Speech.available=()=>new Promise(resolve=>releaseAvailability=resolve);
const speech=runtime({SpeechRecognition:Speech});
const pendingVoice=speech('voice');
await speech('cancelVoice'); releaseAvailability('available');
assert.equal((await pendingVoice).ok,false); assert.equal(starts,0);
console.log('PASS: concurrent writes, stale device change, missing Web Locks, cancellation before speech availability.');

// The wireframe store never overwrites the previous encrypted account.
const vaultBefore=storage.get(key);
assert.equal((await call('wireframeLoad')).data,null);
assert.equal((await call('wireframeSave',{revision:0,data:'{"items":["Milk"]}'})).ok,true);
assert.equal((await runtime()('wireframeLoad')).data,'{"items":["Milk"]}');
assert.equal((await call('wireframeSave',{revision:0,data:'stale'})).ok,false);
quota=true;
assert.equal((await call('wireframeSave',{revision:1,data:'lost'})).ok,false);
quota=false;
assert.equal((await call('wireframeLoad')).revision,1);
assert.equal(storage.get(key),vaultBefore);
console.log('PASS: wireframe persistence, stale-tab protection, quota failure, legacy vault isolation.');
