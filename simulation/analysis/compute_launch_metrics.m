function metrics = compute_launch_metrics(data, cfg)
%COMPUTE_LAUNCH_METRICS Compute launch and wheel-slip indicators.
if nargin < 2 || isempty(cfg), cfg=launch_analysis_config(); end
metrics = struct();
metrics.status = 'INSUFFICIENT_DATA';
metrics.success = NaN;
metrics.timeToTargetSpeed = NaN;
metrics.timeToTargetDistance = NaN;
metrics.responseDelay = NaN;
metrics.peakLongitudinalAcceleration = NaN;
metrics.accelerationResponseTime = NaN;
metrics.wheelSpeedDiffPeak = NaN;
metrics.wheelSpeedDiffRMS = NaN;
metrics.singleWheelSpinDuration = NaN;
metrics.multiWheelSpinDuration = NaN;
metrics.allWheelSpinDuration = NaN;
metrics.spinTriggerDelay = NaN;
metrics.spinClearTime = NaN;
metrics.maxLaunchSlip = NaN;
metrics.meanLaunchSlip = NaN;
metrics.peakTorque = NaN;
metrics.peakTorqueRate = NaN;
metrics.stateTransitionCount = NaN;
metrics.stateChatterCount = NaN;
metrics.invalidSampleCount = 0;
metrics.timeTorqueIncreasingNoMove = NaN;
metrics.postLaunchTorqueContinuous = NaN;
metrics.timeVectorValid = false;
metrics.notes = {};

t = data.t(:);
if isempty(t)
    metrics.status='INVALID_RUN'; metrics.notes{end+1}='Missing time vector.'; return;
end
metrics.invalidSampleCount = sum(~isfinite(t));
dt=diff(t); metrics.timeVectorValid=all(isfinite(t)) && all(dt>0);
if ~metrics.timeVectorValid
    metrics.status='INVALID_RUN'; metrics.notes{end+1}='Time vector contains NaN/Inf or is not strictly increasing.'; return;
end
win = t>=cfg.launchWindow(1) & t<=cfg.launchWindow(2);
if ~any(win), metrics.status='INSUFFICIENT_DATA'; return; end

vx = vectorForTime(data.vx,t); if isempty(vx), vx=vectorForTime(data.vx_est,t); end
X = vectorForTime(data.X,t);
ax = vectorForTime(data.ax,t);
if isempty(ax) && ~isempty(vx), ax=gradient(vx,t); end
if ~isempty(vx)
    idx=find(win & vx>=cfg.targetSpeed,1,'first');
    if ~isempty(idx), metrics.timeToTargetSpeed=t(idx); end
    if ~isempty(ax), metrics.peakLongitudinalAcceleration=max(abs(ax(win))); end
    if isempty(metrics.timeToTargetSpeed), metrics.success=false; else, metrics.success=true; end
end
if ~isempty(X)
    x0=X(find(isfinite(X),1,'first')); idx=find(win & (X-x0)>=cfg.targetDistance,1,'first');
    if ~isempty(idx), metrics.timeToTargetDistance=t(idx); end
end

ws = matrixForTime(data.wheel_speed,t,4);
if ~isempty(ws) && ~isempty(vx)
    ref=repmat(vx,1,4); dv=ws-ref; dv=abs(dv);
    metrics.wheelSpeedDiffPeak=max(dv(win,:),[],'all','omitnan');
    metrics.wheelSpeedDiffRMS=sqrt(mean(dv(win,:).^2,'all','omitnan'));
    spin = dv>=cfg.spinThreshold;
else
    dv=[]; spin=[];
end
if ~isempty(data.spin_flag)
    spin=matrixForTime(data.spin_flag,t,4)~=0;
end
if ~isempty(spin)
    nSpin=sum(spin,2); metrics.singleWheelSpinDuration=max(sum(spin,1))*median(dt);
    metrics.multiWheelSpinDuration=sum(nSpin>=2)*median(dt); metrics.allWheelSpinDuration=sum(nSpin>=4)*median(dt);
    firstSpin=find(any(spin & win,2),1,'first');
    if ~isempty(firstSpin), metrics.spinTriggerDelay=t(firstSpin)-t(find(win,1,'first')); end
    lastSpin=find(any(spin & win,2),1,'last');
    if ~isempty(lastSpin) && ~isempty(firstSpin), metrics.spinClearTime=t(lastSpin)-t(firstSpin); end
