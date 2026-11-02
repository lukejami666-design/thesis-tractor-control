cfg = maintenance_context();
load_system('tractor_mu');
rt=sfroot;
charts=rt.find('-isa','Stateflow.EMChart');
for k=1:numel(charts), fprintf('%s\n',charts(k).Path); end
close_system('tractor_mu',0);
