function logEntry = apply_launch_params(suggestions, parameterFile, confirmed, varargin)
%APPLY_LAUNCH_PARAMS Apply confirmed suggestions to launch_tcs_params.m.
if nargin < 3 || ~isequal(confirmed,true), error('apply_launch_params:ConfirmationRequired','Pass confirmed=true after manual review.'); end
if nargin < 2 || isempty(parameterFile), parameterFile=fullfile(fileparts(mfilename('fullpath')),'..','launch_tcs_params.m'); end
if ~isfile(parameterFile), error('apply_launch_params:MissingFile','Parameter file not found.'); end
if isempty(suggestions), logEntry=struct([]); return; end
if istable(suggestions), suggestions=table2struct(suggestions); end
text=fileread(parameterFile); [folder,base,ext]=fileparts(parameterFile); stamp=datestr(now,'yyyymmdd_HHMMSS'); backup=fullfile(folder,[base '.bak_' stamp ext]); copyfile(parameterFile,backup);
logPath=fullfile(folder,[base '_changes.log']);
logEntry=struct('run_id','','parameter','','old_value',NaN,'new_value',NaN,'reason','','source_metrics',{{}},'user_confirmed',true);
for i=1:numel(suggestions)
    s=suggestions(i); name=s.parameter; new=s.proposedValue;
    if ~isvarname(name) || ~isnumeric(new) || ~isscalar(new) || ~isfinite(new), error('apply_launch_params:InvalidSuggestion','Invalid parameter or value.'); end
    tok=regexp(text,['(?m)^\s*P\.' regexpescape(name) '\s*=\s*([^;]+);'],'tokens','once');
    if isempty(tok), error('apply_launch_params:UnknownParameter','Parameter not found: %s',name); end
    old=str2double(strtrim(tok{1})); if ~isfinite(old), old=NaN; end
    if ~isfinite(new) || ~parameterValueInRange(name,new)
        error('apply_launch_params:OutOfRange','Proposed value is outside the safe range for %s.',name);
    end
    text=regexprep(text,['(?m)(^\s*P\.' regexpescape(name) '\s*=\s*)[^;]+(;)' ],['$1' num2str(new,17) '$2'],'once');
    logEntry(i).run_id=getOption(varargin,'RunId',''); logEntry(i).parameter=name; logEntry(i).old_value=old; logEntry(i).new_value=new;
    if isfield(s,'reason'), logEntry(i).reason=s.reason; end; if isfield(s,'sourceMetrics'), logEntry(i).source_metrics=s.sourceMetrics; end
    fid=fopen(logPath,'a'); fprintf(fid,'run_id: %s\nparameter: %s\nold_value: %.17g\nnew_value: %.17g\nreason: %s\nsource_metrics: %s\nuser_confirmed: true\n\n',logEntry(i).run_id,name,old,new,logEntry(i).reason,strjoin(logEntry(i).source_metrics,', ')); fclose(fid);
end
fid=fopen(parameterFile,'w'); fwrite(fid,text); fclose(fid);
end
function s=regexpescape(x), s=regexprep(x,'([\\.^$|()\[\]{}*+?])','\\$1'); end
function v=getOption(args,name,default)
v=default; for i=1:2:numel(args), if strcmpi(args{i},name), v=args{i+1}; end, end
end
function ok=parameterValueInRange(name,value)
ok=isfinite(value);
if any(strcmp(name,{'alpha_w','alpha_v','alpha_vy','alpha_a','alpha_r','q_start','q_no_move_max','q_multi_min','q_limit_floor','q_protect','applied_active_frac'})), ok=ok && value>=0 && value<=1; end
if any(strcmp(name,{'Ts','t_speed_on','t_speed_off','t_cons_bad','t_no_move','t_spin_on','t_spin_clear'})), ok=ok && value>0; end
if any(strcmp(name,{'q_probe_rate','q_no_move_rate','q_spin_down','q_multi_cut_rate','q_multi_rec_rate','q_limit_cut_rate','q_limit_rec_rate','q_protect_down','cmd_rise_rate','cmd_fall_rate'})), ok=ok && value>=0; end
if any(strcmp(name,{'dv_spin_on','dv_spin_off','dv_growth_on','v_move_on','v_wheel_min','a_response','a_spin_max','q_multi_min','q_limit_floor'})), ok=ok && value>=0; end
end
