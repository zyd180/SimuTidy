function SimuTidy_settingsDialog()
%SimuTidy_settingsDialog 设置对话框（3.3.0）
%   图形化编辑高价值配置子集，保存写入用户配置文件
%   （userpath/SimuTidy_config_user.json，经 userConfig('write') 校验）。
%
%   范围约定（刻意不暴露全部配置）：
%   - 可编辑：Goto 宽/高/间距、命名最大长度、模型标签刷新间隔、
%     updateAfterChange 开关、主题
%   - 不可编辑（JSON 手编）：naming.replaceChars 正则等高级项
%   - 主题走偏好即时生效；其余项需重开主窗口/下一次操作生效
%   - 日志等级不进对话框（面向排障的 JSON 项）

    % 单例
    d = findall(0, 'Type', 'figure', 'Name', 'SimuTidy 设置');
    if ~isempty(d)
        figure(d(1));
        return;
    end

    cfg = SimuTidy_config();

    fig = uifigure('Name', 'SimuTidy 设置', ...
        'Position', [560, 280, 360, 330], 'Color', cfg.gui.bgColor);
    g = uigridlayout(fig);
    g.RowHeight = {24, 24, 24, 24, 24, 24, 26, 30, 22};
    g.ColumnWidth = {150, '1x'};
    g.RowSpacing = 8;
    g.Padding = [12, 12, 12, 12];

    mkRow(1, 'Goto 模块宽度');
    w = uieditfield(g, 'numeric', 'Value', cfg.goto.defaultWidth, ...
        'Limits', [20, 400], 'RoundFractionalValues', 'on');
    w.Layout.Row = 1; w.Layout.Column = 2;

    mkRow(2, 'Goto 模块高度');
    h = uieditfield(g, 'numeric', 'Value', cfg.goto.defaultHeight, ...
        'Limits', [14, 200], 'RoundFractionalValues', 'on');
    h.Layout.Row = 2; h.Layout.Column = 2;

    mkRow(3, 'Goto/From 间距');
    gp = uieditfield(g, 'numeric', 'Value', cfg.goto.gap, ...
        'Limits', [5, 300], 'RoundFractionalValues', 'on');
    gp.Layout.Row = 3; gp.Layout.Column = 2;

    mkRow(4, '命名最大长度');
    ml = uieditfield(g, 'numeric', 'Value', cfg.naming.maxNameLength, ...
        'Limits', [8, 255], 'RoundFractionalValues', 'on');
    ml.Layout.Row = 4; ml.Layout.Column = 2;

    mkRow(5, '模型标签刷新间隔（秒）');
    ri = uieditfield(g, 'numeric', 'Value', cfg.gui.refreshInterval, ...
        'Limits', [0.2, 60], 'RoundFractionalValues', 'off');
    ri.Layout.Row = 5; ri.Layout.Column = 2;

    mkRow(6, '操作后自动更新模型');
    % updateAfterChange 历史上是 char 'on'（cfg 默认值），兼容两种形态读值
    ua = uicheckbox(g, 'Text', '', 'Value', ...
        islogical(cfg.simulink.updateAfterChange) && cfg.simulink.updateAfterChange || ...
        strcmpi(cfg.simulink.updateAfterChange, 'on'));
    ua.Layout.Row = 6; ua.Layout.Column = 2;

    mkRow(7, '主题');
    th = uidropdown(g, 'Items', {'light', 'dark'}, 'Value', cfg.themeName);
    th.Layout.Row = 7; th.Layout.Column = 2;

    saveBtn = uibutton(g, 'push', 'Text', '保存', ...
        'BackgroundColor', cfg.colors.moduleDark, 'FontColor', [1 1 1], ...
        'ButtonPushedFcn', @(~,~) onSave());
    saveBtn.Layout.Row = 8; saveBtn.Layout.Column = [1, 2];

    hint = uilabel(g, 'Text', '主题立即生效；其余项重开主窗口后生效', ...
        'FontSize', 8, 'FontColor', cfg.colors.textFaint, ...
        'HorizontalAlignment', 'center');
    hint.Layout.Row = 9; hint.Layout.Column = [1, 2];

    % ---- 嵌套函数（需要访问 cfg）----
    function mkRow(r, txt)
        l = uilabel(g, 'Text', txt, 'FontColor', cfg.colors.text, ...
            'HorizontalAlignment', 'left');
        l.Layout.Row = r;
        l.Layout.Column = 1;
    end

    function onSave()
        % 收集 → userConfig 白名单校验+写入（坏值被拒收并有 WARN）。
        % 主题单独走偏好（与 config 解析逻辑一致，偏好优先级高于 JSON）
        vals = struct( ...
            'goto',   struct('defaultWidth', w.Value, 'defaultHeight', h.Value, ...
                             'gap', gp.Value), ...
            'naming', struct('maxNameLength', ml.Value), ...
            'gui',    struct('refreshInterval', ri.Value, ...
                             'showOnboarding', logical(cfg.gui.showOnboarding)), ...
            'simulink', struct('updateAfterChange', logical(ua.Value)));
        ok = simutidy.internal.userConfig('write', vals);
        try
            setpref('SimuTidy', 'theme', th.Value);
        catch
        end
        if ok
            hint.Text = '已保存。重开主窗口后全部生效。';
            hint.FontColor = cfg.colors.success;
        else
            hint.Text = '保存失败：所有项均被校验拒绝。';
            hint.FontColor = cfg.colors.error;
        end
    end
end
