cfg = maintenance_context();
load_system('tractor_mu'); rt=sfroot; c=rt.find('-isa','Stateflow.Chart','Name','launch_state'); disp(properties(c)); s=Stateflow.State(c); disp(properties(s)); delete(s); close_system('tractor_mu',0); exit;
