function alignBlocks(sys, alignType)
%alignBlocks 模块批量对齐与分布（3.1.0 自 core/slAlignBlocks 迁入 +simutidy 包）
%   simutidy.alignBlocks() - 左对齐当前子系统选中的模块
%   simutidy.alignBlocks(sys) - 左对齐指定子系统选中的模块
%   simutidy.alignBlocks(sys, alignType) - 指定对齐方式
%
%   输入：
%       sys - 子系统路径或句柄（可选，默认当前子系统）
%       alignType - 对齐方式：
%           'left'/'right'/'top'/'bottom'/'hcenter'/'vcenter'/
%           'hspace'/'vspace'（默认 'left'）
%
%   功能：
%       对齐 6 模式（left/right/top/bottom/hcenter/vcenter）：
%           以"最上最左"的选中块为基准（其余 7 种提示文案均明确此规则），
%           调整其他块实现对齐；基准块位置不变。
%       等间距 2 模式（hspace/vspace，3.4.0 修正语义）：
%           锚点是"中心最小"和"中心最大"的两个块，其余块（含基准块）
%           按中心等差分布。修正前错误地跳过了基准块——基准在中间时
%           等距被破坏、基准是唯一中间块时整体空转（实测 4 块间距
%           250/185/215）；因此本模式不适用"基准不动"承诺，日志也
%           相应改报实际调整数（原虚报 n-1）。
%       作用范围（3.4.0 修正）：只处理当前层的选中块（SearchDepth=1）。
%           修正前不限层，父层与打开的子系统窗口的选中块被混入同一
%           坐标系一起计算，产生非预期大位移（与 highlightUnconnected
%           3.1.0 的限层修正同一理由）
%   兼容：根目录 slAlignBlocks.m 为薄包装，行为契约不变

    % nargin 守卫必须在把 sys 传入 resolveSystem **之前**：
    % 未传参时 sys 是"未定义变量"，直接作实参会在调用点抛
    % "输入参数的数目不足"，永远走不到 resolveSystem 内部的空值分支。
    % （3.1.0 迁移引入的回归：守卫曾随样板一起搬进 resolveSystem，
    % 导致 Tools 菜单/Toolstrip 的零参调用全部报错，已修复并补回归测试）
    if nargin < 1
        sys = gcs;
    end
    % 3.1.0 收敛：sys 校验样板统一走 internal.resolveSystem（原 8 处复制粘贴）
    sysPath = simutidy.internal.resolveSystem(sys);
    if nargin < 2 || isempty(alignType)
        alignType = 'left';
    end

    % 3.4.0 跨层修正：加 SearchDepth=1 只取当前层选中块。原不限层的
    % FindAll 会把打开的子系统里的选中块混进来——不同层坐标系不同，
    % 混算必然产生非预期移动（实测复现，详见文件头"作用范围"）
    selectedObjs = find_system(sysPath, 'FindAll', 'on', 'SearchDepth', 1, ...
        'Selected', 'on', 'Type', 'block');
    if length(selectedObjs) < 2
        error('SimuTidy:tooFewBlocks', '请至少选中 2 个模块。');
    end

    n = length(selectedObjs);
    % 3.1.0 性能优化：位置批量读取。原为逐块 get_param（N 次 API 调用），
    % 向量化后 1 次调用返回 cell；块数越多收益越大。
    % （3.3.0 起经 batchPositions 归一，顺带兼容"选中恰好 1 块"的输入形态；
    %  虽然 <2 已在上游报错，防御层收敛到一处）
    positions = simutidy.internal.batchPositions(selectedObjs);

    lefts   = positions(:, 1);
    tops    = positions(:, 2);
    rights  = positions(:, 3);
    bottoms = positions(:, 4);
    widths  = rights - lefts;
    heights = bottoms - tops;

    [~, sortIdx] = sortrows(positions, [2, 1]);
    baseIdx = sortIdx(1);
    basePos = positions(baseIdx, :);

    % 3.1.0 重构说明：各分支只负责"计算目标位置"写入 newPosMap（默认=原
    % 位置，即基准块天然不动），落盘统一走 switch 之后的写入循环——
    % 便于在唯一入口处做幂等优化（见下），避免 8 个分支各写一份。
    newPosMap = positions;
    switch alignType
        case 'left'
            for i = 1:n
                if i == baseIdx, continue; end
                newLeft = basePos(1);
                newPosMap(i, :) = [newLeft, tops(i), newLeft + widths(i), bottoms(i)];
            end
        case 'right'
            for i = 1:n
                if i == baseIdx, continue; end
                newRight = basePos(3);
                newLeft = newRight - widths(i);
                newPosMap(i, :) = [newLeft, tops(i), newRight, bottoms(i)];
            end
        case 'top'
            for i = 1:n
                if i == baseIdx, continue; end
                newTop = basePos(2);
                newPosMap(i, :) = [lefts(i), newTop, rights(i), newTop + heights(i)];
            end
        case 'bottom'
            for i = 1:n
                if i == baseIdx, continue; end
                newBottom = basePos(4);
                newTop = newBottom - heights(i);
                newPosMap(i, :) = [lefts(i), newTop, rights(i), newBottom];
            end
        case 'hcenter'
            baseCenterX = (basePos(1) + basePos(3)) / 2;
            for i = 1:n
                if i == baseIdx, continue; end
                newLeft = baseCenterX - widths(i) / 2;
                newRight = baseCenterX + widths(i) / 2;
                newPosMap(i, :) = [newLeft, tops(i), newRight, bottoms(i)];
            end
        case 'vcenter'
            baseCenterY = (basePos(2) + basePos(4)) / 2;
            for i = 1:n
                if i == baseIdx, continue; end
                newTop = baseCenterY - heights(i) / 2;
                newBottom = baseCenterY + heights(i) / 2;
                newPosMap(i, :) = [lefts(i), newTop, rights(i), newBottom];
            end
        case 'hspace'
            centersX = (lefts + rights) / 2;
            [sortedX, idx] = sort(centersX);
            minX = sortedX(1);
            maxX = sortedX(end);
            if n > 1
                step = (maxX - minX) / (n - 1);
                for i = 1:n
                    % 3.4.0 修正：删除原"if j == baseIdx, continue"跳过——
                    % 等间距的锚点是中心首尾两块，基准块作为中间块必须参与
                    % 分布，否则等距被破坏（实测复现，详见文件头）
                    j = idx(i);
                    target = minX + (i - 1) * step;
                    newPosMap(j, :) = [target - widths(j) / 2, tops(j), ...
                                       target + widths(j) / 2, bottoms(j)];
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
                    % 3.4.0 修正：同 hspace，基准块不再跳过
                    j = idx(i);
                    target = minY + (i - 1) * step;
                    newPosMap(j, :) = [lefts(j), target - heights(j) / 2, ...
                                       rights(j), target + heights(j) / 2];
                end
            end
        otherwise
            error('SimuTidy:unknownAlignType', '未知的对齐类型: %s', alignType);
    end

    % 3.1.0 性能优化：目标位置与现位置相同的块跳过写入（幂等，重复操作
    % 场景直接省掉）。带连线的块每次 set_param(Position) 都会触发 Simulink
    % 内部连线重排（实测 ~1.1ms/块），能省则省
    % 3.4.0：顺带统计实际调整数——等间距模式修正后基准块可能被移动，
    % 日志不再适用"基准未动"话术，统一改报真实调整数（原虚报 n-1）
    adjusted = 0;
    for i = 1:n
        if isequal(newPosMap(i, :), positions(i, :))
            continue;
        end
        set_param(selectedObjs(i), 'Position', newPosMap(i, :));
        adjusted = adjusted + 1;
    end

    % 3.3.0：汇总输出接入分级日志（原 fprintf，正文不变加 [INFO] 前缀）
    % 3.4.0 分两条话术并明示基准是谁（用户反馈：容易搞不清哪个是基准）：
    %   对齐 6 模式 → 基准=最上最左块，报出其名字且注明未动
    %   等间距 2 模式 → 锚点=中心最小/最大的两块，基准概念不适用
    if any(strcmp(alignType, {'hspace', 'vspace'}))
        simutidy.internal.log('info', '%s 完成：锚点为中心最小/最大的两个块，实际调整 %d 个模块。', ...
            getAlignText(alignType), adjusted);
    else
        simutidy.internal.log('info', '%s 完成，基准模块: %s（所选块中最上最左，位置未动），实际调整 %d 个模块。', ...
            getAlignText(alignType), get_param(selectedObjs(baseIdx), 'Name'), adjusted);
    end

    % 3.1.0 性能优化：移除操作后的 SimulationCommand update。
    % 原因：update 触发整模型编译（500 块实测 ~0.16s，大模型为秒级），而
    % 纯几何移动后 Simulink 会自动重排连线，编译刷新纯属浪费。
    % 需要 update 的只有属性校验类操作（信号对象解析、生成接口），各自保留；
    % cfg.simulink.updateAfterChange 开关的语义已在 SimuTidy_config 中更新。
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
