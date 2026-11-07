import {readFileSync} from 'node:fs';
import {before,after,beforeEach,test} from 'node:test';
import assert from 'node:assert/strict';
import {initializeTestEnvironment,assertSucceeds,assertFails} from '@firebase/rules-unit-testing';
import {doc,setDoc,getDoc,updateDoc,deleteDoc,writeBatch,serverTimestamp,Timestamp,collection,getDocs,query,where,runTransaction,orderBy,limit,getCountFromServer} from 'firebase/firestore';
import {seedCity,cityDocument} from './seed.mjs';
import {eraseFirestoreFixture} from './erase-account.mjs';
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
  batch.set(doc(db,'users',uid,'confirmationRefs',id),{id});
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
  const alice=real('alice');await assertSucceeds(sendFeedback(alice,'f1',feedback()));
  await assertSucceeds(sendFeedback(anon('guest'),'f2',feedback('guest')));
  for(const db of [alice,real('bob'),publicDb()]) await assertFails(getDoc(doc(db,'feedback/f1')));
  await assertFails(getDocs(collection(alice,'feedback')));
  await assertFails(updateDoc(doc(alice,'feedback/f1'),{message:'Otro'}));
  await assertFails(deleteDoc(doc(alice,'feedback/f1')));
});
test('feedback rejects no auth, forged uid and invalid metadata/fields',async()=>{
  await assertFails(setDoc(doc(publicDb(),'feedback/f1'),feedback()));
  for(const change of [{uid:'bob'},{kind:'invalid'},{message:'x'.repeat(2001)},{app_version:3},{data_version:0},{device_model:''},{extra:true}]) {
    await assertFails(sendFeedback(real('alice'),'f1',feedback('alice',change),'alice'));
  }
});
test('leaderboard is public and accepts only the owner personal best',async()=>{
  const alice=real('alice');await assertSucceeds(saveScore(alice,'alice',score()));
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
    await assertFails(saveScore(real('alice'),'alice',score('alice',change)));
  }
  await assertFails(setDoc(doc(publicDb(),scorePath+'alice'),score()));
  await assertFails(setDoc(doc(real('alice'),'leaderboards/lima_2026-W45/scores/alice'),score()));
  await assertFails(setDoc(doc(real('alice'),'leaderboards/arequipa_2026-W99/scores/alice'),score()));
});
test('unknown collections are denied by default',async()=>{
  await assertFails(setDoc(doc(real('alice'),'admin/settings'),{owner:'alice'}));
  await assertFails(getDoc(doc(publicDb(),'admin/settings')));
});

// Sync protocol: each item has an independent revision and deletion marker.
const personal=(key,stamp,value,device='test')=>({key,stamp,device,value});
async function pushPersonal(db,path,local) {
 return runTransaction(db,async tx=>{
  const ref=doc(db,path),snapshot=await tx.get(ref),remote=snapshot.data();
  if(!remote || local.stamp>remote.stamp || (local.stamp===remote.stamp && local.device>remote.device)) { tx.set(ref,local);return local; }
  return remote;
 });
}
test('personal state transaction writes own item and rejects a different uid',async()=>{
 const db=real('alice'),path='users/alice/state/item';
 await assertSucceeds(pushPersonal(db,path,personal('line:a',1,true)));
 await assertFails(pushPersonal(real('bob'),path,personal('line:a',2,null)));
 await assertFails(getDocs(collection(real('bob'),'users/alice/state')));
});
test('late offline revision cannot overwrite a newer server deletion',async()=>{
 const db=real('alice'),path='users/alice/state/item';
 await pushPersonal(db,path,personal('line:a',3,null));
 const result=await pushPersonal(db,path,personal('line:a',2,true));
 assert.equal(result.value,null);assert.equal((await getDoc(doc(db,path))).data().stamp,3);
});
test('independent devices retain independent favorites and saved journeys',async()=>{
 const db=real('alice');
 await Promise.all([pushPersonal(db,'users/alice/state/line',personal('line:a',1,true,'one')),pushPersonal(db,'users/alice/state/trip',personal('library:trip',1,{fixture:true},'two'))]);
 assert.equal((await getDocs(collection(db,'users/alice/state'))).size,2);
});
test('anonymous state supports transaction sync and remains private',async()=>{
 const db=anon('guest');await assertSucceeds(pushPersonal(db,'users/guest/state/item',personal('line:a',1,true)));
 await assertFails(getDoc(doc(real('alice'),'users/guest/state/item')));
});

