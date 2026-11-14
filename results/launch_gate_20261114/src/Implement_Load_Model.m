function [D,D_unlimited,u_imp,vg_record] = Load_Model(t,vg,s,D0,B,C,LoadMode,LoadStart,UseDistance,StartDistance,RampTime, DMax)
%#codegen
% Equivalent longitudinal resistance, N; NOT identified ASABE coefficients.
% Mode 0: constant interface diagnostic; mode 1: parametric subsoiler assumption.
vg_record=0;D_unlimited=0;u_imp=0;D=0;
if ~isfinite(t)||~isfinite(vg)||~isfinite(D0)||~isfinite(B)||~isfinite(C)||~isfinite(DMax)||DMax<0
 return;
end
vg_record=vg;v=max(vg,0);
steady=D0;
if LoadMode>0.5,steady=D0+B*v+C*v*v;end
if ~isfinite(steady),return;end
if ~isfinite(LoadStart)||~isfinite(RampTime),return;end
if UseDistance>0.5
 if ~isfinite(s)||~isfinite(StartDistance)||s<StartDistance,return;end
end
u_imp=min(max((t-LoadStart)/max(RampTime,1e-3),0),1);
D_unlimited=u_imp*max(steady,0);
D=min(D_unlimited,DMax);
end
