"""Verify packaged analysis with no access to the historical project layout."""
from pathlib import Path
import shutil,subprocess,sys,json,hashlib,datetime
D=Path(__file__).resolve().parent;R=D.parents[1]
TEMP=R/'launch_gate_20261114/feasibility_local/offline_replay_20261114/results/launch_gate_20261114'
TEMP.mkdir(parents=True,exist_ok=True)
manifest=json.loads((D/'archive_manifest.json').read_text(encoding='utf8'))
for item in manifest['files']:
    src=D/item['path'];dst=TEMP/item['path'];dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,dst)
run=subprocess.run([sys.executable,str(TEMP/'analyze_feasibility.py')],cwd=TEMP,capture_output=True,text=True,encoding='utf8',errors='replace')
if run.returncode:
    print(run.stderr);raise SystemExit(run.returncode)
checks={}
for name in ['metrics.json','engineering_checks.json','candidate_J_full_parameters.json']:
    checks[name]=json.loads((D/name).read_text(encoding='utf8'))==json.loads((TEMP/name).read_text(encoding='utf8'))
assert all(checks.values())
for item in manifest['files']:
    if item['path'].startswith(('data/','models/','src/')):
        assert hashlib.sha256((D/item['path']).read_bytes()).hexdigest()==item['sha256']
result={'executed_at':datetime.datetime.now().astimezone().isoformat(),'python':sys.version,'temporary_archive':str(TEMP),'historical_source_directory_present':(TEMP.parents[1]/'launch_gate_20261113').exists(),'analysis_exit_code':run.returncode,'exact_json_equality':checks,'packaged_raw_models_and_sources_unchanged':True}
(D/'offline_reproduction_check.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf8')
print(json.dumps(result,ensure_ascii=False,indent=2))
