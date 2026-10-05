import assert from 'node:assert/strict';
import vm from 'node:vm';
import {readFile} from 'node:fs/promises';
const source=await readFile(new URL('../web/pwa.js',import.meta.url),'utf8');
function setup({ios=false,standalone=false,dismissed=0}={}) {
 const events={},storage=new Map([['stage1.install.dismissed',String(dismissed)]]);
 const elements=Object.fromEntries(['install-panel','install-title','install-message','install-action','install-close','offline-status','loading'].map(id=>[id,{hidden:id==='install-panel',listeners:{},addEventListener(type,fn){this.listeners[type]=fn;},showModal(){this.open=true;},close(){this.open=false;},contains(target){return target===elements['install-close'];}}]));
 const window={matchMedia:()=>({matches:standalone}),addEventListener:(name,fn)=>events[name]=fn,isSecureContext:true};
 vm.runInNewContext(source,{window,navigator:{userAgent:ios?'iPhone':'Android',platform:'',maxTouchPoints:0},document:{getElementById:id=>elements[id],activeElement:{focus(){}}},localStorage:{getItem:k=>storage.get(k),setItem:(k,v)=>storage.set(k,v)},URL,location:{href:'https://example.test/'},Date});
 return {events,elements,storage};
}
const i=setup({ios:true});i.events['stage1-ready']();assert.match(i.elements['install-message'].textContent,/Safari.*Share.*Home Screen/);assert(i.elements['install-panel'].open);assert(i.elements['install-action'].hidden);
i.elements['install-close'].listeners.click();assert(i.elements['install-panel'].hidden);assert(Number(i.storage.get('stage1.install.dismissed'))>0);
const installed=setup({standalone:true});installed.events['stage1-ready']();assert(installed.elements['install-panel'].hidden);
const quiet=setup({dismissed:Date.now()});quiet.events['stage1-ready']();assert(quiet.elements['install-panel'].hidden);
const a=setup();let prompted=0,prevented=0;
a.events.beforeinstallprompt({preventDefault:()=>prevented++,prompt:async()=>prompted++,userChoice:Promise.resolve({outcome:'accepted'})});assert.equal(prevented,1);assert(!a.elements['install-action'].hidden);
await a.elements['install-action'].listeners.click();assert.equal(prompted,1);assert(a.elements['install-panel'].hidden);
let stopped=false;a.events.pointerdown({target:a.elements['install-close'],stopImmediatePropagation(){stopped=true;}});assert(stopped);
console.log('PASS: iPhone instructions, Android user-triggered prompt, standalone suppression, dismissal persistence and native touch isolation.');
