import {before,after,afterEach,beforeEach,test} from 'node:test';
import assert from 'node:assert/strict';
import {initializeApp,deleteApp} from 'firebase/app';
import {getAuth,connectAuthEmulator,signInAnonymously,linkWithCredential,EmailAuthProvider,GoogleAuthProvider,signInWithCredential,signInWithEmailAndPassword,createUserWithEmailAndPassword,getIdTokenResult,sendPasswordResetEmail,signOut,deleteUser} from 'firebase/auth';
import {getFirestore,connectFirestoreEmulator,doc,setDoc,getDoc,serverTimestamp,writeBatch} from 'firebase/firestore';
import {initializeTestEnvironment} from '@firebase/rules-unit-testing';
import {eraseFirestoreFixture} from './erase-account.mjs';
const project=process.env.GCLOUD_PROJECT,authHost=process.env.FIREBASE_AUTH_EMULATOR_HOST;
if(!project?.startsWith('demo-') || !authHost?.startsWith('127.0.0.1:') || !process.env.FIRESTORE_EMULATOR_HOST?.startsWith('127.0.0.1:')) throw Error('Auth tests require local demo emulators.');
let environment,app,auth,db,sequence=0;
const email='fixture@example.test',password='Fixture-Pass-123';
const googleCredential=()=>{
 const header=Buffer.from(JSON.stringify({alg:'none',typ:'JWT'})).toString('base64url');
 const payload=Buffer.from(JSON.stringify({iss:'https://accounts.google.com',aud:'fixture-client',sub:'google-fixture',email:'google-fixture@example.test',email_verified:true,name:'Fixture Google',iat:Math.floor(Date.now()/1000),exp:Math.floor(Date.now()/1000)+3600})).toString('base64url');
 return GoogleAuthProvider.credential(`${header}.${payload}.`);
};
before(async()=>{
 const [host,port]=process.env.FIRESTORE_EMULATOR_HOST.split(':');
 environment=await initializeTestEnvironment({projectId:project,firestore:{host,port:Number(port)}});
});
beforeEach(async()=>{
 await environment.clearFirestore();
 const cleared=await fetch(`http://${authHost}/emulator/v1/projects/${project}/accounts`,{method:'DELETE'});
 assert.equal(cleared.ok,true);
 app=initializeApp({apiKey:'demo-key',projectId:project},`auth-test-${sequence++}`);
 auth=getAuth(app);connectAuthEmulator(auth,`http://${authHost}`,{disableWarnings:true});
 db=getFirestore(app);const [host,port]=process.env.FIRESTORE_EMULATOR_HOST.split(':');connectFirestoreEmulator(db,host,Number(port));
});
afterEach(async()=>{await signOut(auth);await deleteApp(app);});
after(async()=>environment?.cleanup());
async function saveFavorite(user){await setDoc(doc(db,`users/${user.uid}/library/favorites`),{lineIds:['fixture-line']});}
async function assertFavorite(user){assert.deepEqual((await getDoc(doc(db,`users/${user.uid}/library/favorites`))).data().lineIds,['fixture-line']);}
test('anonymous session links to email without changing UID or private favorites',async()=>{
 const guest=(await signInAnonymously(auth)).user;await saveFavorite(guest);
 const linked=(await linkWithCredential(guest,EmailAuthProvider.credential(email,password))).user;
 assert.equal(linked.uid,guest.uid);assert.equal(linked.isAnonymous,false);await assertFavorite(linked);
 const token=await getIdTokenResult(linked,true);assert.equal(token.signInProvider,'password');
 await setDoc(doc(db,'reports/email-linked'),{uid:linked.uid,cityCode:'arequipa',type:'other',description:'Fixture después de vincular',latitude:-16.4,longitude:-71.5,createdAt:serverTimestamp(),confirmations:0});
 await signOut(auth);const signed=(await signInWithEmailAndPassword(auth,email,password)).user;assert.equal(signed.uid,guest.uid);
});
test('anonymous session links to Google with the same UID and authorized report creation',async()=>{
 const guest=(await signInAnonymously(auth)).user;await saveFavorite(guest);
 const linked=(await linkWithCredential(guest,googleCredential())).user;
 assert.equal(linked.uid,guest.uid);assert.equal(linked.isAnonymous,false);await assertFavorite(linked);
 assert.equal((await getIdTokenResult(linked,true)).signInProvider,'google.com');
 await setDoc(doc(db,'reports/google-linked'),{uid:linked.uid,cityCode:'arequipa',type:'other',description:'Fixture después de Google',latitude:-16.4,longitude:-71.5,createdAt:serverTimestamp(),confirmations:0});
});
test('existing Google credential cannot be linked to another UID and can sign into its original account',async()=>{
 const original=(await signInWithCredential(auth,googleCredential())).user;await signOut(auth);
 const guest=(await signInAnonymously(auth)).user;
 await assert.rejects(linkWithCredential(guest,googleCredential()),error=>error.code==='auth/credential-already-in-use');
 const signed=(await signInWithCredential(auth,googleCredential())).user;
 assert.equal(signed.uid,original.uid);assert.notEqual(signed.uid,guest.uid);
});
test('email/password validates incorrect credentials and password reset remains local',async()=>{
 const created=(await createUserWithEmailAndPassword(auth,email,password)).user;await signOut(auth);
 await assert.rejects(signInWithEmailAndPassword(auth,email,'Wrong-Pass-123'));
 assert.equal((await signInWithEmailAndPassword(auth,email,password)).user.uid,created.uid);
 await sendPasswordResetEmail(auth,email);
 const response=await fetch(`http://${authHost}/emulator/v1/projects/${project}/oobCodes`);
 const data=await response.json();assert.ok(data.oobCodes.some(code=>code.email===email&&code.requestType==='PASSWORD_RESET'));
 await signOut(auth);assert.equal(auth.currentUser,null);
});

