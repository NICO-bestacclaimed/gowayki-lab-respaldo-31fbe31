"""Measure every game asset and check standalone local references and original artwork."""
from pathlib import Path
import hashlib,json,re
ROOT=Path(__file__).resolve().parents[1]

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    game=ROOT/'assets/game'
    files=sorted(p for p in game.rglob('*') if p.is_file())
    total=sum(p.stat().st_size for p in files)
    assert total<150000,(total,'must be below150000 bytes including sprites')
    assert len(list((game/'sprites').glob('*.webp')))==15
    for filename in ['index.html','game.js','style.css']:assert (game/filename).is_file()
    source=json.loads((ROOT/'tool/data/game_sprites.json').read_text(encoding='utf-8'))
    for entry in source['files']:
        assert sha(ROOT/entry['source'])==entry['source_sha256']
        assert sha(ROOT/entry['asset'])==entry['sha256']
    html=(game/'index.html').read_text(encoding='utf-8')
    js=(game/'game.js').read_text(encoding='utf-8')
    css=(game/'style.css').read_text(encoding='utf-8')
    assert "connect-src 'none'" in html and "default-src 'none'" in html
    assert not re.search(r'https?://|fetch\s*\(|XMLHttpRequest|WebSocket|@import|eval\s*\(',html+js+css)
    for ref in re.findall(r'(?:src|href)="([^"]+)"',html):assert (game/ref).is_file(),ref
    print(json.dumps({'total_bytes':total,'limit_bytes':150000,'files':len(files),
        'sprites':15,'sprite_bytes':sum(e['bytes'] for e in source['files']),
        'originals_preserved':True,'external_references':'none','network_blocked_by_csp':True,
        'assets':[{'path':p.relative_to(ROOT).as_posix(),'bytes':p.stat().st_size,'sha256':sha(p)} for p in files]},indent=2))
if __name__=='__main__':main()
