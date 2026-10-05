import http from 'node:http';
import https from 'node:https';
import {readFile,stat} from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../build/web');
const port=Number(process.env.PORT||5188);
const types={'.html':'text/html','.js':'text/javascript','.json':'application/json','.wasm':'application/wasm','.css':'text/css','.png':'image/png','.svg':'image/svg+xml','.ttf':'font/ttf'};
const handler=async(req,res)=>{
 try {
  if(req.url.startsWith('/api/')) {
    const origin=req.headers.origin;
    const expected=(process.env.TLS_CERT?'https':'http')+'://'+req.headers.host;
    if(origin&&origin!==expected){res.writeHead(403);res.end('Origin denied');return;}
    const headers={...req.headers,host:'127.0.0.1:8787'};delete headers.origin;
    const upstream=http.request({hostname:'127.0.0.1',port:8787,path:req.url,method:req.method,headers},reply=>{res.writeHead(reply.statusCode,reply.headers);reply.pipe(res);});
    upstream.setTimeout(10000,()=>upstream.destroy());
    upstream.on('error',()=>{if(!res.headersSent)res.writeHead(503,{'Content-Type':'application/json'});res.end(JSON.stringify({error:'Local backend unavailable. Start the backend and retry.'}));});req.pipe(upstream);return;
  }
  const pathname=decodeURIComponent(new URL(req.url,'http://local').pathname);
  const target=path.resolve(root,'.'+(pathname.endsWith('/')?pathname+'index.html':pathname));
  if(!target.startsWith(root+path.sep)) {res.writeHead(403);res.end();return;}
  if(!['GET','HEAD'].includes(req.method)) {res.writeHead(405);res.end();return;}
  const info=await stat(target); if(!info.isFile()) throw Error('missing');
  res.writeHead(200,{'Content-Type':types[path.extname(target)]||'application/octet-stream','Cache-Control':'no-cache','X-Content-Type-Options':'nosniff','Referrer-Policy':'no-referrer'});
  res.end(req.method==='HEAD'?undefined:await readFile(target));
 }catch{res.writeHead(404);res.end('Not found');}
};
const secure=process.env.TLS_CERT&&process.env.TLS_KEY;
const server=secure?https.createServer({cert:await readFile(process.env.TLS_CERT),key:await readFile(process.env.TLS_KEY)},handler):http.createServer(handler);
server.listen(port,process.env.HOST||'127.0.0.1',()=>console.log(`Stage 1 ${secure?'https':'http'} server on port ${port}`));
