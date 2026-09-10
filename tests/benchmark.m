%% benchmark.m — SimuTidy 批量操作性能基准（3.1.0）
%   用途：性能优化（目标 ≥3×，高亮/写密集型豁免）的前后对比测量。
%   方法：自动生成 N 块串联模型（unsaved，用完即弃），各功能计时取 3 次最优。
%   计时口径（重要，勿改）：
%     - 选中/取消选中不计入计时——真实场景中选中由用户在 Simulink 内完成，
%       且实测 set_param('Selected') 单次 ~1.7ms，计入会淹没功能本身的耗时
%     - 几何敏感的操作（端口对齐）排在会破坏布局的对齐类操作之前
%   运行：benchmark(N)，N 默认 500；结果追加至 output/benchmark_log.txt

function benchmark(N)
if nargin < 1, N = 500; end
root = fileparts(mfilename('fullpath'));
% 3.4.0 清理：3.1.0 命名空间化后 core 目录已并入 +simutidy 包（随根目录
% 在 path 上即可解析），删除残留的 core addpath
addpath(fullfile(root, '..'), fullfile(root, '..', 'gui'), ...
        fullfile(root, '..', 'utils'));

mdl = 'BENCH_MODEL';
if bdIsLoaded(mdl), bdclose(mdl); end
new_system(mdl); open_system(mdl);
fprintf('生成 %d 块串联模型...\n', N);

% 串联链：Gain x N（autorouting off 只为加速建模，不影响测量对象）
for k = 1:N
    add_block('built-in/Gain', [mdl '/G' num2str(k)], ...
        'Position', [40*k 100 40*k+30 130]);
end
for k = 1:N-1
    add_line(mdl, ['G' num2str(k) '/1'], ['G' num2str(k+1) '/1'], ...
        'autorouting', 'off');
end

handles = find_system(mdl, 'FindAll', 'on', 'Type', 'block');
lineHs  = find_system(mdl, 'FindAll', 'on', 'Type', 'line');

% ---- 每个操作的选中状态准备（prep 不计入计时）----
% 真实场景中选中由用户在 Simulink 内完成，且实测 set_param('Selected')
% 单次 ~1.7ms，计入会淹没功能本身耗时 → prep 与 op 分离

ops = {
    @() opLinePorts(mdl, handles),    'slAlignLinePorts(单块)';
    @() opNames(mdl),                 'slUpdateBlockNames(全模型)';
    @() opName(mdl, lineHs),          'slAutoNameSignals(source, 全线)';
    @() opAlign(mdl, handles),        'slAlignBlocks(left, 全选)';
    @() opUniform(mdl, handles),      'slUniformSize(base, 全选)';
    @() opHighlight(mdl),             'slHighlightUnconnected(全模型, 豁免)';
};
% 与 ops 一一对应的选中准备（在每次计时组开始前执行，不计时）
prep = { ...
    @() selOnly(handles, 2); ...        % linePorts 只选 G2
    @() noop(); ...
    @() selNone(handles); ...           % autoName 需无选中线 → 全不选
    @() rescan(handles); ...            % align 全选并重摆（幂等优化需真实活干）
    @() rescan(handles); ...            % uniform 全选并重摆
    @() noop() ...                      % highlight 与选中无关
};

results = cell(1, size(ops, 1));
% align/uniform 有幂等跳过优化（位置未变不写入），第 2/3 次重复会变成
% 空操作 → 这两个操作每次重复前都要重摆位置（重摆计入 prep，不计时）
perRepPrep = [false false false true true false];
for o = 1:size(ops, 1)
    prep{o}();
    best = Inf;
    for r = 1:3
        if perRepPrep(o), prep{o}(); end
        t = tocSafe(ops{o, 1});
        best = min(best, t);
    end
    results{o} = best;
end

fprintf('\n===== 基准结果（N=%d，3 次取最优，选中不计入计时，单位秒）=====\n', N);
for o = 1:size(ops, 1)
    fprintf('  %-38s %8.3f s\n', ops{o, 2}, results{o});
end

% 结果落盘（output/ 已在 .gitignore），供 Phase 1 前后对比
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
% evalc 吞掉功能函数的汇总打印，保持控制台/日志整洁；
% evalc 开销恒定且对前后两轮测量一致，不影响对比口径
t0 = tic;
evalc('f()');
t = toc(t0);
end

function noop() %#ok<*> 
end

function selAll(handles)
for h = handles(:)'
    set_param(h, 'Selected', 'on');
end
end

function selNone(handles)
for h = handles(:)'
    set_param(h, 'Selected', 'off');
end
end

function selOnly(handles, k)
selNone(handles);
set_param(handles(k), 'Selected', 'on');
end

function rescan(handles)
% 重摆到"错位+变尺寸"网格并保持全选：
% 1) align：x 全部偏离基准 → 每次重复都有真实写入
% 2) uniform：高度按 k 变化（30/40/50 交替）→ 统一到基准尺寸有真实写入
%    （若尺寸全部相同，uniform 的幂等跳过会让计时变成空操作）
% 3) 让 align/uniform 的幂等跳过优化失效，每次重复都是"真实有活干"
% 重摆计入 prep，不计时
for k = 1:numel(handles)
    hgt = 30 + 10 * mod(k, 3);
    set_param(handles(k), 'Position', [40*k 100 40*k+30 100+hgt]);
    set_param(handles(k), 'Selected', 'on');
end
end

function opAlign(mdl, ~) %#ok<INUSL>
slAlignBlocks(mdl, 'left');   % 选中状态由外部准备并保持
end

function opUniform(mdl, ~) %#ok<INUSL>
slUniformSize(mdl, 'base');
end

function opName(mdl, lineHs)
% 每次计时前清名，保证三次重复测的是同一路径
for h = lineHs(:)'
    set_param(h, 'Name', '');
end
slAutoNameSignals(mdl, 'source');
end

function opLinePorts(mdl, handles)
% 下移 40 后端口不同高；对齐方向为回到网格行，与相邻块 x 不重叠，
% 不触发碰撞跳过 → 每次重复都是一次真实的"移动+拉直"
set_param(handles(2), 'Position', get_param(handles(2), 'Position') + [0 40 0 40]);
slAlignLinePorts(mdl);
end

function opNames(mdl)
slUpdateBlockNames(mdl);
end

function opHighlight(mdl)
slHighlightUnconnected(mdl);
slHighlightUnconnected(mdl, true);
end
