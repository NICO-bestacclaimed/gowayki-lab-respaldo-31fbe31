"""Verify only the permissions required by GoWayki; no device or cloud calls."""
from pathlib import Path
import argparse,os,re,json,subprocess
ROOT=Path(__file__).resolve().parents[1]
def main():
 parser=argparse.ArgumentParser();parser.add_argument('--apk',type=Path,default=ROOT/'build/app/outputs/flutter-apk/app-debug.apk');args=parser.parse_args()
 aapt=sorted((Path(os.environ['ANDROID_HOME'])/'build-tools').glob('*/aapt.exe'))[-1]
 output=subprocess.check_output([str(aapt),'dump','permissions',str(args.apk)],encoding='utf-8',errors='replace')
 permissions=sorted(set(re.findall(r"uses-permission[^:]*: name='([^']+)'",output)))
 blocked={'android.permission.ACCESS_BACKGROUND_LOCATION','android.permission.READ_PHONE_STATE','com.google.android.gms.permission.AD_ID'}
 assert not (blocked & set(permissions)),blocked & set(permissions)
 assert 'android.permission.FOREGROUND_SERVICE_LOCATION' in permissions
 print(json.dumps({'apk':str(args.apk),'permissions':permissions,'background_location':False,'phone_state':False,'advertising_id':False},indent=2))
if __name__=='__main__':main()
