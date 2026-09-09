function slSplitGotoFrom(sys)
%slSplitGotoFrom 将选中的信号线批量拆分为 Goto/From 对
%   slSplitGotoFrom() - 拆分当前子系统选中的信号线（支持多选批量）
%   slSplitGotoFrom(sys) - 指定子系统
%
%   功能（对每条选中的信号线）：
%       - Goto 放在源块右侧、From 放在目标块左侧，各留间距
%       - Goto/From 高度与该线所连 Inport/Outport 块高度一致（保持细条风格），
%         宽度用配置默认值；两端都不是 Inport/Outport 时用配置默认尺寸
%       - 空间不足时自动推开源块/目标块，推块前做碰撞检查，避免撞上周围模块；
%         实在放不下则跳过该线并提示，不动任何模块
%       - 单条失败不影响其他连线，最后汇总报告

    if nargin < 1 || isempty(sys)
        sys = gcs;
    end
    if isempty(sys) || ~ishandle(get_param(sys, 'Handle'))
        error('无效的子系统句柄或路径。');
    end

    selectedObjs = find_system(sys, 'FindAll', 'on', 'Selected', 'on', 'Type', 'line');
    if isempty(selectedObjs)
        error('请先选中要拆分的信号线。');
    end

    % 模块位置缓存（推块后同步更新，用于碰撞检查）
    cacheH = find_system(sys, 'FindAll', 'on', 'SearchDepth', 1, 'Type', 'block');
    cacheR = zeros(numel(cacheH), 4);
    for k = 1:numel(cacheH)
        cacheR(k, :) = get_param(cacheH(k), 'Position');
    end

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
    failInfo = failInfo(1:failCount);

    fprintf('Goto/From 批量拆分完成：成功 %d 条，失败 %d 条。\n', okCount, failCount);
    for i = 1:failCount
        fprintf('%s\n', failInfo{i});
    end
end

%% ========================================================================
%  单条连线拆分
%% ========================================================================
function [cacheH, cacheR] = splitOneLine(lineH, cfg, cacheH, cacheR)
    srcPortH = get_param(lineH, 'SrcPortHandle');
    dstPortH = get_param(lineH, 'DstPortHandle');

    if srcPortH == -1
        error('没有源端口。');
    end
    if isempty(dstPortH) || dstPortH(1) == -1
        error('没有目标端口。');
    end
    dstPortH = dstPortH(1);

    srcBlockH = getSimulinkBlockHandle(get_param(srcPortH, 'Parent'));
    dstBlockH = getSimulinkBlockHandle(get_param(dstPortH, 'Parent'));

    srcParent = get_param(srcBlockH, 'Parent');
    dstParent = get_param(dstBlockH, 'Parent');
    if ~strcmp(srcParent, dstParent)
        error('源模块和目标模块不在同一个子系统内。');
    end
    sysPath = srcParent;

    % 线起止点（用于垂直定位与方向判断）
    pts = get_param(lineH, 'Points');
    if size(pts, 1) < 2
        error('连线没有可用的路径点。');
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

    % 标签名（源模块名+随机序号，循环保证块名唯一）
    srcName = get_param(srcBlockH, 'Name');
    tagName = regexprep(srcName, cfg.naming.replaceChars, cfg.naming.replaceWith);
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
        dir = 1;
        need = gap + gotoW + sep + fromW + gap;
        avail = dstPos(1) - srcPos(3);
    else
        dir = -1;
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
                if dir > 0
                    sp = sp + [-sShift, 0, -sShift, 0];
                    dp = dp + [dShift, 0, dShift, 0];
                else
                    sp = sp + [sShift, 0, sShift, 0];
                    dp = dp + [-dShift, 0, -dShift, 0];
                end
                if dir > 0
                    gotoPos = round([sp(3) + gap, srcY - gotoH/2, sp(3) + gap + gotoW, srcY + gotoH/2]);
                    fromPos = round([dp(1) - gap - fromW, dstY - fromH/2, dp(1) - gap, dstY + fromH/2]);
                else
                    gotoPos = round([sp(1) - gap - gotoW, srcY - gotoH/2, sp(1) - gap, srcY + gotoH/2]);
                    fromPos = round([dp(3) + gap, dstY - fromH/2, dp(3) + gap + fromW, dstY + fromH/2]);
                end
                if ~collidesAny(sp, [srcBlockH, dstBlockH], cacheH, cacheR) && ...
                   ~collidesAny(dp, [srcBlockH, dstBlockH], cacheH, cacheR) && ...
                   ~collidesAny(gotoPos, [srcBlockH, dstBlockH], cacheH, cacheR) && ...
                   ~collidesAny(fromPos, [srcBlockH, dstBlockH], cacheH, cacheR)
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
            error('周围空间不足，无法腾出 Goto/From 位置（已跳过，未做任何修改）。');
        end
    else
        if dir > 0
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

    ghPort = get_param(gh, 'PortHandles');
    fhPort = get_param(fh, 'PortHandles');
    add_line(sysPath, srcPortH, ghPort.Inport, 'autorouting', 'on');
    add_line(sysPath, fhPort.Outport, dstPortH, 'autorouting', 'on');

    fprintf('  拆分完成，标签: %s（Goto: %s, From: %s）\n', tagName, ...
        get_param(gotoName, 'Name'), get_param(fromName, 'Name'));
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

function tf = collidesAny(rect, selfH, cacheH, cacheR)
%collidesAny 检查矩形是否与缓存中其他模块重叠
    tf = any(~ismember(cacheH(:), selfH) & ...
             ~(cacheR(:, 3) < rect(1) | cacheR(:, 1) > rect(3) | ...
               cacheR(:, 4) < rect(2) | cacheR(:, 2) > rect(4)));
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
    cacheH(end+1) = blockH;
    cacheR(end+1, :) = pos;
end
