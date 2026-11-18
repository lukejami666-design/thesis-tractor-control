# 起步Stateflow原始标签

从1118保存副本chart_905.xml提取。状态、转移标签完整保留；层级、源/目标关系与执行顺序需要结合旁边XML和control-framework.md。它不是可直接运行的MATLAB脚本。

## state 88

```matlab
MONITOR
entry:
spin_on_t=zeros(4,1); spin_clear_t=zeros(4,1); spin_mask=false(4,1); nspin=0; no_move_t=0;
no_move_confirmed=false; speed_on_t=0; speed_off_t=0; speed_valid=false; cons_bad_t=0;
source_bad=false; desired_stage=uint8(255);
prewarn=false(4,1);warn_armed=true(4,1);warn_age=zeros(4,1);warn_on_t=zeros(4,1);warn_clear_t=zeros(4,1);warn_early_t=zeros(4,1);

control_phase=uint8(3); handover_t=0; handover_alpha=0;
during:
if enable<=0.5 || reset>0.5
    spin_on_t=zeros(4,1); spin_clear_t=zeros(4,1); spin_mask=false(4,1); nspin=0; no_move_t=0;
    no_move_confirmed=false; speed_on_t=0; speed_off_t=0; speed_valid=false; cons_bad_t=0;
    prewarn=false(4,1);warn_armed=true(4,1);warn_age=zeros(4,1);warn_on_t=zeros(4,1);warn_clear_t=zeros(4,1);warn_early_t=zeros(4,1);

    control_phase=uint8(0); handover_t=0; handover_alpha=0;
    source_bad=false; if enable<=0.5, desired_stage=uint8(255); else, desired_stage=uint8(0);
    end
else
    % Establish current-sample validity before warning supervision. A bad
    % source cancels warning immediately; the stage logic below still takes
    % source_bad to PROTECT without waiting for warning timers.
    if source_immediate_bad || ~consistency_ok
        cons_bad_t=min(P.t_cons_bad,cons_bad_t+P.Ts);
    else
        cons_bad_t=max(0,cons_bad_t-P.Ts);
    end
    source_bad=source_immediate_bad || cons_bad_t>=P.t_cons_bad;
    if source_bad
        prewarn=false(4,1); warn_armed=false(4,1); warn_age=zeros(4,1);
        warn_on_t=zeros(4,1); warn_clear_t=zeros(4,1); warn_early_t=zeros(4,1);
    else
        for i=1:4
            if ~prewarn(i) && ~spin_mask(i) && dv_warning(i)<P.gate_warn_off
                warn_armed(i)=true;
            end
        end
    end
    for i=1:4
        if spin_on_raw(i), spin_on_t(i)=min(P.t_spin_on,spin_on_t(i)+P.Ts); spin_clear_t(i)=0;
        else, spin_on_t(i)=max(0,spin_on_t(i)-P.Ts); if spin_clear_raw(i), spin_clear_t(i)=min(P.t_spin_clear,spin_clear_t(i)+P.Ts);
            else, spin_clear_t(i)=0;
            end, end
        if spin_on_t(i)>=P.t_spin_on, spin_mask(i)=true; end
        if spin_clear_t(i)>=P.t_spin_clear, spin_mask(i)=false; end
    end
    % Event supervision only: warning does not mask sustained spin evidence.
    for i=1:4
        if dv_warning(i)>=P.gate_warn_on
            warn_on_t(i)=min(P.gate_warn_delay,warn_on_t(i)+P.Ts);
        else
            warn_on_t(i)=0;
        end
        if dv_warning(i)>=P.gate_early_on && fast_warning(i)
            warn_early_t(i)=min(P.gate_early_delay,warn_early_t(i)+P.Ts);
        else
            warn_early_t(i)=0;
        end
        if spin_mask(i) || source_bad
            prewarn(i)=false; warn_armed(i)=false; warn_age(i)=0;
            warn_on_t(i)=0; warn_clear_t(i)=0; warn_early_t(i)=0;
        elseif ~prewarn(i)
            if warn_armed(i) && (warn_on_t(i)>=P.gate_warn_delay || warn_early_t(i)>=P.gate_early_delay)
                prewarn(i)=true;warn_age(i)=0;warn_clear_t(i)=0;
                warn_armed(i)=false;
            end
        else
            warn_age(i)=warn_age(i)+P.Ts;
            % Once confirmed-spin latching takes over, leave the warning
            % lane immediately; the confirmed-spin limiter owns the event.
            if dv_warning(i)<P.gate_warn_off
                warn_clear_t(i)=min(P.gate_warn_clear,warn_clear_t(i)+P.Ts);
            else
                warn_clear_t(i)=0;
            end
            if prewarn(i) && warn_age(i)>=P.gate_warn_hold && warn_clear_t(i)>=P.gate_warn_clear
                prewarn(i)=false;warn_armed(i)=true;warn_age(i)=0;warn_on_t(i)=0;warn_early_t(i)=0;
            end
        end
    end
    nspin=sum(double(spin_mask));
    if no_move_raw, no_move_t=min(P.t_no_move,no_move_t+P.Ts); elseif move_ok, no_move_t=0; else, no_move_t=max(0,no_move_t-P.Ts); end
    no_move_confirmed=no_move_t>=P.t_no_move;
    if ~speed_valid
        if speed_on_raw && nspin<=1 && ~source_bad, speed_on_t=min(P.t_speed_on,speed_on_t+P.Ts); else, speed_on_t=0; end
        if speed_on_t>=P.t_speed_on, speed_valid=true; speed_off_t=0; end
    else
        if speed_off_raw || nspin>=2 || source_bad, speed_off_t=min(P.t_speed_off,speed_off_t+P.Ts); else, speed_off_t=0; end
        if speed_off_t>=P.t_speed_off, speed_valid=false; speed_on_t=0; end
    end
    if source_bad, desired_stage=uint8(6); elseif nspin>=2, desired_stage=uint8(4);
    elseif nspin==1, desired_stage=uint8(3); elseif speed_valid, desired_stage=uint8(5);
    elseif no_move_confirmed, desired_stage=uint8(2); elseif move_ok, desired_stage=uint8(1);
    else, desired_stage=uint8(0); end
    % 起步 Chart 只保留内部事件阶段；全阶段控制权由独立 TCS_ModeSupervisor 唯一决定。
    % 旧输出端口仅为兼容保留，不接入最终 control_phase / blend_alpha。
    control_phase=uint8(0); handover_t=0; handover_alpha=0;
end

```

