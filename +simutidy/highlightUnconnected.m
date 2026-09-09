function highlightUnconnected(sys, clearFlag)
%highlightUnconnected 高亮显示未连接的端口
%   （3.1.0 自 core/slHighlightUnconnected 迁入 +simutidy 包）
%   simutidy.highlightUnconnected() - 高亮当前子系统未连接端口
%   simutidy.highlightUnconnected(sys) - 高亮指定子系统
%   simutidy.highlightUnconnected([], true) - 清除高亮
%
%   功能：
%       首次运行：高亮所有未连接端口
%       再次运行：取消已连接端口的高亮，保持未连接端口的高亮
%       清除模式：清除所有高亮
%
%   性能豁免说明：高亮依赖 Simulink 逐块内部机制（HiliteAncestors），
%   无法批量 API 化，3.1.0 规划中已声明豁免；本版本仅将扫描范围收敛
%   为当前层（见下），扫描本身的收益保留
%   兼容：根目录 slHighlightUnconnected.m 为薄包装，行为契约不变

    % nargin 守卫必须在最顶部：零参调用时 sys 未定义，而 clearFlag 分支
    % 与 resolveSystem 都要用到它（原因详见 simutidy/alignBlocks.m 入口注释）
    if nargin < 1
        sys = gcs;
    end
    if nargin < 2
        clearFlag = false;
    end

    % 清除模式
    if clearFlag
        clearAllHighlights(sys);
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

    for i = 1:length(blocks)
        ph = get_param(blocks(i), 'PortHandles');
        allPorts = [ph.Inport, ph.Outport, ph.Enable, ph.Trigger, ...
                    ph.State, ph.Ifaction, ph.Reset];
        hasUnconnected = false;

        for p = 1:length(allPorts)
            if allPorts(p) ~= -1
                lineH = get_param(allPorts(p), 'Line');
                if lineH == -1
                    hasUnconnected = true;
                    break;
                end
            end
        end

        if hasUnconnected
            try
                set_param(blocks(i), 'HiliteAncestors', 'error');
                unconnectedCount = unconnectedCount + 1;
            catch
            end
        end
    end

    % 检测悬空信号线（同样限当前层，理由同上）
    lines = find_system(sysPath, 'FindAll', 'on', 'SearchDepth', 1, 'Type', 'line');
    for i = 1:length(lines)
        srcPortH = get_param(lines(i), 'SrcPortHandle');
        dstPortH = get_param(lines(i), 'DstPortHandle');
        if srcPortH == -1 || isempty(dstPortH)
            try
                set_param(lines(i), 'HiliteAncestors', 'error');
            catch
            end
        elseif dstPortH(1) == -1
            try
                set_param(lines(i), 'HiliteAncestors', 'error');
            catch
            end
        end
    end

    fprintf('高亮完成，共发现 %d 个有未连接端口的模块。\n', unconnectedCount);
    fprintf('再次运行将更新高亮状态，运行 simutidy.highlightUnconnected([], true) 可清除高亮。\n');
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
