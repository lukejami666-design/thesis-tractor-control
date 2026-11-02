function suggestions = suggest_launch_params(metrics, cfg, parameterFile)
%SUGGEST_LAUNCH_PARAMS Generate bounded, review-only parameter suggestions.
if nargin < 2 || isempty(cfg), cfg=launch_analysis_config(); end
if nargin < 3 || isempty(parameterFile), parameterFile=cfg.parameterFile; end
P=struct();
try
    [folder,name]=fileparts(parameterFile); if isempty(folder), folder=pwd; end
    previousPath=path;
    pathCleanup=onCleanup(@() path(previousPath));
    addpath(folder); P=feval(name);
catch
end
suggestions=struct('parameter',{},'currentValue',{},'proposedValue',{},'direction',{},'reason',{},'expectedEffect',{},'risk',{},'sourceMetrics',{},'requiresConfirmation',{});
add('dv_spin_on',-0.10,'decrease','Spin detection appears late.','Earlier detection of wheel-speed divergence.','False positives under noisy wheel speed.',{'spinTriggerDelay'});
add('dv_spin_off',-0.05,'decrease','Spin clear threshold may be too high for timely release.','Earlier spin release after convergence.','State chatter if hysteresis becomes too narrow.',{'spinClearTime'});
add('t_spin_on',-0.01,'decrease','Spin confirmation delay is long.','Faster response to sustained spin.','Transient noise may trigger spin.',{'spinTriggerDelay'});
add('q_probe_rate',-0.05,'decrease','Torque ramp is fast while launch response is poor or slip is high.','Gentler torque probing.','Longer launch time.',{'maxLaunchSlip','peakTorqueRate'});
add('q_start',0.02,'increase','Launch response is slow with no evidence of excessive spin.','Faster initial wheel torque buildup.','May increase initial slip.',{'responseDelay','timeToTargetSpeed'});
add('q_no_move_max',-0.03,'decrease','Torque accumulates while the vehicle is not moving.','Reduce stationary torque exposure.','May reduce heavy-load launch capability.',{'timeTorqueIncreasingNoMove'});
add('q_spin_down',0.10,'increase','Spin is sustained after detection.','Stronger post-spin torque reduction.','Can cause a noticeable acceleration dip.',{'multiWheelSpinDuration','singleWheelSpinDuration'});
add('q_multi_cut_rate',0.15,'increase','Multiple-wheel spin persists.','Faster total-torque reduction during multi-wheel spin.','May reduce tractive effort.',{'multiWheelSpinDuration','allWheelSpinDuration'});
add('cmd_rise_rate',-0.10,'decrease','Torque-rate peak is high or torque has jumps.','Smoother commanded torque.','Slower response.',{'peakTorqueRate'});
add('cmd_fall_rate',0.20,'increase','Torque needs to fall faster after spin.','Faster torque removal.','More abrupt longitudinal response.',{'peakTorqueRate','spinClearTime'});
if numel(suggestions)>3, suggestions=suggestions(1:3); end
    function add(name,delta,direction,reason,effect,risk,source)
        if ~isfield(P,name) || ~isfinite(P.(name)), return; end
        trigger=false;
        if strcmp(name,'dv_spin_on') || strcmp(name,'t_spin_on'), trigger=isfinite(metrics.spinTriggerDelay) && metrics.spinTriggerDelay>0.15; end
        if strcmp(name,'dv_spin_off'), trigger=isfinite(metrics.spinClearTime) && metrics.spinClearTime>cfg.maxAllowedSpinTime; end
        if strcmp(name,'q_probe_rate'), trigger=isfinite(metrics.maxLaunchSlip) && metrics.maxLaunchSlip>0.20 && isfinite(metrics.peakTorqueRate); end
        if strcmp(name,'q_start'), trigger=isfinite(metrics.timeToTargetSpeed) && metrics.timeToTargetSpeed>5 && (~isfinite(metrics.maxLaunchSlip) || metrics.maxLaunchSlip<0.20); end
        if strcmp(name,'q_no_move_max'), trigger=isfinite(metrics.timeTorqueIncreasingNoMove) && metrics.timeTorqueIncreasingNoMove>cfg.maxAllowedSpinTime; end
        if strcmp(name,'q_spin_down') || strcmp(name,'q_multi_cut_rate'), trigger=isfinite(metrics.multiWheelSpinDuration) && metrics.multiWheelSpinDuration>cfg.maxAllowedSpinTime; end
        if strcmp(name,'cmd_rise_rate'), trigger=isfinite(metrics.peakTorqueRate) && metrics.peakTorqueRate>10000; end
        if strcmp(name,'cmd_fall_rate'), trigger=isfinite(metrics.spinClearTime) && metrics.spinClearTime>cfg.maxAllowedSpinTime; end
        if ~trigger, return; end
        old=P.(name); proposed=max(0,old+delta);
        s=struct('parameter',name,'currentValue',old,'proposedValue',proposed,'direction',direction,'reason',reason,'expectedEffect',effect,'risk',risk,'sourceMetrics',{source},'requiresConfirmation',true);
        suggestions(end+1)=s;
    end
end
