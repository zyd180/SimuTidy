function slAlignLinePorts(sys)
%slAlignLinePorts 连线端口对齐
%   slAlignLinePorts() - 将当前子系统选中的模块与其连线另一端端口水平对齐
%   slAlignLinePorts(sys) - 指定子系统
%
%   功能：
%       - 以选中模块连线的另一端端口为基准（基准端不动）
%       - 垂直移动选中的模块（只调 y，不改 x），使其端口与基准端口同高
%       - 对齐后该连线成为纯水平直线；同模块其余连线在模块一侧拉直
%       - 对齐依据线：优先用户同时选中的连线，否则取模块第一条已连接连线
%       - 碰撞检查采用两阶段裁决：先按规则算出所有选中模块的目标位置，
%         再在"全部移动后"的虚拟布局上检查碰撞；会与（移动后的）周围模块
%         重叠的模块被跳过（不做任何修改），并回落到原位置参与后续检查
%       - 单个失败不影响其他，最后汇总报告

    if nargin < 1 || isempty(sys)
        sys = gcs;
    end
    if isempty(sys) || ~ishandle(get_param(sys, 'Handle'))
        error('无效的子系统句柄或路径。');
    end

    selBlocks = find_system(sys, 'FindAll', 'on', 'Selected', 'on', 'Type', 'block');
    selLines = find_system(sys, 'FindAll', 'on', 'Selected', 'on', 'Type', 'line');
    if isempty(selBlocks)
        error('请先选中要对齐的模块。');
    end

    % 模块位置缓存
    cacheH = find_system(sys, 'FindAll', 'on', 'SearchDepth', 1, 'Type', 'block');
    % 3.1.0 性能优化：位置批量读取，1 次 API 调用替代逐块 N 次
    cacheR = cell2mat(get_param(cacheH, 'Position'));

    n = numel(selBlocks);
    plans = repmat(struct('blockH', 0, 'dy', 0, 'newPos', zeros(1, 4)), 1, n);
    hasPlan = false(1, n);
    skipped = false(1, n);
    failInfo = cell(1, n);

    % ===== 阶段1：基于初始几何计算每个选中模块的目标位置 =====
    for i = 1:n
        try
            plans(i) = makePlan(selBlocks(i), selLines);
            hasPlan(i) = true;
        catch ME
            skipped(i) = true;
            failInfo{i} = sprintf('  模块%d: %s', i, ME.message);
        end
    end

    % ===== 阶段2：虚拟布局碰撞裁决 =====
    % 虚拟布局：有计划的选中模块放在目标位置，其余保持原位
    virtR = cacheR;
    for i = 1:n
        if hasPlan(i)
            idx = find(cacheH == plans(i).blockH, 1);
            if ~isempty(idx)
                virtR(idx, :) = plans(i).newPos;
            end
        end
    end

    applied = false(1, n);
    for i = 1:n
        if ~hasPlan(i)
            continue;
        end
        if collidesAny(plans(i).newPos, plans(i).blockH, cacheH, virtR)
            skipped(i) = true;
            failInfo{i} = sprintf('  模块%d: 垂直移动会与周围模块重叠（已跳过，未做任何修改）。', i);
            % 裁决失败：该模块回落原位置，后续检查将其视为不动
            idx = find(cacheH == plans(i).blockH, 1);
            if ~isempty(idx)
                virtR(idx, :) = cacheR(idx, :);
            end
        else
            applied(i) = true;
        end
    end

    % ===== 阶段3：应用移动并拉直连线 =====
    okCount = 0;
    for i = 1:n
        if ~applied(i)
            continue;
        end
        set_param(plans(i).blockH, 'Position', plans(i).newPos);
        idx = find(cacheH == plans(i).blockH, 1);
        if ~isempty(idx)
            cacheR(idx, :) = plans(i).newPos;
        end
        straightenBlockLines(plans(i).blockH);
        okCount = okCount + 1;
    end
    failCount = n - okCount;

    fprintf('连线端口对齐完成：对齐 %d 个模块，跳过 %d 个。\n', okCount, failCount);
    for i = 1:n
        if skipped(i) && ~isempty(failInfo{i})
            fprintf('%s\n', failInfo{i});
        end
    end

    % 3.1.0 性能优化：移除 update——本函数只改块 y 坐标并拉直线点，
    % 均为纯几何变化，Simulink 自动重排；编译刷新浪费（理由详见
    % slAlignBlocks 同名注释）
end

