function generatePorts(sys)
%generatePorts 为选中的Subsystem自动生成接口
%   （3.1.0 自 core/slGeneratePorts 迁入 +simutidy 包）
%   simutidy.generatePorts()    - 为当前选中的Subsystem生成端口
%   simutidy.generatePorts(sys) - 为指定Subsystem生成端口
%
%   功能：
%       检测Subsystem未连接的输入/输出端口
%       自动添加对应的Inport/Outport块并连线
%
%   命名规则（3.4.0 更新，原为固定 InportN/OutportN 序号命名）：
%       新块名优先取子系统**内部对应端口块**（按端口号匹配）的名称，
%       使父层接口名与内部语义一致（内部叫 Vin，父层生成块也叫 Vin）：
%       - 内部名经 internal.sanitizeName 清洗非法字符
%       - 父层重名时追加 _1/_2 序号（与 updateBlockNames.renameBlock 同策略）
%       - 内部块缺失/清洗后为空 → 回落旧规则 InportN/OutportN 兜底
%         （N = 子系统内同类型块数 + 端口号，沿用 3.1.0 口径）
%       变更原因：用户需求——生成接口的块名应可读、与内部接口对应，
%       原序号命名（Inport2/Outport2）与内部名称脱节且端口不连续时跳号
%   显示约定（3.4.0，用户需求"默认显示模块名称"）：ShowName='on' +
%   IconDisplay='Port number'，与 updateBlockNames 改名后的显示约定一致，
%   模块名始终可见（原 'Signal name' 图标模式在信号线未命名时图标空白）
%   兼容：根目录 slGeneratePorts.m 为薄包装，对外签名与调用方式不变
%
%   颜色配置（Simulink仅支持预定义颜色名，用户可自行修改下方值）：
%       Inport:  'lightBlue'
%       Outport: '[1, 0.333, 1]'

    % ========== 参数处理 ==========
    if nargin < 1 || isempty(sys)
        sel = gcb;
        if isempty(sel)
            error('SimuTidy:noSelection', '请先选中一个Subsystem模块。');
        end
        sys = getfullname(sel);
    end

    % ========== 验证Subsystem ==========
    blockType = get_param(sys, 'BlockType');
    if ~strcmp(blockType, 'SubSystem')
        error('SimuTidy:notSubsystem', '选中的模块不是Subsystem。');
    end

    sysPath = get_param(sys, 'Parent');
    % 3.4.0：sysName 已无消费方（连线由路径拼接改为端口句柄，见下），删除
    sysPos = get_param(sys, 'Position');

    % ========== 获取端口信息 ==========
    ph = get_param(sys, 'PortHandles');

    % 计算已有端口块数量，用于命名
    existingInports = find_system(sys, 'SearchDepth', 1, 'BlockType', 'Inport');
    existingOutports = find_system(sys, 'SearchDepth', 1, 'BlockType', 'Outport');
    maxInportNum = length(existingInports);
    maxOutportNum = length(existingOutports);

    % ========== 处理输入端口 ==========
    addedInports = 0;
    inNames = {};  % 3.4.0：收集新块名，供汇总日志追溯命名结果
    for i = 1:length(ph.Inport)
        portH = ph.Inport(i);
        lineH = get_param(portH, 'Line');

        if lineH == -1
            % 端口未连接
            portNum = get_param(portH, 'PortNumber');

            % 3.4.0 命名规则更新：优先用子系统内部对应端口块的名称
            % （见 innerPortName），缺失/为空回落旧 InportN 序号；
            % uniqueName 负责父层重名加后缀，返回的名字此刻必然空闲，
            % 故删除原 getSimulinkBlockHandle 判重守卫（该守卫在旧规则下
            % 用于撞名时静默跳过，新规则下撞名由后缀解决，不应再跳过）
            inportName = uniqueName(sysPath, ...
                innerPortName(existingInports, portNum), ...
                sprintf('Inport%d', maxInportNum + portNum));
            inportPath = [sysPath '/' inportName];

            % 计算位置：Subsystem左侧
            portPos = get_param(portH, 'Position');
            x = sysPos(1) - 220;
            y = portPos(2) - 10;

            % 创建Inport块（3.4.0：接住句柄，供下方按端口句柄连线）
                    % 颜色：lightBlue，浅蓝色，不要动
                    % 3.4.0 图标显示改为 Port number（用户需求：默认显示模块
                    % 名称）——原 'Signal name' 模式下图标优先渲染连线信号名，
                    % 信号线未命名时图标空白，模块名反而弱化；改 Port number
                    % 后与 updateBlockNames 的显示约定一致（ShowName on +
                    % 图标显示端口号），模块名始终可见
                    newBlock = add_block('built-in/Inport', inportPath, ...
                        'Position', [x, y, x+180, y+20], ...
                        'BackgroundColor', 'lightBlue', ...
                        'ShowName', 'on',...
                        'IconDisplay','Port number');

            % 3.4.0 连线改用端口句柄：原按"[块名/1]"拼路径，块名含 '/'
            % （Simulink 允许）时路径解析必然断线（同 splitGotoFrom 3.1.0
            % 的修复原因），句柄不受名称影响；且新名可能带后缀，句柄免拼名
            add_line(sysPath, get_param(newBlock, 'PortHandles').Outport(1), ...
                portH, 'autorouting', 'off');

            addedInports = addedInports + 1;
            inNames{end+1} = inportName; %#ok<AGROW> % 3.4.0：记录新块名，供汇总日志追溯
        end
    end

    % ========== 处理输出端口 ==========
    addedOutports = 0;
    outNames = {};  % 3.4.0：收集新块名，供汇总日志追溯命名结果
    for i = 1:length(ph.Outport)
        portH = ph.Outport(i);
        lineH = get_param(portH, 'Line');

        if lineH == -1
            % 端口未连接
            portNum = get_param(portH, 'PortNumber');

            % 3.4.0 命名规则更新：同输入端口（内部 Outport 名优先，回落旧序号）
            outportName = uniqueName(sysPath, ...
                innerPortName(existingOutports, portNum), ...
                sprintf('Outport%d', maxOutportNum + portNum));
            outportPath = [sysPath '/' outportName];

            % 计算位置：Subsystem右侧
            portPos = get_param(portH, 'Position');
            x = sysPos(3) + 50;
            y = portPos(2) - 10;

            % 创建Outport块（3.4.0：接住句柄，供下方按端口句柄连线）
                    % 颜色：RGB [1, 0.333, 1]（255 85 255）,BackgroundColor使用RGB带引号是对的，不要瞎改
                    % 3.4.0 图标显示改为 Port number（理由同上方 Inport）
                    newBlock = add_block('built-in/Outport', outportPath, ...
                        'Position', [x, y, x+220, y+20], ...
                        'BackgroundColor', '[1, 0.333, 1]', ...
                        'ShowName', 'on',...
                        'IconDisplay','Port number');

            % 3.4.0 连线改用端口句柄（理由同输入端口：免拼名、块名含 '/' 不断线）
            add_line(sysPath, portH, ...
                get_param(newBlock, 'PortHandles').Inport(1), 'autorouting', 'off');

            addedOutports = addedOutports + 1;
            outNames{end+1} = outportName; %#ok<AGROW> % 3.4.0：记录新块名，供汇总日志追溯
        end
    end

    % ========== 更新模型 ==========
    % 3.4.0 变更：update 改受 cfg.simulink.updateAfterChange 开关门控
    % （与 setSignalResolve 同款写法，用户选定方案 1）。
    % 缘由：该 update 触发整模型编译（大模型秒级），但只是"让新端口立即
    % 在图上刷新"，不是正确性必需——新块与连线已落盘，下次编译自然生效。
    % 默认仍开启（行为不变），想提速的用户在设置界面关闭即可
    cfg = SimuTidy_config();
    if cfg.simulink.updateAfterChange
        try
            set_param(sysPath, 'SimulationCommand', 'update');
        catch
        end
    end

    % 3.3.0：汇总输出接入分级日志
    % 3.4.0：日志追加本次生成的块名清单（命名规则改了，名字是关键结果，
    % 打出来便于核对内部名匹配/后缀/回落是否按预期工作）
    if isempty(inNames) && isempty(outNames)
        simutidy.internal.log('info', '接口生成完成：无未连接端口，未添加任何模块。');
    else
        simutidy.internal.log('info', '接口生成完成：添加 %d 个Inport（%s），%d 个Outport（%s）', ...
            addedInports, strjoin(inNames, ', '), addedOutports, strjoin(outNames, ', '));
    end
