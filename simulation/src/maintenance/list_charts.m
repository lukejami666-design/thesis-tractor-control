cfg = maintenance_context();
load_system('tractor_mu'); rt=sfroot; c=rt.find('-isa','Stateflow.Chart');
for i=1:numel(c), try, fprintf('CHART %d name=%s path=%s\n',i,c(i).Name,c(i).Path); catch, end, end
close_system('tractor_mu',0); exit;
