"""Recompute fixed-window diagnostics from original 1 ms records; no controller edits."""
from pathlib import Path
import json,csv,hashlib,re,shutil,zipfile,xml.etree.ElementTree as ET
import numpy as np
from scipy.io import loadmat
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
plt.rcParams.update({'font.family':'DejaVu Sans','font.size':9,'axes.grid':True,'grid.alpha':.25})
D=Path(__file__).resolve().parent;R=D.parents[1];DATA=D/'data';FIG=D/'figures';FIG.mkdir(exist_ok=True)
def ld(p):return loadmat(p,simplify_cells=True)['runData']
def js(p,v):p.write_text(json.dumps(v,ensure_ascii=False,indent=2,allow_nan=False),encoding='utf8')
def table(p,rows):
    with p.open('w',newline='',encoding='utf-8-sig') as f:
        w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
def savefig(fig,name):
    temporary=FIG/(name+'.new.png')
    fig.savefig(temporary,dpi=160)
    temporary.replace(FIG/name)
    plt.close(fig)
def t2(d):
    q=d['vx_raw']>=2/3.6
    return next(i for i in range(len(q)-20) if q[i:i+21].all())
def first(q,t):
    a=np.flatnonzero(q);return float(t[a[0]]) if len(a) else None
def drawdown(y,end):
    y=y[:end+1];j=int(np.argmax(np.maximum.accumulate(y)-y));i=int(np.argmax(y[:j+1]));return i,j,float(y[i]-y[j])
g=ld(DATA/'diag_gate_L2_U08.mat');b=ld(DATA/'diag_baseline_L2_U08.mat');gd=g['data'];bd=b['data'];P=g['P'];t=gd['tout'];W=t<=.407;T=gd['T_actual'];cap=gd['T_max'];base=np.maximum(gd['T_base'],0);diag=gd['gate_diag'];N=len(t)
assert np.array_equal(t,bd['tout']) and np.max(np.abs(np.diff(t)-.001))<1e-10
assert all(np.array_equal(np.asarray(P[k]),np.asarray(b['P'][k])) for k in P)
oldg=ld(DATA/'r2_J_rise24.mat')['data'];oldb=ld(DATA/'fix_baseline_L2_U08.mat')['data']
keys=['vx_raw','ax','T_actual','T_max','T_base','dv','lambda_raw','Implement_D','stage']
repro={k:{'gate_max_abs':float(np.max(np.abs(gd[k].astype(float)-oldg[k].astype(float)))),'baseline_max_abs':float(np.max(np.abs(bd[k].astype(float)-oldb[k].astype(float))))} for k in keys}
assert all(v==0 for x in repro.values() for v in x.values())
js(D/'reproduction_checks.json',repro)
# Ordered intersections and signed command-rate effect form an exact accounting identity.
C=np.minimum(base,np.maximum(cap,0));E=np.minimum(C,np.maximum(diag[:,:4],0));S=np.minimum(E,np.maximum(diag[:,4:8],0));prot=diag[:,48:52]>.5
H=np.where(prot,np.minimum(S,P['q_protect']*cap),S)
hard=np.minimum(np.minimum(cap,base),np.maximum(gd['T_lim_out'],0))
target=np.minimum(np.maximum(gd['T_target'],0),hard);prev=np.vstack([np.zeros((1,4)),gd['T_cmd'][:-1]])
rise=P['gate_cmd_rise_rate']*P['TcapDefault']*.001;fall=P['gate_cmd_fall_rate']*P['TcapDefault']*.001
rate=np.where(target>=prev,np.minimum(target,prev+rise),np.maximum(target,prev-fall));rate[gd['stage']==255]=0
multi=(np.sum(gd['spin_mask'],axis=1)>=2)&(diag[:,40]<.5);mb=diag[:,60]
scale=np.ones(N);active=multi&(rate.sum(1)>mb)&(rate.sum(1)>0);scale[active]=np.maximum(mb[active],0)/rate.sum(1)[active]
scaled=rate*scale[:,None];pred=np.minimum(scaled,hard)
reset=gd['stage']==255;pred[reset]=0
if np.max(np.abs(pred-T))>=1e-6:
    err=np.unravel_index(np.argmax(np.abs(pred-T)),T.shape)
    print('RECONSTRUCTION DEBUG',err,'t',t[err[0]],'actual',T[err[0]],'pred',pred[err[0]],'prev',prev[err[0]],'target',target[err[0]],'rate',rate[err[0]],'mb',mb[err[0]],'multi',multi[err[0]],'stage',gd['stage'][err[0]])
