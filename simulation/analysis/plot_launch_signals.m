function files = plot_launch_signals(data, metrics, cfg, outputDir)
%PLOT_LAUNCH_SIGNALS Save diagnostic launch plots as PNG files.
if nargin < 3 || isempty(cfg), cfg=launch_analysis_config(); end
if nargin < 4 || isempty(outputDir), outputDir=cfg.reportsRoot; end
if ~exist(outputDir,'dir'), mkdir(outputDir); end
files=struct(); t=data.t(:); if isempty(t), return; end
vx=fitVector(data.vx,t); vxEst=fitVector(data.vx_est,t);
ws=fitMatrix(data.wheel_speed,t,4); tq=fitMatrix(data.wheel_torque,t,4);
slip=fitMatrix(data.slip,t,4); lim=fitMatrix(data.torque_limit,t,4);
state=fitVector(data.launch_state,t); spin=fitMatrix(data.spin_flag,t,4);
ax=fitVector(data.ax,t); if isempty(ax) && ~isempty(vx), ax=gradient(vx,t); end
files.speed=makePlot(outputDir,'speed.png',t,{vx,vxEst},{'v_x','v_{x,est}'},'Vehicle speed','m/s',cfg,metrics);
files.wheel_speed=makePlot(outputDir,'wheel_speed.png',t,columns(ws),wheelLabels(),'Wheel speed','m/s',cfg,metrics);
if ~isempty(ws) && ~isempty(vx), files.speed_difference=makePlot(outputDir,'speed_difference.png',t,columns(abs(ws-repmat(vx,1,4))),wheelLabels(),'Wheel speed difference','m/s',cfg,metrics); end
files.slip=makePlot(outputDir,'slip.png',t,columns(slip),wheelLabels(),'Wheel slip ratio','-',cfg,metrics);
files.torque=makePlot(outputDir,'torque.png',t,columns(tq),wheelLabels(),'Wheel torque','N*m',cfg,metrics);
files.torque_limit=makePlot(outputDir,'torque_limit.png',t,columns(lim),wheelLabels(),'Wheel torque limit','N*m',cfg,metrics);
files.state=makePlot(outputDir,'state.png',t,{state},{'state'},'Launch state','-',cfg,metrics);
files.spin=makePlot(outputDir,'spin.png',t,columns(spin),wheelLabels(),'Wheel spin flag','-',cfg,metrics);
files.acceleration=makePlot(outputDir,'acceleration.png',t,{ax},{'a_x'},'Longitudinal acceleration','m/s^2',cfg,metrics);
diag={}; names=fieldnames(data.diagnostics);
for i=1:numel(names)
    if endsWith(names{i},'_t'), continue; end
    v=fitVector(data.diagnostics.(names{i}),t); if ~isempty(v), diag{end+1}=v; end %#ok<AGROW>
end
if ~isempty(diag), files.diagnostics=makePlot(outputDir,'diagnostics.png',t,diag,names(1:numel(diag)),'Diagnostics','mixed',cfg,metrics); end
end

function file=makePlot(dirName,fileName,t,series,labels,titleText,unit,cfg,metrics)
file=fullfile(dirName,fileName); valid=false;
for i=1:numel(series), valid=valid || ~isempty(series{i}); end
if ~valid, return; end
fig=figure('Visible','off','Color','w'); axh=axes(fig); hold(axh,'on');
for i=1:numel(series)
    if ~isempty(series{i}), plot(axh,t,series{i},'LineWidth',1.0,'DisplayName',labels{i}); end
end
xlabel(axh,'Time (s)'); ylabel(axh,unit); title(axh,titleText); grid(axh,'on'); legend(axh,'show','Location','best');
markEvents(axh,t,series,cfg,metrics); exportgraphics(fig,file,'Resolution',150); close(fig);
end
function markEvents(axh,~,~,cfg,metrics)
yl=ylim(axh); if isfield(metrics,'timeToTargetSpeed') && isfinite(metrics.timeToTargetSpeed), xline(axh,metrics.timeToTargetSpeed,'--g','target speed'); end
if isfield(metrics,'spinTriggerDelay') && isfinite(metrics.spinTriggerDelay), xline(axh,cfg.launchWindow(1)+metrics.spinTriggerDelay,'--r','spin'); end
ylim(axh,yl);
end
function c=columns(m)
c={}; if isempty(m), return; end
for i=1:size(m,2), c{end+1}=m(:,i); end
end
function labels=wheelLabels(), labels={'FL','FR','RL','RR'}; end
function v=fitVector(v,t)
if isempty(v), v=[]; return; end
v=v(:); n=min(numel(v),numel(t)); v=v(1:n); if n<numel(t), v(end+1:numel(t),1)=NaN; end
end
function m=fitMatrix(m,t,ncol)
if isempty(m), m=[]; return; end
if isvector(m) && numel(m)==ncol, m=repmat(reshape(m,1,ncol),numel(t),1); end
if size(m,1)==ncol && size(m,2)~=ncol, m=m.'; end
n=min(size(m,1),numel(t)); out=nan(numel(t),ncol); out(1:n,1:min(ncol,size(m,2)))=m(1:n,1:min(ncol,size(m,2))); m=out;
end