end
slip=matrixForTime(data.slip,t,4);
if isempty(slip) && ~isempty(ws) && ~isempty(vx)
    slip=(ws-repmat(vx,1,4))./max(abs(repmat(vx,1,4)),cfg.slipSpeedFloor);
end
if ~isempty(slip)
    av=abs(slip(win,:)); metrics.maxLaunchSlip=max(av,[],'all','omitnan'); metrics.meanLaunchSlip=mean(av,'all','omitnan');
end
torque=matrixForTime(data.wheel_torque,t,4);
if ~isempty(torque)
    metrics.peakTorque=max(abs(torque(win,:)),[],'all','omitnan');
    tr=diff(torque)./diff(t); metrics.peakTorqueRate=max(abs(tr),[],'all','omitnan');
    if ~isempty(vx) && isfinite(metrics.peakTorque) && metrics.peakTorque>0
        torqueStart=find(win & any(abs(torque)>=0.02*metrics.peakTorque,2),1,'first');
        moveStart=find(win & vx>=cfg.v_move_on,1,'first');
        if ~isempty(torqueStart) && ~isempty(moveStart), metrics.responseDelay=max(0,t(moveStart)-t(torqueStart)); end
    end
    if ~isempty(vx)
        moving=vx>=cfg.targetSpeed*0.2; rising=[false; any(diff(torque)>0,2)];
        metrics.timeTorqueIncreasingNoMove=sum(win & ~moving & rising)*median(dt);
        if any(moving & win), metrics.postLaunchTorqueContinuous=all(isfinite(torque(moving & win,:)),'all'); end
    end
end
state=vectorForTime(data.launch_state,t);
if ~isempty(state)
    changes=find(diff(state)~=0); metrics.stateTransitionCount=numel(changes);
    metrics.stateChatterCount=sum(diff(t(changes))<cfg.stateChatterWindow);
end
if ~isempty(ax) && ~isempty(vx)
    i0=find(win & vx>=cfg.targetSpeed*0.2,1,'first');
    if ~isempty(i0), metrics.accelerationResponseTime=t(i0)-t(find(win,1,'first')); end
end
metrics.invalidSampleCount=metrics.invalidSampleCount + countInvalid({vx,X,ax,ws,slip,torque});
if metrics.invalidSampleCount>0, metrics.notes{end+1}='One or more analyzed signals contain NaN/Inf.'; end

if isnan(metrics.success)
    metrics.status='INSUFFICIENT_DATA';
elseif metrics.invalidSampleCount>0
    metrics.status='INVALID_RUN';
elseif metrics.success && (~isnan(metrics.multiWheelSpinDuration) && metrics.multiWheelSpinDuration>cfg.maxAllowedSpinTime)
    metrics.status='IMPROVABLE';
elseif metrics.success
    metrics.status='PASS';
else
    metrics.status='IMPROVABLE';
end
end

function v=vectorForTime(v,t)
if isempty(v), v=[]; return; end
v=v(:); n=min(numel(v),numel(t)); v=v(1:n); if n<numel(t), v(end+1:numel(t),1)=NaN; end
end
function m=matrixForTime(v,t,ncol)
if isempty(v), m=[]; return; end
if isvector(v) && numel(v)==ncol, m=repmat(reshape(v,1,ncol),numel(t),1); return; end
if size(v,2)~=ncol && size(v,1)==ncol, v=v.'; end
n=min(size(v,1),numel(t)); m=nan(numel(t),ncol); m(1:n,1:min(ncol,size(v,2)))=v(1:n,1:min(ncol,size(v,2)));
end
function n=countInvalid(c)
n=0; for i=1:numel(c), if ~isempty(c{i}), n=n+sum(~isfinite(c{i}(:))); end, end
end
