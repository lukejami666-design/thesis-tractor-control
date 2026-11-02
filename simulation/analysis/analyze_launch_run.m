function report = analyze_launch_run(matFile, varargin)
%ANALYZE_LAUNCH_RUN Analyze one saved launch simulation MAT file.
%   report = analyze_launch_run('run_001.mat')
%   Name/value options: RunId, OutputDir, MakePlots, SuggestParams, Config.
cfg=launch_analysis_config(); runId=''; makePlots=true; suggest=true; outputDirProvided=false;
for i=1:2:numel(varargin)
    switch lower(varargin{i})
        case 'runid', runId=char(varargin{i+1});
        case 'outputdir', cfg.reportsRoot=char(varargin{i+1}); outputDirProvided=true;
        case 'makeplots', makePlots=logical(varargin{i+1});
        case 'suggestparams', suggest=logical(varargin{i+1});
        case 'config', cfg=varargin{i+1};
        otherwise, error('analyze_launch_run:Option','Unknown option: %s',varargin{i});
    end
end
if isempty(runId), [~,runId]=fileparts(char(matFile)); end
if outputDirProvided, outDir=cfg.reportsRoot; else, outDir=fullfile(cfg.reportsRoot,runId); end
if ~exist(outDir,'dir'), mkdir(outDir); end
[data,info]=load_launch_data(matFile,cfg); metrics=compute_launch_metrics(data,cfg);
if suggest, suggestions=suggest_launch_params(metrics,cfg,cfg.parameterFile); else, suggestions=struct([]); end
files=struct(); if makePlots, files=plot_launch_signals(data,metrics,cfg,outDir); end
report=struct('runId',runId,'data',data,'metrics',metrics,'suggestions',suggestions,'files',files,'status',metrics.status,'missingSignals',{info.missingSignals},'loadInfo',info);
save(fullfile(outDir,'metrics.mat'),'metrics','suggestions','info','-mat'); writeMetricsCsv(metrics,fullfile(outDir,'metrics.csv')); writeMetricsMd(report,fullfile(outDir,'metrics.md'));
end
function writeMetricsCsv(m,file)
names=fieldnames(m); fid=fopen(file,'w'); fprintf(fid,'metric,value\n');
for i=1:numel(names), v=m.(names{i}); if isnumeric(v)&&isscalar(v), fprintf(fid,'%s,%.17g\n',names{i},v); elseif islogical(v)&&isscalar(v), fprintf(fid,'%s,%d\n',names{i},v); end, end
fclose(fid);
end
function writeMetricsMd(r,file)
fid=fopen(file,'w'); fprintf(fid,'# Launch analysis: %s\n\nStatus: `%s`\n\n| Metric | Value |\n|---|---:|\n',r.runId,r.status);
names=fieldnames(r.metrics);
for i=1:numel(names)
    v=r.metrics.(names{i});
    if isnumeric(v)&&isscalar(v), fprintf(fid,'| `%s` | %.6g |\n',names{i},v); elseif islogical(v)&&isscalar(v), fprintf(fid,'| `%s` | %s |\n',names{i},mat2str(v)); end
end
if ~isempty(r.missingSignals), fprintf(fid,'\nMissing signals: `%s`\n',strjoin(r.missingSignals,'`, `')); end
if ~isempty(r.suggestions), fprintf(fid,'\n## Parameter suggestions\n\n'); for i=1:numel(r.suggestions), fprintf(fid,'- `%s`: %.6g -> %.6g (%s). %s\n',r.suggestions(i).parameter,r.suggestions(i).currentValue,r.suggestions(i).proposedValue,r.suggestions(i).direction,r.suggestions(i).reason); end, end
fclose(fid);
end
