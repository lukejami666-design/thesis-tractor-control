function [data, info] = load_launch_data(matFile, cfg)
%LOAD_LAUNCH_DATA Load direct variables, Dataset, SimulationOutput and timeseries.
%   Missing signals remain [] and are listed in info.missingSignals.

if nargin < 2 || isempty(cfg)
    cfg = launch_analysis_config();
end
if ~(ischar(matFile) || isstring(matFile)) || ~isfile(matFile)
    error('load_launch_data:FileNotFound', 'MAT file not found: %s', char(matFile));
end
raw = load(char(matFile), '-mat');
data = struct('t', [], 'vx', [], 'vx_est', [], 'X', [], 'Y', [], ...
    'beta_e', [], 'omega_ref', [], 'ax', [], 'wheel_speed', [], ...
    'wheel_torque', [], 'slip', [], 'launch_state', [], 'spin_flag', [], ...
    'torque_limit', [], 'diagnostics', struct());
info = struct('file', char(matFile), 'timeInferred', false, 'sources', struct(), ...
    'missingSignals', {{}}, 'warnings', {{}});

[globalT, hasGlobalT] = findSignal(raw, cfg.signalMap.time);
if hasGlobalT
    [globalT, ~] = toSignal(globalT, []);
end

simpleNames = {'vx','vxEst','X','Y','beta_e','omega_ref','ax','slip','kappa','state','spinFlag','torqueLimit'};
simpleFields = {'vx','vx_est','X','Y','beta_e','omega_ref','ax','slip','kappa','launch_state','spin_flag','torque_limit'};
for i = 1:numel(simpleNames)
    key = simpleNames{i};
    if ~isfield(cfg.signalMap, key), continue; end
    [v, ok, src] = findSignal(raw, cfg.signalMap.(key));
    if ok
        [v, tv] = toSignal(v, globalT);
        data.(simpleFields{i}) = v;
        if isempty(data.t) && ~isempty(tv), data.t = tv; end
        info.sources.(simpleFields{i}) = src;
    end
end

[data.wheel_speed, tWheel, srcWheel] = assembleFour(raw, cfg.signalMap.wheelSpeed, cfg.signalMap.wheelSpeedIndividual, globalT);
[data.wheel_torque, tTorque, srcTorque] = assembleFour(raw, cfg.signalMap.wheelTorque, cfg.signalMap.wheelTorqueIndividual, globalT);
[data.slip, tSlip, srcSlip] = assembleFour(raw, cfg.signalMap.slip, cfg.signalMap.slipIndividual, globalT);
[data.spin_flag, tSpin, srcSpin] = assembleFour(raw, cfg.signalMap.spinFlag, cfg.signalMap.spinIndividual, globalT, true);
[data.torque_limit, tLimit, srcLimit] = assembleFour(raw, cfg.signalMap.torqueLimit, cfg.signalMap.torqueLimitIndividual, globalT);
if isempty(data.t) 
    candidates = {tWheel,tTorque,tSlip,tSpin,tLimit};
    for i = 1:numel(candidates)
        if ~isempty(candidates{i}), data.t = candidates{i}; break; end
    end
end
info.sources.wheel_speed = srcWheel; info.sources.wheel_torque = srcTorque;
info.sources.slip = srcSlip; info.sources.spin_flag = srcSpin; info.sources.torque_limit = srcLimit;

% If all signals lack an explicit time vector, infer it from the longest signal.
if isempty(data.t)
    n = maxSignalLength(data);
    if n > 0
        data.t = (0:n-1)' * cfg.defaultTs;
        info.timeInferred = true;
        info.warnings{end+1} = 'No time vector was found; sample indices were converted using cfg.defaultTs.';
    end
end
data.t = columnTime(data.t);
if isempty(data.t)
    info.warnings{end+1} = 'No usable time vector or signal data was found.';
end

if strcmpi(cfg.wheelSpeedSource, 'angular') && ~isempty(data.wheel_speed)
    data.wheel_speed = data.wheel_speed .* reshape(cfg.wheelRadius, 1, 4);
end

diagNames = cfg.signalMap.diagnostics;
for i = 1:numel(diagNames)
    [v, ok, src] = findSignal(raw, {diagNames{i}});
    if ok
        [v, tv] = toSignal(v, data.t);
        data.diagnostics.(matlab.lang.makeValidName(diagNames{i})) = v;
        data.diagnostics.([matlab.lang.makeValidName(diagNames{i}) '_t']) = tv;
        info.sources.(['diagnostic_' matlab.lang.makeValidName(diagNames{i})]) = src;
    end
