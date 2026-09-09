function uniformSize(sys, mode)
%uniformSize 统一选中模块的大小（3.1.0 自 core/slUniformSize 迁入 +simutidy 包）
%   simutidy.uniformSize() - 以基准模块为准统一大小
%   simutidy.uniformSize(sys, mode) - 指定模式：base/max/min/avg
%
%   功能：统一所有选中模块的大小，保持中心点不变
%   兼容：根目录 slUniformSize.m 为薄包装，行为契约不变

    % nargin 守卫必须在把 sys 传入 resolveSystem **之前**（原因见
    % simutidy/alignBlocks.m 入口注释：零参调用时 sys 未定义，
    % 作实参直接抛"输入参数的数目不足"）
    if nargin < 1
        sys = gcs;
    end
    sysPath = simutidy.internal.resolveSystem(sys);
    if nargin < 2 || isempty(mode)
        mode = 'base';
    end

    selectedObjs = find_system(sysPath, 'FindAll', 'on', 'Selected', 'on', 'Type', 'block');
    if length(selectedObjs) < 2
        error('SimuTidy:tooFewBlocks', '请至少选中 2 个模块。');
    end

    n = length(selectedObjs);
    % 3.1.0 性能优化：位置批量读取（同 simutidy.alignBlocks，1 次 API 调用替代 N 次）
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

    % 3.3.0：汇总输出接入分级日志（原 fprintf）
    simutidy.internal.log('info', '模块大小统一完成（%s: W=%d, H=%d），共调整 %d 个模块。', ...
        mode, targetW, targetH, n);

    % 3.1.0 性能优化：移除 update——纯几何改尺寸后 Simulink 自动重排连线，
    % 编译刷新浪费整模型编译时间（理由详见 simutidy/alignBlocks.m 同名注释）
end
