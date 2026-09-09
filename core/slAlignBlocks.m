function slAlignBlocks(sys, alignType)
%slAlignBlocks 模块批量对齐与分布
%   slAlignBlocks() - 左对齐当前子系统选中的模块
%   slAlignBlocks(sys) - 左对齐指定子系统选中的模块
%   slAlignBlocks(sys, alignType) - 指定对齐方式
%
%   输入：
%       sys - 子系统路径或句柄（可选，默认当前子系统）
%       alignType - 对齐方式：
%           'left'     - 左对齐（默认）
%           'right'    - 右对齐
%           'top'      - 顶部对齐
%           'bottom'   - 底部对齐
%           'hcenter'  - 水平居中
%           'vcenter'  - 垂直居中
%           'hspace'   - 水平等间距
%           'vspace'   - 垂直等间距
%
%   功能：
%       以最上方最左的模块为基准，调整其他模块位置实现对齐
%       基准模块位置不变

    if nargin < 1 || isempty(sys)
        sys = gcs;
    end
    
    if nargin < 2 || isempty(alignType)
        alignType = 'left';
    end
    
    if isempty(sys) || ~ishandle(get_param(sys, 'Handle'))
        error('无效的子系统句柄或路径。');
    end

    selectedObjs = find_system(sys, 'FindAll', 'on', 'Selected', 'on', 'Type', 'block');
    if length(selectedObjs) < 2
        error('请至少选中 2 个模块。');
    end

    n = length(selectedObjs);
    positions = zeros(n, 4);
    for i = 1:n
        positions(i, :) = get_param(selectedObjs(i), 'Position');
    end

    lefts   = positions(:, 1);
    tops    = positions(:, 2);
    rights  = positions(:, 3);
    bottoms = positions(:, 4);
    widths  = rights - lefts;
    heights = bottoms - tops;

    [~, sortIdx] = sortrows(positions, [2, 1]);
    baseIdx = sortIdx(1);
    basePos = positions(baseIdx, :);

    switch alignType
        case 'left'
            for i = 1:n
                if i == baseIdx, continue; end
                newLeft = basePos(1);
                newPos = [newLeft, tops(i), newLeft + widths(i), bottoms(i)];
                set_param(selectedObjs(i), 'Position', newPos);
            end
        case 'right'
            for i = 1:n
                if i == baseIdx, continue; end
                newRight = basePos(3);
                newLeft = newRight - widths(i);
                newPos = [newLeft, tops(i), newRight, bottoms(i)];
                set_param(selectedObjs(i), 'Position', newPos);
            end
        case 'top'
            for i = 1:n
                if i == baseIdx, continue; end
                newTop = basePos(2);
                newPos = [lefts(i), newTop, rights(i), newTop + heights(i)];
                set_param(selectedObjs(i), 'Position', newPos);
            end
        case 'bottom'
            for i = 1:n
                if i == baseIdx, continue; end
                newBottom = basePos(4);
                newTop = newBottom - heights(i);
                newPos = [lefts(i), newTop, rights(i), newBottom];
                set_param(selectedObjs(i), 'Position', newPos);
            end
        case 'hcenter'
            baseCenterX = (basePos(1) + basePos(3)) / 2;
            for i = 1:n
                if i == baseIdx, continue; end
                newLeft = baseCenterX - widths(i) / 2;
                newRight = baseCenterX + widths(i) / 2;
                newPos = [newLeft, tops(i), newRight, bottoms(i)];
                set_param(selectedObjs(i), 'Position', newPos);
            end
        case 'vcenter'
            baseCenterY = (basePos(2) + basePos(4)) / 2;
            for i = 1:n
                if i == baseIdx, continue; end
                newTop = baseCenterY - heights(i) / 2;
                newBottom = baseCenterY + heights(i) / 2;
                newPos = [lefts(i), newTop, rights(i), newBottom];
                set_param(selectedObjs(i), 'Position', newPos);
            end
        case 'hspace'
            centersX = (lefts + rights) / 2;
            [sortedX, idx] = sort(centersX);
            minX = sortedX(1);
            maxX = sortedX(end);
            if n > 1
                step = (maxX - minX) / (n - 1);
                for i = 1:n
                    j = idx(i);
                    if j == baseIdx, continue; end
                    target = minX + (i - 1) * step;
                    newLeft = target - widths(j) / 2;
                    newRight = target + widths(j) / 2;
                    newPos = [newLeft, tops(j), newRight, bottoms(j)];
                    set_param(selectedObjs(j), 'Position', newPos);
                end
            end
        case 'vspace'
            centersY = (tops + bottoms) / 2;
            [sortedY, idx] = sort(centersY);
            minY = sortedY(1);
            maxY = sortedY(end);
            if n > 1
                step = (maxY - minY) / (n - 1);
                for i = 1:n
                    j = idx(i);
                    if j == baseIdx, continue; end
                    target = minY + (i - 1) * step;
                    newTop = target - heights(j) / 2;
                    newBottom = target + heights(j) / 2;
                    newPos = [lefts(j), newTop, rights(j), newBottom];
                    set_param(selectedObjs(j), 'Position', newPos);
                end
            end
        otherwise
            error('未知的对齐类型: %s', alignType);
    end

    fprintf('%s 完成，基准模块: %s（位置未动），共调整 %d 个模块。\n', ...
        getAlignText(alignType), get_param(selectedObjs(baseIdx), 'Name'), n-1);
    
    cfg = SimuTidy_config();
    if cfg.simulink.updateAfterChange
        try
            set_param(sys, 'SimulationCommand', 'update');
        catch
        end
    end
end

function txt = getAlignText(t)
    switch t
        case 'left',     txt = '左对齐';
        case 'right',    txt = '右对齐';
        case 'top',      txt = '顶部对齐';
        case 'bottom',   txt = '底部对齐';
        case 'hcenter',  txt = '水平居中';
        case 'vcenter',  txt = '垂直居中';
        case 'hspace',   txt = '水平等间距';
        case 'vspace',   txt = '垂直等间距';
        otherwise,       txt = '对齐';
    end
end
