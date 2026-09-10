function res = checkGotoFrom(sys)
%checkGotoFrom 检查 Goto/From 标签配对问题（3.4.0 新增）
%   res = simutidy.checkGotoFrom()       - 检查当前子系统
%   res = simutidy.checkGotoFrom(sys)    - 指定子系统
%
%   检查项：
%       1. 悬空 Goto：当前层的 Goto 在**全模型范围**内找不到任何同 Tag 的 From
%       2. 无源 From：当前层的 From 在全模型范围内找不到任何同 Tag 的 Goto
%       3. 跨层 local 引用：From 引用的 Goto 在其他子系统且 Goto 的
%          TagVisibility 为 'local'——local Tag 只在本层可见，仿真会报错
%          （这是唯一需要跨层比对语义的检查项，故配对池取全模型）
%       发现项输出 res（含可定位句柄），GUI 结果面板逐条定位
%
%   已知取舍：不做编译校验（同 Tag 多 Goto 等复杂语义交给仿真诊断），
%   本检查只覆盖"配对缺失/跨层 local"两类确定性问题
%   兼容：根目录 slCheckGotoFrom.m 为薄包装

    % nargin 守卫须在 resolveSystem 之前（零参调用约定，见 alignBlocks 注释）
    if nargin < 1
        sys = gcs;
    end
    sysPath = simutidy.internal.resolveSystem(sys);
    mdl = bdroot(sysPath);

    % 当前层目标块 + 全模型配对池（一次查询，避免逐块回查）
    gotos = find_system(sysPath, 'FindAll', 'on', 'SearchDepth', 1, 'BlockType', 'Goto');
    froms = find_system(sysPath, 'FindAll', 'on', 'SearchDepth', 1, 'BlockType', 'From');
    allGoto = find_system(mdl, 'FindAll', 'on', 'BlockType', 'Goto');
    allFrom = find_system(mdl, 'FindAll', 'on', 'BlockType', 'From');

    gotoTags  = readTags(allGoto);    % struct 数组：tag / parent / visibility
    fromTags  = readTags(allFrom);

    findings = struct('handle', {}, 'reason', {}, 'index', {});

    % ---- 检查1：悬空 Goto（当前层，全模型无 From 引用）----
    for k = 1:numel(gotos)
        tg = get_param(gotos(k), 'GotoTag');
        if ~any(strcmp({fromTags.tag}, tg))
            findings(end+1) = struct('handle', gotos(k), ...
                'reason', sprintf('Goto "%s" 的标签 ''%s'' 没有任何 From 引用（标签悬空）', ...
                get_param(gotos(k), 'Name'), tg), ...
                'index', numel(findings) + 1); %#ok<AGROW>
        end
    end

    % ---- 检查2/3：无源 From、跨层 local 引用 ----
    for k = 1:numel(froms)
        tg = get_param(froms(k), 'GotoTag');
        hits = gotoTags(strcmp({gotoTags.tag}, tg));
        if isempty(hits)
            findings(end+1) = struct('handle', froms(k), ...
                'reason', sprintf('From "%s" 的标签 ''%s'' 找不到对应 Goto（无信号源）', ...
                get_param(froms(k), 'Name'), tg), ...
                'index', numel(findings) + 1); %#ok<AGROW>
        else
            % 跨层 local：配对 Goto 全部不在 From 所在层，且 visibility=local
            fromParent = get_param(froms(k), 'Parent');
            if all(~strcmp({hits.parent}, fromParent)) && ...
                    any(strcmp({hits.visibility}, 'local'))
                findings(end+1) = struct('handle', froms(k), ...
                    'reason', sprintf('From "%s" 跨层引用 local 标签 ''%s''（local 仅本层可见，仿真会报错）', ...
                    get_param(froms(k), 'Name'), tg), ...
                    'index', numel(findings) + 1); %#ok<AGROW>
            end
        end
    end

    n = numel(gotos) + numel(froms);
    okCount = n - numel(findings);  % 配对正常的 Goto/From 数（跨层 local 视为配对存在但有问题，计入问题侧）

    if isempty(findings)
        simutidy.internal.log('info', 'Goto/From 配对诊断完成：当前层 Goto %d 个、From %d 个，未发现问题。', ...
            numel(gotos), numel(froms));
    else
        simutidy.internal.log('warn', 'Goto/From 配对诊断完成：当前层 Goto %d 个、From %d 个，发现 %d 处问题。', ...
            numel(gotos), numel(froms), numel(findings));
    end

    res = struct('op', 'Goto/From 配对诊断', 'okLabel', '配对正常', 'failLabel', '问题', ...
        'okCount', okCount, 'failCount', numel(findings), 'failItems', findings);
end

%% ========================================================================
%  辅助
%% ========================================================================
function tags = readTags(handles)
%readTags 批量读 Goto/From 块的 Tag、所在层与可见性
%   visibility 仅 Goto 有（From 无此参数），对 From 统一填 '' 占位，
%   保证返回结构字段一致便于数组拼接
    n = numel(handles);
    tags = repmat(struct('tag', '', 'parent', '', 'visibility', ''), 1, n);
    for k = 1:n
        tags(k).tag = char(get_param(handles(k), 'GotoTag'));
        tags(k).parent = get_param(handles(k), 'Parent');
        if strcmp(get_param(handles(k), 'BlockType'), 'Goto')
            tags(k).visibility = get_param(handles(k), 'TagVisibility');
        end
    end
end