async function sendFeedback(db,id,data,uid=data.uid) {
 const batch=writeBatch(db);batch.set(doc(db,'feedback',id),data);batch.set(doc(db,'users',uid,'feedbackRefs',id),{id});return batch.commit();
}
test('feedback and confirmation references are mandatory, immutable and private',async()=>{
 const alice=real('alice'),bob=real('bob');
 await assertFails(setDoc(doc(alice,'feedback/f1'),feedback()));
 await sendFeedback(alice,'f1',feedback());
 await assertSucceeds(getDoc(doc(alice,'users/alice/feedbackRefs/f1')));
 await assertFails(getDoc(doc(bob,'users/alice/feedbackRefs/f1')));
 await assertFails(deleteDoc(doc(alice,'users/alice/feedbackRefs/f1')));
 await assertFails(setDoc(doc(alice,'users/alice/feedbackRefs/fake'),{id:'fake'}));
 await setDoc(doc(alice,'reports/r1'),report());
 const batch=writeBatch(bob);batch.update(doc(bob,'reports/r1'),{confirmations:1});batch.set(doc(bob,'reports/r1/confirmations/bob'),{uid:'bob',createdAt:serverTimestamp()});await assertFails(batch.commit());
 await confirm(bob,'bob');
 await assertFails(deleteDoc(doc(bob,'users/bob/confirmationRefs/r1')));
 await assertFails(setDoc(doc(bob,'users/bob/confirmationRefs/fake'),{id:'fake'}));
});
test('reserved private references cannot bypass rules using a recursive owner grant',async()=>{
 const db=real('alice');await assertFails(setDoc(doc(db,'users/alice/arbitrary/id'),{anything:true}));
 await assertFails(setDoc(doc(db,'users/alice/state/x/nested/y'),{anything:true}));
});
test('line missing report requires a line identifier',async()=>{
 const db=real('alice');await assertFails(setDoc(doc(db,'reports/r1'),report('alice',{type:'line_missing'})));
 await assertSucceeds(setDoc(doc(db,'reports/r2'),report('alice',{type:'line_missing',lineId:'fixture-line'})));
});

async function saveScore(db,uid,data,week='arequipa_2026-W45') {
 const batch=writeBatch(db);batch.set(doc(db,'leaderboards',week,'scores',uid),data);batch.set(doc(db,'users',uid,'scoreRefs',week),{id:week});return batch.commit();
}

