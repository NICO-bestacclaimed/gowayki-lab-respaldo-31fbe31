"""Create small derived sprites. Original illustrations are never modified. Pillow13.0.0."""
from pathlib import Path
from PIL import Image
import hashlib,json
ROOT=Path(__file__).resolve().parents[1]

def main():
    source=json.loads((ROOT/'tool/data/artwork_sources.json').read_text(encoding='utf-8'))
    output=ROOT/'assets/game/sprites'
    output.mkdir(parents=True,exist_ok=True)
    report=[]
    for entry in source['files']:
        if '/micros/' not in entry['asset']:continue
        original=ROOT/entry['asset']
        assert hashlib.sha256(original.read_bytes()).hexdigest()==entry['sha256']
        im=Image.open(original).convert('RGBA')
        bounds=im.getchannel('A').getbbox()
        if bounds:im=im.crop(bounds)
        im.thumbnail((96,88),Image.Resampling.LANCZOS)
        sprite=Image.new('RGBA',(96,96))
        sprite.alpha_composite(im,((96-im.width)//2,(96-im.height)//2))
        target=output/original.name
        sprite.save(target,format='WEBP',quality=45,method=6,exact=False)
        assert target.stat().st_size<5000
        report.append({'source':entry['asset'],'source_sha256':entry['sha256'],
            'asset':target.relative_to(ROOT).as_posix(),'bytes':target.stat().st_size,
            'sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'width':96,'height':96})
    assert len(report)==15
    (ROOT/'tool/data/game_sprites.json').write_text(json.dumps({'pillow':'13.0.0',
        'quality':45,'originals_preserved':True,'files':report},indent=2)+'\n',encoding='utf-8')
    print('Sprites:',len(report),'bytes:',sum(e['bytes'] for e in report))

if __name__=='__main__':main()
