"""Remove only the Tmax-to-source-fault branch; preserve all other SLX members."""
from datetime import datetime
from pathlib import Path
import re
import shutil
import zipfile
import xml.etree.ElementTree as ET
from xml.sax.saxutils import escape

root = Path(__file__).resolve().parents[2]
model = root / 'models' / 'tractor_mu.slx'
stamp = datetime.now().strftime('%Y%m%d_%H%M%S')
backup = root / 'archive' / f'tractor_mu.before_remove_tmax_fault_{stamp}.slx'
candidate = root / 'archive' / 'tractor_mu_no_tmax_fault.slx'

def update_embedded(script):
    assert script.count('cap_ok = true; actual_ok = true;') == 1
    assert script.count('    if ~cap_valid, cap_ok = false; end') == 1
    assert script.count('(~cap_ok) || (~actual_ok)') == 1
    script = script.replace('cap_ok = true; actual_ok = true;', 'actual_ok = true;')
    script = script.replace('    if ~cap_valid, cap_ok = false; end\n', '')
    script = script.replace('                       (~cap_ok) || (~actual_ok);', '                       (~actual_ok);')
    assert 'cap_ok' not in script
    assert 'if cap_valid && act_valid' in script
    return script

with zipfile.ZipFile(model) as zin:
    infos = zin.infolist()
    contents = {info.filename: zin.read(info.filename) for info in infos}
    comment = zin.comment

changed = []
for name, data in list(contents.items()):
    if not (name.startswith('simulink/stateflow/') and name.endswith('.xml')):
        continue
    tree = ET.fromstring(data)
    scripts = [p.text for p in tree.iter('P') if p.get('Name') == 'script' and p.text and
               'source_immediate_bad =' in p.text]
    if not scripts:
        continue
    assert len(scripts) == 1
    original = scripts[0]
    edited = update_embedded(original)
    xml = data.decode('utf-8')
    matches = list(re.finditer(r'(<P\s+Name="script"[^>]*>)([\s\S]*?)(</P>)', xml))
    target = [m for m in matches if ET.fromstring('<P>'+m.group(2)+'</P>').text == original]
    assert len(target) == 1
    m = target[0]
    xml = xml[:m.start(2)] + escape(edited) + xml[m.end(2):]
    ET.fromstring(xml)
    contents[name] = xml.encode('utf-8')
    changed.append(name)
assert len(changed) == 1, changed

shutil.copy2(model, backup)
with zipfile.ZipFile(candidate, 'w') as zout:
    zout.comment = comment
    for info in infos:
        zout.writestr(info, contents[info.filename])
with zipfile.ZipFile(backup) as before, zipfile.ZipFile(candidate) as after:
    assert after.testzip() is None
    delta = [name for name in before.namelist() if before.read(name) != after.read(name)]
    assert delta == changed, delta

source = root / 'src' / 'LaunchTCS_Motion_code.m'
text = source.read_text(encoding='utf-8')
assert text.count('cap_ok=true; actual_ok=true; active=zeros(4,1);') == 1
assert text.count('    if isnan(T_max(i))||isinf(T_max(i))||T_max(i)<P.TcapFloor(i), cap_ok=false; end') == 1
assert text.count('||(~cap_ok)||') == 1
updated = text.replace('cap_ok=true; actual_ok=true; active=zeros(4,1);', 'actual_ok=true; active=zeros(4,1);')
updated = updated.replace('    if isnan(T_max(i))||isinf(T_max(i))||T_max(i)<P.TcapFloor(i), cap_ok=false; end\n', '')
updated = updated.replace('||(~cap_ok)||', '||')
assert 'cap_ok' not in updated
shutil.copy2(source, root / 'archive' / f'LaunchTCS_Motion_code.before_remove_tmax_fault_{stamp}.m')
source.write_text(updated, encoding='utf-8')

print('BACKUP:', backup)
print('CANDIDATE:', candidate)
print('ONLY_CHANGED_SLX_MEMBER:', changed[0])
try:
    shutil.copyfile(candidate, model)
    assert model.read_bytes() == candidate.read_bytes()
    print('FORMAL_MODEL_UPDATED:', model)
except PermissionError:
    print('FORMAL_MODEL_LOCKED: Candidate and source are ready; close tractor_mu to release the file.')
