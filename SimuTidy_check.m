function msg = SimuTidy_check()
%SimuTidy_check 排查SimuTidy安装问题
%   msg = SimuTidy_check()
%   返回排查报告文本，并在命令窗口显示

    lines = {};
    lines{end+1} = '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
    lines{end+1} = '  SimuTidy 安排排查报告';
    lines{end+1} = '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
    lines{end+1} = '';

    % 检查SimuTidy主文件
    mainFile = which('SimuTidy');
    lines{end+1} = '【1】SimuTidy.m 位置：';
    if isempty(mainFile)
        lines{end+1} = '  未找到！';
    else
        lines{end+1} = ['  ' mainFile];
    end
    lines{end+1} = '';

    % 检查配置文件
    configFile = which('SimuTidy_config');
    lines{end+1} = '【2】SimuTidy_config.m 位置：';
    if isempty(configFile)
        lines{end+1} = '  未找到！';
    else
        lines{end+1} = ['  ' configFile];
    end
    lines{end+1} = '';

    % 检查sl_customization.m
    custFile = which('sl_customization');
    lines{end+1} = '【3】sl_customization.m 位置：';
    if isempty(custFile)
        lines{end+1} = '  未找到！';
    else
        lines{end+1} = ['  ' custFile];
        try
            fc = fileread(custFile);
            if contains(fc, 'SimuTidy')
                lines{end+1} = '  包含 SimuTidy 配置';
            else
                lines{end+1} = '  存在但可能不是 SimuTidy 生成的';
            end
        catch
            lines{end+1} = '  无法读取';
        end
    end
    lines{end+1} = '';

    % 检查路径上的sl_customization.m
    lines{end+1} = '【4】路径上所有 sl_customization.m：';
    pathDirs = strsplit(path, pathsep);
    foundCount = 0;
    for i = 1:length(pathDirs)
        d = pathDirs{i};
        if isfolder(d)
            f = fullfile(d, 'sl_customization.m');
            if isfile(f)
                foundCount = foundCount + 1;
                lines{end+1} = ['  ' f];
            end
        end
    end
    if foundCount == 0
        lines{end+1} = '  路径上没有任何 sl_customization.m';
    elseif foundCount > 1
        lines{end+1} = '';
        lines{end+1} = '  发现多个！Simulink 只加载第一个。';
        lines{end+1} = '     请把 SimuTidy 的文件夹移到路径最前面。';
    end
    lines{end+1} = '';

    % 检查子目录
    lines{end+1} = '【5】SimuTidy 子目录检查：';
    rootPath = fileparts(which('SimuTidy'));
    if ~isempty(rootPath)
        subdirs = {'gui', 'core', 'utils'};
        for i = 1:length(subdirs)
            d = fullfile(rootPath, subdirs{i});
            if isfolder(d)
                lines{end+1} = ['  ' subdirs{i} '/ 存在'];
            else
                lines{end+1} = ['  ' subdirs{i} '/ 不存在！'];
            end
        end
    end
    lines{end+1} = '';

    % 用户路径
    up = userpath;
    lines{end+1} = '【6】MATLAB 用户路径：';
    if isempty(up)
        lines{end+1} = '  未设置（运行 userpath 命令配置）';
    else
        lines{end+1} = ['  ' strtrim(up)];
    end
    lines{end+1} = '';

    % 解决方案
    lines{end+1} = '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
    lines{end+1} = '  如果菜单仍不显示：';
    lines{end+1} = '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
    lines{end+1} = '';
    lines{end+1} = '方案A：重新安装';
    lines{end+1} = '  >> SimuTidy_install';
    lines{end+1} = '  >> sl_refresh_customizations';
    lines{end+1} = '';
    lines{end+1} = '方案B：手动添加路径';
    lines{end+1} = '  >> addpath(''你的SimuTidy文件夹'', ''-begin'');';
    lines{end+1} = '  >> savepath;';
    lines{end+1} = '  >> sl_refresh_customizations;';
    lines{end+1} = '';
    lines{end+1} = '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';

    msg = strjoin(lines, '\n');
    disp(msg);
end
