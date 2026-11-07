import {readFileSync} from 'node:fs';
import {before,after,beforeEach,test} from 'node:test';
import assert from 'node:assert/strict';
import {initializeTestEnvironment,assertSucceeds,assertFails} from '@firebase/rules-unit-testing';
import {doc,setDoc,getDoc,updateDoc,deleteDoc,writeBatch,serverTimestamp,Timestamp,collection,getDocs,query,where} from 'firebase/firestore';
import {seedCity,cityDocument} from './seed.mjs';
let env;
const project=process.env.GCLOUD_PROJECT;
if(!project?.startsWith('demo-') || !process.env.FIRESTORE_EMULATOR_HOST?.startsWith('127.0.0.1:')) throw Error('Only local demo emulator tests allowed.');
const real=uid=>env.authenticatedContext(uid,{firebase:{sign_in_provider:'password'}}).firestore();
const anon=uid=>env.authenticatedContext(uid,{firebase:{sign_in_provider:'anonymous'}}).firestore();
const publicDb=()=>env.unauthenticatedContext().firestore();
const report=(uid='alice',overrides={})=>({uid,cityCode:'arequipa',type:'missing_stop',description:'Fixture de prueba',latitude:-16.4,longitude:-71.5,createdAt:serverTimestamp(),confirmations:0,...overrides});
const feedback=(uid='alice',overrides={})=>({uid,kind:'bug',message:'Fixture de prueba',city_code:'arequipa',created_at:serverTimestamp(),app_version:'1.0.0+1',device_model:'Test Windows',data_version:2,...overrides});
const score=(uid='alice',overrides={})=>({uid,displayName:'Prueba',score:100,durationMs:90000,createdAt:serverTimestamp(),updatedAt:serverTimestamp(),...overrides});
const scorePath='leaderboards/arequipa_2026-W45/scores/';
async function confirm(db,uid,id='r1',changes={confirmations:1}) {
  const batch=writeBatch(db);
  batch.update(doc(db,'reports',id),changes);
  batch.set(doc(db,'reports',id,'confirmations',uid),{uid,createdAt:serverTimestamp()});
  return batch.commit();
}
before(async()=>{
  const [host,port]=process.env.FIRESTORE_EMULATOR_HOST.split(':');
  env=await initializeTestEnvironment({projectId:project,firestore:{host,port:Number(port),rules:readFileSync(new URL('../../firestore.rules',import.meta.url),'utf8')}});
});
beforeEach(async()=>env.clearFirestore());
after(async()=>env?.cleanup());
test('city seed uses installed manifest and public reads, clients cannot write cities',async()=>{
  await seedCity(env);const db=publicDb();const result=await assertSucceeds(getDoc(doc(db,'cities/arequipa')));
  assert.equal(result.data().dataVersion,2);assert.equal(result.data().dataSha256,cityDocument().dataSha256);
  assert.equal(result.data().updateAvailable,false);assert.equal('dataUrl' in result.data(),false);
  await assertFails(setDoc(doc(real('alice'),'cities/arequipa'),{active:false}));
});
test('owner can read/write/delete only their user document and nested favorites',async()=>{
  const alice=real('alice');await assertSucceeds(setDoc(doc(alice,'users/alice'),{displayName:'Alice'}));
  await assertSucceeds(setDoc(doc(alice,'users/alice/library/home'),{name:'Casa de prueba'}));
  await assertSucceeds(getDoc(doc(alice,'users/alice/library/home')));
  await assertFails(getDoc(doc(real('bob'),'users/alice')));
  await assertFails(getDoc(doc(real('bob'),'users/alice/library/home')));
  await assertFails(setDoc(doc(real('bob'),'users/alice/library/work'),{name:'Ajeno'}));
  await assertFails(deleteDoc(doc(real('bob'),'users/alice/library/home')));
  await assertFails(getDoc(doc(publicDb(),'users/alice')));
  await assertSucceeds(deleteDoc(doc(alice,'users/alice/library/home')));
});
test('anonymous users can store only their own private library',async()=>{
  const db=anon('guest');await assertSucceeds(setDoc(doc(db,'users/guest/library/home'),{name:'Prueba'}));
  await assertFails(getDoc(doc(db,'users/alice/library/home')));
});
test('real users create valid reports readable without login',async()=>{
  await assertSucceeds(setDoc(doc(real('alice'),'reports/r1'),report()));
  await assertSucceeds(getDoc(doc(publicDb(),'reports/r1')));
  await assertSucceeds(getDocs(query(collection(publicDb(),'reports'),where('cityCode','==','arequipa'))));
});
test('anonymous and unauthenticated reports are denied',async()=>{
  await assertFails(setDoc(doc(anon('guest'),'reports/r1'),report('guest')));
  await assertFails(setDoc(doc(publicDb(),'reports/r1'),report()));
});
test('forged report authors are denied',async()=>{
  await assertFails(setDoc(doc(real('alice'),'reports/r1'),report('bob')));
});
for(const [name,change] of Object.entries({unknownType:{type:'invented'},longMessage:{description:'x'.repeat(501)},shortMessage:{description:'x'},badLatitude:{latitude:91},badLongitude:{longitude:-181},badType:{latitude:'-16.4'},otherCity:{cityCode:'lima'},counterPreset:{confirmations:1},badTimestamp:{createdAt:Timestamp.fromMillis(0)},extraField:{admin:true},longStop:{stopId:'x'.repeat(129)}})) {
 test(`report rejects ${name}`,async()=>assertFails(setDoc(doc(real('alice'),'reports/r1'),report('alice',change))));
}
test('report delete is restricted to its author and body edits are denied',async()=>{
  const alice=real('alice');await setDoc(doc(alice,'reports/r1'),report());
  await assertFails(deleteDoc(doc(real('bob'),'reports/r1')));
  await assertFails(updateDoc(doc(alice,'reports/r1'),{description:'Cambio'}));
  await assertSucceeds(deleteDoc(doc(alice,'reports/r1')));
});
test('confirmation increments exactly once with its document in the same batch',async()=>{
  await setDoc(doc(real('alice'),'reports/r1'),report());const bob=real('bob');
  await assertSucceeds(confirm(bob,'bob'));
  assert.equal((await getDoc(doc(publicDb(),'reports/r1'))).data().confirmations,1);
  await assertFails(confirm(bob,'bob','r1',{confirmations:2}));
  await assertFails(deleteDoc(doc(bob,'reports/r1/confirmations/bob')));
});
test('counter without marker and marker without increment are both denied',async()=>{
  await setDoc(doc(real('alice'),'reports/r1'),report());const bob=real('bob');
  await assertFails(updateDoc(doc(bob,'reports/r1'),{confirmations:1}));
  await assertFails(setDoc(doc(bob,'reports/r1/confirmations/bob'),{uid:'bob',createdAt:serverTimestamp()}));
});
test('anonymous, forged confirmation uid, wrong increment and extra report edits are denied',async()=>{
  await setDoc(doc(real('alice'),'reports/r1'),report());
  await assertFails(confirm(anon('guest'),'guest'));
  await assertFails(confirm(real('bob'),'carol'));
  await assertFails(confirm(real('bob'),'bob','r1',{confirmations:2}));
  await assertFails(confirm(real('bob'),'bob','r1',{confirmations:1,description:'Cambio ilegítimo'}));
});
test('two different accounts can confirm but cannot read another private marker',async()=>{
  await setDoc(doc(real('alice'),'reports/r1'),report());
  await assertSucceeds(confirm(real('bob'),'bob'));
  await assertSucceeds(confirm(real('carol'),'carol','r1',{confirmations:2}));
  await assertSucceeds(getDoc(doc(real('bob'),'reports/r1/confirmations/bob')));
  await assertFails(getDoc(doc(real('alice'),'reports/r1/confirmations/bob')));
});
test('expired reports cannot receive new confirmations',async()=>{
  await env.withSecurityRulesDisabled(async c=>setDoc(doc(c.firestore(),'reports/r1'),report('alice',{createdAt:Timestamp.fromMillis(Date.now()-73*3600000)})));
  await assertFails(confirm(real('bob'),'bob'));
});
test('feedback is create-only for authenticated users, including guests, and is never client-readable',async()=>{
  const alice=real('alice');await assertSucceeds(setDoc(doc(alice,'feedback/f1'),feedback()));
  await assertSucceeds(setDoc(doc(anon('guest'),'feedback/f2'),feedback('guest')));
  for(const db of [alice,real('bob'),publicDb()]) await assertFails(getDoc(doc(db,'feedback/f1')));
  await assertFails(getDocs(collection(alice,'feedback')));
  await assertFails(updateDoc(doc(alice,'feedback/f1'),{message:'Otro'}));
  await assertFails(deleteDoc(doc(alice,'feedback/f1')));
});
test('feedback rejects no auth, forged uid and invalid metadata/fields',async()=>{
  await assertFails(setDoc(doc(publicDb(),'feedback/f1'),feedback()));
  for(const change of [{uid:'bob'},{kind:'invalid'},{message:'x'.repeat(2001)},{app_version:3},{data_version:0},{device_model:''},{extra:true}]) {
    await assertFails(setDoc(doc(real('alice'),'feedback/f1'),feedback('alice',change)));
  }
});
test('leaderboard is public and accepts only the owner personal best',async()=>{
  const alice=real('alice');await assertSucceeds(setDoc(doc(alice,scorePath+'alice'),score()));
  await assertSucceeds(getDoc(doc(publicDb(),scorePath+'alice')));
  await assertSucceeds(getDocs(collection(publicDb(),'leaderboards/arequipa_2026-W45/scores')));
  await assertFails(setDoc(doc(real('bob'),scorePath+'alice'),score('alice',{score:200})));
  await assertFails(updateDoc(doc(alice,scorePath+'alice'),{score:99,updatedAt:serverTimestamp()}));
  await assertFails(updateDoc(doc(alice,scorePath+'alice'),{score:100,updatedAt:serverTimestamp()}));
  await assertSucceeds(updateDoc(doc(alice,scorePath+'alice'),{score:150,updatedAt:serverTimestamp()}));
  await assertFails(deleteDoc(doc(real('bob'),scorePath+'alice')));
  await assertSucceeds(deleteDoc(doc(alice,scorePath+'alice')));
});
test('leaderboard rejects impossible scores, invalid durations and wrong paths',async()=>{
  for(const change of [{score:5001},{score:-1},{score:10.5},{score:5000,durationMs:1000},{durationMs:120001},{uid:'bob'},{displayName:''},{displayName:'x'.repeat(61)},{extra:true}]) {
    await assertFails(setDoc(doc(real('alice'),scorePath+'alice'),score('alice',change)));
  }
  await assertFails(setDoc(doc(publicDb(),scorePath+'alice'),score()));
  await assertFails(setDoc(doc(real('alice'),'leaderboards/lima_2026-W45/scores/alice'),score()));
  await assertFails(setDoc(doc(real('alice'),'leaderboards/arequipa_2026-W99/scores/alice'),score()));
});
test('unknown collections are denied by default',async()=>{
  await assertFails(setDoc(doc(real('alice'),'admin/settings'),{owner:'alice'}));
  await assertFails(getDoc(doc(publicDb(),'admin/settings')));
});
