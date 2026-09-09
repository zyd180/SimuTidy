function slUpdateBlockNames(sys)
%slUpdateBlockNames 更新Inport/Outport模块名称为信号名
%   slUpdateBlockNames() - 更新当前打开的模型
%   slUpdateBlockNames(sys) - 更新指定子系统/模型
%
%   功能：
%       只处理 Inport/Outport，其余模块不动
%       命名来源（按优先级）：
%           1. 信号线名：Inport取输出连线、Outport取输入连线的Name
%           2. 无信号名时沿信号链追源端名：
%              - Inport：查父层连入该端口的线名；再沿源端递归（子系统内部Outport块名等）
%              - Outport：沿输入线源端递归（源为子系统时取内部Outport块名）
%       同层 Inport/Outport 重名时自动追加序号
%       改名后显示模块名称：ShowName='on' + IconDisplay='Signal name'
%
%   注意：
%       仅修改模块显示名，不影响端口编号和连接关系

    if nargin < 1 || isempty(sys)
        sys = bdroot;
        if isempty(sys) || strcmp(sys, '')
            error('没有打开的 Simulink 模型。');
        end
    end

    if isempty(sys) || ~ishandle(get_param(sys, 'Handle'))
        error('无效的子系统句柄或路径。');
    end

    blocks = find_system(sys, 'FindAll', 'on', 'Type', 'block');

    inportCount = 0;
    outportCount = 0;

    for i = 1:length(blocks)
        blockH = blocks(i);
        switch get_param(blockH, 'BlockType')
            case 'Inport'
                newName = resolveInportName(blockH);
                if ~isempty(newName) && renameBlock(blockH, newName)
                    inportCount = inportCount + 1;
                end
            case 'Outport'
                newName = resolveOutportName(blockH);
                if ~isempty(newName) && renameBlock(blockH, newName)
                    outportCount = outportCount + 1;
                end
        end
    end

    fprintf('模块名称更新完成：Inport %d 个，Outport %d 个。\n', ...
        inportCount, outportCount);
end

%% ========================================================================
%  命名解析
%% ========================================================================
function name = resolveInportName(blockH)
%resolveInportName 解析Inport块的目标名称
%   优先内部输出线名，其次外层传入名（父层端口连线），再沿源端追名
    name = getLineName(blockH, 'out');
    if ~isempty(name), return; end

    parent = get_param(blockH, 'Parent');
    if isempty(parent) || strcmp(parent, bdroot), return; end

    portNum = str2double(get_param(blockH, 'Port'));
    ph = get_param(parent, 'PortHandles');
    if portNum > length(ph.Inport), return; end

    outerLine = get_param(ph.Inport(portNum), 'Line');
    if outerLine == -1, return; end
    name = get_param(outerLine, 'Name');
    if ~isempty(name), return; end

    name = traceSource(get_param(outerLine, 'SrcPortHandle'), 0);
end

function name = resolveOutportName(blockH)
%resolveOutportName 解析Outport块的目标名称
%   优先内部输入线名，其次沿输入线源端追名
    name = getLineName(blockH, 'in');
    if ~isempty(name), return; end

    ph = get_param(blockH, 'PortHandles');
    inLine = get_param(ph.Inport(1), 'Line');
    if inLine == -1, return; end

    name = traceSource(get_param(inLine, 'SrcPortHandle'), 0);
end

function name = traceSource(srcPortH, depth)
%traceSource 沿信号链向源端追溯信号名
%   逐层：线名 -> 子系统内部对应Outport块名 -> 递归其输入线源
%   depth防止跨层递归过深
    name = '';
    if depth > 30, return; end
    if srcPortH == -1, return; end

    lineH = get_param(srcPortH, 'Line');
    if lineH == -1, return; end
    name = get_param(lineH, 'Name');
    if ~isempty(name), return; end

    srcBlock = get_param(srcPortH, 'Parent');
    if strcmp(get_param(srcBlock, 'BlockType'), 'SubSystem')
        portNum = get_param(srcPortH, 'PortNumber');
        innerOut = find_system(srcBlock, 'SearchDepth', 1, 'BlockType', 'Outport');
        if portNum <= length(innerOut)
            innerName = char(get_param(innerOut{portNum}, 'Name'));
            if ~isDefaultName(innerName)
                name = innerName;
                return;
            end
            iph = get_param(innerOut{portNum}, 'PortHandles');
            inLine = get_param(iph.Inport(1), 'Line');
            if inLine ~= -1
                name = traceSource(get_param(inLine, 'SrcPortHandle'), depth + 1);
            end
        end
    else
        name = char(get_param(srcBlock, 'Name'));
    end
end

function tf = isDefaultName(nm)
%isDefaultName 判断是否为默认端口名（OutputN/InputN/InN等）
    tf = ~isempty(regexp(nm, '^(Output|Input|Inport|Outport|In|Out)[0-9]*$', 'once'));
end

%% ========================================================================
%  工具函数
%% ========================================================================
function name = getLineName(blockH, dir)
%getLineName 获取端口连接线上的信号名
%   dir: 'out' 取输出端口连线，'in' 取输入端口连线
    name = '';
    ph = get_param(blockH, 'PortHandles');
    if strcmp(dir, 'out')
        portH = ph.Outport;
    else
        portH = ph.Inport;
    end
    if isempty(portH) || portH(1) == -1, return; end
    lineH = get_param(portH(1), 'Line');
    if lineH == -1, return; end
    try
        name = get_param(lineH, 'Name');
    catch
        name = '';
    end
end

function ok = renameBlock(blockH, newName)
%renameBlock 安全重命名模块，保证同层Inport/Outport名称唯一
    ok = false;
    if isempty(newName), return; end
    cfg = SimuTidy_config();
    newName = regexprep(newName, cfg.naming.replaceChars, cfg.naming.replaceWith);
    if isempty(newName), return; end

    curName = get_param(blockH, 'Name');
    if strcmp(curName, newName), return; end

    blockType = get_param(blockH, 'BlockType');
    parentPath = get_param(blockH, 'Parent');
    candidate = newName;
    suffix = 1;
    while nameConflict(parentPath, candidate, blockType)
        candidate = [newName '_' num2str(suffix)];
        suffix = suffix + 1;
    end

    try
        set_param(blockH, 'Name', candidate);
        set_param(blockH, 'IconDisplay', 'Port number');
        set_param(blockH, 'ShowName', 'on');
        ok = true;
    catch
    end
end

function tf = nameConflict(parentPath, candidate, blockType)
%nameConflict 判断同层级Inport/Outport是否已使用该名称
    tf = false;
    h = getSimulinkBlockHandle([parentPath '/' candidate]);
    if h ~= -1
        try
            existingType = get_param(h, 'BlockType');
            tf = sameNameGroup(blockType, existingType);
        catch
            tf = true;
        end
    end
end

function tf = sameNameGroup(typeA, typeB)
%sameNameGroup Inport与Outport同属一个命名空间，同层互斥
    inout = {'Inport', 'Outport'};
    tf = ismember(typeA, inout) && ismember(typeB, inout);
end