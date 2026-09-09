function setSignalResolve(sys, mode)
%setSignalResolve 批量勾选/取消"信号名称必须解析为 Simulink 对象"
%   （3.1.0 自 core/slSetSignalResolve 迁入 +simutidy 包）
%   simutidy.setSignalResolve()              - 当前层级所有有名字的信号线勾选该属性
%   simutidy.setSignalResolve(sys, 'off')    - 取消勾选（mode: 'on' 默认 / 'off'）
%
%   功能：
%       - 作用范围为当前层级（SearchDepth=1），不影响子层级
%       - 只处理有名字的信号线；属性存储在该线**源端口**上
%         （Simulink 信号属性对话框编辑的即源端口参数 MustResolveToSignalObject）
%       - 无名字的线自动跳过（没有名字无从解析）
%       - 已处于目标状态的端口跳过（幂等，不重复计数）
%       - 选中线优先：若当前有选中的线，则只处理选中的线
%       - 勾选后 Simulink 更新图时将强制校验信号名必须指向基础工作区
%         对象（如 Simulink.Signal）；若名字无法解析，更新诊断会报错——
%         这正是该校验的目的
%   兼容：根目录 slSetSignalResolve.m 为薄包装，行为契约不变

    % nargin 守卫必须在把 sys 传入 resolveSystem **之前**（原因见
    % simutidy/alignBlocks.m 入口注释：零参调用时 sys 未定义，
    % 作实参直接抛"输入参数的数目不足"）
    if nargin < 1
        sys = gcs;
    end
    sysPath = simutidy.internal.resolveSystem(sys);
    if nargin < 2 || isempty(mode)
        mode = 'on';
    end
    if ~any(strcmp(mode, {'on', 'off'}))
        error('SimuTidy:invalidMode', 'mode 只能是 ''on'' 或 ''off''。');
    end

    % 选中线优先，未选则扫当前层全部线
    selLines = find_system(sysPath, 'FindAll', 'on', 'SearchDepth', 1, ...
                           'Selected', 'on', 'Type', 'line');
    if ~isempty(selLines)
        lineHandles = selLines;
    else
        lineHandles = find_system(sysPath, 'FindAll', 'on', 'SearchDepth', 1, 'Type', 'line');
    end

    setCount = 0;
    alreadyCount = 0;
    unnamedCount = 0;

    for i = 1:numel(lineHandles)
        lh = lineHandles(i);
        try
            name = get_param(lh, 'Name');
            if isempty(strtrim(char(name)))
                unnamedCount = unnamedCount + 1;
                continue;
            end
            srcPort = get_param(lh, 'SrcPortHandle');
            if srcPort == -1
                % 分支段没有源端口，属性在其根线的源端口上，跳过
                unnamedCount = unnamedCount + 1;
                continue;
            end
            if strcmpi(get_param(srcPort, 'MustResolveToSignalObject'), mode)
                alreadyCount = alreadyCount + 1;
                continue;
            end
            set_param(srcPort, 'MustResolveToSignalObject', mode);
            setCount = setCount + 1;
        catch
            unnamedCount = unnamedCount + 1;
        end
    end

    % 保留自定义汇总：本操作有三种计数（新设置/已是目标态/跳过），
    % 与 internal.report 的"成功/失败"二态模型不匹配，故不强行套用
    fprintf('信号对象解析设置完成（%s）：新设置 %d 个端口，已是目标态 %d 个，跳过 %d 条（未命名/分支段/无效）。\n', ...
            mode, setCount, alreadyCount, unnamedCount);

    % 本操作保留 update：勾选 MustResolveToSignalObject 后，update 编译
    % 才会触发"信号名必须能解析到工作区对象"的校验——这是该功能的验收
    % 语义，不是可省的刷新（与纯几何操作的去 update 理由不同）
    cfg = SimuTidy_config();
    if cfg.simulink.updateAfterChange
        try
            set_param(sysPath, 'SimulationCommand', 'update');
        catch
            % 名字无法解析时 update 诊断报错属预期校验行为，此处不中断
        end
    end
end
