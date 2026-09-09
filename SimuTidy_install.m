function SimuTidy_install()
%SimuTidy_install 安装SimuTidy到Simulink工具栏（永久集成版）
%   SimuTidy_install() - 将SimuTidy永久添加到MATLAB/Simulink

    % 显示版本信息
    cfg = SimuTidy_config();
    fprintf('SimuTidy 安装程序 v%s\n', cfg.version);
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n');

    % 获取SimuTidy根目录
    rootPath = fileparts(mfilename('fullpath'));
    if isempty(rootPath)
        rootPath = pwd;
    end

    % ========== 步骤1：添加到永久路径 ==========
    fprintf('[1/5] 添加路径...\n');
    
    % 3.1.0 命名空间化：核心实体在 +simutidy 包内（随根目录生效），
    % 不再有 core 子目录；gui/utils 仍需单独加入
    pathsToAdd = {
        rootPath
        fullfile(rootPath, 'gui')
        fullfile(rootPath, 'utils')
    };
    
    for i = 1:length(pathsToAdd)
        p = pathsToAdd{i};
        if ~contains(path, p)
            addpath(p);
        end
    end
    
    try
        savepath;
        fprintf('      路径已保存\n');
    catch ME
        warning('savepath 失败: %s\n', ME.message);
    end

    % ========== 步骤2：生成 sl_customization.m ==========
    fprintf('[2/5] 生成 sl_customization.m...\n');
    
    userPath = userpath;
    if isempty(userPath)
        userPath = fullfile(getenv('USERPROFILE'), 'Documents', 'MATLAB');
    end
    userPath = strtrim(userPath);
    if ~isfolder(userPath)
        mkdir(userPath);
    end

    custFile = fullfile(userPath, 'sl_customization.m');
    
    if isfile(custFile)
        backupFile = fullfile(userPath, ['sl_customization.m.bak.' datestr(now, 'yyyymmddHHMMSS')]);
        copyfile(custFile, backupFile);
        fprintf('      已备份原文件\n');
    end
    
    % 直接写入文件，避免字符串拼接过长
    writeCustomizationFile(custFile, cfg);
    fprintf('      已创建: %s\n', custFile);

    % ========== 步骤3：添加到 startup.m ==========
    fprintf('[3/5] 配置启动项...\n');
    
    startupFile = fullfile(userPath, 'startup.m');
    startupCmd = sprintf('addpath(''%s'', ''%s'', ''%s''); SimuTidy_version;', ...
        rootPath, fullfile(rootPath, 'gui'), fullfile(rootPath, 'utils'));
    
    if isfile(startupFile)
        content = fileread(startupFile);
        if ~contains(content, 'SimuTidy')
            fid = fopen(startupFile, 'a');
            if fid ~= -1
                fprintf(fid, '\n%% SimuTidy - Simulink 建模辅助工具\n');
                fprintf(fid, '%s\n', startupCmd);
                fclose(fid);
                fprintf('      已添加到 startup.m\n');
            end
        else
            fprintf('      startup.m 已包含 SimuTidy\n');
        end
    else
        fid = fopen(startupFile, 'w');
        if fid ~= -1
            fprintf(fid, '%% MATLAB 启动脚本\n');
            fprintf(fid, '%s\n', startupCmd);
            fclose(fid);
            fprintf('      已创建 startup.m\n');
        end
    end

    % ========== 步骤4：刷新 Simulink 菜单 ==========
    fprintf('[4/5] 刷新 Simulink 菜单...\n');

    try
        sl_refresh_customizations;
        fprintf('      菜单已刷新\n');
    catch
        fprintf('      请手动运行: sl_refresh_customizations\n');
    end

    % ========== 步骤5：注册 Simulink Toolstrip 选项卡 ==========
    fprintf('[5/5] 注册 Toolstrip 选项卡...\n');
    if exist('slReloadToolstripConfig', 'file')
        try
            slReloadToolstripConfig;
            fprintf('      已注册（打开模型后在 格式 与 APP 之间可见 SimuTidy 选项卡）\n');
        catch
            fprintf('      注册未完成，重开 Simulink 模型后自动生效\n');
        end
    else
        fprintf('      当前 MATLAB 版本不支持 Toolstrip 定制，仅保留 Tools 菜单方式\n');
    end

    % ========== 完成 ==========
    fprintf('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    fprintf('  安装完成！\n');
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n');
    fprintf('  使用方法：\n');
    fprintf('    打开 Simulink -> Tools -> SimuTidy\n\n');
    fprintf('  版本: %s\n', cfg.version);
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
end

%% ========================================================================
%  直接写入 sl_customization.m 文件
%% ========================================================================
function writeCustomizationFile(custFile, cfg)
    fid = fopen(custFile, 'w');
    if fid == -1
        error('无法创建文件: %s', custFile);
    end
    
    % 写入头部
    fprintf(fid, 'function sl_customization(cm)\n');
    fprintf(fid, '%% sl_customization - SimuTidy Simulink 菜单集成\n');
    fprintf(fid, '%% 版本: %s\n\n', cfg.version);
    fprintf(fid, '    cm.addCustomMenuFcn(''Simulink:ToolsMenu'', @getSimuTidyItems);\n');
    fprintf(fid, 'end\n\n');
    
    % 菜单列表
    fprintf(fid, 'function schemas = getSimuTidyItems(~)\n');
    fprintf(fid, '    schemas = {\n');
    fprintf(fid, '        @getOpenGUI\n');
    fprintf(fid, '        @getExportItem\n');
    fprintf(fid, '        @getStraightenItem\n');
    fprintf(fid, '        @getAlignItem\n');
    fprintf(fid, '        @getSizeItem\n');
    fprintf(fid, '        @getNameItem\n');
    fprintf(fid, '        @getSplitItem\n');
    fprintf(fid, '        @getHighlightItem\n');
    fprintf(fid, '        @getGeneratePortsItem\n');
    fprintf(fid, '        @getUpdateBlockNamesItem\n');
    fprintf(fid, '    };\n');
    fprintf(fid, 'end\n\n');
    
    % 打开GUI
    fprintf(fid, 'function schema = getOpenGUI(~)\n');
    fprintf(fid, '    schema = sl_action_schema;\n');
    fprintf(fid, '    schema.tag = ''SimuTidyOpenGUI'';\n');
    fprintf(fid, '    schema.label = ''SimuTidy 打开工具窗口'';\n');
    fprintf(fid, '    schema.callback = @(~) SimuTidy();\n');
    fprintf(fid, 'end\n\n');
    
    % 导出Web视图
    fprintf(fid, 'function schema = getExportItem(~)\n');
    fprintf(fid, '    schema = sl_action_schema;\n');
    fprintf(fid, '    schema.tag = ''SimuTidyExport'';\n');
    fprintf(fid, '    schema.label = ''导出 Web 视图 (ZIP)'';\n');
    fprintf(fid, '    schema.callback = @(~) slExportWebView();\n');
    fprintf(fid, 'end\n\n');
    
    % 连线端口对齐
    fprintf(fid, 'function schema = getStraightenItem(~)\n');
    fprintf(fid, '    schema = sl_action_schema;\n');
    fprintf(fid, '    schema.tag = ''SimuTidyAlignLinePorts'';\n');
    fprintf(fid, '    schema.label = ''连线端口对齐'';\n');
    fprintf(fid, '    schema.callback = @(~) slAlignLinePorts();\n');
    fprintf(fid, 'end\n\n');
    
    % 模块对齐
    fprintf(fid, 'function schema = getAlignItem(~)\n');
    fprintf(fid, '    schema = sl_container_schema;\n');
    fprintf(fid, '    schema.tag = ''SimuTidyAlign'';\n');
    fprintf(fid, '    schema.label = ''模块对齐'';\n');
    fprintf(fid, '    schema.childrenFcns = {\n');
    fprintf(fid, '        @getAlignLeft\n');
    fprintf(fid, '        @getAlignRight\n');
    fprintf(fid, '        @getAlignTop\n');
    fprintf(fid, '        @getAlignBottom\n');
    fprintf(fid, '        @getAlignHCenter\n');
    fprintf(fid, '        @getAlignVCenter\n');
    fprintf(fid, '        @getAlignHSpace\n');
    fprintf(fid, '        @getAlignVSpace\n');
    fprintf(fid, '    };\n');
    fprintf(fid, 'end\n\n');
    
    % 对齐子项
    alignItems = {'Left', 'left', '左对齐'; ...
                  'Right', 'right', '右对齐'; ...
                  'Top', 'top', '顶部对齐'; ...
                  'Bottom', 'bottom', '底部对齐'; ...
                  'HCenter', 'hcenter', '水平居中'; ...
                  'VCenter', 'vcenter', '垂直居中'; ...
                  'HSpace', 'hspace', '水平等间距'; ...
                  'VSpace', 'vspace', '垂直等间距'};
    
    for i = 1:size(alignItems, 1)
        name = alignItems{i, 1};
        type = alignItems{i, 2};
        label = alignItems{i, 3};
        fprintf(fid, 'function schema = getAlign%s(~)\n', name);
        fprintf(fid, '    schema = sl_action_schema;\n');
        fprintf(fid, '    schema.label = ''%s'';\n', label);
        fprintf(fid, '    schema.callback = @(~) slAlignBlocks([], ''%s'');\n', type);
        fprintf(fid, 'end\n\n');
    end
    
    % 大小统一
    fprintf(fid, 'function schema = getSizeItem(~)\n');
    fprintf(fid, '    schema = sl_action_schema;\n');
    fprintf(fid, '    schema.tag = ''SimuTidySize'';\n');
    fprintf(fid, '    schema.label = ''模块大小统一'';\n');
    fprintf(fid, '    schema.callback = @(~) slUniformSize();\n');
    fprintf(fid, 'end\n\n');
    
    % 信号线命名
    fprintf(fid, 'function schema = getNameItem(~)\n');
    fprintf(fid, '    schema = sl_container_schema;\n');
    fprintf(fid, '    schema.tag = ''SimuTidyName'';\n');
    fprintf(fid, '    schema.label = ''信号线命名'';\n');
    fprintf(fid, '    schema.childrenFcns = {\n');
    fprintf(fid, '        @getNameBySource\n');
    fprintf(fid, '        @getNameBySourcePort\n');
    fprintf(fid, '        @getNameByOutport\n');
    fprintf(fid, '        @getNameClear\n');
    fprintf(fid, '    };\n');
    fprintf(fid, 'end\n\n');
    
    % 命名子项
    nameItems = {'BySource', 'source', '按源模块名命名'; ...
                 'BySourcePort', 'source_port', '按源模块名+端口号命名'; ...
                 'ByOutport', 'outport', '按输出端口命名'; ...
                 'Clear', 'clear', '清除所有命名'};
    
    for i = 1:size(nameItems, 1)
        name = nameItems{i, 1};
        mode = nameItems{i, 2};
        label = nameItems{i, 3};
        fprintf(fid, 'function schema = getName%s(~)\n', name);
        fprintf(fid, '    schema = sl_action_schema;\n');
        fprintf(fid, '    schema.label = ''%s'';\n', label);
        fprintf(fid, '    schema.callback = @(~) slAutoNameSignals([], ''%s'');\n', mode);
        fprintf(fid, 'end\n\n');
    end
    
    % Goto/From拆分
    fprintf(fid, 'function schema = getSplitItem(~)\n');
    fprintf(fid, '    schema = sl_action_schema;\n');
    fprintf(fid, '    schema.tag = ''SimuTidySplit'';\n');
    fprintf(fid, '    schema.label = ''长连线拆 Goto/From'';\n');
    fprintf(fid, '    schema.callback = @(~) slSplitGotoFrom();\n');
    fprintf(fid, 'end\n\n');
    
    % 高亮未连接端口
    fprintf(fid, 'function schema = getHighlightItem(~)\n');
    fprintf(fid, '    schema = sl_action_schema;\n');
    fprintf(fid, '    schema.tag = ''SimuTidyHighlight'';\n');
    fprintf(fid, '    schema.label = ''高亮未连接端口'';\n');
    fprintf(fid, '    schema.callback = @(~) slHighlightUnconnected();\n');
    fprintf(fid, 'end\n\n');
    
    % 生成接口
    fprintf(fid, 'function schema = getGeneratePortsItem(~)\n');
    fprintf(fid, '    schema = sl_action_schema;\n');
    fprintf(fid, '    schema.tag = ''SimuTidyGeneratePorts'';\n');
    fprintf(fid, '    schema.label = ''生成接口'';\n');
    fprintf(fid, '    schema.callback = @(~) slGeneratePorts();\n');
    fprintf(fid, 'end\n');

    % 更新模块名称
    fprintf(fid, 'function schema = getUpdateBlockNamesItem(~)\n');
    fprintf(fid, '    schema = sl_action_schema;\n');
    fprintf(fid, '    schema.tag = ''SimuTidyUpdateBlockNames'';\n');
    fprintf(fid, '    schema.label = ''更新模块名称'';\n');
    fprintf(fid, '    schema.callback = @(~) slUpdateBlockNames();\n');
    fprintf(fid, 'end\n');
    
    fclose(fid);
end
