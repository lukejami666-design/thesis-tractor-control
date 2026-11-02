cfg = maintenance_context();
load_system('tractor_mu'); rt=sfroot; em=rt.find('-isa','Stateflow.EMChart'); for k=1:numel(em), if contains(em(k).Path,'MATLAB Function4'), em(k).Script=fileread(fullfile(cfg.sourceRoot,'LaunchTCS_Motion_code.m')); end, end; save_system('tractor_mu'); close_system('tractor_mu',0); exit;
