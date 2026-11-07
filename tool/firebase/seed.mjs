import {readFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {initializeTestEnvironment} from '@firebase/rules-unit-testing';
import {doc,setDoc} from 'firebase/firestore';
import {resolve} from 'node:path';
export function cityDocument() {
  const manifest=JSON.parse(readFileSync(new URL('../../assets/city/arequipa/manifest.json',import.meta.url),'utf8'));
  const config=JSON.parse(readFileSync(new URL('../build_city_pack/config/arequipa.json',import.meta.url),'utf8'));
  const [minLat,minLng,maxLat,maxLng]=manifest.provenance.bbox;
  return {code:config.city_code,name:config.city_name,region:'Arequipa, Perú',active:true,
    center_lat:(minLat+maxLat)/2,center_lng:(minLng+maxLng)/2,centerSource:'installed_pack_bbox_midpoint',
    dataVersion:manifest.version,dataSha256:manifest.sha256,dataBytes:manifest.size_bytes,
    schemaVersion:manifest.schema_version,dataDate:manifest.date,updateAvailable:false};
}
export async function seedCity(environment) {
  await environment.withSecurityRulesDisabled(async context=>setDoc(doc(context.firestore(),'cities/arequipa'),cityDocument()));
}
if(process.argv[1] && resolve(process.argv[1])===fileURLToPath(import.meta.url)) {
  const host=process.env.FIRESTORE_EMULATOR_HOST;
  const project=process.env.GCLOUD_PROJECT;
  if(!host || !/^127\.0\.0\.1:\d+$/.test(host) || !project?.startsWith('demo-')) {
    throw Error('Seed restricted to a loopback Firestore emulator and a demo- project. No cloud writes.');
  }
  const [hostname,port]=host.split(':');
  const environment=await initializeTestEnvironment({projectId:project,firestore:{host:hostname,port:Number(port)}});
  try {await seedCity(environment);console.log('Seeded cities/arequipa in local emulator:',project);}
  finally {await environment.cleanup();}
}
