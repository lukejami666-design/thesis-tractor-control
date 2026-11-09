function [Tfl,Tfr,Trl,Trr] = baseline_torque_distribution(Mz,T0,derta,k,mode)
rf = single(0.834);
rr = single(0.94);
df = single(2.39);
dr = single(2.33);
a = single(2.043);

Trr = single(0);
Trl = single(0);
Tfl = single(0);
Tfr = single(0);


% 强制将输入 Mz 类型设为 single，避免隐式转换
Mz = single(Mz);
T0 = single(T0);
derta = single(derta);
mode = single(mode);

% if mode == 5 || mode == 6
%     k = single(3/7); 
% elseif mode == 1 || mode == 3 
%     k = min(k,1);
%     k = max(k,0.3);
% end

A = T0 / (k + single(1));
B = (Mz - a*sin(derta)*k*A/rf) / (df*cos(derta)*k*rr + dr*rf) * (2*rf*rr);
Trr = (A + B) / single(2);
Trl = (A - B) / single(2);
Tfl = k * Trl;
Tfr = k * Trr;

