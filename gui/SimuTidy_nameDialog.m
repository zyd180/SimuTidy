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
    % 3.4.0：新增"清除所选信号线命名"按钮，对话框加高 50px 容纳新按钮
    % （高度在 SimuTidy_config 的 nameDialogPos 中调整）
    dlg = uifigure('Name', '信号线自动命名', ...
                   'Position', cfg.gui.nameDialogPos, ...
                   'Color', cfg.gui.bgColor, ...
                   'Resize', 'off');

    % 命名方式标题
    uilabel(dlg, 'Text', '命名方式', ...
        'Position', [20, 310, 280, 24], 'FontSize', 14, ...
        'FontWeight', 'bold', 'HorizontalAlignment', 'center');

    % 命名按钮
    uibutton(dlg, 'push', 'Text', '按源模块名命名', ...
        'Position', [40, 262, 240, 36], 'FontSize', 12, ...
        'BackgroundColor', cfg.colors.line, 'FontColor', [1 1 1], ...
        'ButtonPushedFcn', @(~,~) doName(parentFig, dlg, 'source'));

    uibutton(dlg, 'push', 'Text', '按源模块名+端口号命名', ...
        'Position', [40, 214, 240, 36], 'FontSize', 12, ...
        'BackgroundColor', cfg.colors.line, 'FontColor', [1 1 1], ...
        'ButtonPushedFcn', @(~,~) doName(parentFig, dlg, 'source_port'));

    uibutton(dlg, 'push', 'Text', '按输出端口 (Outport) 命名', ...
        'Position', [40, 166, 240, 36], 'FontSize', 12, ...
        'BackgroundColor', cfg.colors.line, 'FontColor', [1 1 1], ...
        'ButtonPushedFcn', @(~,~) doName(parentFig, dlg, 'outport'));

    % 3.4.0 新增：只清选中的线；没选中时由核心函数 WARN 提醒、不做处理
    uibutton(dlg, 'push', 'Text', '清除所选信号线命名', ...
        'Position', [40, 112, 240, 36], 'FontSize', 12, ...
        'BackgroundColor', cfg.colors.line, 'FontColor', [1 1 1], ...
        'ButtonPushedFcn', @(~,~) doName(parentFig, dlg, 'clear_sel'));

    % 3.4.0：清除所有前弹窗二次确认（误点会清掉当前层全部命名，不可轻率）；
    % 确认后走 clear_all 模式——无视选中状态清当前层全部线
    uibutton(dlg, 'push', 'Text', '清除所有信号线命名', ...
        'Position', [40, 62, 240, 32], 'FontSize', 12, ...
        'BackgroundColor', cfg.colors.btnGrey, 'FontColor', [1 1 1], ...  % 3.2.0 色值入调色板
        'ButtonPushedFcn', @(~,~) confirmClearAll(parentFig, dlg));

    % 关闭按钮
    uibutton(dlg, 'push', 'Text', '关闭', ...
        'Position', [110, 14, 100, 30], 'FontSize', 11, ...
        'BackgroundColor', cfg.colors.btnGrey, 'FontColor', [1 1 1], ...  % 3.2.0 色值入调色板
        'ButtonPushedFcn', @(~,~) close(dlg));
end

function confirmClearAll(parentFig, dlg)
%confirmClearAll "清除所有信号线命名"的二次确认（3.4.0 新增）
%   默认选项为"取消"——回车/误触不至于直接清掉整层命名
    choice = uiconfirm(dlg, ...
        '将清除当前层级所有信号线的命名，确定继续？', ...
        '清除所有信号线命名', ...
        'Options', {'清除', '取消'}, 'DefaultOption', 2);
    if strcmp(choice, '清除')
        doName(parentFig, dlg, 'clear_all');
    end
end

function doName(parentFig, dlg, mode) %#ok<INUSL>
    cfg = SimuTidy_config();
    % 3.4.0：嵌套 sltidy_iif 换成 switch（新增 clear_sel/clear_all 两模式
    % 后嵌套三元已不可读）；文案仅供状态栏"正在XX"提示用
    switch mode
        case 'source',      mt = '按源模块名';
        case 'source_port', mt = '按源模块名+端口号';
        case 'outport',     mt = '按输出端口';
        case 'clear_sel',   mt = '清除所选线';
        case 'clear_all',   mt = '清除当前层全部线';
        otherwise,          mt = '清除';
    end
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
        % 3.3.0 命名空间化 + 结果反馈：直调包实体并接 res（失败弹结果面板）
        res = simutidy.autoNameSignals([], mode);
        if hasStatus
            sl.Text = [mt '命名完成'];
            sl.FontColor = cfg.colors.success;
        end
        SimuTidy_resultPanel(res);
    catch ME
        if hasStatus
            sl.Text = ['错误: ' ME.message];
            sl.FontColor = cfg.colors.error;
        else
            fprintf('信号线命名%s: %s\n', sltidy_iif(strcmp(ME.identifier,''), '完成', '失败'), ME.message);
        end
    end
end
