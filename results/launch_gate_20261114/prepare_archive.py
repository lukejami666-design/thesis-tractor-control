"""Snapshot existing user files without modifying them; all generated hashes are SHA-256."""
from pathlib import Path
import hashlib, json, shutil, zipfile, datetime
ROOT=Path('D:/毕设'); DST=ROOT/'results/launch_gate_20261114'
LOCAL=ROOT/'launch_gate_20261114/feasibility_local'
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def cp(src,dst):
    dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,dst)
paths=[ROOT/'simulation/models/tractor_mu.slx',ROOT/'simulation/src/launch_tcs_params.m',ROOT/'launch_gate_20261113/launch_gate_exp.slx',ROOT/'launch_gate_20261113/run_gate_trial.m',ROOT/'launch_gate_20261113/gate_params.m',ROOT/'launch_gate_20261113/LaunchTCS_Torque_gate.m',ROOT/'launch_gate_20261113/MONITOR_gate.txt',Path('C:/Users/Public/Documents/TruckSim2019.0_Data/launch_tcs_params.m')]
manifest=[]
for p in paths:
    st=p.stat();manifest.append(dict(path=str(p),sha256=sha(p),bytes=st.st_size,mtime=datetime.datetime.fromtimestamp(st.st_mtime).isoformat()))
for p in paths[:2]: cp(p,LOCAL/'before_deployment'/p.name)
for n in ['launch_gate_exp.slx','LaunchTCS_Torque_gate.m','MONITOR_gate.txt','gate_params.m','run_gate_trial.m','install_gate.m']:
    cp(ROOT/'launch_gate_20261113'/n,DST/('models' if n.endswith('.slx') else 'src')/n)
cp(paths[-1],DST/'src/launch_tcs_params.m')
for name in ['r2_J_rise24.mat','fix_baseline_L2_U08.mat']:
    cp(ROOT/'launch_gate_20261113'/name,DST/'data'/name)
cp(ROOT/'launch_gate_20261114/corrected/selected_gate_parameters.mat',DST/'data/selected_gate_parameter_overrides.mat')
for name in ['r2_J_L2_U05.mat','r2_J_L1_U08.mat','r2_J_L1_RAMP.mat','r2_J_L2_RAMP.mat']:
    cp(ROOT/'launch_gate_20261113'/name,DST/'data'/name)
(DST/'source_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf8')
before=ROOT/'launch_gate_20261113/before_20261113_095512/tractor_mu.slx'
models=[p for p in before.parent.glob('*.slx')]
if len(models)==1:
    a,b=models[0],paths[0]
    with zipfile.ZipFile(a) as za,zipfile.ZipFile(b) as zb:
        na,nb=set(za.namelist()),set(zb.namelist())
        changes=[]
        for n in sorted(na|nb):
            aa=za.read(n) if n in na else b'';bb=zb.read(n) if n in nb else b''
            if aa!=bb:changes.append({'member':n,'old_bytes':len(aa),'new_bytes':len(bb)})
        (DST/'formal_model_member_diff.json').write_text(json.dumps({'before_path':str(a),'before_sha256':sha(a),'current_sha256':sha(b),'changed_members':changes},ensure_ascii=False,indent=2),encoding='utf8')
print(json.dumps(manifest,ensure_ascii=False,indent=2))
