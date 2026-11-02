cfg = maintenance_context();
try
load_system('tractor_mu'); rt=sfroot; e=rt.find('-isa','Stateflow.EMChart'); fprintf('n %d\n',numel(e)); for k=1:numel(e), fprintf('%d %s\n',k,e(k).Path); end; close_system('tractor_mu',0); exit;
catch ME, fid=fopen(fullfile(cfg.inspectDir, 'err2.txt'),'w'); fprintf(fid,'%s',getReport(ME,'extended','hyperlinks','off')); fclose(fid); exit(1); end