async function deleting(db,uid){return setDoc(doc(db,'users',uid),{deleting:true,deletionStartedAt:serverTimestamp()},{merge:true});}
async function removeVote(db,uid,{count=0,removeIndex=true,removeMarker=true}={}) {
 const batch=writeBatch(db);batch.update(doc(db,'reports/r1'),{confirmations:count});if(removeMarker)batch.delete(doc(db,'reports/r1/confirmations',uid));if(removeIndex)batch.delete(doc(db,'users',uid,'confirmationRefs/r1'));return batch.commit();
}
test('erasure decrements exactly one vote and removes only its paired marker and index',async()=>{
 await setDoc(doc(real('alice'),'reports/r1'),report());const bob=real('bob');await confirm(bob,'bob');await deleting(bob,'bob');
 await assertFails(removeVote(bob,'bob',{count:0,removeIndex:false}));
 await assertFails(removeVote(bob,'bob',{count:0,removeMarker:false}));
 await assertFails(removeVote(bob,'bob',{count:-1}));
 await assertSucceeds(removeVote(bob,'bob'));
 assert.equal((await getDoc(doc(publicDb(),'reports/r1'))).data().confirmations,0);
 await assertFails(removeVote(bob,'bob'));
});
test('erasure cannot remove somebody else vote or feedback and cannot bypass counter adjustment',async()=>{
 const alice=real('alice'),bob=real('bob');await setDoc(doc(alice,'reports/r1'),report());await confirm(bob,'bob');await sendFeedback(bob,'fb',feedback('bob'));await deleting(alice,'alice');
 await assertFails(deleteDoc(doc(alice,'reports/r1/confirmations/bob')));
 await assertFails(deleteDoc(doc(alice,'users/bob/confirmationRefs/r1')));
 await assertFails(deleteDoc(doc(alice,'feedback/fb')));
 await assertFails(updateDoc(doc(alice,'reports/r1'),{confirmations:0}));
});
test('deleting flag is irreversible until root erasure and blocks new private/public data',async()=>{
 const alice=real('alice');await setDoc(doc(alice,'users/alice'),{displayName:'Prueba'});await assertFails(deleteDoc(doc(alice,'users/alice')));await deleting(alice,'alice');
 await assertFails(updateDoc(doc(alice,'users/alice'),{deleting:false}));
 await assertFails(setDoc(doc(alice,'reports/r1'),report()));
 await assertFails(sendFeedback(alice,'f1',feedback()));
 await assertFails(saveScore(alice,'alice',score()));
 await assertFails(setDoc(doc(alice,'users/alice/state/item'),personal('line:a',1,true)));
 const seal=writeBatch(alice);seal.set(doc(alice,'deletedAccounts/alice'),{});seal.delete(doc(alice,'users/alice'));await assertSucceeds(seal.commit());
});
test('old and orphaned confirmation references can be erased',async()=>{
 const alice=real('alice'),bob=real('bob');await setDoc(doc(alice,'reports/r1'),report());await confirm(bob,'bob');await deleteDoc(doc(alice,'reports/r1'));
 await assertSucceeds(eraseFirestoreFixture(bob,'bob'));await env.withSecurityRulesDisabled(async c=>{assert.equal((await getDoc(doc(c.firestore(),'reports/r1/confirmations/bob'))).exists(),false);});
});
test('expired report counter still decreases on account erasure',async()=>{
 const alice=real('alice'),bob=real('bob');await setDoc(doc(alice,'reports/r1'),report());await confirm(bob,'bob');
 await env.withSecurityRulesDisabled(async c=>updateDoc(doc(c.firestore(),'reports/r1'),{createdAt:Timestamp.fromMillis(Date.now()-73*3600000)}));
 await assertSucceeds(eraseFirestoreFixture(bob,'bob'));assert.equal((await getDoc(doc(publicDb(),'reports/r1'))).data().confirmations,0);
});
test('weekly scores require a private reference and references cannot be discarded separately',async()=>{
 const alice=real('alice');await assertFails(setDoc(doc(alice,scorePath+'alice'),score()));await saveScore(alice,'alice',score());
 await assertFails(deleteDoc(doc(alice,'users/alice/scoreRefs/arequipa_2026-W45')));
 await assertFails(getDoc(doc(real('bob'),'users/alice/scoreRefs/arequipa_2026-W45')));
 await deleting(alice,'alice');await assertFails(deleteDoc(doc(alice,'users/alice/scoreRefs/arequipa_2026-W45')));
 const batch=writeBatch(alice);batch.delete(doc(alice,scorePath+'alice'));batch.delete(doc(alice,'users/alice/scoreRefs/arequipa_2026-W45'));await assertSucceeds(batch.commit());
});
test('complete erasure removes 25 unreadable feedbacks, private data, own reports, every score and own confirmations',async()=>{
 const alice=real('alice'),bob=real('bob');await setDoc(doc(bob,'reports/r1'),report('bob'));await confirm(alice,'alice');await setDoc(doc(alice,'reports/own'),report());
 await sendFeedback(bob,'other-feedback',feedback('bob'));
 for(let i=0;i<25;i++)await sendFeedback(alice,`f${i}`,feedback());
 for(const week of ['arequipa_2026-W44','arequipa_2026-W45'])await saveScore(alice,'alice',score(),week);
 for(const section of ['state','library','preferences'])await setDoc(doc(alice,'users/alice',section,'item'),{fixture:true});
 await assertSucceeds(eraseFirestoreFixture(alice,'alice'));
 await env.withSecurityRulesDisabled(async c=>{const db=c.firestore();assert.equal((await getDoc(doc(db,'users/alice'))).exists(),false);assert.equal((await getDoc(doc(db,'reports/own'))).exists(),false);assert.equal((await getDoc(doc(db,'reports/r1'))).data().confirmations,0);assert.equal((await getDoc(doc(db,'reports/r1/confirmations/alice'))).exists(),false);assert.equal((await getDocs(collection(db,'feedback'))).size,1);assert.equal((await getDoc(doc(db,'feedback/other-feedback'))).data().uid,'bob');for(const section of ['state','library','preferences','feedbackRefs','confirmationRefs','scoreRefs'])assert.equal((await getDocs(collection(db,'users/alice',section))).size,0);for(const week of ['arequipa_2026-W44','arequipa_2026-W45'])assert.equal((await getDoc(doc(db,'leaderboards',week,'scores/alice'))).exists(),false);});
});
test('erasure resumes safely after a partial failure without deleting another user data',async()=>{
 const alice=real('alice'),bob=real('bob');await setDoc(doc(bob,'reports/r1'),report('bob'));await confirm(alice,'alice');await sendFeedback(alice,'f1',feedback());await setDoc(doc(bob,'users/bob/library/home'),{fixture:true});
 await assert.rejects(eraseFirestoreFixture(alice,'alice',{afterPhase:async phase=>{if(phase==='feedback')throw Error('Simulated interruption');}}));
 assert.equal((await getDoc(doc(alice,'users/alice'))).data().deleting,true);assert.equal((await getDoc(doc(publicDb(),'reports/r1'))).data().confirmations,1);
 await assertSucceeds(eraseFirestoreFixture(alice,'alice'));assert.equal((await getDoc(doc(publicDb(),'reports/r1'))).data().confirmations,0);await assertSucceeds(getDoc(doc(bob,'users/bob/library/home')));
});

