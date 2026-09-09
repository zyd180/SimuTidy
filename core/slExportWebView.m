function zipFile = slExportWebView(modelName, outputFolder)
%slExportWebView 导出Simulink模型为HTML Web视图ZIP
%   zipFile = slExportWebView()
%   zipFile = slExportWebView(modelName)
%   zipFile = slExportWebView(modelName, outputFolder)
%
%   输入：
%       modelName - 模型名称（可选，默认当前模型）
%       outputFolder - 输出文件夹（可选，默认当前目录）
%
%   输出：
%       zipFile - 生成的ZIP文件路径
%
%   需要：Simulink Report Generator 许可证

    if ~license('test', 'Simulink_Report_Gen')
        error('需要 Simulink Report Generator 许可证。');
    end
    
    if nargin < 1 || isempty(modelName)
        modelName = bdroot;
        if isempty(modelName) || strcmp(modelName, '')
            error('没有打开的 Simulink 模型。');
        end
    end
    
    if ~bdIsLoaded(modelName)
        error('模型 "%s" 未加载。', modelName);
    end
    
    if nargin < 2 || isempty(outputFolder)
        outputFolder = pwd;
    end
    
    if ~isfolder(outputFolder)
        mkdir(outputFolder);
    end
    
    zipFile = slwebview(modelName, ...
        'PackageType', 'zipped', ...
        'PackageFolder', outputFolder, ...
        'ViewFile', false, ...
        'SearchScope', 'CurrentAndBelow');
end
