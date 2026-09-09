function fig = SimuTidy_mainGUI()
%SimuTidy_mainGUI 创建SimuTidy主GUI界面（v2.6.1 按功能分区 + 靛青专业配色）
%   fig = SimuTidy_mainGUI()
%   返回创建的GUI窗口句柄
%
%   界面按功能分为5个分区（分区即配色）：
%       1. 视图与导出：导出Web视图（深海蓝）
%       2. 模块整理：对齐/等间距(8种)、大小统一（钢青蓝）
%       3. 连线整理：连线端口对齐、信号线命名、拆分Goto/From（青绿）
%       4. 接口与命名：生成接口、更新模块名称（靛紫）
%       5. 检查与诊断：高亮未连接端口（琥珀）

    % 检查是否已有窗口打开（uifigure 默认句柄隐藏，须用 findall）
    fig = findall(0, 'Type', 'figure', 'Name', 'SimuTidy');
    if ~isempty(fig)
        figure(fig(1));
        return;
    end

    % 获取配置
    cfg = SimuTidy_config();

    % 创建主窗口
    fig = uifigure('Name', 'SimuTidy', ...
                   'Position', cfg.gui.mainPosition, ...
                   'Color', cfg.gui.bgColor, ...
                   'Resize', 'off', ...
                   'WindowStyle', 'normal');

    % ========== 顶部区域 ==========
    % 标题（3.2.0：宽度让位给右侧主题/引导按钮；字色入主题调色板）
    uilabel(fig, 'Text', 'SimuTidy Simulink 辅助工具', ...
        'Position', [10, 590, 278, 24], 'FontSize', 15, ...
        'FontWeight', 'bold', 'FontColor', cfg.colors.text, ...
        'HorizontalAlignment', 'center');

    % 主题切换按钮（3.2.0 新增：写偏好后重建窗口，见 onToggleTheme）
    uibutton(fig, 'push', 'Text', sltidy_iif(strcmp(cfg.themeName, 'light'), ...
        '深色主题', '浅色主题'), ...
        'Position', [292, 590, 74, 24], 'FontSize', 9, ...
        'BackgroundColor', cfg.gui.bgColor, 'FontColor', cfg.colors.textSubtle, ...
        'Tooltip', '在浅色/深色主题间切换（重启窗口生效，偏好自动记住）', ...
        'ButtonPushedFcn', @(~,~) onToggleTheme(fig));

    % 使用引导按钮（随时重新查看新手引导）
    uibutton(fig, 'push', 'Text', '使用引导', ...
        'Position', [372, 590, 78, 24], 'FontSize', 9, ...
        'BackgroundColor', cfg.gui.bgColor, 'FontColor', cfg.colors.textSubtle, ...
        'Tooltip', '重新查看新手引导', ...
        'ButtonPushedFcn', @(~,~) SimuTidy_onboarding());

    % 模型标签（3.2.0：字色入主题调色板）
    modelLabel = uilabel(fig, 'Text', sltidy_getModelName(), ...
        'Position', [10, 566, 440, 18], 'FontSize', 10, ...
        'FontColor', cfg.colors.textSubtle, 'HorizontalAlignment', 'center');

    % ========== ❶ 视图与导出 ==========
    p1 = uipanel(fig, 'Title', '  视图与导出  ', ...
        'Position', [10, 490, 440, 70], ...
        'BackgroundColor', cfg.gui.bgColor, 'ForegroundColor', cfg.colors.panelTitle, ...
        'FontWeight', 'bold');

    uibutton(p1, 'push', 'Text', '导出 Web 视图 (ZIP)', ...
        'Position', [10, 10, 420, 30], 'FontSize', 12, ...
        'FontWeight', 'bold', 'BackgroundColor', cfg.colors.export, ...
        'FontColor', [1 1 1], ...
        'Tooltip', '将当前模型导出为HTML Web视图ZIP包（需要Simulink Report Generator许可证）', ...
        'ButtonPushedFcn', @(~,~) onExportWebView(fig));

    % ========== ❷ 模块整理 ==========
    p2 = uipanel(fig, 'Title', '  模块整理  ', ...
        'Position', [10, 344, 440, 140], ...
        'BackgroundColor', cfg.gui.bgColor, 'ForegroundColor', cfg.colors.panelTitle, ...
        'FontWeight', 'bold');

    % 第1行：左对齐、右对齐、顶部对齐、底部对齐
    uibutton(p2, 'push', 'Text', '左对齐', ...
        'Position', [10, 82, 100, 28], 'FontSize', 11, ...
        'BackgroundColor', cfg.colors.module, 'FontColor', [1 1 1], ...
        'Tooltip', '所有选中模块左边缘对齐到基准模块（最上最左）', ...
        'ButtonPushedFcn', @(~,~) doAlign(fig, 'left'));
    uibutton(p2, 'push', 'Text', '右对齐', ...
        'Position', [117, 82, 100, 28], 'FontSize', 11, ...
        'BackgroundColor', cfg.colors.module, 'FontColor', [1 1 1], ...
        'Tooltip', '所有选中模块右边缘对齐到基准模块（最上最左）', ...
        'ButtonPushedFcn', @(~,~) doAlign(fig, 'right'));
    uibutton(p2, 'push', 'Text', '顶部对齐', ...
        'Position', [223, 82, 100, 28], 'FontSize', 11, ...
        'BackgroundColor', cfg.colors.module, 'FontColor', [1 1 1], ...
        'Tooltip', '所有选中模块顶边对齐到基准模块（最上最左）', ...
        'ButtonPushedFcn', @(~,~) doAlign(fig, 'top'));
    uibutton(p2, 'push', 'Text', '底部对齐', ...
        'Position', [330, 82, 100, 28], 'FontSize', 11, ...
        'BackgroundColor', cfg.colors.module, 'FontColor', [1 1 1], ...
        'Tooltip', '所有选中模块底边对齐到基准模块（最上最左）', ...
        'ButtonPushedFcn', @(~,~) doAlign(fig, 'bottom'));

    % 第2行：水平居中、垂直居中、水平等间距、垂直等间距
    uibutton(p2, 'push', 'Text', '水平居中', ...
        'Position', [10, 46, 100, 28], 'FontSize', 11, ...
        'BackgroundColor', cfg.colors.module, 'FontColor', [1 1 1], ...
        'Tooltip', '所有选中模块水平中心线对齐到基准模块（最上最左）', ...
        'ButtonPushedFcn', @(~,~) doAlign(fig, 'hcenter'));
    uibutton(p2, 'push', 'Text', '垂直居中', ...
        'Position', [117, 46, 100, 28], 'FontSize', 11, ...
        'BackgroundColor', cfg.colors.module, 'FontColor', [1 1 1], ...
        'Tooltip', '所有选中模块垂直中心线对齐到基准模块（最上最左）', ...
        'ButtonPushedFcn', @(~,~) doAlign(fig, 'vcenter'));
    uibutton(p2, 'push', 'Text', '水平等间距', ...
        'Position', [223, 46, 100, 28], 'FontSize', 11, ...
        'BackgroundColor', cfg.colors.module, 'FontColor', [1 1 1], ...
        'Tooltip', '按水平中心将选中模块在首尾范围内等间距分布', ...
        'ButtonPushedFcn', @(~,~) doAlign(fig, 'hspace'));
    uibutton(p2, 'push', 'Text', '垂直等间距', ...
        'Position', [330, 46, 100, 28], 'FontSize', 11, ...
        'BackgroundColor', cfg.colors.module, 'FontColor', [1 1 1], ...
        'Tooltip', '按垂直中心将选中模块在首尾范围内等间距分布', ...
        'ButtonPushedFcn', @(~,~) doAlign(fig, 'vspace'));

    % 第3行：大小统一
    uibutton(p2, 'push', 'Text', '大小统一', ...
        'Position', [10, 10, 420, 28], 'FontSize', 11, ...
        'BackgroundColor', cfg.colors.moduleDark, 'FontColor', [1 1 1], ...
        'Tooltip', '以基准模块（最上最左）为准统一选中模块大小，保持中心点不变', ...
        'ButtonPushedFcn', @(~,~) onUniformSize(fig));

    % ========== ❸ 连线整理 ==========
    p3 = uipanel(fig, 'Title', '  连线整理  ', ...
        'Position', [10, 218, 440, 120], ...
        'BackgroundColor', cfg.gui.bgColor, 'ForegroundColor', cfg.colors.panelTitle, ...
        'FontWeight', 'bold');

    uibutton(p3, 'push', 'Text', '连线端口对齐', ...
        'Position', [10, 58, 420, 28], 'FontSize', 12, ...
        'FontWeight', 'bold', 'BackgroundColor', cfg.colors.lineDark, ...
        'FontColor', [1 1 1], ...
        'Tooltip', '以选中模块连线的另一端端口为基准（不动），垂直移动选中模块使端口同高，连线变为水平直线（只调垂直位置，不改水平位置）', ...
        'ButtonPushedFcn', @(~,~) onAlignLinePorts(fig));
    uibutton(p3, 'push', 'Text', '信号线命名', ...
        'Position', [10, 20, 134, 28], 'FontSize', 11, ...
        'BackgroundColor', cfg.colors.line, 'FontColor', [1 1 1], ...
        'Tooltip', '打开命名对话框：按源模块名/源模块名+端口号/输出端口命名信号线，或清除命名', ...
        'ButtonPushedFcn', @(~,~) SimuTidy_nameDialog(fig));
    uibutton(p3, 'push', 'Text', '拆分 Goto/From', ...
        'Position', [149, 20, 134, 28], 'FontSize', 11, ...
        'BackgroundColor', cfg.colors.line, 'FontColor', [1 1 1], ...
        'Tooltip', '将选中的长连线批量拆分为Goto/From对（支持多选；Goto在源端、From在目标端，两端模块外移留出间距）', ...
        'ButtonPushedFcn', @(~,~) onSplitGoto(fig));
    uibutton(p3, 'push', 'Text', '信号对象解析', ...
        'Position', [288, 20, 142, 28], 'FontSize', 11, ...
        'BackgroundColor', cfg.colors.line, 'FontColor', [1 1 1], ...
        'Tooltip', '为当前层级所有有名字的信号线勾选"信号名称必须解析为Simulink对象"（更新图时强制校验名字指向工作区对象）；选中线则只处理选中的；mode off 可取消', ...
        'ButtonPushedFcn', @(~,~) onSetSignalResolve(fig));

    % ========== ❹ 接口与命名 ==========
    p4 = uipanel(fig, 'Title', '  接口与命名  ', ...
        'Position', [10, 137, 440, 75], ...
        'BackgroundColor', cfg.gui.bgColor, 'ForegroundColor', cfg.colors.panelTitle, ...
        'FontWeight', 'bold');

    uibutton(p4, 'push', 'Text', '生成接口', ...
        'Position', [10, 12, 205, 28], 'FontSize', 11, ...
        'BackgroundColor', cfg.colors.port, 'FontColor', [1 1 1], ...
        'Tooltip', '为选中的Subsystem未连接端口自动添加Inport/Outport块并连线', ...
        'ButtonPushedFcn', @(~,~) onGeneratePorts(fig));
    uibutton(p4, 'push', 'Text', '更新模块名称', ...
        'Position', [225, 12, 205, 28], 'FontSize', 11, ...
        'BackgroundColor', cfg.colors.portDark, 'FontColor', [1 1 1], ...
        'Tooltip', '将Inport/Outport模块名更新为信号线名；Inport无信号名时用外层传入名，重名自动追加序号', ...
        'ButtonPushedFcn', @(~,~) onUpdateBlockNames(fig));

    % ========== ❺ 检查与诊断 ==========
    p5 = uipanel(fig, 'Title', '  检查与诊断  ', ...
        'Position', [10, 56, 440, 75], ...
        'BackgroundColor', cfg.gui.bgColor, 'ForegroundColor', cfg.colors.panelTitle, ...
        'FontWeight', 'bold');

    uibutton(p5, 'push', 'Text', '高亮未连接端口', ...
        'Position', [10, 12, 420, 28], 'FontSize', 11, ...
        'BackgroundColor', cfg.colors.check, 'FontColor', [1 1 1], ...
        'Tooltip', '高亮有未连接端口的模块及悬空信号线；再次运行刷新状态，已连接的自动取消高亮', ...
        'ButtonPushedFcn', @(~,~) onHighlightUnconnected(fig));

    % 开发者信息（3.2.0：字色入主题调色板）
    uilabel(fig, 'Text', '开发者: Henry  |  1378099981@qq.com  |  github.com/zyd180', ...
        'Position', [10, 14, 440, 16], 'FontSize', 8, ...
        'FontColor', cfg.colors.textFaint, 'HorizontalAlignment', 'center');

    % 状态标签（3.2.0：字色入主题调色板）
    statusLabel = uilabel(fig, 'Text', '就绪', ...
        'Position', [10, 36, 440, 18], 'FontSize', 9, ...
        'FontColor', cfg.colors.textFaint, 'HorizontalAlignment', 'center');

    % 存储用户数据
    fig.UserData.statusLabel = statusLabel;
    fig.UserData.modelLabel = modelLabel;

    % 3.3.0 统一日志：注册状态栏 sink——核心函数内的 WARN/ERROR 自动上屏
    %（warn=琥珀色 error=红色）；关窗/切主题时清除（见 onClose/onToggleTheme）
    simutidy.internal.setLogSink(@(msg, level) guiLogSink(statusLabel, msg, level));

    % 定时器刷新模型标签
    t = timer('ExecutionMode', 'fixedRate', 'Period', cfg.gui.refreshInterval, ...
              'TimerFcn', @(~,~) refreshModelLabel(fig));
    start(t);
    fig.UserData.timer = t;
    fig.CloseRequestFcn = @(src,~) onClose(src, t);

    % 新手引导：首次启动自动弹出（cfg.gui.showOnboarding 可关闭）
    if cfg.gui.showOnboarding
        onboarded = false;
        try
            onboarded = getpref('SimuTidy', 'onboarded');
        catch
        end
        if ~onboarded
            SimuTidy_onboarding();
        end
    end
