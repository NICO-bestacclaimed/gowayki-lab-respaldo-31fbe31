"""Create a local upload-signing key without printing passwords. Never uploads it."""
import hashlib,json,os,re,secrets,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]

def main():
    if ROOT.parent.resolve()!=Path('C:/Proyecto_001').resolve():
        raise ValueError('This local setup is restricted to C:/Proyecto_001')
    folder=ROOT.parent/'.tools/signing'
    folder.mkdir(parents=True,exist_ok=True)
    store=folder/'gowayki-upload.p12'
    properties=ROOT/'android/key.properties'
    if store.exists() or properties.exists():
        if not store.exists() or not properties.exists():
            raise ValueError('Incomplete existing signing configuration; preserve it and review manually')
        print('Existing signing files preserved. No key or password was replaced.')
        return
    password=secrets.token_hex(32)
    child_env=os.environ.copy()
    child_env['GOWAYKI_SIGNING_PASSWORD']=password
    keytool=Path(os.environ['JAVA_HOME'])/'bin/keytool.exe'
    command=[str(keytool),'-genkeypair','-noprompt','-keystore',str(store),'-storetype','PKCS12',
      '-alias','gowayki-upload','-keyalg','RSA','-keysize','3072','-sigalg','SHA256withRSA','-validity','10000',
      '-dname','CN=GoWayki local build','-storepass:env','GOWAYKI_SIGNING_PASSWORD','-keypass:env','GOWAYKI_SIGNING_PASSWORD']
    result=subprocess.run(command,env=child_env,capture_output=True,text=True)
    if result.returncode:
        raise RuntimeError('keytool failed; no credentials were printed. Preserve any existing output for review.')
    properties.write_text(f'storePassword={password}\nkeyPassword={password}\nkeyAlias=gowayki-upload\nstoreFile={store.as_posix()}\n',encoding='utf-8')
    result=subprocess.run([str(keytool),'-list','-v','-J-Duser.language=en','-keystore',str(store),'-storepass:env','GOWAYKI_SIGNING_PASSWORD'],env=child_env,capture_output=True,text=True,check=True)
    fingerprints={name:re.search(rf'{name}:\s*([A-F0-9:]+)',result.stdout).group(1) for name in ['SHA1','SHA256']}
    record={'keystore':str(store),'properties':str(properties),'alias':'gowayki-upload','certificate':fingerprints,
      'usage':'Local upload-signing candidate. Not registered or distributed. Owner must preserve key and passwords.'}
    (ROOT/'docs/ANDROID_RELEASE_SIGNING.json').write_text(json.dumps(record,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(record,indent=2))

if __name__=='__main__':main()