end

required = {'vx','wheel_speed','wheel_torque','slip','launch_state','spin_flag','torque_limit'};
for i = 1:numel(required)
    if isempty(data.(required{i})), info.missingSignals{end+1} = required{i}; end
end
end

function [value, ok, source] = findSignal(raw, aliases)
value = []; ok = false; source = '';
if ischar(aliases) || isstring(aliases), aliases = {char(aliases)}; end
for i = 1:numel(aliases)
    name = aliases{i};
    [value, ok] = lookup(raw, name);
    if ok, source = name; return; end
end
% Dataset and SimulationOutput are often stored under these fields.
containers = {'logsout','out','simOut'};
for c = 1:numel(containers)
    [container, found] = lookup(raw, containers{c});
    if ~found, continue; end
    for i = 1:numel(aliases)
        [value, ok] = lookup(container, aliases{i});
        if ok, source = [containers{c} '.' aliases{i}]; return; end
    end
end
end

function [value, ok] = lookup(container, name)
value = []; ok = false;
if isempty(container), return; end
if isstruct(container)
    if isfield(container, name), value = container.(name); ok = true; return; end
    if contains(name,'.')
        parts = strsplit(name,'.'); value = container;
        for p = 1:numel(parts)
            if isstruct(value) && isfield(value,parts{p}), value = value.(parts{p}); else, value=[]; return; end
        end
        ok = true; return;
    end
end
try
    if isa(container, 'Simulink.SimulationData.Dataset')
        el = container.getElementByName(name);
        if ~isempty(el), value = el.Values; ok = true; return; end
    end
catch
end
try
    if isobject(container)
        if isprop(container, name), value = container.(name); ok = true; return; end
        if any(strcmp(methods(container), 'get'))
            value = container.get(name);
            if ~isempty(value), ok = true; return; end
        end
    end
catch
end
end

function [value, t] = toSignal(v, fallbackT)
t = [];
if isempty(v), value=[]; return; end
try
    if isa(v,'timeseries')
        t = v.Time; value = v.Data;
    elseif isstruct(v) && isfield(v,'time') && isfield(v,'signals')
        t = v.time; value = v.signals.values;
    elseif isstruct(v) && isfield(v,'Time') && isfield(v,'Data')
        t = v.Time; value = v.Data;
    elseif isstruct(v) && isfield(v,'values')
        value = v.values; if isfield(v,'time'), t=v.time; end
    elseif isobject(v) && isprop(v,'Time') && isprop(v,'Data')
        t = v.Time; value = v.Data;
    else
        value = v;
    end
catch
    value = v;
end
if isempty(t), t = fallbackT; end
if isnumeric(value) || islogical(value)
    if isvector(value), value = value(:); end
end
if ~isempty(t), t = t(:); end
end

function [out, tOut, sources] = assembleFour(raw, matrixAliases, individualAliases, globalT, logicalFlag)
if nargin < 6, logicalFlag = false; end
out=[]; tOut=[]; sources={};
[v, ok, src] = findSignal(raw, matrixAliases);
if ok
    [v,tOut] = toSignal(v,globalT);
    out = orientFour(v);
    if logicalFlag, out = logical(out); end
    sources = {src}; return;
end
parts = cell(1,4); partT = cell(1,4); got = false(1,4);
for i=1:4
    [v, got(i), src] = findSignal(raw, individualAliases{i});
    if got(i), [parts{i},partT{i}] = toSignal(v,globalT); sources{i}=src; end
end
if any(got)
    n = 0; for i=1:4, if got(i), n=max(n,numel(parts{i})); end, end
    out = nan(n,4); tOut=globalT;
    for i=1:4
        if got(i)
            p=parts{i}; p=p(:); out(1:min(n,numel(p)),i)=p(1:min(n,numel(p)));
            if isempty(tOut) && ~isempty(partT{i}), tOut=partT{i}; end
        end
    end
    if logicalFlag, out = out ~= 0; end
end
end

function out = orientFour(v)
if isempty(v), out=[]; return; end
if isvector(v)
    if numel(v)==4, out=reshape(v,1,4); else, out=v(:); end
elseif size(v,2)==4, out=v;
elseif size(v,1)==4, out=v.';
else, out=v;
end
end

function t = columnTime(t)
if isempty(t), return; end
t=t(:);
end

function n = maxSignalLength(data)
n=0; names=fieldnames(data);
for i=1:numel(names)
    v=data.(names{i});
    if isnumeric(v) || islogical(v), n=max(n,size(v,1)); end
end
end