assert np.max(np.abs(pred-T))<1e-6
components={'base':base.sum(1),'cap_loss':(base-C).sum(1),'envelope_loss':(C-E).sum(1),'single_bound_loss':(E-S).sum(1),'protection_loss':(S-H).sum(1),'target_interface_loss':(H-target).sum(1),'rate_effect_signed':(target-rate).sum(1),'multi_projection_loss':(rate-scaled).sum(1),'wheel_projection_loss':(scaled-pred).sum(1),'actual':T.sum(1)}
res=components['base']-sum(v for k,v in components.items() if k not in ['base','actual'])-components['actual']
assert np.max(np.abs(res))<1e-6
rows=[{'time_s':float(t[i]),**{k:float(v[i]) for k,v in components.items()},'residual_Nm':float(res[i])} for i in range(N)]
table(D/'torque_decomposition_1ms.csv',rows)
ip,jp,dd=drawdown(T.sum(1),t2(gd));dbi,dbj,dbdd=drawdown(bd['T_actual'].sum(1),t2(bd))
contrib={k:float(v[ip]-v[jp]) if k=='base' else float(v[jp]-v[ip]) for k,v in components.items() if k!='actual'}
events=[]
for strategy,d in [('gate',gd),('baseline',bd)]:
    for j,wheel in enumerate(['FL','FR','RL','RR']):
        for name,q in [('prewarn_first',d['prewarn'][:,j]>0),('spin_confirm_first',d['spin_mask'][:,j]>0),('actual_torque_first_decrease',np.r_[False,np.diff(d['T_actual'][:,j])< -1e-6]),('Fx_peak_0_407',None),('dv_peak_0_407',None)]:
            z=first(q,t) if q is not None else float(t[np.flatnonzero(W)[np.argmax(d['Fx'][W,j] if name.startswith('Fx') else d['dv'][W,j])]])
            events.append(dict(strategy=strategy,wheel=wheel,event=name,time_s=z,interpretation='baseline supervisor is bypassed; events do not execute control' if strategy=='baseline' and name in ['prewarn_first','spin_confirm_first'] else ''))
    events.append(dict(strategy=strategy,wheel='vehicle',event='t2_20ms_hold',time_s=float(t[t2(d)]),interpretation='2 km/h continuous 21 samples, onset time'))
events.append(dict(strategy='gate',wheel='vehicle',event='torque_drawdown_peak',time_s=float(t[ip]),interpretation=f'end={t[jp]:.3f} s; drawdown={dd:.6f} Nm'))
table(D/'event_timeline.csv',events);js(D/'event_timeline.json',events)
metrics=[]
for strategy,d in [('baseline',bd),('candidate_J',gd)]:
    q=t2(d);i,j,draw=drawdown(d['T_actual'].sum(1),q)
    f=d['Fx_forward_planar'];sp=d['spin_mask'];Tt=d['T_actual'];gg=d['gate_diag'];m=np.sum(sp,axis=1)>=2
    row={'strategy':strategy,'t2_s':float(t[q]),'dv_peak_common_mps':float(d['dv'][W].max()),'lambda_raw_P95_common':float(np.percentile(d['lambda_raw'][W],95)),'torque_drawdown_to_t2_Nm':draw,'drawdown_start_s':float(t[i]),'drawdown_end_s':float(t[j]),'actual_min_Nm':float(Tt.min()),'max_over_cap_Nm':float((Tt-d['T_max']).max()),'Fx_forward_impulse_common_Ns':float(np.trapezoid(f[W].sum(1),t[W])),'Fx_forward_mean_common_N':float(f[W].sum(1).mean()),'Fx_front_mean_common_N':float(f[W,:2].sum(1).mean()),'Fx_rear_mean_common_N':float(f[W,2:].sum(1).mean()),'Fz_min_N':float(d['Fz'].min()),'gate_path_loss_common_ratio':float(np.trapezoid(np.maximum(np.minimum(np.maximum(d['T_base'][W],0),d['T_max'][W])-Tt[W],0).sum(1),t[W])/np.trapezoid(np.minimum(np.maximum(d['T_base'][W],0),d['T_max'][W]).sum(1),t[W]))}
    metrics.append(row)
