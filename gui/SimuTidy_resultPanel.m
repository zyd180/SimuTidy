function SimuTidy_resultPanel(res)
%SimuTidy_resultPanel 批量操作结果面板（3.3.0，非模态）
%   SimuTidy_resultPanel(res) - res.failCount > 0 时显示失败明细
%
%   res 结构（由批量操作的可选输出提供，见 +simutidy 各函数）：
%       op        - 操作名
%       okCount / failCount - 成功/失败数
%       failItems - struct 数组：handle（可定位对象句柄）/ reason / index
%
%   交互：每条失败一行"定位"按钮 → 打开对象所在系统并红色高亮
%   （块/线通用，走 HiliteAncestors，与高亮诊断功能同一机制）
%   面板单例：再次打开时旧面板自动关闭（始终显示最新一次操作）

    if isempty(res) || res.failCount == 0
        return;
    end

    cfg = SimuTidy_config();

    % 单例：旧面板直接关闭，避免堆叠
    old = findall(0, 'Type', 'figure', 'Name', 'SimuTidy 操作结果');
    if ~isempty(old)
        delete(old);
    end

    fig = uifigure('Name', 'SimuTidy 操作结果', ...
        'Position', [560, 240, 480, 340], ...
        'Color', cfg.gui.bgColor);
    g = uigridlayout(fig);
    g.ColumnWidth = {'1x', 64};
    g.RowHeight = [{24}, repmat({26}, 1, res.failCount), {30}];
    g.Padding = [10 10 10 10];
    g.RowSpacing = 4;

    % 表头：操作名 + 计数
    % 3.4.0：诊断类检查（高亮未连接/重叠/GotoFrom 配对）语义上没有
    % "失败"，经可选 res.okLabel/failLabel 提供文案（缺省回落
    % 成功/失败，兼容既有批量操作 res 结构）
    if isfield(res, 'okLabel'),   okLbl = res.okLabel;     else, okLbl = '成功';   end
    if isfield(res, 'failLabel'), failLbl = res.failLabel; else, failLbl = '失败'; end
    hdr = uilabel(g, 'Text', sprintf('%s：%s %d / %s %d', ...
        res.op, okLbl, res.okCount, failLbl, res.failCount), ...
        'FontWeight', 'bold', 'FontColor', cfg.colors.error, ...
        'HorizontalAlignment', 'left');
    hdr.Layout.Row = 1;
    hdr.Layout.Column = [1, 2];

    % 逐条失败：原因 + 定位
    for k = 1:res.failCount
        item = res.failItems(k);
        row = k + 1;
        lbl = uilabel(g, ...
            'Text', sprintf('%d. %s', item.index, item.reason), ...
            'FontColor', cfg.colors.text, ...
            'HorizontalAlignment', 'left');
        lbl.Layout.Row = row;
        lbl.Layout.Column = 1;

        btn = uibutton(g, 'push', 'Text', '定位', ...
            'BackgroundColor', cfg.colors.module, 'FontColor', [1 1 1], ...
            'ButtonPushedFcn', @(~,~) locate(item.handle));
        btn.Layout.Row = row;
        btn.Layout.Column = 2;
    end

    % 关闭行
    closeBtn = uibutton(g, 'push', 'Text', '关闭', ...
        'BackgroundColor', cfg.colors.btnGrey, 'FontColor', [1 1 1], ...
        'ButtonPushedFcn', @(~,~) close(fig));
    closeBtn.Layout.Row = res.failCount + 2;
    closeBtn.Layout.Column = [1, 2];
end

function locate(h)
%locate 在 Simulink 中打开对象所在系统并高亮（块/线通用）
%   get_param(h, 'Parent') 对块和线均返回所在系统路径
    try
        parent = get_param(h, 'Parent');
        open_system(parent);
        set_param(h, 'HiliteAncestors', 'error');
    catch ME
        simutidy.internal.log('warn', '定位失败：%s', ME.message);
    end
end
