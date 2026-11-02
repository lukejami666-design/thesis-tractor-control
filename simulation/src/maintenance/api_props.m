cfg = maintenance_context();
load_system('tractor_mu'); rt=sfroot;
paths={'tractor_mu/驱动防滑模块/MATLAB Function4','tractor_mu/驱动防滑模块/MATLAB Function5','tractor_mu/驱动防滑模块/launch_state'};
for k=1:3
 x=rt.find('-isa','Stateflow.EMChart','Path',paths{k}); fprintf('path %s count %d\n',paths{k},numel(x));
 if ~isempty(x), fprintf('class %s\n',class(x)); end
end
x=rt.find('-isa','Stateflow.EMChart','Path',paths{1}); disp(properties(x));
close_system('tractor_mu',0); exit;