table(D/'metrics.csv',metrics);js(D/'metrics.json',metrics)
lim=multi&(t>0)
checks={'finite_core':True,'sample_count':N,'end_time_s':float(t[-1]),'candidate_parameters_equal_baseline':True,'override_parameters_equal_snapshot':True,'max_actual_minus_cmd_Nm':float(np.abs(T-gd['T_cmd']).max()),'max_single_hard_excess_Nm':float((T-gd['T_lim_out']).max()),'max_multi_excess_Nm':float((T[lim].sum(1)-mb[lim]).max()),'max_reconstruction_residual_Nm':float(np.abs(res).max()),'single_bound_active_samples_per_wheel':np.sum(diag[:,24:28]>.5,axis=0).tolist(),'minimum_single_bound_after_first_warning_Nm':float(diag[t>.1,4:8].min()),'warn_edges':np.sum(np.diff(gd['prewarn'].astype(int),axis=0)==1,axis=0).tolist(),'spin_edges':np.sum(np.diff(gd['spin_mask'].astype(int),axis=0)==1,axis=0).tolist(),'stage_counts':{str(k):int(v) for k,v in zip(*np.unique(gd['stage'],return_counts=True))},'handoff_time_s':first(diag[:,40]>.5,t),'protection_samples_in_vehicle_run':int(prot.any(1).sum()),'drawdown_components_Nm':contrib,'drawdown_sum_Nm':float(sum(contrib.values())),'baseline_drawdown_Nm':dbdd,'conclusion':'证据不足','deployment':False,'blocking_defect':'single-wheel event bound initialized at 1e12 never reaches finite event target within run; inactive in all samples'}
js(D/'engineering_checks.json',checks)
raw_delay=np.vstack([np.zeros((1,4)),gd['T_distribution_unclipped'][:-1]]).astype(float)
previous_cap=np.vstack([np.zeros((1,4)),cap[:-1]])
upstream_pred=np.minimum(np.maximum(raw_delay.astype(np.float32),0),previous_cap.astype(np.float32)).astype(float)
checks['upstream_cap_single_precision_max_residual_Nm']=float(np.abs(upstream_pred-base).max())
assert checks['upstream_cap_single_precision_max_residual_Nm']<.005
upstream_loss=(raw_delay-base).sum(1)
checks['drawdown_refined_Nm']={'unclipped_distribution_change':float(raw_delay[ip].sum()-raw_delay[jp].sum()),'upstream_common_cap_change':float(upstream_loss[jp]-upstream_loss[ip]),'current_cap_change':contrib['cap_loss'],'gate_and_rate_endpoint_change':float(sum(v for k,v in contrib.items() if k not in ['base','cap_loss']))}
table(D/'drawdown_refined_attribution.csv',[{'component':k,'contribution_to_drawdown_Nm':v} for k,v in checks['drawdown_refined_Nm'].items()])
checks['gate_diag_target_max_error_Nm']=float(np.abs(diag[:,52:56]-target).max())
checks['gate_diag_target_note']='gate_diag(53:56) repeats last scalar target (RR); use T_target and T_lim_out for per-wheel accounting'
checks['maximum_path_deficit_common_Nm']=float((C[W].sum(1)-T[W].sum(1)).max())
checks['maximum_multi_projection_common_Nm']=float(components['multi_projection_loss'][W].max())
js(D/'engineering_checks.json',checks)
table(D/'drawdown_attribution.csv',[{'component':k,'contribution_to_drawdown_Nm':v} for k,v in contrib.items()])
# Parameter values and code-use locations, including inherited inactive legacy fields.
src=(D/'src/LaunchTCS_Torque_gate.m').read_text(encoding='utf8')+'\n'+(D/'src/MONITOR_gate.txt').read_text(encoding='utf8')+'\n'+(D/'src/LaunchTCS_Motion.m').read_text(encoding='utf8')
prows=[]
for k,v in P.items():
    prows.append({'parameter':k,'value':json.dumps(np.asarray(v).tolist()),'used_in_launch_sources':bool(re.search(r'\bP\.'+re.escape(k)+r'\b',src))})
