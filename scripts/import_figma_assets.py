"""Import image/SVG assets from locally saved Figma design-context responses."""
import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / 'ThreadsClone/Resources/Assets.xcassets'
sources = [Path('/tmp/threads-design-0.txt'), Path('/tmp/threads-design-1.txt')]
sources += sorted(Path('/tmp').glob('threads-12-*.txt'))
sources += sorted(Path('/tmp').glob('threads-extra-*.txt'))
assets = {}
for source in sources:
    code = source.read_text()
    urls = dict(re.findall(r'const (\w+) = "(https://www.figma.com/api/mcp/asset/[^"]+)"', code))
    stack = []
    for token in re.findall(r'<div\b[^>]*>|</div>|<img\b[^>]*>', code):
        if token == '</div>':
            if stack: stack.pop()
        elif token.startswith('<div'):
            named = re.search(r'data-name="([^"]+)"', token)
            if not token.endswith('/>'): stack.append(named.group(1) if named else '')
        else:
            variable = re.search(r'src=\{(\w+)\}', token)
            if not variable or variable.group(1) not in urls: continue
            semantic = next((n for n in reversed(stack) if n.startswith(('Icon/', 'Brand/Threads symbol', 'Content/'))), None)
            if semantic:
                name = semantic.replace('Icon/','').replace('Brand/Threads symbol','threads_symbol').replace('Content/','')
                assets.setdefault(name, urls[variable.group(1)])
    photo_maps = {
        'threads-design-0.txt': {'imgPhoto':'avatar_muratov_clean','imgPhoto1':'avatar_lizzi_znaet','imgPhoto2':'avatar_demianets','imgKnockout':'follow_knockout','imgWhiteBadge':'follow_white','imgFrame5':'follow_plus'},
        'threads-design-1.txt': {'imgPhoto':'avatar_to_tln','imgPhoto1':'avatar_nazkaa_kampit','imgPhoto2':'avatar_skyinaz'},
        'threads-extra-1.txt': {'imgPhoto':'avatar_your1ion'},
        'threads-12-5146.txt': {'imgPhoto1':'avatar_olzhikbro','imgPhoto2':'finance_expenses','imgPhoto3':'finance_accounts','imgPhoto4':'avatar_nik','imgPhoto5':'avatar_korn'}
    }
    for var,name in photo_maps.get(source.name,{}).items():
        if var in urls: assets[name] = urls[var]
CATALOG.mkdir(parents=True, exist_ok=True)
(CATALOG/'Contents.json').write_text(json.dumps({'info':{'author':'xcode','version':1}}))
for name,url in assets.items():
    directory = CATALOG / (name+'.imageset')
    directory.mkdir(exist_ok=True)
    filename = name+Path(url).suffix
    if not (directory/filename).exists():
        subprocess.run(['curl','-f','-sS','-L',url,'-o',str(directory/filename)],check=True)
    (directory/'Contents.json').write_text(json.dumps({'images':[{'filename':filename,'idiom':'universal'}],'info':{'author':'xcode','version':1},'properties':{'preserves-vector-representation':True}},indent=2))
print('Imported',len(assets),'Figma assets:', ', '.join(sorted(assets)))
