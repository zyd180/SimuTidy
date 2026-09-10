function res = highlightUnconnected(sys, varargin)
%highlightUnconnected 高亮显示未连接的端口（3.4.0 升级：res 输出 + 分类）
%   （3.1.0 自 core/slHighlightUnconnected 迁入 +simutidy 包）
%   res = simutidy.highlightUnconnected() - 高亮当前子系统未连接端口
%   simutidy.highlightUnconnected(sys)    - 高亮指定子系统
%   simutidy.highlightUnconnected([], true) - 清除高亮
%   simutidy.highlightUnconnected([], 'Progress', fig) - GUI 进度条
%
%   功能：
%       首次运行：高亮所有未连接端口
%       再次运行：取消已连接端口的高亮，保持未连接端口的高亮
%       清除模式：清除所有高亮
%   3.4.0 升级（res 可选输出，命令行不接输出行为不变）：
%       - 逐项分类记录发现：输入/输出/使能等端口未连接、悬空信号线
%       - res.failItems 含可定位句柄，GUI 结果面板逐条"定位"
%       - okLabel/failLabel 供面板文案（"连接完好"/"有问题"）
%
%   性能豁免说明：高亮依赖 Simulink 逐块内部机制（HiliteAncestors），
%   无法批量 API 化，3.1.0 规划中已声明豁免；本版本仅将扫描范围收敛
%   为当前层（见下），扫描本身的收益保留
%   兼容：根目录 slHighlightUnconnected.m 为薄包装，行为契约不变

    % 3.3.0 进度条：'Progress' 选项；clearFlag 位置参数与名值对共存。
    % 只把 logical 位置参数识别为 clearFlag——第 2 参历史上只有 true/false，
    % 若是 char 只能是 'Progress' 选项名，交给 parseOptions
    % 3.4.0 修复：clearFlag 默认值必须**先于**任何条件分支赋值。原写法
    % `if nargin < 2 || isempty(clearFlag)` 在 nargin=3（sys+'Progress'+fig，
    % 即 GUI 路径）时左边为 false，右边去读未定义的 clearFlag 直接抛
    % "函数或变量 'clearFlag' 无法识别"——3.3.0 加 Progress 选项引入的
    % 存量 bug，回归测试只覆盖 1/2 参调用未踩到，用户 GUI 点击时暴露
    clearFlag = false;
    if nargin > 1 && ~isempty(varargin) && islogical(varargin{1})
        clearFlag = varargin{1};
        varargin(1) = [];
    end
    opt = simutidy.internal.parseOptions(varargin, {'Progress'});

    % nargin 守卫必须在最顶部：零参调用时 sys 未定义，而 clearFlag 分支
    % 与 resolveSystem 都要用到它（原因详见 simutidy/alignBlocks.m 入口注释）
    if nargin < 1
        sys = gcs;
    end

    % 清除模式
    if clearFlag
        clearAllHighlights(sys);
        % 3.4.0：清除模式返回零发现 res（GUI 面板对 failCount=0 自动跳过）
        res = emptyRes();
        return;
    end

    % 3.1.0 收敛：sys 校验样板统一走 internal.resolveSystem
    sysPath = simutidy.internal.resolveSystem(sys);

    % 步骤1：先清除所有高亮
    clearAllHighlights(sysPath);

    % 步骤2：重新检测并高亮未连接端口
    % 3.1.0 行为修正：加 SearchDepth=1 限定当前层。原实现递归全模型，
    % 把子层块混入当前层诊断（帮助文档本就声明"当前子系统"），且全层
    % 递归在大模型上显著变慢；高亮依赖 Simulink 逐块机制，性能豁免，
    % 但扫描范围收敛为当前层
    blocks = find_system(sysPath, 'FindAll', 'on', 'SearchDepth', 1, 'Type', 'block');
    unconnectedCount = 0;

    % 悬空信号线查询提前（3.3.0：进度条需要先知道总工作量）
    lines = find_system(sysPath, 'FindAll', 'on', 'SearchDepth', 1, 'Type', 'line');
    dlg = simutidy.internal.progress('start', opt.progress, ...
        numel(blocks) + numel(lines), '高亮未连接端口');
    % 3.4.0：异常安全——循环中途报错（如某块 PortHandles 异常）时对话框
    % 必须自动关闭，否则 uiprogressdlg 模态挂住主窗口，用户感觉"卡死"。
    % onCleanup 兜底；正常路径 done 会重置内部状态，二次 done 是空操作
    cleanupDlg = onCleanup(@() simutidy.internal.progress('done', dlg));

    % 3.4.0：逐项发现记录（分类原因 + 可定位句柄，供结果面板）
    findings = struct('handle', {}, 'reason', {}, 'index', {});

    for i = 1:length(blocks)
        keep = simutidy.internal.progress('step', dlg, ...
            sprintf('检查模块 %d/%d', i, numel(blocks)));
        if ~keep
            simutidy.internal.log('warn', '已取消：模块检查到第 %d/%d 个。', i, numel(blocks));
            break;
        end
        ph = get_param(blocks(i), 'PortHandles');
        % 3.4.0 分类统计：输入/输出/控制类端口分开计数，原因文案更具体
        % （原实现只判 hasUnconnected 后 break，说不出缺的是哪端）
        nUncIn    = countUnconnected(ph.Inport);
        nUncOut   = countUnconnected(ph.Outport);
        nUncOther = countUnconnected([ph.Enable, ph.Trigger, ...
                                     ph.State, ph.Ifaction, ph.Reset]);
        hasUnconnected = (nUncIn + nUncOut + nUncOther) > 0;

        if hasUnconnected
            try
                set_param(blocks(i), 'HiliteAncestors', 'error');
                unconnectedCount = unconnectedCount + 1;
            catch
            end
            findings(end+1) = struct('handle', blocks(i), ...
                'reason', unconnReason(nUncIn, nUncOut, nUncOther), ...
                'index', numel(findings) + 1); %#ok<AGROW>
        end
    end

    % 检测悬空信号线（同样限当前层，理由同上）
    for i = 1:length(lines)
        keep = simutidy.internal.progress('step', dlg, ...
            sprintf('检查信号线 %d/%d', i, numel(lines)));
        if ~keep
            simutidy.internal.log('warn', '已取消：信号线检查到第 %d/%d 条。', i, numel(lines));
            break;
        end
        srcPortH = get_param(lines(i), 'SrcPortHandle');
        dstPortH = get_param(lines(i), 'DstPortHandle');
        if srcPortH == -1 || isempty(dstPortH) || dstPortH(1) == -1
            try
                set_param(lines(i), 'HiliteAncestors', 'error');
            catch
            end
            % 3.4.0：悬空线并入同一发现清单（原两处重复的 try/catch 收敛）
            findings(end+1) = struct('handle', lines(i), ...
                'reason', '悬空信号线（源端或目标端未连接）', ...
                'index', numel(findings) + 1); %#ok<AGROW>
        end
    end
    simutidy.internal.progress('done', dlg);

    % 3.3.0：汇总输出接入分级日志
    simutidy.internal.log('info', '高亮完成，共发现 %d 个有未连接端口的模块。', unconnectedCount);
    simutidy.internal.log('info', ['再次运行将更新高亮状态，运行 ' ...
        'simutidy.highlightUnconnected([], true) 可清除高亮。']);

    % 3.4.0：res 可选输出（okCount = 检查对象总数 - 有问题的对象数）
    res = struct('op', '高亮未连接端口', 'okLabel', '连接完好', 'failLabel', '有问题', ...
        'okCount', numel(blocks) + numel(lines) - numel(findings), ...
        'failCount', numel(findings), 'failItems', findings);
