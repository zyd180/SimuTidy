function splitGotoFrom(sys)
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

    selectedObjs = find_system(sysPath, 'FindAll', 'on', 'Selected', 'on', 'Type', 'line');
    if isempty(selectedObjs)
        error('SimuTidy:noSelection', '请先选中要拆分的信号线。');
    end

    % 模块位置缓存（推块后同步更新，用于碰撞检查）
    cacheH = find_system(sysPath, 'FindAll', 'on', 'SearchDepth', 1, 'Type', 'block');
    % 3.1.0 性能优化：位置批量读取，1 次 API 调用替代逐块 N 次
    cacheR = cell2mat(get_param(cacheH, 'Position'));

    cfg = SimuTidy_config();
    okCount = 0;
    failCount = 0;
    failInfo = cell(1, length(selectedObjs));

    for i = 1:length(selectedObjs)
        try
            [cacheH, cacheR] = splitOneLine(selectedObjs(i), cfg, cacheH, cacheR);
            okCount = okCount + 1;
        catch ME
            failCount = failCount + 1;
            failInfo{failCount} = sprintf('  连线%d: %s', i, ME.message);
        end
    end

    % 3.1.0 收敛：汇总输出统一走 internal.report
    simutidy.internal.report('Goto/From 批量拆分', okCount, failCount, failInfo(1:failCount));
end

