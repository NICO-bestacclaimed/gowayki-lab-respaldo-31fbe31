import {doc,collection,getDocFromServer,getDocsFromServer,query,where,limit,writeBatch,runTransaction,setDoc,deleteDoc,serverTimestamp} from 'firebase/firestore';
function guard(){if(!process.env.GCLOUD_PROJECT?.startsWith('demo-') || !process.env.FIRESTORE_EMULATOR_HOST?.startsWith('127.0.0.1:'))throw Error('Account erasure fixtures are restricted to the local demo emulator.');}
export async function eraseFirestoreFixture(db,uid,{afterPhase=async()=>{}}={}) {
 guard();const root=doc(db,'users',uid),marker=doc(db,'deletedAccounts',uid);const sealed=(await getDocFromServer(marker)).exists();
 if(!sealed && (await getDocFromServer(root)).data()?.deleting!==true)await setDoc(root,{deleting:true,deletionStartedAt:serverTimestamp()},{merge:true});
 for(;;){const rows=await getDocsFromServer(query(collection(db,'users',uid,'feedbackRefs'),limit(4)));if(rows.empty)break;const batch=writeBatch(db);for(const row of rows.docs){batch.delete(doc(db,'feedback',row.id));batch.delete(row.ref);}await batch.commit();}
 await afterPhase('feedback');
 for(;;){const rows=await getDocsFromServer(query(collection(db,'users',uid,'confirmationRefs'),limit(100)));if(rows.empty)break;for(const row of rows.docs){await runTransaction(db,async tx=>{const parent=doc(db,'reports',row.id),marker=doc(db,'reports',row.id,'confirmations',uid);const report=await tx.get(parent),vote=await tx.get(marker),index=await tx.get(row.ref);if(!index.exists())return;if(vote.exists()){if(report.exists())tx.update(parent,{confirmations:report.data().confirmations-1});tx.delete(marker);}tx.delete(row.ref);});}}
 await afterPhase('confirmations');
 for(;;){const rows=await getDocsFromServer(query(collection(db,'reports'),where('uid','==',uid),limit(100)));if(rows.empty)break;const batch=writeBatch(db);for(const row of rows.docs)batch.delete(row.ref);await batch.commit();}
 await afterPhase('reports');
 for(;;){const rows=await getDocsFromServer(query(collection(db,'users',uid,'scoreRefs'),limit(5)));if(rows.empty)break;const batch=writeBatch(db);for(const row of rows.docs){batch.delete(doc(db,'leaderboards',row.id,'scores',uid));batch.delete(row.ref);}await batch.commit();}
 await afterPhase('scores');
 for(const section of ['state','library','preferences']){for(;;){const rows=await getDocsFromServer(query(collection(db,'users',uid,section),limit(100)));if(rows.empty)break;const batch=writeBatch(db);for(const row of rows.docs)batch.delete(row.ref);await batch.commit();}}
 await afterPhase('private');if(!sealed){const seal=writeBatch(db);seal.set(marker,{});seal.delete(root);await seal.commit();}
}
