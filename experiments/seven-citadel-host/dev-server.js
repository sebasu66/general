import http from 'node:http';
import { readFile, stat } from 'node:fs/promises';
import { extname, join, normalize } from 'node:path';

const root = process.cwd();
const port = Number(process.env.PORT || 4173);
const types = {'.html':'text/html; charset=utf-8','.js':'text/javascript; charset=utf-8','.css':'text/css; charset=utf-8','.json':'application/json; charset=utf-8','.svg':'image/svg+xml','.webp':'image/webp','.png':'image/png'};

http.createServer(async (req,res) => {
  try {
    const pathname = decodeURIComponent(new URL(req.url,'http://localhost').pathname);
    const rel = pathname === '/' ? 'index.html' : pathname.replace(/^\/+/, '');
    const file = normalize(join(root, rel));
    if (!file.startsWith(normalize(root))) throw new Error('invalid path');
    const info = await stat(file);
    const target = info.isDirectory() ? join(file,'index.html') : file;
    const body = await readFile(target);
    res.writeHead(200, {'content-type':types[extname(target)] || 'application/octet-stream','cache-control':'no-store'});
    res.end(body);
  } catch {
    res.writeHead(404, {'content-type':'text/plain; charset=utf-8'});
    res.end('Not found');
  }
}).listen(port,'127.0.0.1',()=>console.log(`Seven Citadel: http://127.0.0.1:${port}`));
