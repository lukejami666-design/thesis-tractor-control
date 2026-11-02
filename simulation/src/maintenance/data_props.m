cfg = maintenance_context();
load_system('tractor_mu'); rt=sfroot; c=rt.find('-isa','Stateflow.Chart','Name','launch_state'); d=Stateflow.Data(c); disp(properties(d)); delete(d); close_system('tractor_mu',0); exit;
