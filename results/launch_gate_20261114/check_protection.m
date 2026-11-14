function check_protection(archiveDir)
% Isolated function replay, not a vehicle test and not candidate performance data.
if nargin<1,archiveDir=fileparts(mfilename('fullpath'));end
s=load(fullfile(archiveDir,'data','candidate_J_full_parameters.mat'));P=s.P;
testdir=fullfile(archiveDir,'protection_harness');if ~isfolder(testdir),mkdir(testdir);end
copyfile(fullfile(archiveDir,'src','LaunchTCS_Torque_gate.m'),fullfile(testdir,'LaunchTCS_Torque.m'),'f');
addpath(testdir,'-begin');cleanup=onCleanup(@()rmpath(testdir));clear LaunchTCS_Torque;
z=zeros(4,1);f=false(4,1);base=60000*ones(4,1);cap=50000*ones(4,1);prev=z;
for k=1:100
 [~,lim,cmd]=LaunchTCS_Torque(uint8(1),f,z,base,cap,0,f,f,z,prev,0,false,P);prev=cmd;
end
[~,lim,cmd,~,~,~,~,~,~,~,~,~,gd]=LaunchTCS_Torque(uint8(6),f,z,base,cap,0,f,f,z,prev,0,false,P);
assert(all(cmd>=0)&all(cmd<=P.q_protect*cap+1e-8)&all(cmd<=lim+1e-8));
result.stage6_cmd=cmd;result.stage6_limit=lim;result.stage6_protect_flags=gd(49:52);result.q_protect=P.q_protect;
[~,lim,cmd]=LaunchTCS_Torque(uint8(1),f,z,base,cap,0,f,f,z,prev,0,true,P);
assert(all(cmd>=0)&all(cmd<=P.q_protect*cap+1e-8));result.source_bad_cmd=cmd;
cap(1)=NaN;[~,lim,cmd]=LaunchTCS_Torque(uint8(1),f,z,base,cap,0,f,f,z,prev,0,false,P);
assert(all(isfinite(cmd))&&cmd(1)==0);result.invalid_cap_cmd=cmd;
save(fullfile(archiveDir,'data','protection_replay.mat'),'result','-v7');
fout=fopen(fullfile(archiveDir,'protection_replay.json'),'w','n','UTF-8');fprintf(fout,'%s',jsonencode(result));fclose(fout);
clear LaunchTCS_Torque;
end
