/** Read-only verification of the authorized GoWayki Firestore deployment. */
const fs=require('node:fs');
const path=require('node:path');
const assert=require('node:assert/strict');
const crypto=require('node:crypto');
const root=path.resolve(__dirname,'..');
const cli=name=>require(path.join(root,'tool/firebase/node_modules/firebase-tools/lib',name));
const hash=content=>crypto.createHash('sha256').update(content).digest('hex');
const identity=index=>JSON.stringify({collectionGroup:index.collectionGroup,
 queryScope:index.queryScope,fields:index.fields.filter(field=>field.fieldPath!=='__name__')});
(async()=>{
 const project='gowayki-lab', database='(default)';
 const account=cli('auth').getProjectDefaultAccount(root);
 if(!account)throw Error('Sign in to the Firebase CLI first.');
 await cli('requireAuth').requireAuth({project,...account});
 const api=new (cli('firestore/api').FirestoreApi)();
 const db=await api.getDatabase(project,database);
 assert.equal(db.name,`projects/${project}/databases/${database}`);
 assert.equal(db.type,'FIRESTORE_NATIVE');assert.equal(db.databaseEdition,'STANDARD');
 const rules=cli('gcp/rules');
 const releases=await rules.listAllReleases(project);
 const release=releases.find(item=>item.name===`projects/${project}/releases/cloud.firestore`);
 assert.ok(release,'Default Firestore rules release missing');
 const files=await rules.getRulesetContent(release.rulesetName);
 const deployed=files.find(file=>file.name==='firestore.rules');
 assert.ok(deployed,'Expected rules source missing');
 const localHash=hash(fs.readFileSync(path.join(root,'firestore.rules')));
 assert.equal(hash(deployed.content),localHash,'Active rules do not match the local file');
 const expected=JSON.parse(fs.readFileSync(path.join(root,'firestore.indexes.json'),'utf8')).indexes;
 let matched=[];
 const deadline=Date.now()+600000;
 while(true){
  const indexes=await api.listIndexes(project,database);
  const normalized=indexes.map(index=>({...index,collectionGroup:index.name.split('/collectionGroups/')[1].split('/indexes/')[0]}));
  matched=expected.map(spec=>normalized.find(index=>identity(index)===identity(spec)));
  assert.ok(matched.every(Boolean),'A configured index was not deployed');
  assert.ok(matched.every(index=>index.state!=='NEEDS_REPAIR'),'An index requires repair');
  if(matched.every(index=>index.state==='READY'))break;
  console.log(JSON.stringify({ready:matched.filter(index=>index.state==='READY').length,total:expected.length,states:matched.map(index=>index.state),status:'waiting_for_indexes'}));
  if(Date.now()>=deadline)throw Error('Indexes are still building. Deployment succeeded; verify again before marking ready.');
  await new Promise(resolve=>setTimeout(resolve,10000));
 }
 const backupFile=path.join(root,'../.tools/logs/firestore-deploy-backup.json');
 const backup=fs.existsSync(backupFile)?JSON.parse(fs.readFileSync(backupFile,'utf8')).directory:null;
 const receipt={project,database,database_type:db.type,edition:db.databaseEdition,location:db.locationId,
 verified_at:new Date().toISOString(),ruleset:release.rulesetName,rules_sha256:localHash,rules_match:true,
 indexes:matched.map(index=>({name:index.name,collectionGroup:index.collectionGroup,queryScope:index.queryScope,
 fields:index.fields,state:index.state})),indexes_ready:matched.length,backup,
 verification:'Read-only API checks; no application documents read or written.',
 scope:'Firestore rules and indexes. No Hosting, app distribution, collection seeding or authentication-provider changes.'};
 fs.writeFileSync(path.join(root,'docs/FIRESTORE_DESPLIEGUE.json'),JSON.stringify(receipt,null,2)+'\n');
 console.log(JSON.stringify({project,database,rules_match:true,indexes_ready:matched.length,status:'verified'},null,2));
})().catch(error=>{console.error(error.message);process.exitCode=1;});