end

%% ========================================================================
%  对齐回调
%% ========================================================================
function doAlign(fig, alignType)
    sl = fig.UserData.statusLabel;
    cfg = SimuTidy_config();

    alignNames = struct(...
        'left', '左对齐', 'right', '右对齐', ...
        'top', '顶部对齐', 'bottom', '底部对齐', ...
        'hcenter', '水平居中', 'vcenter', '垂直居中', ...
        'hspace', '水平等间距', 'vspace', '垂直等间距');

    sl.Text = ['正在' alignNames.(alignType) '...'];
    sl.FontColor = cfg.colors.module;
    drawnow;

    try
        % 3.1.0 命名空间化：以下回调统一改调 +simutidy 包实体（core/sl* 已迁移）。
    % 经由根目录 slXxx 兼容包装亦可工作，但 GUI 属内部调用方，直调包函数
    % 少一层间接；slXxx 包装仅供外部脚本与 sl_customization 菜单使用
    simutidy.alignBlocks([], alignType);
        sl.Text = [alignNames.(alignType) '完成'];
        sl.FontColor = cfg.colors.success;
    catch ME
        sl.Text = ['错误: ' ME.message];
        sl.FontColor = cfg.colors.error;
    end
end

%% ========================================================================
%  功能回调
%% ========================================================================
function onExportWebView(fig)
    sl = fig.UserData.statusLabel;
    cfg = SimuTidy_config();
    sl.Text = '正在导出...'; sl.FontColor = cfg.colors.export; drawnow;
    try
        zipFile = simutidy.exportWebView();
        [~, n, e] = fileparts(zipFile);
        sl.Text = ['导出成功: ' n e]; sl.FontColor = cfg.colors.success;
    catch ME
        sl.Text = ['错误: ' ME.message]; sl.FontColor = cfg.colors.error;
    end
