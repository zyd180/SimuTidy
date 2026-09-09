%% benchmark.m — SimuTidy 批量操作性能基准
%   用途：3.1.0 性能优化（目标 ≥3×，高亮豁免）的前后对比测量。
%   方法：自动生成 N 块串联模型（unsaved，用完即弃），各功能计时取 3 次最优。
%   运行：cd 到本目录后执行 benchmark；或 benchmark(N) 指定规模。
%   注意：基线代码在每个几何操作后触发 update（整模型编译），
%         这正是 3.1.0 要移除的主要开销——对比时勿改动计时口径。

function benchmark(N)
if nargin < 1, N = 500; end
root = fileparts(mfilename('fullpath'));
addpath(fullfile(root, '..'), fullfile(root, '..', 'gui'), ...
        fullfile(root, '..', 'core'), fullfile(root, '..', 'utils'));

mdl = 'BENCH_MODEL';
if bdIsLoaded(mdl), bdclose(mdl); end
new_system(mdl); open_system(mdl);
fprintf('生成 %d 块串联模型...\n', N);

% 串联链：Gain x N，两两连线（autorouting off 加速建模本身）
tic;
for k = 1:N
    add_block('built-in/Gain', [mdl '/G' num2str(k)], ...
        'Position', [40*k 100 40*k+30 130]);
end
for k = 1:N-1
    add_line(mdl, ['G' num2str(k) '/1'], ['G' num2str(k+1) '/1'], ...
        'autorouting', 'off');
end
buildT = toc;
fprintf('建模完成（%.1fs，不计入测量）\n', buildT);

handles = find_system(mdl, 'FindAll', 'on', 'Type', 'block');
lineHs  = find_system(mdl, 'FindAll', 'on', 'Type', 'line');

ops = {
    @() opLinePorts(mdl, handles),    'slAlignLinePorts(单块)';
    @() opNames(mdl),                 'slUpdateBlockNames(全模型)';
    @() opName(mdl, lineHs),          'slAutoNameSignals(source, 全线)';
    @() opAlign(mdl, handles),        'slAlignBlocks(left, 全选)';
    @() opUniform(mdl, handles),      'slUniformSize(base, 全选)';
    @() opHighlight(mdl),             'slHighlightUnconnected(全模型, 豁免)';
};
% 顺序刻意安排：linePorts 依赖链状网格几何，必须在对齐类操作（会把整链
% 压到同一列、破坏碰撞前提）之前跑；对齐/大小统一放最后，互不影响。

results = cell(1, size(ops, 1));
for o = 1:size(ops, 1)
    best = Inf;
    for r = 1:3
        t = tocSafe(ops{o, 1});
        best = min(best, t);
    end
    results{o} = best;
end

fprintf('\n===== 基准结果（N=%d，3 次取最优，单位秒）=====\n', N);
for o = 1:size(ops, 1)
    fprintf('  %-38s %8.3f s\n', ops{o, 2}, results{o});
end

% 结果落盘（tests/output/），供 Phase 1 前后对比；output/ 已在 .gitignore
outDir = fullfile(root, 'output');
if ~isfolder(outDir), mkdir(outDir); end
fid = fopen(fullfile(outDir, 'benchmark_log.txt'), 'a');
parts = cellfun(@(o) sprintf('%s=%.3f', ops{o, 2}, results{o}), ...
    num2cell(1:size(ops, 1)), 'UniformOutput', false);
fprintf(fid, '[%s] N=%d  %s\n', datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'), ...
    N, strjoin(parts, '  '));
fclose(fid);
fprintf('结果已追加至 tests/output/benchmark_log.txt\n');
bdclose(mdl);
end

%% ---------------------------------------------------------------- 操作封装
function t = tocSafe(f)
t0 = tic; f(); t = toc(t0);
end

function opAlign(mdl, handles)
for h = handles(:)'
    set_param(h, 'Selected', 'on');
end
slAlignBlocks(mdl, 'left');
end

function opUniform(mdl, handles)
for h = handles(:)'
    set_param(h, 'Selected', 'on');
end
slUniformSize(mdl, 'base');
end

function opName(mdl, lineHs)
for h = lineHs(:)'
    set_param(h, 'Name', '');
end
slAutoNameSignals(mdl, 'source');
end

function opLinePorts(mdl, handles)
% 先清空历史选择（前面用例可能留下全选状态），再只选目标块——
% 否则 500 块全部进入 makePlan，测的是"全选跳过"路径而非真实用例
for h = handles(:)'
    set_param(h, 'Selected', 'off');
end
% 下移 40：目标高度无占用（链块均在 y=100~130），不触发碰撞跳过，
% 得到一次真实的"移动+拉直"路径
set_param(handles(2), 'Position', get_param(handles(2), 'Position') + [0 40 0 40]);
set_param(handles(2), 'Selected', 'on');
slAlignLinePorts(mdl);
end

function opNames(mdl)
slUpdateBlockNames(mdl);
end

function opHighlight(mdl)
slHighlightUnconnected(mdl);
slHighlightUnconnected(mdl, true);
end
