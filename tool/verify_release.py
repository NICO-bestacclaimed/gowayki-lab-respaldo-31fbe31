"""Verify Android release identity, signing and telemetry defaults without cloud/device access."""
import argparse,hashlib,json,os,re,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apk',type=Path,default=ROOT/'build/app/outputs/flutter-apk/app-release.apk')
    args=parser.parse_args();apk=args.apk.resolve()
    tools=sorted((Path(os.environ['ANDROID_HOME'])/'build-tools').glob('*/aapt.exe'))[-1].parent
    java=Path(os.environ['JAVA_HOME'])/'bin/java.exe'
    signed=subprocess.check_output([str(java),'-jar',str(tools/'lib/apksigner.jar'),'verify','--verbose','--print-certs',str(apk)],encoding='utf-8',errors='replace')
    sha=re.search(r'Signer #1 certificate SHA-256 digest:\s*([a-fA-F0-9]+)',signed).group(1).lower()
    expected=json.loads((ROOT/'docs/ANDROID_RELEASE_SIGNING.json').read_text(encoding='utf-8'))['certificate']['SHA256'].replace(':','').lower()
    assert sha==expected,'Unexpected signing certificate'
    badging=subprocess.check_output([str(tools/'aapt.exe'),'dump','badging',str(apk)],encoding='utf-8',errors='replace')
    assert "name='pe.edu.tecsup.gowayki_lab'" in badging
    version=re.search(r'^version:\s*([^\s]+)',(ROOT/'pubspec.yaml').read_text(encoding='utf-8'),re.M).group(1)
    name,code=version.split('+',1)
    assert f"versionCode='{code}'" in badging and f"versionName='{name}'" in badging
    assert "application-label:'GoWayki'" in badging
    assert 'application-debuggable' not in badging
    manifest=subprocess.check_output([str(tools/'aapt.exe'),'dump','xmltree',str(apk),'AndroidManifest.xml'],encoding='utf-8',errors='replace')
    assert 'FirebaseInitProvider' not in manifest
    flags=['firebase_data_collection_default_enabled','firebase_analytics_collection_enabled','firebase_crashlytics_collection_enabled',
      'google_analytics_adid_collection_enabled','google_analytics_automatic_screen_reporting_enabled']
    for flag in flags:
        name=f'"{flag}"'
        lines=manifest.splitlines()
        pos=next(i for i,line in enumerate(lines) if name in line)
        start=pos
        while start>0 and not lines[start].lstrip().startswith('E:'):
            start-=1
        end=pos+1
        while end<len(lines) and not lines[end].lstrip().startswith('E:'):
            end+=1
        section='\n'.join(lines[start:end])
        assert re.search(r'android:value[^\n]*\(type 0x12\)0x0\b',section),f'Collection default is not false: {flag}'
    print(json.dumps({'apk':str(apk),'bytes':apk.stat().st_size,'sha256':hashlib.sha256(apk.read_bytes()).hexdigest(),
      'package':'pe.edu.tecsup.gowayki_lab','name':'GoWayki','version':version,'debuggable':False,
      'signer_sha256':sha,'signature':'verified against local upload certificate','telemetry_defaults':'disabled',
      'firebase_init_provider':'removed','device_runtime':'not tested'},indent=2))

if __name__=='__main__':main()
