import http from 'node:http';
import crypto from 'node:crypto';

const PORT=Number(process.env.PORT||10000);
const API_KEY=process.env.PUBLISHER_API_KEY||'';
const HERE_API='https://here.now/api/v1';
const json=(res,status,obj)=>{res.writeHead(status,{'content-type':'application/json','access-control-allow-origin':'*'});res.end(JSON.stringify(obj));};
const body=async req=>{const chunks=[];let n=0;for await(const c of req){n+=c.length;if(n>12*1024*1024)throw new Error('payload too large');chunks.push(c)}return JSON.parse(Buffer.concat(chunks).toString('utf8')||'{}')};
const auth=req=>!API_KEY||req.headers.authorization===`Bearer ${API_KEY}`;
async function call(url,opts={}){const r=await fetch(url,opts);const text=await r.text();let data;try{data=JSON.parse(text)}catch{data=text}if(!r.ok)throw new Error(`${r.status} ${typeof data==='string'?data:JSON.stringify(data)}`);return data}
function normalizeFiles(files){return files.map(f=>{const bytes=Buffer.from(f.base64,'base64');return{path:String(f.path).replace(/^\/+/,''),bytes,size:bytes.length,sha256:crypto.createHash('sha256').update(bytes).digest('hex'),contentType:f.contentType||'application/octet-stream'}})}
async function publish(input){const files=normalizeFiles(input.files||[]);if(!files.length)throw new Error('files required');const manifest=files.map(({path,size,sha256})=>({path,size,sha256}));const headers={'content-type':'application/json'};if(input.claimToken)headers.authorization=`Bearer ${input.claimToken}`;
const init=await call(`${HERE_API}/publish`,{method:'POST',headers,body:JSON.stringify({site:input.site||undefined,files:manifest})});
const uploads=init.uploads||init.files||[];await Promise.all(uploads.map(async u=>{const f=files.find(x=>x.path===(u.path||u.name));if(!f)return;const url=u.uploadUrl||u.url;if(!url)return;const r=await fetch(url,{method:'PUT',headers:{'content-type':f.contentType},body:f.bytes});if(!r.ok)throw new Error(`upload ${f.path}: ${r.status} ${await r.text()}`)}));
const finalizeUrl=init.finalizeUrl||init.finalize?.url||`${HERE_API}/publish/${init.versionId}/finalize`;const done=await call(finalizeUrl,{method:'POST',headers:{'content-type':'application/json',...(input.claimToken?{authorization:`Bearer ${input.claimToken}`}:{})},body:JSON.stringify({})});return{init,done}}
const server=http.createServer(async(req,res)=>{try{if(req.method==='OPTIONS'){res.writeHead(204,{'access-control-allow-origin':'*','access-control-allow-headers':'authorization,content-type','access-control-allow-methods':'GET,POST,OPTIONS'});return res.end()}if(req.url==='/health'&&req.method==='GET')return json(res,200,{ok:true,service:'here-now-publisher'});if(req.url==='/publish'&&req.method==='POST'){if(!auth(req))return json(res,401,{error:'unauthorized'});return json(res,200,await publish(await body(req)))}return json(res,404,{error:'not found'})}catch(e){console.error(e);return json(res,500,{error:e.message})}});
server.listen(PORT,'0.0.0.0',()=>console.log(`publisher listening on ${PORT}`));
