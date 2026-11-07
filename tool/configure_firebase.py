"""Import Firebase CLIENT configuration supplied by the project owner; no cloud calls."""
from pathlib import Path
import argparse,hashlib,json,plistlib,shutil,re
ROOT=Path(__file__).resolve().parents[1]

def literal(value):return json.dumps(str(value),ensure_ascii=False).replace('$',r'\$')
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--android',type=Path,default=ROOT.parent/'google-services.json')
    parser.add_argument('--ios',type=Path,default=ROOT.parent/'GoogleService-Info.plist')
    args=parser.parse_args()
    android=json.loads(args.android.read_text(encoding='utf-8-sig'))
    ios=plistlib.loads(args.ios.read_bytes())
    project=android['project_info']['project_id']
    clients=[c for c in android['client'] if c['client_info']['android_client_info']['package_name']=='pe.edu.tecsup.gowayki_lab']
    assert len(clients)==1,'Expected exactly one matching Android app'
    client=clients[0]
    assert ios['PROJECT_ID']==project,'Different Firebase projects'
    assert ios['BUNDLE_ID']=='pe.edu.tecsup.mobilityLab','Wrong iOS bundle ID'
    assert str(android['project_info']['project_number'])==str(ios['GCM_SENDER_ID']),'Sender IDs differ'
    android_id=client['client_info']['mobilesdk_app_id']
    ios_id=ios['GOOGLE_APP_ID']
    assert android_id.split(':')[2]=='android' and ios_id.split(':')[2]=='ios'
    assert not any('REEMPLAZAR' in str(v) for v in [project,android_id,ios_id,ios['API_KEY'],client['api_key'][0]['current_key']])
    for source,target in [(args.android,ROOT/'android/app/google-services.json'),(args.ios,ROOT/'ios/Runner/GoogleService-Info.plist')]:
        if source.resolve()!=target.resolve():shutil.copyfile(source,target)
        assert sha(source)==sha(target)
    def fields(values):return '\n'.join(f'    {key}: {literal(value)},' for key,value in values.items() if value)
    av={'apiKey':client['api_key'][0]['current_key'],'appId':android_id,'messagingSenderId':android['project_info']['project_number'],'projectId':project,'storageBucket':android['project_info'].get('storage_bucket')}
    iv={'apiKey':ios['API_KEY'],'appId':ios_id,'messagingSenderId':ios['GCM_SENDER_ID'],'projectId':project,'storageBucket':ios.get('STORAGE_BUCKET'),'iosBundleId':ios['BUNDLE_ID'],'iosClientId':ios.get('CLIENT_ID')}
    text="""// Generated locally from the supplied client configuration. Regenerate with tool/configure_firebase.py.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform,kIsWeb,TargetPlatform;
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if(kIsWeb) throw UnsupportedError('Firebase web no configurado.');
    return switch(defaultTargetPlatform) {
      TargetPlatform.android => android,
      TargetPlatform.iOS => ios,
      _ => throw UnsupportedError('Firebase disponible para Android/iOS en este proyecto.'),
    };
  }
  static const android=FirebaseOptions(
"""+fields(av)+"\n  );\n  static const ios=FirebaseOptions(\n"+fields(iv)+"\n  );\n}\n"
    (ROOT/'lib/firebase_options.dart').write_text(text,encoding='utf-8')
    config_path=ROOT/'firebase.json'
    config=json.loads(config_path.read_text(encoding='utf-8'))
    for platform,app_id,path in [('android',android_id,'android/app/google-services.json'),('ios',ios_id,'ios/Runner/GoogleService-Info.plist')]:
        config['flutter']['platforms'][platform]['default'].update(projectId=project,appId=app_id,fileOutput=path)
    config['firestore']={'rules':'firestore.rules','indexes':'firestore.indexes.json'}
    config['hosting']={'public':'hosting','ignore':['firebase.json','**/.*','**/node_modules/**']}
    config['emulators']={'auth':{'host':'127.0.0.1','port':9099},'firestore':{'host':'127.0.0.1','port':8085},'ui':{'enabled':False},'singleProjectMode':True}
    config_path.write_text(json.dumps(config,indent=2)+'\n',encoding='utf-8')
    (ROOT/'.firebaserc').write_text(json.dumps({'projects':{'default':project}},indent=2)+'\n',encoding='utf-8')
    report={'project_id':project,'android_package':'pe.edu.tecsup.gowayki_lab','android_app_id':android_id,'ios_bundle':ios['BUNDLE_ID'],'ios_app_id':ios_id,'android_config_sha256':sha(args.android),'ios_config_sha256':sha(args.ios),'same_project':True,'google_android_web_client_present':any(c.get('client_type')==3 for c in client.get('oauth_client',[])),'google_ios_client_present':bool(ios.get('CLIENT_ID')),'google_ios_url_scheme_present':bool(ios.get('REVERSED_CLIENT_ID'))}
    (ROOT/'docs/FIREBASE_CONFIG_8A.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print('Client configuration verified for:',project)
    print('Google OAuth complete:',report['google_android_web_client_present'] and report['google_ios_client_present'] and report['google_ios_url_scheme_present'])
if __name__=='__main__':main()
