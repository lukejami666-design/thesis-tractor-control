function cfg = launch_analysis_config(varargin)
%LAUNCH_ANALYSIS_CONFIG Configuration for launch traction-control analysis.
%   cfg = launch_analysis_config() returns the default configuration.
%   Name/value options are intended for small per-run overrides.

cfg = struct();
cfg.defaultTs = 0.001;
cfg.targetSpeed = 1.5;
cfg.targetDistance = 5.0;
cfg.launchWindow = [0 10];
cfg.maxAllowedSpinTime = 0.5;
cfg.maxAllowedTorqueRate = [];
cfg.successSpeedTolerance = 0.1;
cfg.spinThreshold = 0.8;
cfg.spinClearThreshold = 0.4;
cfg.stateChatterWindow = 0.20;
cfg.slipSpeedFloor = 0.25;
cfg.v_move_on = 0.25;
cfg.wheelSpeedSource = 'linear'; % Set to 'angular' only when mapped signals are rad/s.
cfg.wheelRadius = [0.834; 0.834; 0.940; 0.940];
cfg.parameterFile = fullfile(fileparts(mfilename('fullpath')), '..', 'src', 'launch_tcs_params.m');
cfg.reportsRoot = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'results', 'generated', 'analysis');

% Aliases are checked in this order. The first available signal is used.
cfg.signalMap = struct();
cfg.signalMap.time = {'tout','time','t'};
cfg.signalMap.vx = {'vx','Vx','vehicle_speed','speed'};
cfg.signalMap.vxEst = {'vx_est','Vx_est','vehicle_speed_est','speed_est'};
cfg.signalMap.X = {'X','x_vehicle','vehicle_x'};
cfg.signalMap.Y = {'Y','y_vehicle','vehicle_y'};
cfg.signalMap.beta_e = {'beta_e','beta','sideslip'};
cfg.signalMap.omega_ref = {'omega_ref','yaw_rate_ref','r_ref'};
cfg.signalMap.ax = {'ax','Ax','longitudinal_acceleration','a_x'};
cfg.signalMap.wheelSpeed = {'wheel_speed','sp','wheel_linear_speed'};
cfg.signalMap.wheelSpeedIndividual = {{'sp1','w_fl','wheel_speed_fl'}, ...
    {'sp2','w_fr','wheel_speed_fr'}, {'sp3','w_rl','wheel_speed_rl'}, ...
    {'sp4','w_rr','wheel_speed_rr'}};
cfg.signalMap.wheelTorque = {'Tm4','wheel_torque','torque'};
cfg.signalMap.wheelTorqueIndividual = {{'Tfl','T_FL','torque_fl'}, ...
    {'Tfr','T_FR','torque_fr'}, {'Trl','T_RL','torque_rl'}, ...
    {'Trr','T_RR','torque_rr'}};
cfg.signalMap.slip = {'lambda','lamda','slip','slip_ratio'};
cfg.signalMap.slipIndividual = {{'lamda1','lambda1','slip1','kappa1'}, ...
    {'lamda2','lambda2','slip2','kappa2'}, {'lamda3','lambda3','slip3','kappa3'}, ...
    {'lamda4','lambda4','slip4','kappa4'}};
cfg.signalMap.kappa = {'kappa'};
cfg.signalMap.state = {'launch_state','mode','state','state_machine'};
cfg.signalMap.spinFlag = {'spin_flag','spin','wheel_spin_flag'};
cfg.signalMap.spinIndividual = {{'spin1','spin_fl','spin_flag1'}, ...
    {'spin2','spin_fr','spin_flag2'}, {'spin3','spin_rl','spin_flag3'}, ...
    {'spin4','spin_rr','spin_flag4'}};
cfg.signalMap.torqueLimit = {'torque_limit','TMax','Tcap','T_max'};
cfg.signalMap.torqueLimitIndividual = {{'TMaxFL','Tmax1','Tcap1'}, ...
    {'TMaxFR','Tmax2','Tcap2'}, {'TMaxRL','Tmax3','Tcap3'}, ...
    {'TMaxRR','Tmax4','Tcap4'}};
cfg.signalMap.diagnostics = {'slip_valid','qp_status','R_load','GearD','st','st_L','st_R','Fz1','Fz2','Fz3','Fz4'};

if mod(nargin,2) ~= 0
    error('launch_analysis_config:NameValue', 'Options must be name/value pairs.');
end
for k = 1:2:nargin
    name = varargin{k};
    value = varargin{k+1};
    if ~ischar(name) && ~isstring(name)
        error('launch_analysis_config:NameValue', 'Option names must be text.');
    end
    name = char(name);
    if ~isfield(cfg, name)
        error('launch_analysis_config:UnknownOption', 'Unknown option: %s', name);
    end
    cfg.(name) = value;
end
end
