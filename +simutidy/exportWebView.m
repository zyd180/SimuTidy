function zipFile = exportWebView(modelName, outputFolder)
%exportWebView 导出Simulink模型为HTML Web视图ZIP
%   （3.1.0 自 core/slExportWebView 迁入 +simutidy 包）
%   zipFile = simutidy.exportWebView()
%   zipFile = simutidy.exportWebView(modelName)
%   zipFile = simutidy.exportWebView(modelName, outputFolder)
%
%   需要：Simulink Report Generator 许可证
%   兼容：根目录 slExportWebView.m 为薄包装，行为契约不变

    % 3.1.0 收敛：许可证检测统一走 internal.capabilities（原散落各处）
    cap = simutidy.internal.capabilities();
    if ~cap.hasReportGen
        error('SimuTidy:noLicense', '需要 Simulink Report Generator 许可证。');
    end

    if nargin < 1 || isempty(modelName)
        modelName = bdroot;
        if isempty(modelName) || strcmp(modelName, '')
            error('SimuTidy:noModel', '没有打开的 Simulink 模型。');
        end
    end

    if ~bdIsLoaded(modelName)
        error('SimuTidy:modelNotLoaded', '模型 "%s" 未加载。', modelName);
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
