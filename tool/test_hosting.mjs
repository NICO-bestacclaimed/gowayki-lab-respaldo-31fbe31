import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const origin='http://127.0.0.1:5005';
const generated=JSON.parse(readFileSync(new URL('../hosting/.gowayki-generated.json',import.meta.url),'utf8'));
assert.equal(generated.status,'draft');
for(const path of ['/','/privacidad/','/terminos/','/style.css']) {
  const response=await fetch(origin+path);assert.equal(response.status,200,path);
  assert.equal(response.headers.get('x-content-type-options'),'nosniff');
  assert.ok(response.headers.get('content-security-policy')?.includes("default-src 'none'"));
  const text=await response.text();assert.ok(!text.includes('{{'));
  if(path !== '/style.css')assert.ok(text.includes('Borrador local sin publicar'));
}
const data=new URL(generated.metadata.dataUrl).pathname;
const manifest=await fetch(origin+data.replace('pack.sqlite','manifest.json')).then(r=>r.json());
assert.equal(manifest.sha256,generated.metadata.dataSha256);
const pack=await fetch(origin+data,{method:'HEAD',headers:{'accept-encoding':'identity'}});
assert.equal(pack.status,200);assert.ok(pack.headers.get('cache-control')?.includes('immutable'));assert.equal(Number(pack.headers.get('content-length')),generated.metadata.dataBytes);
const page=await fetch(origin).then(r=>r.text());
const apkPath=page.match(/href="(\/downloads\/gowayki-[a-f0-9]+\.apk)"/)?.[1];
assert.ok(apkPath,'Verified release candidate was not attached');
const apk=await fetch(origin+apkPath,{method:'HEAD',headers:{'accept-encoding':'identity'}});
assert.equal(apk.status,200);assert.ok(Number(apk.headers.get('content-length'))>0);
console.log('Local Hosting verified: draft pages, security headers, manifest, pack length and APK download. No deployment.');
