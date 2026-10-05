import {spawnSync} from 'node:child_process';
import {readFile,writeFile,readdir,rm} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
import path from 'node:path';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const flutter=process.env.FLUTTER_BIN || '/Users/ups/Documents/Flutter/flutter/bin/flutter';
if (!process.argv.includes('--package-only')) {
 const result=spawnSync(flutter,['--suppress-analytics','build','web','--release','--no-pub','--pwa-strategy=none'],{cwd:root,stdio:'inherit',env:{...process.env,FLUTTER_SUPPRESS_ANALYTICS:'true',DART_SUPPRESS_ANALYTICS:'true'}});
 if(result.status!==0) process.exit(result.status||1);
}
const dir=path.join(root,'build/web');
await rm(path.join(dir,'flutter_service_worker.js'),{force:true});
async function walk(folder='') {
 const out=[];
 for(const entry of await readdir(path.join(dir,folder),{withFileTypes:true})) {
  const name=path.posix.join(folder,entry.name);
  if(entry.isDirectory()) out.push(...await walk(name));
  else if(!['sw.js','sw.template.js','pwa-build.json','.DS_Store'].includes(entry.name) && !name.endsWith('.map')) out.push(name);
 }
 return out;
}
const files=(await walk()).sort();
const hash=createHash('sha256');
for(const name of files) hash.update(name).update(await readFile(path.join(dir,name)));
hash.update(await readFile(path.join(root,'web/sw.template.js')));
const version=hash.digest('hex').slice(0,16);
const source=(await readFile(path.join(root,'web/sw.template.js'),'utf8')).replace('__VERSION__',version).replace('__FILES__',JSON.stringify(files));
await writeFile(path.join(dir,'sw.js'),source);
await rm(path.join(dir,'sw.template.js'),{force:true});
await writeFile(path.join(dir,'pwa-build.json'),JSON.stringify({version,files:files.length},null,2));
console.log(`PWA ${version}: ${files.length} local resources cached atomically.`);