end

%% ========================================================================
%  辅助函数
%% ========================================================================
function n = countUnconnected(ports)
%countUnconnected 统计未连接的端口数（3.4.0 新增）
%   PortHandles 中的 -1 是"无此类端口"占位，须先剔除再取 Line
%   3.4.0 修复：get_param 传**多个**句柄时返回 cell（与 Position 同款
%   多值返回行为，batchPositions 归一的同一坑），直接 `== -1` 会抛
%   "'cell' 类型的函数 'eq' 未定义"（用户实测：多输入块触发）。
%   这里 iscell 归一为数值向量再比较；单句柄返回标量数，两态都兼容
    ports = ports(ports ~= -1);
    if isempty(ports)
        n = 0;
        return;
    end
    lh = get_param(ports, 'Line');
    if iscell(lh)
        lh = cell2mat(lh);
    end
    n = sum(lh == -1);
end

function txt = unconnReason(nIn, nOut, nOther)
%unconnReason 按端口类别拼装发现原因（3.4.0 新增）
    parts = {};
    if nIn > 0,    parts{end+1} = sprintf('%d 个输入端口', nIn); end
    if nOut > 0,   parts{end+1} = sprintf('%d 个输出端口', nOut); end
    if nOther > 0, parts{end+1} = sprintf('%d 个控制/状态端口', nOther); end
    txt = [strjoin(parts, '、') '未连接'];
end

function res = emptyRes()
%emptyRes 清除模式/无发现时的零项 res（3.4.0 新增）
    res = struct('op', '高亮未连接端口', 'okLabel', '连接完好', 'failLabel', '有问题', ...
        'okCount', 0, 'failCount', 0, ...
        'failItems', struct('handle', {}, 'reason', {}, 'index', {}));
end

%% ========================================================================
%  辅助函数
%% ========================================================================
function clearAllHighlights(sys)
%clearAllHighlights 清除所有高亮显示
%   注意：清除仍用全层递归——清除操作无坐标语义，清得越彻底越安全
    try
        blocks = find_system(sys, 'FindAll', 'on', 'Type', 'block');
        for i = 1:length(blocks)
            try
                set_param(blocks(i), 'HiliteAncestors', 'none');
            catch
            end
        end

        lines = find_system(sys, 'FindAll', 'on', 'Type', 'line');
        for i = 1:length(lines)
            try
                set_param(lines(i), 'HiliteAncestors', 'none');
            catch
            end
        end

        fprintf('高亮已清除。\n');
    catch
    end
end
