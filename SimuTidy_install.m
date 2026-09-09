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
    
    % 3.1.0 兼容层：菜单定义改为模板文件维护。原实现用 ~170 行 fprintf
    % 拼接生成 sl_customization.m——不可 diff、难维护、菜单改动要改
    % 安装脚本本身。现在唯一数据源是 resources/templates/ 下的模板，
    % 占位符仅 @VERSION@；改菜单只改模板，安装脚本零改动
    tmpl = fullfile(rootPath, 'resources', 'templates', 'sl_customization.m.tmpl');
    if ~isfile(tmpl)
        error('SimuTidy:templateMissing', '菜单模板缺失: %s', tmpl);
    end
    content = fileread(tmpl);
    fid = fopen(custFile, 'w');
    if fid == -1
        error('SimuTidy:writeFailed', '无法创建文件: %s', custFile);
    end
    fwrite(fid, strrep(content, '@VERSION@', cfg.version));
    fclose(fid);
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
    % 3.1.0 兼容层：特性检测统一走 simutidy.internal.capabilities
    % （原 exist('slReloadToolstripConfig','file') 就地判断，无法复用）
    cap = simutidy.internal.capabilities();
    if cap.hasToolstrip
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
