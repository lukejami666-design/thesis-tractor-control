cfg = maintenance_context();
load_system('tractor_mu.slx');
blks=find_system('tractor_mu','LookUnderMasks','all','FollowLinks','on','Type','Block');
for k=1:numel(blks)
 nm=get_param(blks{k},'Name'); bt=get_param(blks{k},'BlockType'); mt=get_param(blks{k},'MaskType');
 if contains(lower(nm),'launch') || contains(nm,'??') || strcmp(bt,'MATLABSystem') || strcmp(mt,'Stateflow')
  fprintf('%s | Type=%s | Mask=%s | Ports=%s\n',blks{k},bt,mt,mat2str(get_param(blks{k},'Ports')));
 end
end
save_system('tractor_mu'); close_system('tractor_mu',0); exit;
