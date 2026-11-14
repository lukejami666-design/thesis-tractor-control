"""Finalize only this task's archive; preserve pre-existing worktree modifications."""
from pathlib import Path
import json,hashlib,shutil,subprocess,datetime
from scipy.io import loadmat
import scipy,numpy,matplotlib,sys
D=Path(__file__).resolve().parent;R=D.parents[1];LOCAL=R/'launch_gate_20261114/feasibility_local'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def dump(p,v):p.write_text(json.dumps(v,ensure_ascii=False,indent=2),encoding='utf8')
branches=[]
for n in ['round2_base_L2_U08','r2_H_rise16','r2_I_rise20','r2_no_prewarn_L2_U08']:
    src=R/'launch_gate_20261113'/(n+'.mat');dst=D/'data'/(n+'.mat')
    if src.exists():
        shutil.copy2(src,dst);x=loadmat(src,simplify_cells=True)['runData'];branches.append({'original_name':n,'sha256':sha(src),'archived_path':str(dst.relative_to(D)),'case':x['case_id'],'strategy':x['strategy'],'bypass_switch':int(x['ManualSwitch2_CurrentSetting']),'rise_rate':float(x['P']['gate_cmd_rise_rate'])})
dump(D/'historical_branch_identity.json',branches)
dump(D/'python_versions.json',{'python':sys.version,'numpy':numpy.__version__,'scipy':scipy.__version__,'matplotlib':matplotlib.__version__})
for name in ['起步混合自动机监督门控第二轮性能优化报告.md','起步门控事件与扭矩约束修正报告.md']:
    src=R/'launch_gate_20261114/corrected'/name
    if src.exists():
        (D/'history').mkdir(exist_ok=True);shutil.copy2(src,D/'history'/name)
# The Simulink streaming dataset duplicates the authoritative runData MAT files.
# Keep it locally rather than committing implementation-specific streaming objects.
stream=D/'diagnostic_dataset.mat'
if stream.exists():
    LOCAL.mkdir(parents=True,exist_ok=True);shutil.move(str(stream),str(LOCAL/'diagnostic_dataset.mat'))
formal=[R/'simulation/models/tractor_mu.slx',R/'simulation/src/launch_tcs_params.m']
manifest=json.loads((D/'source_manifest.json').read_text(encoding='utf8'))
verify=[]
for p in formal:
    before=next(x for x in manifest if x['path']==str(p));verify.append({'path':str(p),'before_sha256':before['sha256'],'after_sha256':sha(p),'unchanged':before['sha256']==sha(p)})
assert all(x['unchanged'] for x in verify)
import zipfile,xml.etree.ElementTree as ET
with zipfile.ZipFile(D/'models/launch_gate_exp.slx') as z:
    found=[]
    for name in z.namelist():
        if name.startswith('simulink/stateflow/chart_') and name.endswith('.xml'):
            for e in ET.fromstring(z.read(name)).iter('P'):
                if e.get('Name')=='script' and e.text and ' LaunchTCS_Torque(' in e.text:
                    source=(D/'src/LaunchTCS_Torque_gate.m').read_text(encoding='utf8')
                    assert source.replace('\r','').strip()==e.text.replace('\r','').strip();found.append(name)
    assert len(found)==1
dump(D/'model_source_consistency.json',{'archived_Torque_source_matches_saved_model':True,'member':found[0],'formal_and_parameter_files_unchanged':True})
def git(*args):return subprocess.run(['git',*args],cwd=R,capture_output=True,text=True,encoding='utf8',errors='replace').stdout.strip()
dump(D/'final_verification.json',{'date':datetime.datetime.now().astimezone().isoformat(),'formal_files':verify,'branch':git('branch','--show-current'),'head_before_archive':git('rev-parse','HEAD'),'origin':git('remote','get-url','origin'),'working_tree':git('status','--short'),'deployment':'NOT DEPLOYED: active-control defect and diagnostic defect','parameter_source_copy_equal':sha(D/'src/launch_tcs_params.m')==manifest[1]['sha256']})
files=[]
for p in sorted(D.rglob('*')):
    if p.is_file() and p.name!='archive_manifest.json' and p.suffix not in ['.autosave','.pyc'] and '__pycache__' not in p.parts:
        files.append({'path':p.relative_to(D).as_posix(),'bytes':p.stat().st_size,'sha256':sha(p)})
assert max(x['bytes'] for x in files)<50*1024*1024
dump(D/'archive_manifest.json',{'execution_date':'2026-11-14','simulation_dates':['2026-11-14'],'hash_algorithm':'SHA-256','files':files,'count':len(files),'total_bytes':sum(x['bytes'] for x in files),'largest_bytes':max(x['bytes'] for x in files),'large_file_policy':'No existing Git LFS rules. Every archived file is below 50 MiB (and below GitHub 100 MiB hard limit); ordinary Git binary attributes used. No important runData omitted. Raw duplicate streaming dataset kept locally.','excluded_local_only':['formal user model/parameter protection backups','duplicate Simulink streaming dataset','autosaves/cache/codegen','licenses, commercial TruckSim tire decks/configuration data, machine settings']})
print(json.dumps({'files':len(files),'total_MiB':sum(x['bytes'] for x in files)/2**20,'largest_MiB':max(x['bytes'] for x in files)/2**20,'formal_unchanged':all(x['unchanged'] for x in verify)},indent=2))