end

%% ========================================================================
%  命名辅助（3.4.0 新增，服务"内部接口名优先"规则）
%% ========================================================================
function name = innerPortName(portBlocks, portNum)
%innerPortName 取子系统内部对应端口块的名称
%   portBlocks - SearchDepth=1 查到的内部 Inport/Outport 块路径 cell
%                （即调用方已缓存的 existingInports/existingOutports，不重复查询；
%                3.4.0 复查：无需 sys 参数，portBlocks 路径已含子系统信息）
%   匹配方式：按 Port 参数精确等于 portNum——cell 顺序不保证等于端口序，
%   不能按位置取。块名经 internal.sanitizeName 清洗（与 autoNameSignals 等
%   消费方同一规则源）
%   找不到对应块或清洗后为空 → 返回 ''，由调用方回落旧序号命名兜底
    name = '';
    for k = 1:numel(portBlocks)
        if str2double(get_param(portBlocks{k}, 'Port')) == portNum
            name = simutidy.internal.sanitizeName(get_param(portBlocks{k}, 'Name'));
            return;
        end
    end
end

function name = uniqueName(sysPath, preferred, fallback)
%uniqueName 解析出一个父层未占用的块名
%   优先用 preferred（内部接口名）；preferred 为空时用 fallback（旧
%   InportN/OutportN 规则）；名字被父层既有块占用时追加 _1/_2/...
%   （与 updateBlockNames.renameBlock 同策略）。返回的名字此刻必然空闲，
%   调用方可直接 add_block（取代旧版"撞名即静默跳过"的守卫语义）
    if isempty(preferred)
        preferred = fallback;
    end
    name = preferred;
    suffix = 1;
    while getSimulinkBlockHandle([sysPath '/' name]) ~= -1
        name = [preferred '_' num2str(suffix)];
        suffix = suffix + 1;
    end
end