%% ========================================================================
%  单条连线拆分
%% ========================================================================
function [cacheH, cacheR] = splitOneLine(lineH, cfg, cacheH, cacheR)
    srcPortH = get_param(lineH, 'SrcPortHandle');
    dstPortH = get_param(lineH, 'DstPortHandle');

    if srcPortH == -1
        error('SimuTidy:noSrcPort', '没有源端口。');
    end
    if isempty(dstPortH) || dstPortH(1) == -1
        error('SimuTidy:noDstPort', '没有目标端口。');
    end
    dstPortH = dstPortH(1);

    srcBlockH = getSimulinkBlockHandle(get_param(srcPortH, 'Parent'));
    dstBlockH = getSimulinkBlockHandle(get_param(dstPortH, 'Parent'));

    srcParent = get_param(srcBlockH, 'Parent');
    dstParent = get_param(dstBlockH, 'Parent');
    if ~strcmp(srcParent, dstParent)
        error('SimuTidy:crossLevelLine', '源模块和目标模块不在同一个子系统内。');
    end
    sysPath = srcParent;

    % 线起止点（用于垂直定位与方向判断）
    pts = get_param(lineH, 'Points');
    if size(pts, 1) < 2
        error('SimuTidy:noLinePoints', '连线没有可用的路径点。');
    end
    srcY = pts(1, 2);
    dstY = pts(end, 2);
    isHorizontal = abs(pts(end, 1) - pts(1, 1)) >= abs(dstY - srcY);

    % Goto/From 尺寸：高度取该端 Inport/Outport 块高度，宽度固定默认值
    gotoH = endBlockHeight(srcBlockH, dstBlockH, cfg);
    fromH = endBlockHeight(dstBlockH, srcBlockH, cfg);
    gotoW = cfg.goto.defaultWidth;
    fromW = cfg.goto.defaultWidth;

    gap = cfg.goto.gap;
    sep = cfg.goto.gap;

    % 标签名（源模块名清洗 + 随机序号，循环保证块名唯一）
    % 3.1.0 收敛：名称清洗统一走 internal.sanitizeName
    srcName = get_param(srcBlockH, 'Name');
    tagName = simutidy.internal.sanitizeName(srcName);
    tagName = [tagName '_' sprintf('%03d', randi(999))];

    gotoName = [sysPath '/Goto_' tagName];
    fromName = [sysPath '/From_' tagName];
    suffix = 1;
    while getSimulinkBlockHandle(gotoName) ~= -1
        gotoName = [sysPath '/Goto_' tagName '_' num2str(suffix)];
        suffix = suffix + 1;
    end
    suffix = 1;
    while getSimulinkBlockHandle(fromName) ~= -1
        fromName = [sysPath '/From_' tagName '_' num2str(suffix)];
        suffix = suffix + 1;
    end

    % 方向与所需走廊
    srcPos = get_param(srcBlockH, 'Position');
    dstPos = get_param(dstBlockH, 'Position');
    if pts(end, 1) >= pts(1, 1)
        moveDir = 1;
        need = gap + gotoW + sep + fromW + gap;
        avail = dstPos(1) - srcPos(3);
    else
        moveDir = -1;
        need = gap + gotoW + sep + fromW + gap;
        avail = srcPos(1) - dstPos(3);
    end

    placed = false;
    if isHorizontal && avail < need
        % 空间不足：尝试多档推开量与分配比例，全部通过碰撞检查才落位
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
                    fromPos = round([dp(1) - gap - fromW, dstY - fromH/2, dp(1) - gap, dstY + fromH/2]);
                else
                    gotoPos = round([sp(1) - gap - gotoW, srcY - gotoH/2, sp(1) - gap, srcY + gotoH/2]);
                    fromPos = round([dp(3) + gap, dstY - fromH/2, dp(3) + gap + fromW, dstY + fromH/2]);
                end
                % 3.1.0 收敛：碰撞检查统一走 internal.collidesAny
                if ~simutidy.internal.collidesAny(sp, [srcBlockH, dstBlockH], cacheH, cacheR) && ...
                   ~simutidy.internal.collidesAny(dp, [srcBlockH, dstBlockH], cacheH, cacheR) && ...
                   ~simutidy.internal.collidesAny(gotoPos, [srcBlockH, dstBlockH], cacheH, cacheR) && ...
                   ~simutidy.internal.collidesAny(fromPos, [srcBlockH, dstBlockH], cacheH, cacheR)
                    set_param(srcBlockH, 'Position', sp);
                    set_param(dstBlockH, 'Position', dp);
                    [cacheH, cacheR] = cacheUpdate(cacheH, cacheR, srcBlockH, sp);
                    [cacheH, cacheR] = cacheUpdate(cacheH, cacheR, dstBlockH, dp);
                    placed = true;
                    break;
                end
            end
            if placed, break; end
        end
        if ~placed
            error('SimuTidy:noRoomForGotoFrom', ...
                '周围空间不足，无法腾出 Goto/From 位置（已跳过，未做任何修改）。');
        end
    else
        if moveDir > 0
            gotoPos = round([srcPos(3) + gap, srcY - gotoH/2, srcPos(3) + gap + gotoW, srcY + gotoH/2]);
            fromPos = round([dstPos(1) - gap - fromW, dstY - fromH/2, dstPos(1) - gap, dstY + fromH/2]);
        else
            gotoPos = round([srcPos(1) - gap - gotoW, srcY - gotoH/2, srcPos(1) - gap, srcY + gotoH/2]);
            fromPos = round([dstPos(3) + gap, dstY - fromH/2, dstPos(3) + gap + fromW, dstY + fromH/2]);
        end
    end

    gh = add_block('built-in/Goto', gotoName, ...
        'GotoTag', tagName, ...
        'Position', gotoPos, ...
        'TagVisibility', cfg.goto.tagVisibility);

    fh = add_block('built-in/From', fromName, ...
        'GotoTag', tagName, ...
        'Position', fromPos);

    [cacheH, cacheR] = cacheAdd(cacheH, cacheR, gh, gotoPos);
    [cacheH, cacheR] = cacheAdd(cacheH, cacheR, fh, fromPos);

    delete_line(lineH);

    % 3.1.0 修复：改用端口句柄连接。原实现按"块名/端口号"拼路径，
    % 块名含 '/' 时（Simulink 允许）路径解析必然断线；句柄不受名称影响。
    % 顺带移除了对 gotoName/fromName 的名字依赖（块句柄 gh/fh 已在手）
    ghPort = get_param(gh, 'PortHandles');
    fhPort = get_param(fh, 'PortHandles');
    add_line(sysPath, srcPortH, ghPort.Inport, 'autorouting', 'on');
    add_line(sysPath, fhPort.Outport, dstPortH, 'autorouting', 'on');

    % 3.3.0：逐线明细接入分级日志（原 fprintf，保留逐线粒度）
    simutidy.internal.log('info', '  拆分完成，标签: %s（Goto: %s, From: %s）', tagName, ...
        get_param(gh, 'Name'), get_param(fh, 'Name'));
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
