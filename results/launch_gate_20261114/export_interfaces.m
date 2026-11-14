function export_interfaces(dst)
m='launch_gate_exp';sf=sfroot;ch=sf.find('-isa','Stateflow.EMChart');index=struct('path',{},'file',{});
for j=1:numel(ch)
 if startsWith(ch(j).Path,[m '/']) && (contains(ch(j).Path,'四轮转矩分配')||contains(ch(j).Path,'总驱动力矩制定')||contains(ch(j).Path,'Common motor capability')||contains(ch(j).Path,'滑转率计算'))
  name=['interface_chart_' num2str(ch(j).Id) '.m'];f=fopen(fullfile(dst,'src',name),'w','n','UTF-8');fprintf(f,'%s',ch(j).Script);fclose(f);index(end+1)=struct('path',ch(j).Path,'file',name);
 end
end
f=fopen(fullfile(dst,'interface_source_map.json'),'w','n','UTF-8');fprintf(f,'%s',jsonencode(index));fclose(f);
end
