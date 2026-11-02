function check_parent_dims
cfg = maintenance_context();
model = 'tractor_mu_parent_dims_fixed';
load_system(fullfile(cfg.archiveDir, [model '.slx']));
cleanup = onCleanup(@() close_system(model, 0));

sel = [model '/TCS base selector'];
sw = [model '/1'];
reshapeBlock = [model '/TCS_base_row_to_col'];

fprintf('selector input 1 line = %g\n', get_param(get_param(sel, 'PortHandles').Inport(1), 'Line'));
fprintf('selector input 2 line = %g\n', get_param(get_param(sel, 'PortHandles').Inport(2), 'Line'));
fprintf('reshape output dimensions = %s\n', get_param(reshapeBlock, 'OutputDimensions'));

try
    set_param(model, 'SimulationCommand', 'update');
    fprintf('MODEL_UPDATE_OK\n');
catch err
    fprintf('MODEL_UPDATE_ERROR: %s\n', err.message);
end

for block = {sw, reshapeBlock, sel}
    try
        dims = get_param(block{1}, 'CompiledPortDimensions');
        fprintf('%s compiled dims: %s\n', block{1}, mat2str(dims));
    catch err
        fprintf('%s compiled dims unavailable: %s\n', block{1}, err.message);
    end
end
end
