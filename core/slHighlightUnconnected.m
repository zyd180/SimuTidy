function slHighlightUnconnected(sys, clearFlag)
%slHighlightUnconnected 高亮显示未连接的端口
%   slHighlightUnconnected() - 高亮当前子系统未连接端口
%   slHighlightUnconnected(sys) - 高亮指定子系统
%   slHighlightUnconnected([], true) - 清除高亮
%
%   功能：
%       首次运行：高亮所有未连接端口
%       再次运行：取消已连接端口的高亮，保持未连接端口的高亮
%       清除模式：清除所有高亮
%
%   输入：
%       sys - 子系统路径或句柄（可选，默认当前子系统）
%       clearFlag - 是否清除高亮（可选，默认false）

    if nargin < 1 || isempty(sys)
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

    if isempty(sys) || ~ishandle(get_param(sys, 'Handle'))
        error('无效的子系统句柄或路径。');
    end

    % 步骤1：先清除所有高亮
    clearAllHighlights(sys);
    
    % 步骤2：重新检测并高亮未连接端口
    blocks = find_system(sys, 'FindAll', 'on', 'Type', 'block');
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

    % 检测悬空信号线
    lines = find_system(sys, 'FindAll', 'on', 'Type', 'line');
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
    fprintf('再次运行将更新高亮状态，运行 slHighlightUnconnected([], true) 可清除高亮。\n');
end

%% ========================================================================
%  辅助函数
%% ========================================================================
function clearAllHighlights(sys)
%clearAllHighlights 清除所有高亮显示
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
