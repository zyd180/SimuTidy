function slAutoNameSignals(sys, mode)
%slAutoNameSignals 信号线自动命名
%   slAutoNameSignals() - 按源模块名命名当前子系统的信号线
%   slAutoNameSignals(sys) - 指定子系统
%   slAutoNameSignals(sys, mode) - 指定命名模式
%
%   输入：
%       sys - 子系统路径或句柄（可选，默认当前子系统）
%       mode - 命名模式：
%           'source'      - 按源模块名命名（默认）
%           'source_port' - 按源模块名+端口号命名
%           'outport'     - 按输出端口命名
%           'clear'       - 清除所有信号线命名
%
%   功能：
%       根据指定模式自动为信号线命名

    if nargin < 1 || isempty(sys)
        sys = gcs;
    end
    
    if nargin < 2 || isempty(mode)
        mode = 'source';
    end
    
    if isempty(sys) || ~ishandle(get_param(sys, 'Handle'))
        error('无效的子系统句柄或路径。');
    end

    selectedObjs = find_system(sys, 'FindAll', 'on', 'Selected', 'on', 'Type', 'line');
    if isempty(selectedObjs)
        lineHandles = find_system(sys, 'FindAll', 'on', 'Type', 'line');
    else
        lineHandles = selectedObjs;
    end

    % 3.1.0 性能优化：cfg 调用提升到循环外。原实现在每条线的处理里都调
    % SimuTidy_config()（N 次重复构造配置结构），纯浪费
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

        srcBlockName = regexprep(srcBlockName, cfg.naming.replaceChars, cfg.naming.replaceWith);
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
                        newName = regexprep(newName, cfg.naming.replaceChars, cfg.naming.replaceWith);
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
        sltidy_iif(strcmp(mode,'clear'),'清除命名',sltidy_iif(strcmp(mode,'outport'),'按输出端口命名',sltidy_iif(strcmp(mode,'source_port'),'按源模块+端口命名','按源模块命名'))), ...
        namedCount);
end
