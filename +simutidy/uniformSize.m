function uniformSize(sys, mode)
%uniformSize 统一选中模块的大小（3.1.0 自 core/slUniformSize 迁入 +simutidy 包）
%   simutidy.uniformSize() - 以基准模块为准统一大小
%   simutidy.uniformSize(sys, mode) - 指定模式：base/max/min/avg
%
%   功能：统一所有选中模块的大小，保持中心点不变
%   作用范围（3.4.0 修正）：只处理当前层的选中块（SearchDepth=1）——
%       原不限层的 FindAll 会把打开的子系统里的选中块混进来，不同层
%       坐标系不同，混算产生非预期改尺寸（同 alignBlocks 3.4.0 修正）
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

    % 3.4.0 跨层修正：加 SearchDepth=1 只取当前层选中块（理由同 alignBlocks）
    selectedObjs = find_system(sysPath, 'FindAll', 'on', 'SearchDepth', 1, ...
        'Selected', 'on', 'Type', 'block');
    if length(selectedObjs) < 2
        error('SimuTidy:tooFewBlocks', '请至少选中 2 个模块。');
    end

    n = length(selectedObjs);
    % 3.1.0 性能优化：位置批量读取（3.3.0 起经 batchPositions 归一）
    positions = simutidy.internal.batchPositions(selectedObjs);

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

    % 3.1.0 性能优化：尺寸已是目标值则跳过写入（幂等）。带连线的块
    % 每次 set_param(Position) 都触发 Simulink 内部连线重排，能省则省
    % 3.4.0：顺带统计实际调整数（原日志虚报 n，见下）
    adjusted = 0;
    for i = 1:n
        newLeft   = centersX(i) - targetW / 2;
        newRight  = centersX(i) + targetW / 2;
        newTop    = centersY(i) - targetH / 2;
        newBottom = centersY(i) + targetH / 2;
        newPos = [newLeft, newTop, newRight, newBottom];
        if isequal(newPos, positions(i, :))
            continue;
        end
        set_param(selectedObjs(i), 'Position', newPos);
        adjusted = adjusted + 1;
    end

    % 3.3.0：汇总输出接入分级日志（原 fprintf）
    % 3.4.0：明示基准是谁 + 改报实际调整数（原"共调整 %d 个"用 n，
    % 与幂等跳过后的真实写入数不符，易误导）
    if strcmpi(mode, 'base')
        simutidy.internal.log('info', '模块大小统一完成（基准模块: %s，所选块中最上最左；目标尺寸 W=%d, H=%d），实际调整 %d 个模块。', ...
            get_param(selectedObjs(baseIdx), 'Name'), targetW, targetH, adjusted);
    else
        simutidy.internal.log('info', '模块大小统一完成（%s: W=%d, H=%d），实际调整 %d 个模块。', ...
            mode, targetW, targetH, adjusted);
    end

    % 3.1.0 性能优化：移除 update——纯几何改尺寸后 Simulink 自动重排连线，
    % 编译刷新浪费整模型编译时间（理由详见 simutidy/alignBlocks.m 同名注释）
end
