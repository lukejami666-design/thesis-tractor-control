function [Tfl,Tfr,Trl,Trr] = fcn(F,derta,dwfl,dwfr,dwrl,dwrr)
% 向左为正
rf = 0.834;
rr = 0.94;
If = 110.64; % kg*m^2
Ir = 356.42;

Ffl = F(1)*cos(derta) + F(2)*sin(derta);
Tfl = Ffl*rf + If*dwfl;
Ffr = F(3)*cos(derta) + F(4)*sin(derta);
Tfr = Ffr*rf + If*dwfr;
Frl = F(5);
Trl = Frl*rr + Ir*dwrl;
Frr = F(7);
Trr = Frr*rr + Ir*dwrr;