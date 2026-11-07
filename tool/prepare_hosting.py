"""Prepare a verified local Hosting candidate. Never deploys or writes Firestore."""
import argparse
import hashlib
import html
import json
from pathlib import Path
import shutil
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parent.parent

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--base-url', required=True, help='Proposed HTTPS Hosting origin; this does not verify deployment.')
    parser.add_argument('--release-apk', type=Path)
    args = parser.parse_args()
    origin = urlparse(args.base_url)
    if origin.scheme != 'https' or not origin.hostname or origin.username or origin.password or origin.query or origin.fragment or origin.path not in ('', '/'):
        raise ValueError('base-url must be a clean HTTPS origin')
    base_url = args.base_url.rstrip('/')
    assets = ROOT / 'assets/city/arequipa'
    source = (assets/'manifest.json').read_text(encoding='utf-8')
    manifest = json.loads(source)
    if manifest['city_code'] != 'arequipa' or manifest['schema_version'] != 1 or set(manifest['files']) != {'pack.sqlite', 'routes.geojson'}:
        raise ValueError('Unsupported pack')
    for name, info in manifest['files'].items():
        content = (assets/name).read_bytes()
        if len(content) != info['bytes'] or hashlib.sha256(content).hexdigest() != info['sha256']:
            raise ValueError(f'Invalid asset: {name}')
    if manifest['sha256'] != manifest['files']['pack.sqlite']['sha256'] or manifest['size_bytes'] != manifest['files']['pack.sqlite']['bytes']:
        raise ValueError('Inconsistent manifest')
    templates = ROOT/'tool/hosting'
    legal = json.loads((templates/'legal.json').read_text(encoding='utf-8'))
    # This generator intentionally preserves the draft status. No publication occurs.
    if legal['status'] != 'draft':
        raise ValueError('Approved policies require a separate review of the draft templates')
    output = ROOT/'hosting'
    output.mkdir(exist_ok=True)
    data_path = f"/data/arequipa/{manifest['version']}-{manifest['sha256']}"
    target = output/data_path.lstrip('/')
    target.mkdir(parents=True,exist_ok=True)
    for name in ['manifest.json', *manifest['files']]:
        destination = target/name
        content = (assets/name).read_bytes()
        if destination.exists() and destination.read_bytes() != content:
            raise ValueError(f'Cannot overwrite immutable build: {name}')
        destination.write_bytes(content)
    apk_html = '<p>La descarga de Android estará disponible después de verificar el APK de release. Todavía no hay un APK publicado.</p>'
    if args.release_apk:
        apk = args.release_apk.resolve()
        if not apk.is_relative_to(ROOT) or not apk.is_file() or apk.suffix != '.apk':
            raise ValueError('APK must be inside this repository')
        digest = hashlib.sha256(apk.read_bytes()).hexdigest()
        downloads = output/'downloads'
        downloads.mkdir(exist_ok=True)
        shutil.copyfile(apk, downloads/f'gowayki-{digest}.apk')
        apk_html = f'<p><a class="button" href="/downloads/gowayki-{digest}.apk">Descargar APK de prueba</a></p><p>SHA-256: <code>{digest}</code>. Candidato local, sin publicar.</p>'
    for template, relative in [('index.html','index.html'),('privacidad.html','privacidad/index.html'),('terminos.html','terminos/index.html'),('style.css','style.css')]:
        content = (templates/template).read_text(encoding='utf-8').replace('{{DATA_PATH}}',html.escape(data_path,quote=True)).replace('{{DATA_VERSION}}',str(manifest['version'])).replace('{{APK_DOWNLOAD}}',apk_html)
        destination = output/relative
        destination.parent.mkdir(parents=True,exist_ok=True)
        destination.write_text(content,encoding='utf-8')
    metadata = {'dataVersion':manifest['version'],'dataSha256':manifest['sha256'],'dataBytes':manifest['size_bytes'],
      'dataUrl':f'{base_url}{data_path}/pack.sqlite','minAppVersion':'1.0.0'}
    preview = ROOT/'build/hosting'
    preview.mkdir(parents=True,exist_ok=True)
    (preview/'cities.arequipa.json').write_text(json.dumps(metadata,indent=2)+'\n',encoding='utf-8')
    (output/'.gowayki-generated.json').write_text(json.dumps({'status':'draft','publicOriginVerified':False,'legal':legal,'metadata':metadata},indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'output':str(output),'version':manifest['version'],'sha256':manifest['sha256'],'status':'draft','deployed':False},indent=2))

if __name__ == '__main__':
    main()
