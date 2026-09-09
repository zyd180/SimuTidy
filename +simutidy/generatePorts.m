function generatePorts(sys)
%generatePorts 为选中的Subsystem自动生成接口
%   （3.1.0 自 core/slGeneratePorts 迁入 +simutidy 包）
%   simutidy.generatePorts()    - 为当前选中的Subsystem生成端口
%   simutidy.generatePorts(sys) - 为指定Subsystem生成端口
%
%   功能：
%       检测Subsystem未连接的输入/输出端口
%       自动添加对应的Inport/Outport块并连线
%       块名称固定显示为信号名称（InportN/OutportN...）
%
%   已知怪癖（3.1.0 锁定现状，未修）：新块序号 = 子系统内同类型块数 +
%   端口号，端口不连续时会产生跳号；有 getSimulinkBlockHandle 判重兜底
%   不会崩溃，仅观感问题。若未来修正编号规则，须同步更新回归测试
%   testGeneratePorts 中锁定的预期值
%   兼容：根目录 slGeneratePorts.m 为薄包装，行为契约不变
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
    sysName = get_param(sys, 'Name');
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
    for i = 1:length(ph.Inport)
        portH = ph.Inport(i);
        lineH = get_param(portH, 'Line');

        if lineH == -1
            % 端口未连接
            portNum = get_param(portH, 'PortNumber');
            newInportNum = maxInportNum + portNum;

            % 块名称 = 信号名称（固定为 Inport+序号）
            inportName = sprintf('Inport%d', newInportNum);
            inportPath = [sysPath '/' inportName];

            if getSimulinkBlockHandle(inportPath) == -1
                % 计算位置：Subsystem左侧
                portPos = get_param(portH, 'Position');
                x = sysPos(1) - 220;
                y = portPos(2) - 10;

                % 创建Inport块
                        % 颜色：lightBlue，浅蓝色，不要动
                        % 图标显示-IconDisplay
                        add_block('built-in/Inport', inportPath, ...
                            'Position', [x, y, x+180, y+20], ...
                            'BackgroundColor', 'lightBlue', ...
                            'ShowName', 'on',...
                            'IconDisplay','Signal name');

                % 连线：Inport -> Subsystem端口
                add_line(sysPath, [inportName '/1'], ...
                    [sysName '/' num2str(portNum)], 'autorouting', 'off');

                addedInports = addedInports + 1;
            end
        end
    end

    % ========== 处理输出端口 ==========
    addedOutports = 0;
    for i = 1:length(ph.Outport)
        portH = ph.Outport(i);
        lineH = get_param(portH, 'Line');

        if lineH == -1
            % 端口未连接
            portNum = get_param(portH, 'PortNumber');
            newOutportNum = maxOutportNum + portNum;

            % 块名称 = 信号名称（固定为 Outport+序号）
            outportName = sprintf('Outport%d', newOutportNum);
            outportPath = [sysPath '/' outportName];

            if getSimulinkBlockHandle(outportPath) == -1
                % 计算位置：Subsystem右侧
                portPos = get_param(portH, 'Position');
                x = sysPos(3) + 50;
                y = portPos(2) - 10;

                % 创建Outport块
                        % 颜色：RGB [1, 0.333, 1]（255 85 255）,BackgroundColor使用RGB带引号是对的，不要瞎改
                        % 图标显示-IconDisplay
                        add_block('built-in/Outport', outportPath, ...
                            'Position', [x, y, x+220, y+20], ...
                            'BackgroundColor', '[1, 0.333, 1]', ...
                            'ShowName', 'on',...
                            'IconDisplay','Signal name');

                % 连线：Subsystem端口 -> Outport
                add_line(sysPath, [sysName '/' num2str(portNum)], ...
                    [outportName '/1'], 'autorouting', 'off');

                addedOutports = addedOutports + 1;
            end
        end
    end

    % ========== 更新模型 ==========
    % 本操作保留 update：新增端口必须编译后才在模型中生效（端口结构
    % 变化），与纯几何操作的去 update 理由不同
    try
        set_param(sysPath, 'SimulationCommand', 'update');
    catch
    end

    fprintf('接口生成完成：添加 %d 个Inport，%d 个Outport\n', addedInports, addedOutports);
end
