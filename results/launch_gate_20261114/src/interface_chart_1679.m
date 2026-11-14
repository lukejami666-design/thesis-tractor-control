function T = common_cap(raw,cap)
%#codegen
T=zeros(4,1);
for i=1:4
 if isfinite(raw(i)) && isfinite(cap(i)) && cap(i)>=0
 T(i)=min(max(raw(i),0),cap(i));
 end
end
end
