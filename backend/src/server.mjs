import http from 'node:http';
import {pathToFileURL} from 'node:url';
import {listService} from './lists.mjs';
import {readService} from './reads.mjs';
import {pilotAuth} from './pilot-auth.mjs';
import {localAdmin} from './admin.mjs';
import {ApiError,householdService} from './households.mjs';
export function apiServer({db,auth}) {
 const reads=readService(db),lists=listService(db),service=householdService(db),limits=new Map();
 return http.createServer({requestTimeout:10000,headersTimeout:10000,maxHeaderSize:8192},async(req,res)=>{
  res.setHeader('Content-Type','application/json');res.setHeader('Cache-Control','no-store');res.setHeader('X-Content-Type-Options','nosniff');
  const send=(status,data)=>{res.writeHead(status);res.end(JSON.stringify(data));};
  try {
   if(req.url==='/health'&&req.method==='GET')return send(200,{status:'ok',mode:'local-emulators'});
   if(req.method!=='POST')throw new ApiError(405,'Use POST');
   // No cross-origin cookie or credential support. Client integration will proxy /api.
   if(req.headers.origin&&req.headers.origin!==`http://${req.headers.host}`)throw new ApiError(403,'Origin not allowed');
   if(!req.headers['content-type']?.startsWith('application/json'))throw new ApiError(415,'Use application/json');
   const chunks=[];let bytes=0;for await(const part of req){bytes+=part.length;if(bytes>16384)throw new ApiError(413,'Request too large');chunks.push(part);}
   const body=Buffer.concat(chunks).toString('utf8');
   let input;try{input=JSON.parse(body);}catch{throw new ApiError(400,'Invalid JSON');}
   if(req.url==='/api/login'&&auth.login){
    const key='ip:'+req.socket.remoteAddress,now=Date.now(),entry=limits.get(key);
    const counter=entry&&entry.until>now?entry:{count:0,until:now+60000};limits.set(key,counter);
    if(++counter.count>10)throw new ApiError(429,'Too many login attempts; wait a minute');
    return send(200,await auth.login(input));
   }
   const token=/^Bearer ([^ ]+)$/.exec(req.headers.authorization||'')?.[1];if(!token)throw new ApiError(401,'Sign in required');
   let user;try{user=await auth.verifyIdToken(token,true);}catch{throw new ApiError(401,'Invalid or expired session');}
   if((user.authenticated!==true&&user.email_verified!==true))throw new ApiError(403,'Authenticated account required');
   const now=Date.now();for(const [key,v]of limits)if(v.until<=now)limits.delete(key);
   const limit=limits.get(user.uid)||{count:0,until:now+60000};if(++limit.count>30)throw new ApiError(429,'Too many requests; try again shortly');limits.set(user.uid,limit);
   if(user.mustChangePassword && !['/api/password','/api/logout'].includes(req.url))throw new ApiError(403,'Change your temporary password first');
   const route=new URL(req.url,'http://local').pathname;let result;
   if(route==='/api/me')result=await reads.me(user);
   else if(/^\/api\/households\/[a-zA-Z0-9_-]+\/snapshot$/.test(route))result=await reads.snapshot(user,route.split('/')[3],input);
   else if(route==='/api/logout'&&auth.logout)result=await auth.logout(token);
   else if(route==='/api/password'&&auth.change)result=await auth.change(user,input);
   else if(route==='/api/admin/accounts'&&auth.create)result=await auth.create(user,input);
   else if(route==='/api/admin/reset'&&auth.reset)result=await auth.reset(user,input);
   else if(/^\/api\/admin\/households\/[a-zA-Z0-9_-]+\/caregiver$/.test(route)&&auth.caregiver)result=await auth.caregiver(user,route.split('/')[4],input);
   else if(route==='/api/households')result=await service.create(user,input);
   else if(route==='/api/invitations/redeem')result=await service.redeem(user,input);
   else if (/^\/api\/households\/[a-zA-Z0-9_-]+\/(lists|safety-rules)(\/|$)/.test(route)) {
    const parts=route.split('/').slice(3),hid=parts[0];
    if(parts[1]==='lists'&&parts.length===3&&parts[2]==='read')result=await reads.lists(user,hid);
    else if(parts[1]==='safety-rules'&&parts.length===4&&parts[3]==='delete')result=await lists.deleteRule(user,hid,parts[2],input);
    else if(parts[1]==='safety-rules'&&parts.length===3)result=await lists.rule(user,hid,parts[2],input);
    else if(parts[1]==='lists'&&parts.length===2)result=await lists.create(user,hid,input);
    else if(parts[1]==='lists'&&parts[3]==='items'&&parts.length===4)result=await lists.save(user,hid,parts[2],input);
    else if(parts[1]==='lists'&&parts[3]==='items'&&parts.length===6&&['delete','restore'].includes(parts[5]))result=await lists[parts[5]==='delete'?'remove':'restore'](user,hid,parts[2],parts[4],input);
    else throw new ApiError(404,'Endpoint not found');
   }
   else {
    const match=/^\/api\/households\/([a-zA-Z0-9_-]+)\/(invitations|transfer|members\/([a-zA-Z0-9_-]+))$/.exec(route);
    if(!match)throw new ApiError(404,'Endpoint not found');
    result=match[2]==='invitations'?await service.invite(user,match[1],input):match[2]==='transfer'?await service.transfer(user,match[1],input):await service.member(user,match[1],match[3],input);
   }
   send(200,result);
  }catch(error){send(error instanceof ApiError?error.status:500,{error:error instanceof ApiError?error.message:'Request failed'});}
 });
}
if(import.meta.url===pathToFileURL(process.argv[1]||'').href){
 const context=localAdmin('local-api');
 const server=apiServer({db:context.db,auth:pilotAuth(context.db)});
 server.listen(Number(process.env.PORT||8787),'127.0.0.1',()=>console.log('Local household API: http://127.0.0.1:8787'));
}