end

function onAlignLinePorts(fig)
    sl = fig.UserData.statusLabel;
    cfg = SimuTidy_config();
    sl.Text = '正在端口对齐...'; sl.FontColor = cfg.colors.lineDark; drawnow;
    try
        simutidy.alignLinePorts();
        sl.Text = '连线端口对齐完成';
        sl.FontColor = cfg.colors.success;
    catch ME
        sl.Text = ['错误: ' ME.message]; sl.FontColor = cfg.colors.error;
    end
end

function onUniformSize(fig)
    sl = fig.UserData.statusLabel;
    cfg = SimuTidy_config();
    sl.Text = '正在统一大小...'; sl.FontColor = cfg.colors.moduleDark; drawnow;
    try
        simutidy.uniformSize();
        sl.Text = '大小统一完成';
        sl.FontColor = cfg.colors.success;
    catch ME
        sl.Text = ['错误: ' ME.message]; sl.FontColor = cfg.colors.error;
    end
end

function onSplitGoto(fig)
    sl = fig.UserData.statusLabel;
    cfg = SimuTidy_config();
    sl.Text = '正在拆分...'; sl.FontColor = cfg.colors.line; drawnow;
    try
        simutidy.splitGotoFrom();
        sl.Text = '拆分完成';
        sl.FontColor = cfg.colors.success;
    catch ME
        sl.Text = ['错误: ' ME.message]; sl.FontColor = cfg.colors.error;
    end