table(D/'parameter_values.csv',prows)
js(D/'candidate_J_full_parameters.json',{k:np.asarray(v).tolist() for k,v in P.items()})
# Prior evidence index, explicitly distinguishing first-round matrix and J subset.
index=[]
for prefix,cases in [('fix_base_', [f'L{l}_{u}' for l in range(3) for u in ['U05','U08','RAMP']]),('fix_gate_', [f'L{l}_{u}' for l in range(3) for u in ['U05','U08','RAMP']])]:
    for case in cases:
        p=R/'launch_gate_20261113'/((prefix+case) if not(prefix=='fix_base_' and case=='L2_U08') else 'fix_baseline_L2_U08');p=p.with_suffix('.mat')
        if p.exists():index.append({'version':'first correction; not full J matrix','case':case,'source':str(p),'archived_path':'','sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size})
for p in sorted(DATA.glob('r2_J*.mat')):index.append({'version':'candidate J','case':ld(p)['case_id'],'source':str(R/'launch_gate_20261113'/p.name),'archived_path':str(p.relative_to(D)),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size})
if (R/'launch_gate_20261113').exists():table(D/'validation_version_index.csv',index)
for src,dst in [('fix_metrics.csv','historical_nine_case_metrics.csv'),('candidate_gate_metrics.csv','historical_candidate_metrics.csv')]:
    if (R/'launch_gate_20261113'/src).exists():shutil.copy2(R/'launch_gate_20261113'/src,D/dst)
# Check actual model member differences without mistaking layout edits for logic changes.
visual={'Position','ZOrder','Points','Location','Open','ZoomFactor','visible','viewLimits','viewObj','screen','subviewS','EditorSettings','Creator','LastModifiedBy','LastModifiedDate','ModifiedTime','SavedCharacterEncoding'}
def clean_xml(blob):
    root=ET.fromstring(blob)
    def clean(e):
        for c in list(e):
            if (c.tag=='P' and c.get('Name') in visual) or c.tag in ['subviewS']:e.remove(c)
            else:clean(c)
        if e.text is not None:e.text=e.text.strip() or None
        if e.tail is not None:e.tail=None
    clean(root);return ET.tostring(root)
def semantic_system(blob):
    root=ET.fromstring(clean_xml(blob));edges=[]
    for line in list(root.findall('Line')):
        src=line.find("P[@Name='Src']")
        if src is not None:
            edges.extend((src.text,p.text) for p in line.iter('P') if p.get('Name')=='Dst')
        root.remove(line)
    # Label placement is presentation only; source/destination graph is checked independently.
    for el in root.iter():
        for p in list(el):
            if p.tag=='P' and p.get('Name') in {'Labels','NameLocation','NamePlacement'}:el.remove(p)
    return ET.tostring(root),sorted(edges)
old=R/'launch_gate_20261113/before_20261113_095512/tractor_mu.slx';now=R/'simulation/models/tractor_mu.slx'
checksxml={}
if old.exists() and now.exists():
    with zipfile.ZipFile(old) as za,zipfile.ZipFile(now) as zb:
        for name in ['simulink/stateflow/chart_870.xml','simulink/systems/system_1787.xml','simulink/systems/system_root.xml']:
            checksxml[name]=clean_xml(za.read(name))==clean_xml(zb.read(name))
        graph_checks={name:semantic_system(za.read(name))==semantic_system(zb.read(name)) for name in ['simulink/systems/system_1787.xml','simulink/systems/system_root.xml']}
    js(D/'formal_normalized_checks.json',{'method':'Presentation-property removal plus independent unordered source-to-destination graph comparison; all other block parameters and scripts retained','equal_after_presentation_removal':checksxml,'semantic_block_and_connection_equality':graph_checks,'formal_untouched_this_task':True})
# Preserve every warning occurrence and a compact de-duplicated summary.
warning_summary={}
for p in D.glob('*_warnings.txt'):
    text=p.read_text(encoding='utf8',errors='replace').replace('\x08','')
    msgs=re.findall(r'警告: ([^\n]+)',text)
    clean=[re.sub('<[^>]+>','',x).strip() for x in msgs]
    from collections import Counter
    warning_summary[p.name]={'occurrences':len(clean),'unique':dict(Counter(clean))}
js(D/'warning_summary.json',warning_summary)
# Plot 0-0.5 seconds on exactly the same time axis.
colors=['#2368a2','#de7c28','#258359','#a44290'];wh=['FL','FR','RL','RR']
fig,axs=plt.subplots(8,1,figsize=(12,16),sharex=True,layout='constrained')
for d,label,style in [(bd,'Vertical-load baseline','--'),(gd,'Candidate J','-')]:
    axs[0].plot(t,d['vx_raw']*3.6,style,label=label);axs[1].plot(t,d['ax'],style,label=label)
    for j in range(4):axs[2].plot(t,d['dv'][:,j],style,color=colors[j],alpha=.75,label=wh[j] if label=='Candidate J' else None)
    for j in range(4):axs[3].plot(t,d['lambda_raw'][:,j],style,color=colors[j],alpha=.75)
    axs[4].plot(t,d['T_actual'].sum(1)/1000,style,label=label)
    axs[5].plot(t,d['Fx_forward_planar'].sum(1)/1000,style,label=label+' total')
axs[0].axhline(2,color='gray',lw=.8);axs[4].plot(t,base.sum(1)/1000,':',color='black',label='J base');axs[4].plot(t,cap.sum(1)/1000,':',color='gray',label='J cap sum')
axs[6].plot(t,gd['Implement_D']/1000,label='J equivalent resistance');axs[6].plot(t,bd['Implement_D']/1000,'--',label='baseline resistance')
for j in range(4):
    axs[7].step(t,gd['prewarn'][:,j]+j*2,where='post',color=colors[j],label=wh[j]+' warning')
    axs[7].step(t,gd['spin_mask'][:,j]+j*2,where='post',color=colors[j],ls='--')
for ax,y in zip(axs,['Ground speed (km/h)','ax (m/s2)','dv (m/s)','Raw slip ratio','Torque sum (kNm)','Forward planar Fx (kN)','Resistance D (kN)','Events, offset / wheel']):
    ax.set_ylabel(y);ax.set_xlim(0,.5);ax.axvline(.406,color='black',alpha=.3,lw=.7);ax.axvline(.407,color='gray',alpha=.4,lw=.7)
for j in [0,2,4,5,6,7]:axs[j].legend(loc='upper right',ncol=3,fontsize=8)
axs[-1].set_xlabel('Time (s)');fig.suptitle('L2_U08 fixed-parameter diagnosis | solid: J; dashed: baseline | 1 ms sampling')
for ax,ylim in zip(axs,[(0,2.6),(-.05,2.5),(-.2,13.5),(-.02,1.05),(-2,180),(-1,47),(-.2,15.5),(-.2,7.5)]):ax.set_ylim(*ylim)
savefig(fig,'L2_U08_common_0_0p5.png')
fig,axs=plt.subplots(4,3,figsize=(16,12),sharex=True,layout='constrained')
for j in range(4):
    axs[j,0].plot(t,gd['Romega_raw'][:,j],label='raw R omega');axs[j,0].plot(t,gd['v_ref'][:,j],label='filtered wheel-direction v_ref');axs[j,0].set_ylabel(wh[j]+' speed (m/s)')
    for d,ls,label in [(gd,'-','J'),(bd,'--','baseline')]:
        axs[j,1].plot(t,d['Fx'][:,j]/1000,ls,label=label+' Fx');axs[j,1].plot(t,d['Fz'][:,j]/1000,ls,alpha=.5,label=label+' Fz')
    for name,label,ls in [('T_base','base',':'),('T_target','target','--'),('T_actual','command','-'),('T_max','cap','-.')]:axs[j,2].plot(t,gd[name][:,j]/1000,ls,label=label)
    axs[j,1].set_ylabel(wh[j]+' force (kN)');axs[j,2].set_ylabel(wh[j]+' torque (kNm)')
for ax in axs.flat:ax.set_xlim(0,1.5)
for ax in axs[0]:ax.legend(fontsize=8)
for ax in axs[-1]:ax.set_xlabel('Time (s)')
fig.suptitle('Direct solver force diagnostics and wheel commands; includes >1 s after t2')
savefig(fig,'wheel_diagnostics_0_1p5.png')
fig,axs=plt.subplots(3,1,figsize=(12,10),sharex=True,layout='constrained')
axs[0].plot(t,T.sum(1)/1000,label='actual command');axs[0].plot(t,C.sum(1)/1000,label='executable demand min(base, cap)');axs[0].plot(t,base.sum(1)/1000,':',label='base');axs[0].legend()
for k in ['cap_loss','envelope_loss','single_bound_loss','rate_effect_signed','multi_projection_loss','wheel_projection_loss']:axs[1].plot(t,components[k]/1000,label=k)
axs[1].legend(ncol=3,fontsize=8)
for j in range(4):axs[2].semilogy(t,np.maximum(diag[:,4+j],1),color=colors[j],label=wh[j]+' actual single bound')
axs[2].plot(t,cap.max(1),'k--',label='max wheel motor cap');axs[2].legend(ncol=3)
for ax in axs:ax.set_xlim(0,.5);ax.axvline(t[ip],color='gray',ls=':');ax.axvline(t[jp],color='gray',ls=':')
axs[0].set_ylabel('Torque sum (kNm)');axs[1].set_ylabel('Loss/effect (kNm)');axs[2].set_ylabel('Single bound (Nm, log)');axs[2].set_xlabel('Time (s)')
axs[1].set_ylim(-4,20)
fig.suptitle('Exact command accounting; inactive 1e12 single bounds are a control defect')
savefig(fig,'torque_source_decomposition.png')
fig,axs=plt.subplots(4,1,figsize=(12,10),sharex=True,layout='constrained')
for d,ls,lbl in [(gd,'-','J'),(bd,'--','baseline')]:
    axs[0].plot(t,d['vx_raw']*3.6,ls,label=lbl);axs[1].plot(t,d['Fx_forward_planar'][:,:2].sum(1)/1000,ls,label=lbl+' front');axs[1].plot(t,d['Fx_forward_planar'][:,2:].sum(1)/1000,ls,label=lbl+' rear');axs[2].plot(t,d['T_actual'].sum(1)/1000,ls,label=lbl);axs[3].plot(t,d['T0']/1000,ls,label=lbl+' T0');axs[3].plot(t,d['Implement_D']/1000,ls,label=lbl+' D (kN)')
for ax,y in zip(axs,['Speed (km/h)','Axle force (kN)','Command sum (kNm)','T0 (kNm), D (kN)']):ax.set_ylabel(y);ax.legend(ncol=4);ax.set_xlim(0,5)
axs[-1].set_xlabel('Time (s)');savefig(fig,'full_run_0_5.png')
print(json.dumps({'metrics':metrics,'checks':checks,'formal_xml':checksxml},ensure_ascii=False,indent=2))
