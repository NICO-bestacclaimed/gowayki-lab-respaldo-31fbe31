"""Compare Firebase client options with compiled Android resources. No API calls."""
from pathlib import Path
import argparse,json,os,subprocess,hashlib
ROOT=Path(__file__).resolve().parents[1]
APK=ROOT/'build/app/outputs/flutter-apk/app-debug.apk'
def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apk',type=Path,default=APK)
    args=parser.parse_args()
    artifact=args.apk.resolve()
    config=json.loads((ROOT/'android/app/google-services.json').read_text(encoding='utf-8'))
    client=next(c for c in config['client'] if c['client_info']['android_client_info']['package_name']=='pe.edu.tecsup.gowayki_lab')
    aapt=sorted((Path(os.environ['ANDROID_HOME'])/'build-tools').glob('*/aapt.exe'))[-1]
    output=subprocess.check_output([str(aapt),'dump','--values','resources',str(artifact)],encoding='utf-8',errors='replace')
    for name,value in {'google_app_id':client['client_info']['mobilesdk_app_id'],'project_id':config['project_info']['project_id'],'gcm_defaultSenderId':config['project_info']['project_number']}.items():
        assert name in output and str(value) in output,name
    web=[c['client_id'] for c in client.get('oauth_client',[]) if c.get('client_type')==3]
    if web:assert 'default_web_client_id' in output and web[0] in output,'Google web client missing'
    print(json.dumps({'project_id':config['project_info']['project_id'],'android_app_id':client['client_info']['mobilesdk_app_id'],'compiled_android_resources':'matched supplied configuration','apk_sha256':hashlib.sha256(artifact.read_bytes()).hexdigest(),'native_runtime':'not tested'},indent=2))
if __name__=='__main__':main()