end

function onHighlightUnconnected(fig)
    sl = fig.UserData.statusLabel;
    cfg = SimuTidy_config();
    sl.Text = '正在高亮...'; sl.FontColor = cfg.colors.check; drawnow;
    try
        simutidy.highlightUnconnected();
        sl.Text = '高亮完成';
        sl.FontColor = cfg.colors.success;
    catch ME
        sl.Text = ['错误: ' ME.message]; sl.FontColor = cfg.colors.error;
    end
end

function onGeneratePorts(fig)
    sl = fig.UserData.statusLabel;
    cfg = SimuTidy_config();
    sl.Text = '正在生成接口...'; sl.FontColor = cfg.colors.port; drawnow;
    try
        simutidy.generatePorts();
        sl.Text = '接口生成完成';
        sl.FontColor = cfg.colors.success;
    catch ME
        sl.Text = ['错误: ' ME.message];
        sl.FontColor = cfg.colors.error;
    end
end

function onUpdateBlockNames(fig)
    sl = fig.UserData.statusLabel;
    cfg = SimuTidy_config();
    sl.Text = '正在更新模块名称...'; sl.FontColor = cfg.colors.portDark; drawnow;
    try
        simutidy.updateBlockNames();
        sl.Text = '模块名称更新完成';
        sl.FontColor = cfg.colors.success;
    catch ME
        sl.Text = ['错误: ' ME.message];
        sl.FontColor = cfg.colors.error;
    end
