function SimuTidy_uninstall()
%SimuTidy_uninstall 从MATLAB/Simulink中移除SimuTidy
%   SimuTidy_uninstall() - 移除SimuTidy路径和菜单配置

    fprintf('SimuTidy 卸载程序\n');
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n');

    % 获取SimuTidy根目录
    rootPath = fileparts(mfilename('fullpath'));
    if isempty(rootPath)
        rootPath = pwd;
    end

    % ========== 步骤1：从路径中移除 ==========
    fprintf('[1/3] 移除路径...\n');
    
    % 3.1.0 命名空间化：core 目录已并入 +simutidy 包（随根目录），不再单独移除
    pathsToRemove = {
        rootPath
        fullfile(rootPath, 'gui')
        fullfile(rootPath, 'utils')
    };
    
    for i = 1:length(pathsToRemove)
        p = pathsToRemove{i};
        if contains(path, p)
            rmpath(p);
        end
    end
    
    try
        savepath;
        fprintf('      路径已移除并保存\n');
    catch ME
        warning('savepath 失败: %s\n', ME.message);
    end

    % ========== 步骤2：移除 sl_customization.m ==========
    fprintf('[2/3] 移除 sl_customization.m...\n');
    
    userPath = userpath;
    if ~isempty(userPath)
        custFile = fullfile(userPath, 'sl_customization.m');
        if isfile(custFile)
            % 检查是否是 SimuTidy 生成的
            content = fileread(custFile);
            if (contains(content, 'SimuTidy') && contains(content, 'SimuTidyOpenGUI')) || ...
                    (contains(content, 'SK2') && contains(content, 'SK2OpenGUI'))
                delete(custFile);
                fprintf('      已删除: %s\n', custFile);
            else
                fprintf('      sl_customization.m 不是 SimuTidy 生成的，跳过\n');
            end
        end
    end

    % ========== 步骤3：从 startup.m 中移除 ==========
    fprintf('[3/3] 清理 startup.m...\n');
    
    if ~isempty(userPath)
        startupFile = fullfile(userPath, 'startup.m');
        if isfile(startupFile)
            content = fileread(startupFile);
            if contains(content, 'SimuTidy') || contains(content, 'SK2')
                % 读取并过滤
                lines = strsplit(content, '\n');
                newLines = {};
                skipBlock = false;
                
                for i = 1:length(lines)
                    line = lines{i};
                    if contains(line, 'SimuTidy - Simulink') || contains(line, 'SimuTidy_version') ...
                            || contains(line, 'SK2 - Simulink') || contains(line, 'SK2_version')
                        skipBlock = true;
                        continue;
                    end
                    if skipBlock && (isempty(strtrim(line)) || startsWith(strtrim(line), '%%'))
                        skipBlock = false;
                    end
                    if ~skipBlock
                        newLines{end+1} = line; %#ok<AGROW>
                    end
                end
                
                % 写回文件
                fid = fopen(startupFile, 'w');
                if fid ~= -1
                    fprintf(fid, '%s\n', strjoin(newLines, '\n'));
                    fclose(fid);
                    fprintf('      已从 startup.m 移除 SimuTidy 配置\n');
                end
            else
                fprintf('      startup.m 不包含 SimuTidy 配置，跳过\n');
            end
        end
    end

    % ========== 完成 ==========
    fprintf('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    fprintf('  卸载完成！\n');
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n');
    fprintf('  请重启 MATLAB 使更改生效\n');
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
end