test('deleting an authenticated account removes its Firestore data and Auth user while preserving another account',async()=>{
 const owner=(await createUserWithEmailAndPassword(auth,email,password)).user;await saveFavorite(owner);
 const ownReport='owner-report',peerReport='peer-report';
 const makeReport=uid=>({uid,cityCode:'arequipa',type:'other',description:'Fixture de eliminación',latitude:-16.4,longitude:-71.5,createdAt:serverTimestamp(),confirmations:0});
 await setDoc(doc(db,'reports',ownReport),makeReport(owner.uid));
 const batch=writeBatch(db);batch.set(doc(db,'feedback','owner-feedback'),{uid:owner.uid,kind:'bug',message:'Fixture de eliminación',city_code:'arequipa',created_at:serverTimestamp(),app_version:'1.0.0+1',device_model:'Fixture',data_version:2});batch.set(doc(db,'users',owner.uid,'feedbackRefs','owner-feedback'),{id:'owner-feedback'});await batch.commit();
 const peerEmail='peer@example.test',peer=(await createUserWithEmailAndPassword(auth,peerEmail,password)).user;await saveFavorite(peer);await setDoc(doc(db,'reports',peerReport),makeReport(peer.uid));
 await signInWithEmailAndPassword(auth,email,password);
 const vote=writeBatch(db);vote.update(doc(db,'reports',peerReport),{confirmations:1});vote.set(doc(db,'reports',peerReport,'confirmations',owner.uid),{uid:owner.uid,createdAt:serverTimestamp()});vote.set(doc(db,'users',owner.uid,'confirmationRefs',peerReport),{id:peerReport});await vote.commit();
 await eraseFirestoreFixture(db,owner.uid);await deleteUser(auth.currentUser);
 assert.equal(auth.currentUser,null);await assert.rejects(signInWithEmailAndPassword(auth,email,password));
 assert.equal((await signInWithEmailAndPassword(auth,peerEmail,password)).user.uid,peer.uid);await assertFavorite(peer);
 await environment.withSecurityRulesDisabled(async context=>{const check=context.firestore();assert.equal((await getDoc(doc(check,'users',owner.uid))).exists(),false);assert.equal((await getDoc(doc(check,'users',owner.uid,'library/favorites'))).exists(),false);assert.equal((await getDoc(doc(check,'reports',ownReport))).exists(),false);assert.equal((await getDoc(doc(check,'feedback','owner-feedback'))).exists(),false);assert.equal((await getDoc(doc(check,'reports',peerReport))).data().confirmations,0);});
});
