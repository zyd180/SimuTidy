function res = splitGotoFrom(sys, varargin)
%splitGotoFrom 将选中的信号线批量拆分为 Goto/From 对
%   （3.1.0 自 core/slSplitGotoFrom 迁入 +simutidy 包）
%   simutidy.splitGotoFrom() - 拆分当前子系统选中的信号线（支持多选批量）
%   simutidy.splitGotoFrom(sys) - 指定子系统
%
%   功能（对每条选中的信号线）：
%       - Goto 放在源块右侧、From 放在目标块左侧，各留间距
%       - Goto/From 高度与该线所连 Inport/Outport 块高度一致（保持细条风格），
%         宽度用配置默认值；两端都不是 Inport/Outport 时用配置默认尺寸
%       - 空间不足时自动推开源块/目标块，推块前做碰撞检查，避免撞上周围模块；
%         实在放不下则跳过该线并提示，不动任何模块
%       - 3.4.1 分支支持：一条线分出多个目标时，Goto 只建 1 个（源端），
%         每个可行分支各建 1 个 From（同 GotoTag，Simulink 允许多 From）；
%         空间不足的分支保留原连线不动（部分拆分计入失败侧说明），
%         全部分支都放不下则整线跳过。核心依据：delete_line 按
%         （源端口, 目标端口）对只删单条分支（实验确认）
%       - 单条失败不影响其他连线，最后汇总报告
%   兼容：根目录 slSplitGotoFrom.m 为薄包装，行为契约不变
%
%   3.1.0 修复说明：add_line 改用端口句柄连接（原实现用块名拼路径，
%   块名含 '/' 时路径解析必然失败；端口句柄不受名称影响）

    % nargin 守卫必须在把 sys 传入 resolveSystem **之前**（原因见
    % simutidy/alignBlocks.m 入口注释：零参调用时 sys 未定义，
    % 作实参直接抛"输入参数的数目不足"）
    if nargin < 1
        sys = gcs;
    end
    sysPath = simutidy.internal.resolveSystem(sys);

    % 3.3.0 进度条：可选名值对 'Progress', <窗口句柄>——传有效窗口才弹
    % uiprogressdlg（含取消）；命令行不传则零弹窗（理由见 internal/progress）
    opt = simutidy.internal.parseOptions(varargin, {'Progress'});
    progParent = opt.progress;

    selectedObjs = find_system(sysPath, 'FindAll', 'on', 'Selected', 'on', 'Type', 'line');
    if isempty(selectedObjs)
        error('SimuTidy:noSelection', '请先选中要拆分的信号线。');
    end

    % 3.4.1 分支支持配套：按源端口分组并**合并同源全部分支目标**。
    % 分支线在 find_system 中会返回主/支多条 line 记录（同一物理线），
    % 且记录结构因模型而异——新模型常合并为"1 条主线带 N 个 dst"，
    % 老模型可能存为"同源的多条独立记录、每条 1 dst"（用户实测复现：
    % 只按单条记录拆分会漏掉其余分支，表现为"只有第一条被替换"）。
    % 因此逐组 union 全部 DstPortHandle 再逐分支处理；Points 取自
    % dst 最多的记录（主线，路径点最完整）。无源段（srcPort==-1，
    % 悬空线）不参与分组，避免把不同悬空线合并
    allSrc = arrayfun(@(h) get_param(h, 'SrcPortHandle'), selectedObjs);
    plan = cell(0, 2);  % 每行 = {lineH, dstList}（dstList 空=按线自带 dst）
    processedSrc = [];
    for k = 1:numel(selectedObjs)
        s = allSrc(k);
        if s == -1
            plan(end+1, :) = {selectedObjs(k), []}; %#ok<AGROW>
            continue;
        end
        if any(processedSrc == s)
            continue;
        end
        processedSrc(end+1) = s; %#ok<AGROW>
        group = selectedObjs(allSrc == s);
        dstList = [];
        for grec = group(:)'
            d = get_param(grec, 'DstPortHandle');
            dstList = [dstList, d(:).']; %#ok<AGROW>
        end
        dstList = unique(dstList, 'stable');
        ndst = arrayfun(@(h) numel(get_param(h, 'DstPortHandle')), group);
        [~, im] = max(ndst);
        plan(end+1, :) = {group(im), dstList}; %#ok<AGROW>
    end
    plan = reshape(plan, [], 2);

    % 模块位置缓存（推块后同步更新，用于碰撞检查）
    cacheH = find_system(sysPath, 'FindAll', 'on', 'SearchDepth', 1, 'Type', 'block');
    % 3.1.0 性能优化：位置批量读取（3.3.0 起经 batchPositions 兼容单块子系统）
    cacheR = simutidy.internal.batchPositions(cacheH);

    cfg = SimuTidy_config();
    okCount = 0;
    failCount = 0;
    failInfo = cell(1, length(selectedObjs));
    % 3.3.0 结果反馈：收集失败对象（句柄+原因），供 GUI 结果面板"定位"
    failItems = struct('handle', {}, 'reason', {}, 'index', {});

    dlg = simutidy.internal.progress('start', progParent, numel(plan(:, 1)), '拆分 Goto/From');
    for i = 1:size(plan, 1)
        % 3.4.1 进度条：步进 + 取消检查（取消后按已完成数量正常汇报）
        keep = simutidy.internal.progress('step', dlg, ...
            sprintf('拆分连线 %d/%d', i, size(plan, 1)));
        if ~keep
            simutidy.internal.log('warn', '已取消：完成 %d/%d 条。', ...
                okCount, size(plan, 1));
            break;
        end
        try
            % 3.4.1：skipMsg 非空 = 部分分支被跳过（拆分已部分完成）——
            % 计入 fail 侧并在面板/日志中说明，保留的分支不动
            [cacheH, cacheR, skipMsg] = splitOneLine(plan{i, 1}, plan{i, 2}, cfg, cacheH, cacheR);
            if isempty(skipMsg)
                okCount = okCount + 1;
            else
                failCount = failCount + 1;
                failInfo{failCount} = sprintf('  连线%d: %s', i, skipMsg);
                failItems(failCount) = struct('handle', plan{i, 1}, ...
                    'reason', skipMsg, 'index', i);
            end
        catch ME
            failCount = failCount + 1;
            failInfo{failCount} = sprintf('  连线%d: %s', i, ME.message);
            failItems(failCount) = struct('handle', selectedObjs(i), ...
                'reason', ME.message, 'index', i);
        end
    end
    simutidy.internal.progress('done', dlg);

    % 3.1.0 收敛：汇总输出统一走 internal.report
    simutidy.internal.report('Goto/From 批量拆分', okCount, failCount, failInfo(1:failCount));

    % 3.3.0 结果反馈：res 为可选输出（GUI 弹面板定位失败项；
    % 命令行不接输出则与旧版行为完全一致）
    res = struct('op', 'Goto/From 批量拆分', 'okCount', okCount, ...
        'failCount', failCount, 'failItems', failItems);
end

%% ========================================================================
%  单条连线拆分
%% ========================================================================
function [cacheH, cacheR, skipMsg] = splitOneLine(lineH, dstList, cfg, cacheH, cacheR)
    srcPortH = get_param(lineH, 'SrcPortHandle');
    % 3.4.1 分支支持：dstList 由调用方对同源全部记录 union 而来（见调用方
    % 分组注释）；传空则回退按线自带 dst（兼容无源段等单线调用）
    if isempty(dstList)
        dstPortH = get_param(lineH, 'DstPortHandle');
    else
        dstPortH = dstList;
    end

    if srcPortH == -1
        error('SimuTidy:noSrcPort', '没有源端口。');
    end
    if isempty(dstPortH) || dstPortH(1) == -1
        error('SimuTidy:noDstPort', '没有目标端口。');
    end
    % 3.4.1 分支支持：全量目标收集（原只取 dstPortH(1)，末尾 delete_line
    % 删整条线把其余分支一并带走——USER_GUIDE 已知限制的根源）
    nBranch = numel(dstPortH);

    srcBlockH = getSimulinkBlockHandle(get_param(srcPortH, 'Parent'));
    srcParent = get_param(srcBlockH, 'Parent');

    % 逐分支解析目标块；任一分支跨层即整线报错（与原单分支行为一致）
    dstBlockH = zeros(1, nBranch);
    for j = 1:nBranch
        dstBlockH(j) = getSimulinkBlockHandle(get_param(dstPortH(j), 'Parent'));
        if ~strcmp(get_param(dstBlockH(j), 'Parent'), srcParent)
            error('SimuTidy:crossLevelLine', '源模块和目标模块不在同一个子系统内。');
        end
    end
    sysPath = srcParent;

    % 线起止点（用于垂直定位与方向判断）
    % 3.4.1 分支注意：Points 只描述主线路径，各分支端点 y 改用目标端口
    % 坐标（见下方阶段1），不能再用 pts(end,2) 代表所有分支
    pts = get_param(lineH, 'Points');
    if size(pts, 1) < 2
        error('SimuTidy:noLinePoints', '连线没有可用的路径点。');
    end
    srcY = pts(1, 2);
    isHorizontal = abs(pts(end, 1) - pts(1, 1)) >= abs(pts(end, 2) - pts(1, 2));

    % Goto 尺寸：高度取该端 Inport/Outport 块高度，宽度固定默认值
    % 3.4.1：From 高度逐分支计算（见阶段1），不再共用一个 fromH
    gotoH = endBlockHeight(srcBlockH, dstBlockH(1), cfg);
    gotoW = cfg.goto.defaultWidth;
    fromW = cfg.goto.defaultWidth;  % From 宽度仍用全局默认（高度才逐分支）

    gap = cfg.goto.gap;
    sep = cfg.goto.gap;

    % 标签名（3.4.1 更新）：直接用清洗后的源信号名，撞已有 Tag 时追加
    % _1/_2 确定性序号。原方案无条件加 3 位随机数（源名_047），Tag 不可
    % 读（用户反馈）；随机数的初衷是防同名撞车——同层两个同名源的线
    % 拆分后 Tag 相同会导致 From 连错 Goto（编译报错），改为查重后缀
    % 同样不撞且可读。查重范围限当前层：Goto 的 TagVisibility 默认
    % 'local'（仅本层可见），本层不撞即可（global 场景罕见，不做全模型
    % 查重的代价是极端场景可能跨层撞——留给编译诊断兜底）
    tagNameBase = simutidy.internal.sanitizeName(get_param(srcBlockH, 'Name'));
    gotoBlocks = find_system(sysPath, 'FindAll', 'on', 'SearchDepth', 1, ...
        'BlockType', 'Goto');
    if isempty(gotoBlocks)
        existingTags = {};
    else
        existingTags = cellstr(get_param(gotoBlocks, 'GotoTag'));
    end
    tagName = tagNameBase;
    suffix = 1;
    while any(strcmp(existingTags, tagName))
        tagName = [tagNameBase '_' num2str(suffix)];
        suffix = suffix + 1;
    end

    gotoName = [sysPath '/Goto_' tagName];
    suffix = 1;
    while getSimulinkBlockHandle(gotoName) ~= -1
        gotoName = [sysPath '/Goto_' tagName '_' num2str(suffix)];
        suffix = suffix + 1;
    end

    % 方向与所需走廊（以第一分支的目标为走廊锚点，沿用原口径）
    srcPos = get_param(srcBlockH, 'Position');
    dstPos = get_param(dstBlockH(1), 'Position');
    if pts(end, 1) >= pts(1, 1)
        moveDir = 1;
    else
        moveDir = -1;
    end
    need = gap + gotoW + sep + fromW + gap;
    if moveDir > 0
        avail = dstPos(1) - srcPos(3);
    else
        avail = srcPos(1) - dstPos(3);
    end

    placed = false;
    if isHorizontal && avail < need
        % 空间不足：尝试多档推开量与分配比例，全部通过碰撞检查才落位
        % 3.4.1：走廊/推块只服务 Goto（源侧）与第一分支锚点；From 改为
        % 逐分支独立预算可行性（见阶段1），不再绑死在推块循环里
        Ds = need - avail + (0:4) * 2 * gap;
        for d = Ds
            if d == 0
                splits = [0.5, 0.5];
            else
                splits = [0.5, 0.5; 0, 1; 1, 0];
            end
            for s = 1:size(splits, 1)
                sShift = round(d * splits(s, 1));
                dShift = d - sShift;
                sp = srcPos;
                dp = dstPos;
                if moveDir > 0
                    sp = sp + [-sShift, 0, -sShift, 0];
                    dp = dp + [dShift, 0, dShift, 0];
                else
                    sp = sp + [sShift, 0, sShift, 0];
                    dp = dp + [-dShift, 0, -dShift, 0];
                end
                if moveDir > 0
                    gotoPos = round([sp(3) + gap, srcY - gotoH/2, sp(3) + gap + gotoW, srcY + gotoH/2]);
                else
                    gotoPos = round([sp(1) - gap - gotoW, srcY - gotoH/2, sp(1) - gap, srcY + gotoH/2]);
                end
                % 3.1.0 收敛：碰撞检查统一走 internal.collidesAny
                if ~simutidy.internal.collidesAny(sp, [srcBlockH, dstBlockH(1)], cacheH, cacheR) && ...
                   ~simutidy.internal.collidesAny(dp, [srcBlockH, dstBlockH(1)], cacheH, cacheR) && ...
                   ~simutidy.internal.collidesAny(gotoPos, [srcBlockH, dstBlockH(1)], cacheH, cacheR)
                    set_param(srcBlockH, 'Position', sp);
                    set_param(dstBlockH(1), 'Position', dp);
                    [cacheH, cacheR] = cacheUpdate(cacheH, cacheR, srcBlockH, sp);
                    [cacheH, cacheR] = cacheUpdate(cacheH, cacheR, dstBlockH(1), dp);
                    placed = true;
                    break;
                end
            end
            if placed, break; end
        end
        if ~placed
            error('SimuTidy:noRoomForGotoFrom', ...
                '周围空间不足，无法腾出 Goto 位置（已跳过，未做任何修改）。');
        end
    else
        if moveDir > 0
            gotoPos = round([srcPos(3) + gap, srcY - gotoH/2, srcPos(3) + gap + gotoW, srcY + gotoH/2]);
        else
            gotoPos = round([srcPos(1) - gap - gotoW, srcY - gotoH/2, srcPos(1) - gap, srcY + gotoH/2]);
        end
    end

    % ---- 阶段1（3.4.1）：逐分支预算 From 位置与可行性（不动模型）----
    % 分支端点 y 取目标端口坐标（分支线的 Points 只含主线路径）；碰撞
    % 排除本分支两端块（源+该目标）及已可行的其他 From（分支彼此相邻
    % 时 From 可能互相压叠）。不可行分支保留原线不动
    feasible = false(1, nBranch);
    fromPos = zeros(nBranch, 4);
    for j = 1:nBranch
        dstPosJ = get_param(dstBlockH(j), 'Position');
        portXY = get_param(dstPortH(j), 'Position');
        yJ = portXY(2);
        fromH = endBlockHeight(dstBlockH(j), srcBlockH, cfg);
        if moveDir > 0
            fromPos(j, :) = round([dstPosJ(1) - gap - fromW, yJ - fromH/2, ...
                                   dstPosJ(1) - gap, yJ + fromH/2]);
        else
            fromPos(j, :) = round([dstPosJ(3) + gap, yJ - fromH/2, ...
                                   dstPosJ(3) + gap + fromW, yJ + fromH/2]);
        end
        if simutidy.internal.collidesAny(fromPos(j, :), ...
                [srcBlockH, dstBlockH(j)], cacheH, cacheR)
            continue;
        end
        hitFrom = false;
        for k = find(feasible)
            a = fromPos(j, :); b = fromPos(k, :);
            if ~(a(3) < b(1) || a(1) > b(3) || a(4) < b(2) || a(2) > b(4))
                hitFrom = true;
                break;
            end
        end
        if ~hitFrom
            feasible(j) = true;
        end
    end

    % ---- 阶段2：落位（只动可行分支；不可行分支的原连线保留）----
    % 3.4.1 实验确认：delete_line(sysPath, 源端口句柄, 目标端口句柄)
    % 只删除该一条分支，其余分支原样保留——这是分支支持的核心依据
    if ~any(feasible)
        error('SimuTidy:noRoomForGotoFrom', ...
            '所有分支均无空间放置 From（已跳过，未做任何修改）。');
    end
    for j = find(feasible)
        delete_line(sysPath, srcPortH, dstPortH(j));
    end

    gh = add_block('built-in/Goto', gotoName, ...
        'GotoTag', tagName, ...
        'Position', gotoPos, ...
        'TagVisibility', cfg.goto.tagVisibility);
    [cacheH, cacheR] = cacheAdd(cacheH, cacheR, gh, gotoPos);

    % 源 → Goto（3.1.0 起用端口句柄连接，块名含 '/' 不断线）
    ghPort = get_param(gh, 'PortHandles');
    add_line(sysPath, srcPortH, ghPort.Inport, 'autorouting', 'on');

    % 每个可行分支一个 From（多 From 读同一 GotoTag 在 Simulink 中合法）
    for j = find(feasible)
        fromName = [sysPath '/From_' tagName];
        suffix = 1;
        while getSimulinkBlockHandle(fromName) ~= -1
            fromName = [sysPath '/From_' tagName '_' num2str(suffix)];
            suffix = suffix + 1;
        end
        fh = add_block('built-in/From', fromName, ...
            'GotoTag', tagName, ...
            'Position', fromPos(j, :));
        fhPort = get_param(fh, 'PortHandles');
        add_line(sysPath, fhPort.Outport, dstPortH(j), 'autorouting', 'on');
        [cacheH, cacheR] = cacheAdd(cacheH, cacheR, fh, fromPos(j, :));
    end

    % 3.3.0：逐线明细接入分级日志（3.4.1 增补分支粒度）
    skipMsg = '';
    if ~all(feasible)
        skipMsg = sprintf('%d 个分支空间不足，已保留原连线（实际拆分 %d/%d 分支）', ...
            nnz(~feasible), nnz(feasible), nBranch);
        simutidy.internal.log('warn', '  部分拆分，标签: %s（%s）', tagName, skipMsg);
    else
        simutidy.internal.log('info', '  拆分完成，标签: %s（Goto: %s，From ×%d）', ...
            tagName, get_param(gh, 'Name'), nBranch);
    end
end

%% ========================================================================
%  尺寸、碰撞与缓存辅助
%% ========================================================================
function h = endBlockHeight(blockH, otherH, cfg)
%endBlockHeight 取线端块高度：优先 Inport/Outport 块，其次另一端，最后默认
    if isInOutportBlock(blockH) || isInOutportBlock(otherH)
        if isInOutportBlock(blockH)
            p = get_param(blockH, 'Position');
        else
            p = get_param(otherH, 'Position');
        end
        h = p(4) - p(2);
    else
        h = cfg.goto.defaultHeight;
    end
end

function tf = isInOutportBlock(blockH)
    tf = any(strcmp(get_param(blockH, 'BlockType'), {'Inport', 'Outport'}));
end

function [cacheH, cacheR] = cacheUpdate(cacheH, cacheR, blockH, pos)
%cacheUpdate 推块后同步缓存位置
    idx = find(cacheH == blockH, 1);
    if ~isempty(idx)
        cacheR(idx, :) = pos;
    end
end

function [cacheH, cacheR] = cacheAdd(cacheH, cacheR, blockH, pos)
%cacheAdd 新建块加入缓存
    cacheH(end+1) = blockH; %#ok<AGROW>
    cacheR(end+1, :) = pos; %#ok<AGROW>
end