end

function onSetSignalResolve(fig)
    sl = fig.UserData.statusLabel;
    cfg = SimuTidy_config();
    sl.Text = '正在设置信号对象解析...'; sl.FontColor = cfg.colors.lineDark; drawnow;
    try
        simutidy.setSignalResolve();
        sl.Text = '信号对象解析设置完成';
        sl.FontColor = cfg.colors.success;
    catch ME
        sl.Text = ['错误: ' ME.message]; sl.FontColor = cfg.colors.error;
    end
end

%% ========================================================================
%  辅助函数
%% ========================================================================
function refreshModelLabel(fig)
    if ~isvalid(fig), return; end
    if ~isfield(fig.UserData, 'modelLabel'), return; end
    if ~isvalid(fig.UserData.modelLabel), return; end
    try
        % 3.1.0 性能优化：文本未变化时不再 set。定时器每秒触发，set 同值
        % 也会触发控件重绘事件，模型不变时是纯浪费
        txt = sltidy_getModelName();
        if ~strcmp(fig.UserData.modelLabel.Text, txt)
            fig.UserData.modelLabel.Text = txt;
        end
    catch
    end
end

function guiLogSink(sl, msg, level)
%guiLogSink 3.3.0 状态栏日志接收器（经 setLogSink 注册）
%   核心函数内部产生的 warn/error 无需经过 GUI 回调包装也能上状态栏，
%   状态文本用完整原因，颜色按等级：warn=琥珀、error=红
    if ~isvalid(sl), return; end
    cfg = SimuTidy_config();
    sl.Text = msg;
    if strcmp(level, 'error')
        sl.FontColor = cfg.colors.error;
    else
        sl.FontColor = cfg.colors.check;
    end
end

function onToggleTheme(fig)
%onToggleTheme 主题切换（3.2.0 新增）
%   写偏好 → 走定时器清理 → 销毁重建窗口。
%   选择"重建"而非就地改色：控件数量多，且各回调闭包持有旧 cfg 快照，
%   就地改色容易漏控件；重建走既有单例/定时器清理逻辑，最简单可靠
    cfg = SimuTidy_config();
    newTheme = sltidy_iif(strcmp(cfg.themeName, 'light'), 'dark', 'light');
    try
        setpref('SimuTidy', 'theme', newTheme);
    catch
    end
    t = fig.UserData.timer;
    if isvalid(t)
        try, stop(t); catch, end
        try, delete(t); catch, end
    end
    simutidy.internal.setLogSink([]);  % 3.3.0：旧窗口的 sink 一并注销
    delete(fig);
    SimuTidy_mainGUI();
end

function onClose(fig, t)
    if isvalid(t)
        try, stop(t); catch, end
        try, delete(t); catch, end
    end
    simutidy.internal.setLogSink([]);  % 3.3.0：sink 随窗口注销
    delete(fig);
end