test('weekly top is limited to 20 and own position uses competition ranking for ties',async()=>{
 for(let i=0;i<25;i++){const uid=`fixture-${i}`;await saveScore(real(uid),uid,score(uid,{score:100+i*10}));}
 await saveScore(real('tie'),'tie',score('tie',{score:100}));
 const scores=collection(publicDb(),'leaderboards/arequipa_2026-W45/scores');
 const top=await getDocs(query(scores,orderBy('score','desc'),orderBy('updatedAt','asc'),limit(20)));
 assert.equal(top.size,20);assert.equal(top.docs[0].data().score,340);
 const count=(await getCountFromServer(query(scores,where('score','>',100)))).data().count;
 assert.equal(count+1,25);
});
test('an orphaned feedback reference can be cleared without reading feedback',async()=>{
 const alice=real('alice');await sendFeedback(alice,'f1',feedback());
 await env.withSecurityRulesDisabled(async c=>deleteDoc(doc(c.firestore(),'feedback/f1')));
 await assertSucceeds(eraseFirestoreFixture(alice,'alice'));
 await env.withSecurityRulesDisabled(async c=>assert.equal((await getDoc(doc(c.firestore(),'users/alice/feedbackRefs/f1'))).exists(),false));
});

test('deleted-account marker blocks stale sessions from recreating any account data',async()=>{
 const alice=real('alice');await setDoc(doc(alice,'users/alice/library/home'),{fixture:true});await eraseFirestoreFixture(alice,'alice');
 const stale=real('alice');await assertFails(setDoc(doc(stale,'users/alice'),{displayName:'Resurrection'}));
 await assertFails(setDoc(doc(stale,'users/alice/state/item'),personal('line:a',1,true)));
 await assertFails(setDoc(doc(stale,'reports/new'),report()));await assertFails(sendFeedback(stale,'new',feedback()));await assertFails(saveScore(stale,'alice',score()));
 assert.deepEqual((await assertSucceeds(getDoc(doc(stale,'deletedAccounts/alice')))).data(),{});
 await assertFails(deleteDoc(doc(stale,'deletedAccounts/alice')));await assertFails(updateDoc(doc(stale,'deletedAccounts/alice'),{payload:'data'}));await assertFails(getDoc(doc(real('bob'),'deletedAccounts/alice')));
 await assertSucceeds(eraseFirestoreFixture(stale,'alice')); // Retry after Auth failed; no personal data returns.
});
test('security marker cannot be forged or contain personal data and requires paired root deletion',async()=>{
 const alice=real('alice');await assertFails(setDoc(doc(alice,'deletedAccounts/alice'),{}));await deleting(alice,'alice');
 await assertFails(setDoc(doc(alice,'deletedAccounts/alice'),{}));
 const bad=writeBatch(alice);bad.set(doc(alice,'deletedAccounts/alice'),{email:'fixture@example.test'});bad.delete(doc(alice,'users/alice'));await assertFails(bad.commit());
 const forged=writeBatch(alice);forged.set(doc(alice,'deletedAccounts/bob'),{});forged.delete(doc(alice,'users/alice'));await assertFails(forged.commit());
 await assertFails(deleteDoc(doc(alice,'users/alice')));
});
