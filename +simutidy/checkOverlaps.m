function res = checkOverlaps(sys)
%checkOverlaps 检查当前层级中互相重叠的模块（3.4.0 新增）
%   res = simutidy.checkOverlaps()       - 检查当前子系统
%   res = simutidy.checkOverlaps(sys)    - 指定子系统
%
%   功能：
%       - 作用范围：当前层全部块（SearchDepth=1，与选中状态无关）
%       - 两两 AABB 重叠检测，输出重叠对清单（每对一条，含可定位句柄）
%       - 返回 res 供 GUI 结果面板逐条"定位"（打开所在系统并高亮该块，
%         搭档块名写在 reason 里）
%       - 命令行不接输出时行为不变（只有汇总日志）
%
%   已知取舍：两两检测为 O(n²)，500 块实测毫秒级（纯数值比较，
%   无 Simulink API 调用）；千块以上单层再考虑向量化优化
%   兼容：根目录 slCheckOverlaps.m 为薄包装

    % nargin 守卫须在 resolveSystem 之前（零参调用约定，见 alignBlocks 注释）
    if nargin < 1
        sys = gcs;
    end
    sysPath = simutidy.internal.resolveSystem(sys);

    cacheH = find_system(sysPath, 'FindAll', 'on', 'SearchDepth', 1, 'Type', 'block');
    cacheR = simutidy.internal.batchPositions(cacheH);
    n = numel(cacheH);

    % 批量取名字（面板 reason 与日志用），一次 API 调用
    if n > 0
        names = get_param(cacheH, 'Name');
        if ~iscell(names), names = {names}; end
    else
        names = {};
    end

    findings = struct('handle', {}, 'reason', {}, 'index', {});
    involved = [];  % 参与重叠的块句柄（okCount 用）
    for i = 1:n
        for j = i+1:n
            % AABB 相交判定（与 internal.collidesAny 同口径，就地内联
            % 避免每对一次函数调用的开销；collidesAny 是"对全员"版本，
            % 这里要的是点对点）
            a = cacheR(i, :); b = cacheR(j, :);
            if ~(a(3) < b(1) || a(1) > b(3) || a(4) < b(2) || a(2) > b(4))
                findings(end+1) = struct('handle', cacheH(i), ...
                    'reason', sprintf('与模块 "%s" 重叠', names{j}), ...
                    'index', numel(findings) + 1); %#ok<AGROW>
                involved = [involved, cacheH(i), cacheH(j)]; %#ok<AGROW>
            end
        end
    end

    okCount = n - numel(unique(involved));

    if isempty(findings)
        simutidy.internal.log('info', '重叠检测完成：当前层 %d 个块，未发现重叠。', n);
    else
        simutidy.internal.log('warn', '重叠检测完成：当前层 %d 个块，发现 %d 处重叠（%d 个块受影响）。', ...
            n, numel(findings), numel(unique(involved)));
    end

    % okLabel/failLabel：结果面板的文案钩子（诊断类"失败"实为"发现项"）
    res = struct('op', '模块重叠检测', 'okLabel', '无重叠', 'failLabel', '重叠块', ...
        'okCount', okCount, 'failCount', numel(findings), 'failItems', findings);
end