%% ========================================================================
%  计划生成（阶段1）
%% ========================================================================
function plan = makePlan(blockH, selLines)
%makePlan 计算单个选中模块的对齐计划（基于初始几何，不做任何修改）
    plan = struct('blockH', blockH, 'dy', 0, 'newPos', zeros(1, 4));

    % 收集该模块所有已连接的线
    ph = get_param(blockH, 'PortHandles');
    allPorts = [ph.Inport, ph.Outport, ph.Enable, ph.Trigger, ...
                ph.State, ph.Ifaction, ph.Reset];
    lineHs = [];
    for p = 1:numel(allPorts)
        if allPorts(p) ~= -1
            lh = get_param(allPorts(p), 'Line');
            if lh ~= -1
                lineHs(end+1) = lh; %#ok<AGROW>
            end
        end
    end
    lineHs = unique(lineHs);
    if isempty(lineHs)
        error('没有已连接的连线。');
    end

    % 对齐依据线：优先用户同时选中的线
    common = intersect(lineHs, selLines);
    if ~isempty(common)
        pickLine = common(1);
    else
        pickLine = lineHs(1);
    end

    % 确定本模块在对齐依据线的哪一端，并取两端 y
    sp = get_param(pickLine, 'SrcPortHandle');
    dp = get_param(pickLine, 'DstPortHandle');
    if isempty(dp) || dp(1) == -1
        error('对齐依据连线的端口不完整。');
    end
    isSrc = false;
    if sp ~= -1 && getSimulinkBlockHandle(get_param(sp, 'Parent')) == blockH
        isSrc = true;
    else
        found = false;
        for d = dp(:)
            if getSimulinkBlockHandle(get_param(d, 'Parent')) == blockH
                found = true;
                break;
            end
        end
        if ~found
            error('对齐依据连线与本模块不相连。');
        end
    end

    pts = get_param(pickLine, 'Points');
    if size(pts, 1) < 2
        error('对齐依据连线没有可用的路径点。');
    end
    if isSrc
        myY = pts(1, 2);
        otherY = pts(end, 2);
    else
        myY = pts(end, 2);
        otherY = pts(1, 2);
    end

    dy = otherY - myY;
    if abs(dy) < 0.5
        error('端口已对齐，无需移动。');
    end

    % 只调垂直位置：x 不变，y 平移 dy
    pos = get_param(blockH, 'Position');
    plan.dy = dy;
    plan.newPos = pos + [0, dy, 0, dy];
end

%% ========================================================================
%  连线拉直（阶段3）
%% ========================================================================
function straightenBlockLines(blockH)
%straightenBlockLines 拉直模块的所有连线
%   说明：模块移动后 Simulink 会自动把连线端点更新到新端口位置，
%   因此这里直接重读线点，把模块一侧的端点及中间点压平到近端当前高度，
%   远端保持不变；对对齐依据线（两端已同高）即成为纯水平直线
    ph = get_param(blockH, 'PortHandles');
    allPorts = [ph.Inport, ph.Outport, ph.Enable, ph.Trigger, ...
                ph.State, ph.Ifaction, ph.Reset];
    done = [];
    for p = 1:numel(allPorts)
        if allPorts(p) == -1
            continue;
        end
        lh = get_param(allPorts(p), 'Line');
        if lh == -1 || ~isempty(find(done == lh, 1))
            continue;
        end
        done(end+1) = lh; %#ok<AGROW>
        pts = get_param(lh, 'Points');
        m = size(pts, 1);
        if m < 2
            continue;
        end
        newPts = pts;
        if isBlockSrcOfLine(lh, blockH)
            newPts(1:m-1, 2) = pts(1, 2);
        else
            newPts(2:m, 2) = pts(m, 2);
        end
        % 3.1.0 性能优化：已平直的线跳过 Points 写入。Points 写入逐条产生
        % undo 记录，全选场景下几百条未变化的线可全部省掉
        if ~isequal(newPts, pts)
            try
                set_param(lh, 'Points', newPts);
            catch
            end
        end
    end
end

function tf = isBlockSrcOfLine(lh, blockH)
    tf = false;
    sp = get_param(lh, 'SrcPortHandle');
    if sp ~= -1 && getSimulinkBlockHandle(get_param(sp, 'Parent')) == blockH
        tf = true;
    end
end

%% ========================================================================
%  碰撞与缓存辅助
%% ========================================================================
function tf = collidesAny(rect, selfH, cacheH, cacheR)
%collidesAny 检查矩形是否与缓存中其他模块重叠
    tf = any(~ismember(cacheH(:), selfH) & ...
             ~(cacheR(:, 3) < rect(1) | cacheR(:, 1) > rect(3) | ...
               cacheR(:, 4) < rect(2) | cacheR(:, 2) > rect(4)));
end
