function autoNameSignals(sys, mode)
%autoNameSignals 信号线自动命名（3.1.0 自 core/slAutoNameSignals 迁入 +simutidy 包）
%   simutidy.autoNameSignals() - 按源模块名命名当前子系统的信号线
%   simutidy.autoNameSignals(sys, mode) - 指定命名模式：
%       'source'      - 按源模块名命名（默认）
%       'source_port' - 按源模块名+端口号命名
%       'outport'     - 按输出端口命名
%       'clear'       - 清除所有信号线命名
%   兼容：根目录 slAutoNameSignals.m 为薄包装，行为契约不变

    sysPath = simutidy.internal.resolveSystem(sys);
    if nargin < 2 || isempty(mode)
        mode = 'source';
    end

    selectedObjs = find_system(sysPath, 'FindAll', 'on', 'Selected', 'on', 'Type', 'line');
    if isempty(selectedObjs)
        lineHandles = find_system(sysPath, 'FindAll', 'on', 'Type', 'line');
    else
        lineHandles = selectedObjs;
    end

    % 3.1.0 性能优化：cfg 调用提升到循环外（原实现每条线构造一次配置）
    cfg = SimuTidy_config();

    namedCount = 0;
    for i = 1:length(lineHandles)
        lineH = lineHandles(i);
        try
            currentName = get_param(lineH, 'Name');
        catch
            continue;
        end

        if strcmp(mode, 'clear')
            try
                set_param(lineH, 'Name', '');
                namedCount = namedCount + 1;
            catch
            end
            continue;
        end

        srcPortH = get_param(lineH, 'SrcPortHandle');
        if srcPortH == -1, continue; end

        srcBlockH = get_param(srcPortH, 'Parent');
        srcBlockName = get_param(srcBlockH, 'Name');

        % 3.1.0 收敛：名称清洗统一走 internal.sanitizeName（原 3 处重复
        % regexprep，规则只应有一处定义）
        srcBlockName = simutidy.internal.sanitizeName(srcBlockName);
        portNum = get_param(srcPortH, 'PortNumber');

        switch mode
            case 'source'
                newName = srcBlockName;
            case 'source_port'
                newName = sprintf('%s_out%d', srcBlockName, portNum);
            case 'outport'
                dstPortH = get_param(lineH, 'DstPortHandle');
                if ~isempty(dstPortH) && dstPortH(1) ~= -1
                    dstBlockH = get_param(dstPortH(1), 'Parent');
                    dstBlockType = get_param(dstBlockH, 'BlockType');
                    if strcmp(dstBlockType, 'Outport')
                        newName = get_param(dstBlockH, 'Name');
                        newName = simutidy.internal.sanitizeName(newName);
                    else
                        newName = srcBlockName;
                    end
                else
                    newName = srcBlockName;
                end
            otherwise
                newName = srcBlockName;
        end

        try
            set_param(lineH, 'Name', newName);
            namedCount = namedCount + 1;
        catch
        end
    end

    fprintf('%s 完成，共处理 %d 条信号线。\n', ...
        modeLabel(mode), namedCount);
end

function txt = modeLabel(mode)
% 本函数内的模式文案（3.1.0 迁移时保留原输出格式不变）
    switch mode
        case 'clear',       txt = '清除命名';
        case 'outport',     txt = '按输出端口命名';
        case 'source_port', txt = '按源模块+端口命名';
        otherwise,          txt = '按源模块命名';
    end
end
