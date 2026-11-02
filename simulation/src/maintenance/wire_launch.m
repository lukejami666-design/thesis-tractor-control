function wire_launch
cfg = maintenance_context();
try
load_system('tractor_mu'); top='tractor_mu'; root=get_param(top,'Handle'); anti=Simulink.ID.getHandle('tractor_mu:1787'); sub=getfullname(anti); fprintf('sub %s\n',sub);
% Add wrapper input T_base and output T_cmd
blk=add_block('simulink/Ports & Subsystems/In1',[sub,'/T_base'],'Position',[ -2015 1400 -1985 1414]); set_param(blk,'Port','11');
blk=add_block('simulink/Ports & Subsystems/Out1',[sub,'/T_cmd'],'Position',[-1865 1420 -1835 1434]); set_param(blk,'Port','7');
% Internal helper blocks
pos=[50 50]; 
% Wheel speed vector, already converted to rad/s in model (pi/30 gains)
wheelTags={'fl','fr','rl','rr'}; steerTags={'L','R'}; capTags={'FL','FR','RL','RR'};
ww=add_block('simulink/Signal Routing/Mux',[sub,'/Launch_w_mux'],'Inputs','4','Position',[650 1430 655 1500]);
for k=1:4, f=addFrom(sub,['Launch_w',num2str(k)],['w_',wheelTags{k}],550,1400+35*k); add_line(sub,get_param(f,'PortHandles').Outport(1),get_param(ww,'PortHandles').Inport(k),'autorouting','on'); end
% front steering angles in degrees converted to radians; rear wheel angles zero
muxd=add_block('simulink/Signal Routing/Mux',[sub,'/Launch_delta_mux'],'Inputs','4','Position',[650 1540 655 1610]);
for k=1:2, f=addFrom(sub,['Launch_steer',num2str(k)],['st_',steerTags{k}],550,1530+35*k); g=add_block('simulink/Math Operations/Gain',[sub,'/Launch_delta_gain',num2str(k)],'Gain','pi/180','Position',[610 1530+35*k 640 1550+35*k]); add_line(sub,get_param(f,'PortHandles').Outport(1),get_param(g,'PortHandles').Inport(1),'autorouting','on'); add_line(sub,get_param(g,'PortHandles').Outport(1),get_param(muxd,'PortHandles').Inport(k),'autorouting','on'); end
for k=3:4, c=add_block('simulink/Sources/Constant',[sub,'/Launch_delta_zero',num2str(k)],'Value','0','Position',[600 1530+35*k 630 1550+35*k]); add_line(sub,get_param(c,'PortHandles').Outport(1),get_param(muxd,'PortHandles').Inport(k),'autorouting','on'); end
% yaw, acceleration, T_max vector
f=addFrom(sub,'Launch_yaw','omega',550,1670); gy=add_block('simulink/Math Operations/Gain',[sub,'/Launch_yaw_rad'],'Gain','pi/180','Position',[610 1670 640 1690]); add_line(sub,get_param(f,'PortHandles').Outport(1),get_param(gy,'PortHandles').Inport(1),'autorouting','on');
fax=addFrom(sub,'Launch_ax','ax',550,1710);
maxt=add_block('simulink/Signal Routing/Mux',[sub,'/Launch_Tmax_mux'],'Inputs','4','Position',[650 1760 655 1830]);
for k=1:4, f=addFrom(sub,['Launch_Tmax',num2str(k)],['TMax',capTags{k}],550,1740+35*k); add_line(sub,get_param(f,'PortHandles').Outport(1),get_param(maxt,'PortHandles').Inport(k),'autorouting','on'); end
% Fixed first-version enable/reset/source validity
cvalid=add_block('simulink/Sources/Constant',[sub,'/Launch_speed_src_valid'],'Value','1','Position',[550 1890 580 1910]); cen=add_block('simulink/Sources/Constant',[sub,'/Launch_enable'],'Value','1','Position',[550 1920 580 1940]); crst=add_block('simulink/Sources/Constant',[sub,'/Launch_reset'],'Value','0','Position',[550 1950 580 1970]);
% find target blocks by their stable SIDs
motion=Simulink.ID.getHandle('tractor_mu:5662'); torque=Simulink.ID.getHandle('tractor_mu:5663'); chart=Simulink.ID.getHandle('tractor_mu:5664');
pm=get_param(motion,'PortHandles'); pt=get_param(torque,'PortHandles'); pc=get_param(chart,'PortHandles');
% Motion input mapping: w, vx, vy, ax, r, delta, speed-valid, delayed Tcmd, Tmax, reset
% existing subsystem inputs are ports 5=vx,6=vy
add_line(sub,get_param(ww,'PortHandles').Outport(1),pm.Inport(1),'autorouting','on');
add_line(sub,get_param([sub,'/vx'],'PortHandles').Outport(1),pm.Inport(2),'autorouting','on');
add_line(sub,get_param([sub,'/vy'],'PortHandles').Outport(1),pm.Inport(3),'autorouting','on');
add_line(sub,get_param(fax,'PortHandles').Outport(1),pm.Inport(4),'autorouting','on');
add_line(sub,get_param(gy,'PortHandles').Outport(1),pm.Inport(5),'autorouting','on');
add_line(sub,get_param(muxd,'PortHandles').Outport(1),pm.Inport(6),'autorouting','on');
add_line(sub,get_param(cvalid,'PortHandles').Outport(1),pm.Inport(7),'autorouting','on');
% rear input mapping uses delay output to motion; create feedback delay from T_cmd
ud=add_block('simulink/Discrete/Unit Delay',[sub,'/Launch_Tcmd_delay'],'SampleTime','0.001','InitialCondition','zeros(4,1)','Position',[1660 1630 1700 1660]);
add_line(sub,pt.Outport(3),get_param(ud,'PortHandles').Inport(1),'autorouting','on');
add_line(sub,get_param(ud,'PortHandles').Outport(1),pm.Inport(8),'autorouting','on');
add_line(sub,get_param(maxt,'PortHandles').Outport(1),pm.Inport(9),'autorouting','on');
add_line(sub,get_param(crst,'PortHandles').Outport(1),pm.Inport(10),'autorouting','on');
% chart inputs from motion outputs 3..10 and constants
for k=1:8, add_line(sub,pm.Outport(k+2),pc.Inport(k),'autorouting','on'); end
add_line(sub,get_param(cen,'PortHandles').Outport(1),pc.Inport(9),'autorouting','on'); add_line(sub,get_param(crst,'PortHandles').Outport(1),pc.Inport(10),'autorouting','on');
% torque input mapping
add_line(sub,pc.Outport(1),pt.Inport(1),'autorouting','on'); add_line(sub,pc.Outport(2),pt.Inport(2),'autorouting','on');
add_line(sub,get_param([sub,'/T_base'],'PortHandles').Outport(1),pt.Inport(3),'autorouting','on'); add_line(sub,get_param(maxt,'PortHandles').Outport(1),pt.Inport(4),'autorouting','on'); add_line(sub,get_param(crst,'PortHandles').Outport(1),pt.Inport(5),'autorouting','on');
% connect required observation outputs to terminators
for k=[1 2 12], t=addTerm(sub,['Launch_motion_obs',num2str(k)],1740,1400+35*k); add_line(sub,pm.Outport(k),get_param(t,'PortHandles').Inport(1),'autorouting','on'); end
for k=3:6, t=addTerm(sub,['Launch_state_obs',num2str(k)],1740,1600+30*k); add_line(sub,pc.Outport(k),get_param(t,'PortHandles').Inport(1),'autorouting','on'); end
t=addTerm(sub,'Launch_torque_diag_term',1740,1810); add_line(sub,pt.Outport(4),get_param(t,'PortHandles').Inport(1),'autorouting','on');
% connect Tcmd output port to wrapper Outport
outblock=get_param([sub,'/T_cmd'],'Handle'); add_line(sub,pt.Outport(3),get_param(outblock,'PortHandles').Inport(1),'autorouting','on');
% Parent level duplicate Manual Switch selects same pre-TCS torque vector as actual import switch
ms=add_block('simulink/Signal Routing/Manual Switch',[top,'/TCS base selector'],'Position',[-280 720 -250 756]); set_param(ms,'CurrentSetting',get_param(Simulink.ID.getHandle('tractor_mu:4648'),'CurrentSetting'));
add_line(top,get_param(Simulink.ID.getHandle('tractor_mu:1410'),'PortHandles').Outport(1),get_param(ms,'PortHandles').Inport(1),'autorouting','on');
add_line(top,get_param(Simulink.ID.getHandle('tractor_mu:5082'),'PortHandles').Outport(1),get_param(ms,'PortHandles').Inport(2),'autorouting','on');
add_line(top,get_param(ms,'PortHandles').Outport(1),get_param(anti,'PortHandles').Inport(11),'autorouting','on');
% Replace only the TruckSim torque import branch with the TCS absolute command
truck=Simulink.ID.getHandle('tractor_mu:1625'); delete_line(top,get_param(Simulink.ID.getHandle('tractor_mu:4648'),'PortHandles').Outport(1),get_param(truck,'PortHandles').Inport(1));
add_line(top,get_param(anti,'PortHandles').Outport(7),get_param(truck,'PortHandles').Inport(1),'autorouting','on');
save_system('tractor_mu'); close_system('tractor_mu',0); exit;
catch ME
fid=fopen(fullfile(cfg.inspectDir, 'wire_err4.txt'),'w'); fprintf(fid,'%s',getReport(ME,'extended','hyperlinks','off')); fclose(fid); exit(1);
end
end
function h=addFrom(sys,name,tag,x,y)
h=add_block('simulink/Signal Routing/From',[sys,'/',name],'Position',[x y x+45 y+20]); set_param(h,'GotoTag',tag);
end
function h=addTerm(sys,name,x,y)
h=add_block('simulink/Sinks/Terminator',[sys,'/',name],'Position',[x y x+20 y+18]);
end





