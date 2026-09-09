function slUniformSize(sys, mode)
%slUniformSize 统一选中模块的大小
%   slUniformSize() - 以基准模块为准统一大小
%   slUniformSize(sys) - 指定子系统
%   slUniformSize(sys, mode) - 指定模式
%
%   输入：
%       sys - 子系统路径或句柄（可选，默认当前子系统）
%       mode - 统一模式：
%           'base' - 以基准模块（最上方最左）为准（默认）
%           'max'  - 以最大宽高为准
%           'min'  - 以最小宽高为准
%           'avg'  - 以平均宽高为准
%
%   功能：
%       统一所有选中模块的大小，保持中心点不变

    if nargin < 1 || isempty(sys)
        sys = gcs;
    end
    
    if nargin < 2 || isempty(mode)
        mode = 'base';
    end
    
    if isempty(sys) || ~ishandle(get_param(sys, 'Handle'))
        error('无效的子系统句柄或路径。');
    end

    selectedObjs = find_system(sys, 'FindAll', 'on', 'Selected', 'on', 'Type', 'block');
    if length(selectedObjs) < 2
        error('请至少选中 2 个模块。');
    end

    n = length(selectedObjs);
    % 3.1.0 性能优化：位置批量读取（同 slAlignBlocks，1 次 API 调用替代 N 次）
    positions = cell2mat(get_param(selectedObjs, 'Position'));

    widths  = positions(:, 3) - positions(:, 1);
    heights = positions(:, 4) - positions(:, 2);
    centersX = (positions(:, 1) + positions(:, 3)) / 2;
    centersY = (positions(:, 2) + positions(:, 4)) / 2;

    switch lower(mode)
        case 'max'
            targetW = max(widths);
            targetH = max(heights);
        case 'min'
            targetW = min(widths);
            targetH = min(heights);
        case 'base'
            [~, sortIdx] = sortrows(positions, [2, 1]);
            baseIdx = sortIdx(1);
            targetW = widths(baseIdx);
            targetH = heights(baseIdx);
        otherwise  % 'avg'
            targetW = round(mean(widths));
            targetH = round(mean(heights));
    end

    for i = 1:n
        newLeft   = centersX(i) - targetW / 2;
        newRight  = centersX(i) + targetW / 2;
        newTop    = centersY(i) - targetH / 2;
        newBottom = centersY(i) + targetH / 2;
        newPos = [newLeft, newTop, newRight, newBottom];
        % 3.1.0 性能优化：尺寸已是目标值则跳过写入（幂等）。带连线的块
        % 每次 set_param(Position) 都触发 Simulink 内部连线重排，能省则省
        if isequal(newPos, positions(i, :))
            continue;
        end
        set_param(selectedObjs(i), 'Position', newPos);
    end

    fprintf('模块大小统一完成（%s: W=%d, H=%d），共调整 %d 个模块。\n', ...
        mode, targetW, targetH, n);

    % 3.1.0 性能优化：移除 update——纯几何改尺寸后 Simulink 自动重排连线，
    % 编译刷新浪费整模型编译时间（理由详见 slAlignBlocks 同名注释）
end