## state 89

```matlab
MODE
```

## state 90

```matlab
DISABLED
entry: stage = uint8(255);
```

## state 91

```matlab
START_PROBE
entry: stage = uint8(0);
```

## state 92

```matlab
NORMAL_LAUNCH
entry: stage = uint8(1);
```

## state 93

```matlab
HEAVY_NO_MOVE
entry: stage = uint8(2);
```

## state 94

```matlab
SINGLE_SPIN
entry: stage = uint8(3);
```

## state 95

```matlab
MULTI_SPIN
entry: stage = uint8(4);
```

## state 96

```matlab
WORK_PASS
entry: stage = uint8(5);
```

## state 97

```matlab
PROTECT
entry: stage = uint8(6);
```

## transition 103

```matlab
[desired_stage == uint8(0)]
```

## transition 101

```matlab
[desired_stage == uint8(255)]
```

## transition 100

```matlab
[desired_stage ~= uint8(255)]
```

## transition 102

```matlab
[desired_stage ~= uint8(0)]
```

## transition 107

```matlab
[desired_stage == uint8(2)]
```

## transition 105

```matlab
[desired_stage == uint8(1)]
```

## transition 106

```matlab
[desired_stage ~= uint8(2)]
```

## transition 104

```matlab
[desired_stage ~= uint8(1)]
```

## transition 111

```matlab
[desired_stage == uint8(4)]
```

## transition 109

```matlab
[desired_stage == uint8(3)]
```

## transition 110

```matlab
[desired_stage == uint8(6) || desired_stage == uint8(255) || (desired_stage ~= uint8(4) && after(0.2,sec))]
```

## transition 108

```matlab
[desired_stage == uint8(6) || desired_stage == uint8(255) || (desired_stage ~= uint8(3) && after(0.2,sec))]
```

## transition 115

```matlab
[desired_stage == uint8(6)]
```

## transition 114

```matlab
[desired_stage ~= uint8(6)]
```

## transition 113

```matlab
[desired_stage == uint8(5)]
```

## transition 112

```matlab
[desired_stage ~= uint8(5)]
```
