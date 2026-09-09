function SimuTidy_nameDialog(parentFig)
%SimuTidy_nameDialog 创建信号线自动命名对话框
%   SimuTidy_nameDialog(parentFig) - 在父窗口旁创建命名对话框
%   SimuTidy_nameDialog() - 独立打开（如从 Simulink Toolstrip 调用），无状态栏联动

    if nargin < 1
        parentFig = [];
    end

    % 检查是否已有对话框打开（uifigure 默认句柄隐藏，须用 findall）
    d = findall(0, 'Type', 'figure', 'Name', '信号线自动命名');
    if ~isempty(d)
        figure(d(1));
        return;
    end

    % 获取配置
    cfg = SimuTidy_config();

    % 创建对话框
    dlg = uifigure('Name', '信号线自动命名', ...
                   'Position', cfg.gui.nameDialogPos, ...
                   'Color', cfg.gui.bgColor, ...
                   'Resize', 'off');

    % 命名方式标题
    uilabel(dlg, 'Text', '命名方式', ...
        'Position', [20, 260, 280, 24], 'FontSize', 14, ...
        'FontWeight', 'bold', 'HorizontalAlignment', 'center');

    % 命名按钮
    uibutton(dlg, 'push', 'Text', '按源模块名命名', ...
        'Position', [40, 210, 240, 36], 'FontSize', 12, ...
        'BackgroundColor', cfg.colors.line, 'FontColor', [1 1 1], ...
        'ButtonPushedFcn', @(~,~) doName(parentFig, dlg, 'source'));

    uibutton(dlg, 'push', 'Text', '按源模块名+端口号命名', ...
        'Position', [40, 160, 240, 36], 'FontSize', 12, ...
        'BackgroundColor', cfg.colors.line, 'FontColor', [1 1 1], ...
        'ButtonPushedFcn', @(~,~) doName(parentFig, dlg, 'source_port'));

    uibutton(dlg, 'push', 'Text', '按输出端口 (Outport) 命名', ...
        'Position', [40, 110, 240, 36], 'FontSize', 12, ...
        'BackgroundColor', cfg.colors.line, 'FontColor', [1 1 1], ...
        'ButtonPushedFcn', @(~,~) doName(parentFig, dlg, 'outport'));

    uibutton(dlg, 'push', 'Text', '清除所有信号线命名', ...
        'Position', [40, 55, 240, 32], 'FontSize', 12, ...
        'BackgroundColor', [0.58 0.58 0.58], 'FontColor', [1 1 1], ...
        'ButtonPushedFcn', @(~,~) doName(parentFig, dlg, 'clear'));

    % 关闭按钮
    uibutton(dlg, 'push', 'Text', '关闭', ...
        'Position', [110, 10, 100, 30], 'FontSize', 11, ...
        'BackgroundColor', [0.6 0.6 0.6], 'FontColor', [1 1 1], ...
        'ButtonPushedFcn', @(~,~) close(dlg));
end

function doName(parentFig, dlg, mode) %#ok<INUSL>
    cfg = SimuTidy_config();
    mt = sltidy_iif(strcmp(mode,'source'),'按源模块名',sltidy_iif(strcmp(mode,'source_port'),'按源模块名+端口号',sltidy_iif(strcmp(mode,'outport'),'按输出端口','清除')));
    % 3.1.0 清理：原三段式 sltidy_iif 嵌套可读性差，保留仅为兼容历史调用；
    % 实际文案已由 simutidy.autoNameSignals 内部统一生成，此处仅在
    % 状态栏显示"正在XX命名"用
    % 独立调用（无父窗口）时仅在命令行提示，不更新状态栏
    hasStatus = ~isempty(parentFig) && isvalid(parentFig) && ...
                isfield(parentFig.UserData, 'statusLabel') && isvalid(parentFig.UserData.statusLabel);
    if hasStatus
        sl = parentFig.UserData.statusLabel;
        sl.Text = ['正在' mt '命名...'];
        sl.FontColor = cfg.colors.line;
        drawnow;
    end
    try
        % 3.1.0 命名空间化：GUI 内部调用直调 +simutidy 包实体（理由见主窗口 doAlign 注释）
        simutidy.autoNameSignals([], mode);
        if hasStatus
            sl.Text = [mt '命名完成'];
            sl.FontColor = cfg.colors.success;
        end
    catch ME
        if hasStatus
            sl.Text = ['错误: ' ME.message];
            sl.FontColor = cfg.colors.error;
        else
            fprintf('信号线命名%s: %s\n', sltidy_iif(strcmp(ME.identifier,''), '完成', '失败'), ME.message);
        end
    end
end
