import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import vm from 'node:vm';
const template=await readFile(new URL('../web/sw.template.js',import.meta.url),'utf8');
function worker({fail=false}={}) {
 const events={},stores=new Map([['stage1-pwa-old',new Map()],['unrelated',new Map()]]);let skipped=0,claimed=0,network=0;
 const context={URL,Request,fetch:async()=>{network++;return 'network';},caches:{
  open:async name=>{if(!stores.has(name))stores.set(name,new Map());return {addAll:async requests=>{if(fail)throw Error('offline');for(const r of requests)stores.get(name).set(r.url,'cached:'+r.url);},match:async key=>stores.get(name).get(key)};},
  keys:async()=>[...stores.keys()],delete:async key=>stores.delete(key)
 },self:{location:{href:'https://example.test/app/sw.js'},clients:{claim:async()=>claimed++},skipWaiting:()=>skipped++,addEventListener:(type,fn)=>events[type]=fn}};
 vm.runInNewContext(template.replace('__VERSION__','test').replace('__FILES__',JSON.stringify(['index.html','main.dart.js'])),context);
 const dispatch=async(type,extra={})=>{let result;events[type]({waitUntil:p=>result=p,respondWith:p=>result=p,...extra});return await result;};
 return {dispatch,stores,stats:()=>({skipped,claimed,network})};
}
const w=worker();await w.dispatch('install');assert.equal(w.stats().skipped,0);await w.dispatch('activate');
assert(!w.stores.has('stage1-pwa-old'));assert(w.stores.has('unrelated'));assert.equal(w.stats().claimed,1);
assert.equal(await w.dispatch('fetch',{request:{method:'GET',mode:'navigate',url:'https://example.test/app/?install=1'}}),'cached:https://example.test/app/index.html');
assert.equal(await w.dispatch('fetch',{request:{method:'GET',mode:'cors',url:'https://example.test/app/main.dart.js?v=1'}}),'cached:https://example.test/app/main.dart.js');
assert.equal(w.stats().network,0);
assert.equal(await w.dispatch('fetch',{request:{method:'POST',url:'https://example.test/app/'}}),undefined);
assert.equal(await w.dispatch('fetch',{request:{method:'GET',url:'https://external.test/x'}}),undefined);
await w.dispatch('message',{data:{type:'ACTIVATE_UPDATE'}});assert.equal(w.stats().skipped,1);
const broken=worker({fail:true});await assert.rejects(broken.dispatch('install'));assert(!broken.stores.has('stage1-pwa-test'));assert(broken.stores.has('stage1-pwa-old'));
const manifest=JSON.parse(await readFile(new URL('../web/manifest.json',import.meta.url)));
assert.equal(manifest.display,'standalone');assert.equal(manifest.scope,'./');
const generated=await readFile(new URL('../build/web/sw.js',import.meta.url),'utf8');
assert(!generated.includes('__FILES__'));assert(!generated.includes('"sw.template.js"'));
console.log('PASS: atomic offline cache, subpath navigation, query assets, failed update recovery, explicit activation, unrelated cache isolation, manifest and packaged worker.');
