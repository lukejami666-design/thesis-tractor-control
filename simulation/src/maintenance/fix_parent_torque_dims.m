function fix_parent_torque_dims
cfg = maintenance_context();
% Repair the two torque-vector branches at the top level of tractor_mu.
% The manual-switch output is a 1x4 row vector; downstream blocks need 4x1.

simDir = cfg.modelRoot;
source = fullfile(simDir, 'tractor_mu.slx');
candidate = fullfile(cfg.archiveDir, 'tractor_mu_parent_dims_fixed.slx');

if bdIsLoaded('tractor_mu_parent_dims_fixed')
    close_system('tractor_mu_parent_dims_fixed', 0);
end
copyfile(source, candidate, 'f');
load_system(candidate);
top = 'tractor_mu_parent_dims_fixed';

% Resolve blocks by SID so this is independent of display names.
mem = Simulink.ID.getHandle([top ':1410']);
selector = Simulink.ID.getHandle([top ':5699']);
manualSwitch = Simulink.ID.getHandle([top ':5082']);
baseSwitch = Simulink.ID.getHandle([top ':4648']);

memPorts = get_param(mem, 'PortHandles');
selectorPorts = get_param(selector, 'PortHandles');
manualPorts = get_param(manualSwitch, 'PortHandles');
baseSwitchPorts = get_param(baseSwitch, 'PortHandles');

% Restore the missing Memory -> TCS base selector input-1 connection.
if get_param(selectorPorts.Inport(1), 'Line') == -1
    add_line(top, memPorts.Outport(1), selectorPorts.Inport(1), 'autorouting', 'on');
end

% Create one explicit conversion block for the 1x4 manual-switch output.
reshapeName = 'TCS_base_row_to_col';
reshapePath = [top '/' reshapeName];
existing = find_system(top, 'SearchDepth', 1, 'Name', reshapeName);
if isempty(existing)
    add_block('simulink/Math Operations/Reshape', reshapePath, ...
        'OutputDimensions', '[4 1]', ...
        'Position', [-390 1670 -300 1710]);
else
    set_param(reshapePath, 'OutputDimensions', '[4 1]');
end
reshapePorts = get_param(reshapePath, 'PortHandles');

% Remove old direct row-vector lines, if present.
oldLine = get_param(baseSwitchPorts.Inport(2), 'Line');
if oldLine ~= -1
    delete_line(top, oldLine);
end
oldLine = get_param(selectorPorts.Inport(2), 'Line');
if oldLine ~= -1
    delete_line(top, oldLine);
end
oldLine = get_param(manualPorts.Outport(1), 'Line');
if oldLine ~= -1
    delete_line(top, oldLine);
end

% Reconnect through the 4x1 conversion block.
add_line(top, manualPorts.Outport(1), reshapePorts.Inport(1), 'autorouting', 'on');
add_line(top, reshapePorts.Outport(1), baseSwitchPorts.Inport(2), 'autorouting', 'on');
add_line(top, reshapePorts.Outport(1), selectorPorts.Inport(2), 'autorouting', 'on');

save_system(top);
close_system(top, 0);
fprintf('PARENT_TORQUE_DIM_REPAIR_SAVED\n');
end
