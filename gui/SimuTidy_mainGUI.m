function fig = SimuTidy_mainGUI()
%SimuTidy_mainGUI 创建SimuTidy主GUI界面
%   fig = SimuTidy_mainGUI()
%   返回创建的GUI窗口句柄
%
%   界面按功能分为5个分区（分区即配色）：
%       1. 视图与导出：导出Web视图（深海蓝）
%       2. 模块整理：对齐/等间距(8种)、大小统一（钢青蓝）
%       3. 连线整理：连线端口对齐、信号线命名、拆分Goto/From（青绿）
%       4. 接口与命名：生成接口、更新模块名称（靛紫）
%       5. 检查与诊断：高亮未连接端口（琥珀）
%
%   3.3.0 布局重构：绝对定位 → uigridlayout——窗口可缩放（'Resize' 默认 on），
%   控件随单元格伸展；记住窗口位置与尺寸（偏好 mainWindowPos，关窗时保存）。
%   回调与核心调用逻辑不变，仅容器换血。

    % 检查是否已有窗口打开（uifigure 默认句柄隐藏，须用 findall）
    % 3.4.1 修复：uifigure 的 delete 是**异步**的——刚关闭的窗口会短暂
    % 残留在 findall 结果里且 isvalid 仍为 true（异步中间态），单例检查
    % 直接返回会把死窗口交给用户（"关窗立刻重开"必现；isvalid 过滤
    % 治不了根，实测）。改为**存活标记**方案：创建时打
    % 'SimuTidy_Alive'=true，关闭路径先摘标再 delete，单例只认有标记的
    % 窗口——不依赖异步销毁时机，确定性行为
    fig = findall(0, 'Type', 'figure', 'Name', 'SimuTidy');
    fig = fig(arrayfun(@(f) isvalid(f) && isappdata(f, 'SimuTidy_Alive') ...
        && islogical(getappdata(f, 'SimuTidy_Alive')) ...
        && getappdata(f, 'SimuTidy_Alive'), fig));
    if ~isempty(fig)
        figure(fig(1));
        return;
    end

    cfg = SimuTidy_config();

    % 创建主窗口（3.3.0：位置/尺寸来自偏好，越界自动回落默认）
    fig = uifigure('Name', 'SimuTidy', ...
                   'Position', loadWindowPos(cfg), ...
                   'Color', cfg.gui.bgColor, ...
                   'WindowStyle', 'normal');
    setappdata(fig, 'SimuTidy_Alive', true);  % 3.4.1 存活标记（见上）

    g = uigridlayout(fig);
    g.ColumnWidth = {'1x'};
    % 3.3.1 行高经验值：必须给足余量——uifigure 在高 DPI 下控件最小尺寸
    % 变大，行高压到最小值以下时按钮会被裁成细条（用户实测截图反馈：
    % 标题行 26px 裁字、"连线整理"第二行被挤扁）
    % 3.4.0：新增第 8 行"运行日志"（110px：面板标题 ~24px + ~3 行文本），
    % 总高相应抬升
    g.RowHeight = {34, 20, 72, 162, 118, 72, 72, 110, 20, 24};
    g.RowSpacing = 6;
    g.ColumnSpacing = 8;
    g.Padding = [8, 8, 8, 8];

    % ===== 行1：标题 + 主题 + 引导 =====
    top = uigridlayout(g);
    top.Layout.Row = 1;
    top.Layout.Column = 1;
    top.ColumnWidth = {'1x', 76, 78};
    % 3.3.1：嵌套 grid 必须显式 Padding=0——默认 8px 内边距会把 34px 行
    % 吃剩 18px，主题/引导按钮下边缘被裁（与底部"设置"按钮同根因）
    top.RowHeight = {34};
    top.Padding = [0, 0, 0, 0];

    uilabel(top, 'Text', 'SimuTidy Simulink 辅助工具', ...
        'FontSize', 15, 'FontWeight', 'bold', 'FontColor', cfg.colors.text, ...
        'HorizontalAlignment', 'left');

    uibutton(top, 'push', 'Text', sltidy_iif(strcmp(cfg.themeName, 'light'), ...
        '深色主题', '浅色主题'), ...
        'FontSize', 9, 'BackgroundColor', cfg.gui.bgColor, ...
        'FontColor', cfg.colors.textSubtle, ...
        'Tooltip', '在浅色/深色主题间切换（重启窗口生效，偏好自动记住）', ...
        'ButtonPushedFcn', @(~,~) onToggleTheme(fig));

    uibutton(top, 'push', 'Text', '使用引导', ...
        'FontSize', 9, 'BackgroundColor', cfg.gui.bgColor, ...
        'FontColor', cfg.colors.textSubtle, ...
        'Tooltip', '重新查看新手引导', ...
        'ButtonPushedFcn', @(~,~) SimuTidy_onboarding());

    % ===== 行2：模型标签 =====
    modelLabel = uilabel(g, 'Text', sltidy_getModelName(), ...
        'FontSize', 10, 'FontColor', cfg.colors.textSubtle, ...
        'HorizontalAlignment', 'center');
    modelLabel.Layout.Row = 2;

    % ===== 行3：❶ 视图与导出 =====
    p1 = uipanel(g, 'Title', '  视图与导出  ', ...
        'BackgroundColor', cfg.gui.bgColor, ...
        'ForegroundColor', cfg.colors.panelTitle, 'FontWeight', 'bold');
    p1.Layout.Row = 3;
    pg1 = uigridlayout(p1);
    pg1.ColumnWidth = {'1x'};
    pg1.RowHeight = {34};
    pg1.RowSpacing = 8;
    pg1.Padding = [6, 6, 6, 6];

    uibutton(pg1, 'push', 'Text', '导出 Web 视图 (ZIP)', ...
        'FontSize', 12, 'FontWeight', 'bold', ...
        'BackgroundColor', cfg.colors.export, 'FontColor', [1 1 1], ...
        'Tooltip', '将当前模型导出为HTML Web视图ZIP包（需要Simulink Report Generator许可证）', ...
        'ButtonPushedFcn', @(~,~) onExportWebView(fig));

    % ===== 行4：❷ 模块整理 =====
    p2 = uipanel(g, 'Title', '  模块整理  ', ...
        'BackgroundColor', cfg.gui.bgColor, ...
        'ForegroundColor', cfg.colors.panelTitle, 'FontWeight', 'bold');
    p2.Layout.Row = 4;
    pg2 = uigridlayout(p2);
    pg2.RowHeight = {34, 34, 34};
    pg2.ColumnWidth = {'1x', '1x', '1x', '1x'};
    pg2.RowSpacing = 8;
    pg2.Padding = [6, 6, 6, 6];

    alignDefs = { ...
        '左对齐',   'left',    '所有选中模块左边缘对齐到基准模块（最上最左）'
        '右对齐',   'right',   '所有选中模块右边缘对齐到基准模块（最上最左）'
        '顶部对齐', 'top',     '所有选中模块顶边对齐到基准模块（最上最左）'
        '底部对齐', 'bottom',  '所有选中模块底边对齐到基准模块（最上最左）'
        '水平居中', 'hcenter', '所有选中模块水平中心线对齐到基准模块（最上最左）'
        '垂直居中', 'vcenter', '所有选中模块垂直中心线对齐到基准模块（最上最左）'
        '水平等间距', 'hspace', '按水平中心将选中模块等间距分布（锚点：中心最小/最大的两块，其余块含基准块参与移动）'
        '垂直等间距', 'vspace', '按垂直中心将选中模块等间距分布（锚点：中心最小/最大的两块，其余块含基准块参与移动）'};
    for k = 1:size(alignDefs, 1)
        b = uibutton(pg2, 'push', 'Text', alignDefs{k, 1}, ...
            'FontSize', 11, 'BackgroundColor', cfg.colors.module, ...
            'FontColor', [1 1 1], 'Tooltip', alignDefs{k, 3}, ...
            'ButtonPushedFcn', @(~,~) doAlign(fig, alignDefs{k, 2}));
        b.Layout.Row = ceil(k / 4);
        b.Layout.Column = mod(k - 1, 4) + 1;
    end

    bSize = uibutton(pg2, 'push', 'Text', '大小统一', ...
        'FontSize', 11, 'BackgroundColor', cfg.colors.moduleDark, ...
        'FontColor', [1 1 1], ...
        'Tooltip', '以基准模块（最上最左）为准统一选中模块大小，保持中心点不变', ...
        'ButtonPushedFcn', @(~,~) onUniformSize(fig));
    bSize.Layout.Row = 3;
    bSize.Layout.Column = [1, 4];

    % ===== 行5：❸ 连线整理 =====
    p3 = uipanel(g, 'Title', '  连线整理  ', ...
        'BackgroundColor', cfg.gui.bgColor, ...
        'ForegroundColor', cfg.colors.panelTitle, 'FontWeight', 'bold');
    p3.Layout.Row = 5;
    pg3 = uigridlayout(p3);
    % 3.3.1 拍平嵌套：此前第二行用了嵌套 grid，被外层固定行高挤压成
    % 细条（嵌套自身的 Padding/最小尺寸吃掉了 32px 行）。改为单层
    % 2 行网格：第一行跨 3 列，第二行 3 个按钮
    pg3.RowHeight = {34, 34};
    pg3.ColumnWidth = {'1x', '1x', '1x'};
    pg3.RowSpacing = 8;
    pg3.Padding = [6, 6, 6, 6];

    bPort = uibutton(pg3, 'push', 'Text', '连线端口对齐', ...
        'FontSize', 12, 'FontWeight', 'bold', ...
        'BackgroundColor', cfg.colors.lineDark, 'FontColor', [1 1 1], ...
        'Tooltip', '以选中模块连线的另一端端口为基准（不动），垂直移动选中模块使端口同高，连线变为水平直线（只调垂直位置，不改水平位置）', ...
        'ButtonPushedFcn', @(~,~) onAlignLinePorts(fig));
    bPort.Layout.Row = 1;
    bPort.Layout.Column = [1, 3];

    bName = uibutton(pg3, 'push', 'Text', '信号线命名', ...
        'FontSize', 11, 'BackgroundColor', cfg.colors.line, 'FontColor', [1 1 1], ...
        'Tooltip', '打开命名对话框：按源模块名/源模块名+端口号/输出端口命名信号线，或清除命名', ...
        'ButtonPushedFcn', @(~,~) SimuTidy_nameDialog(fig));
    bName.Layout.Row = 2;
    bName.Layout.Column = 1;

    bSplit = uibutton(pg3, 'push', 'Text', '拆分 Goto/From', ...
        'FontSize', 11, 'BackgroundColor', cfg.colors.line, 'FontColor', [1 1 1], ...
        'Tooltip', '将选中的长连线批量拆分为Goto/From对（支持多选；Goto在源端、From在目标端，两端模块外移留出间距）', ...
        'ButtonPushedFcn', @(~,~) onSplitGoto(fig));
    bSplit.Layout.Row = 2;
    bSplit.Layout.Column = 2;

    bResolve = uibutton(pg3, 'push', 'Text', '信号对象解析', ...
        'FontSize', 11, 'BackgroundColor', cfg.colors.line, 'FontColor', [1 1 1], ...
        'Tooltip', '为当前层级所有有名字的信号线勾选"信号名称必须解析为Simulink对象"（更新图时强制校验名字指向工作区对象）；选中线则只处理选中的；mode off 可取消', ...
        'ButtonPushedFcn', @(~,~) onSetSignalResolve(fig));
    bResolve.Layout.Row = 2;
    bResolve.Layout.Column = 3;

    % ===== 行6：❹ 接口与命名 =====
    p4 = uipanel(g, 'Title', '  接口与命名  ', ...
        'BackgroundColor', cfg.gui.bgColor, ...
        'ForegroundColor', cfg.colors.panelTitle, 'FontWeight', 'bold');
    p4.Layout.Row = 6;
    pg4 = uigridlayout(p4);
    pg4.RowHeight = {34};
    pg4.ColumnWidth = {'1x', '1x'};
    pg4.RowSpacing = 8;
    pg4.Padding = [6, 6, 6, 6];

    uibutton(pg4, 'push', 'Text', '生成接口', ...
        'FontSize', 11, 'BackgroundColor', cfg.colors.port, 'FontColor', [1 1 1], ...
        'Tooltip', '为选中的Subsystem未连接端口自动添加Inport/Outport块并连线', ...
        'ButtonPushedFcn', @(~,~) onGeneratePorts(fig));
    uibutton(pg4, 'push', 'Text', '更新模块名称', ...
        'FontSize', 11, 'BackgroundColor', cfg.colors.portDark, 'FontColor', [1 1 1], ...
        'Tooltip', '将Inport/Outport模块名更新为信号线名；Inport无信号名时用外层传入名，重名自动追加序号', ...
        'ButtonPushedFcn', @(~,~) onUpdateBlockNames(fig));

    % ===== 行7：❺ 检查与诊断 =====
    p5 = uipanel(g, 'Title', '  检查与诊断  ', ...
        'BackgroundColor', cfg.gui.bgColor, ...
        'ForegroundColor', cfg.colors.panelTitle, 'FontWeight', 'bold');
    p5.Layout.Row = 7;
    pg5 = uigridlayout(p5);
    pg5.RowHeight = {34};
    % 3.4.0：诊断三功能并排一行（高亮/重叠/GotoFrom 配对），不增行高、
    % 主窗口总高度不变
    pg5.ColumnWidth = {'1x', '1x', '1x'};
    pg5.RowSpacing = 8;
    pg5.Padding = [6, 6, 6, 6];

    uibutton(pg5, 'push', 'Text', '高亮未连接端口', ...
        'FontSize', 11, 'BackgroundColor', cfg.colors.check, 'FontColor', [1 1 1], ...
        'Tooltip', '高亮有未连接端口的模块及悬空信号线；再次运行刷新状态，已连接的自动取消高亮；3.4.0 起失败项可在结果面板逐条定位', ...
        'ButtonPushedFcn', @(~,~) onHighlightUnconnected(fig));

    % 3.4.0 新增：模块重叠检测
    uibutton(pg5, 'push', 'Text', '重叠检测', ...
        'FontSize', 11, 'BackgroundColor', cfg.colors.check, 'FontColor', [1 1 1], ...
        'Tooltip', '检查当前层级两两重叠的模块（AABB），发现项在结果面板逐条定位', ...
        'ButtonPushedFcn', @(~,~) onCheckOverlaps(fig));

    % 3.4.0 新增：Goto/From 配对诊断
    uibutton(pg5, 'push', 'Text', 'Goto/From 配对诊断', ...
        'FontSize', 11, 'BackgroundColor', cfg.colors.check, 'FontColor', [1 1 1], ...
        'Tooltip', '检查悬空 Goto（无 From 引用）、无源 From、跨层 local 标签引用（仿真会报错）；发现项在结果面板逐条定位', ...
        'ButtonPushedFcn', @(~,~) onCheckGotoFrom(fig));

    % ===== 行8：运行日志（3.4.0 新增）=====
    % 只读追加区：显示每次操作的完整明细（对齐基准/跳过原因/诊断发现），
    % 弥补状态栏"只看得到最后一条"的不足；命令行输出保持不变
    % 3.4.0 追改：标题用 uipanel Title 固定在日志区上方（用户反馈：原标题
    % 混在 textarea 首行，新增行插顶后会被推下去"下沉"且被选中态干扰；
    % 面板标题与其他分区标题样式一致，恒定可见）
    p6 = uipanel(g, 'Title', '  运行日志  ', ...
        'BackgroundColor', cfg.gui.bgColor, ...
        'ForegroundColor', cfg.colors.panelTitle, 'FontWeight', 'bold');
    p6.Layout.Row = 8;
    pg6 = uigridlayout(p6);
    pg6.ColumnWidth = {'1x'};
    pg6.RowHeight = {'1x'};  % 单行伸展占满面板
    pg6.Padding = [2, 2, 2, 2];
    logArea = uitextarea(pg6, ...
        'Editable', 'off', ...
        'FontName', 'Consolas', 'FontSize', 9, ...
        'BackgroundColor', cfg.gui.bgColor, ...
        'Value', '');

    % ===== 行9：状态标签 =====
    statusLabel = uilabel(g, 'Text', '就绪', ...
        'FontSize', 9, 'FontColor', cfg.colors.textFaint, ...
        'HorizontalAlignment', 'center');
    statusLabel.Layout.Row = 9;

    % ===== 行10：开发者信息 + 设置 =====
    foot = uigridlayout(g);
    foot.Layout.Row = 10;
    foot.ColumnWidth = {'1x', 64};
    % 3.3.1：嵌套网格必须显式给行高并收紧 Padding，否则内部按钮被
    % 默认值挤成 0 高（实测"设置"按钮不可见）
    foot.RowHeight = {24};
    foot.Padding = [0, 0, 0, 0];
    uilabel(foot, 'Text', '开发者: Henry  |  1378099981@qq.com  |  github.com/zyd180', ...
        'FontSize', 8, 'FontColor', cfg.colors.textFaint, ...
        'HorizontalAlignment', 'center');
    % 3.3.0 设置入口：图形化编辑高价值配置子集，写入用户 JSON
    uibutton(foot, 'push', 'Text', '设置', ...
        'FontSize', 9, 'BackgroundColor', cfg.gui.bgColor, ...
        'FontColor', cfg.colors.textSubtle, ...
        'Tooltip', '编辑常用配置（写入用户配置文件，部分项需重开窗口生效）', ...
        'ButtonPushedFcn', @(~,~) SimuTidy_settingsDialog());

    % 存储用户数据
    fig.UserData.statusLabel = statusLabel;
    fig.UserData.modelLabel = modelLabel;

    % 3.3.0 统一日志：注册状态栏 sink——核心函数内的 WARN/ERROR 自动上屏
    %（warn=琥珀色 error=红色）；3.4.0：info 及以上同时追加进日志区；
    % 关窗/切主题时清除（见 onClose/onToggleTheme）
    simutidy.internal.setLogSink(@(msg, level) guiLogSink(statusLabel, msg, level, logArea));

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
        % 3.1.0 命名空间化：GUI 属内部调用方，直调 +simutidy 包实体；
        % slXxx 包装仅供外部脚本与 sl_customization 菜单使用
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
        % 3.3.0 结果反馈 + 进度条：接 res 弹失败面板；'Progress' 传主窗口
        res = simutidy.alignLinePorts([], 'Progress', fig);
        sl.Text = '连线端口对齐完成';
        sl.FontColor = cfg.colors.success;
        SimuTidy_resultPanel(res);
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
        % 3.3.0 结果反馈 + 进度条（同 onAlignLinePorts）
        res = simutidy.splitGotoFrom([], 'Progress', fig);
        sl.Text = '拆分完成';
        sl.FontColor = cfg.colors.success;
        SimuTidy_resultPanel(res);
    catch ME
        sl.Text = ['错误: ' ME.message]; sl.FontColor = cfg.colors.error;
    end
end

function onHighlightUnconnected(fig)
    sl = fig.UserData.statusLabel;
    cfg = SimuTidy_config();
    sl.Text = '正在高亮...'; sl.FontColor = cfg.colors.check; drawnow;
    try
        % 3.3.0 进度条：高亮逐块机制慢，GUI 路径带进度与取消
        % 3.4.0 结果反馈：接 res 弹结果面板逐条定位
        res = simutidy.highlightUnconnected([], 'Progress', fig);
        sl.Text = '高亮完成';
        sl.FontColor = cfg.colors.success;
        SimuTidy_resultPanel(res);
    catch ME
        sl.Text = ['错误: ' ME.message]; sl.FontColor = cfg.colors.error;
    end
end

function onCheckOverlaps(fig)
    % 3.4.0 新增：模块重叠检测（纯几何，无进度条必要）
    sl = fig.UserData.statusLabel;
    cfg = SimuTidy_config();
    sl.Text = '正在检测重叠...'; sl.FontColor = cfg.colors.check; drawnow;
    try
        res = simutidy.checkOverlaps();
        sl.Text = '重叠检测完成';
        sl.FontColor = cfg.colors.success;
        SimuTidy_resultPanel(res);
    catch ME
        sl.Text = ['错误: ' ME.message]; sl.FontColor = cfg.colors.error;
    end
end

function onCheckGotoFrom(fig)
    % 3.4.0 新增：Goto/From 配对诊断
    sl = fig.UserData.statusLabel;
    cfg = SimuTidy_config();
    sl.Text = '正在诊断 Goto/From 配对...'; sl.FontColor = cfg.colors.check; drawnow;
    try
        res = simutidy.checkGotoFrom();
        sl.Text = '配对诊断完成';
        sl.FontColor = cfg.colors.success;
        SimuTidy_resultPanel(res);
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
        % 3.3.0 进度条：IO 数量大时逐块反馈
        simutidy.updateBlockNames([], 'Progress', fig);
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
function pos = loadWindowPos(cfg)
%loadWindowPos 读取记忆的窗口位置/尺寸（3.3.0 可缩放布局配套）
%   偏好缺失/非法时回落 cfg.gui.mainPosition；存在的值夹回屏幕范围，
%   防止显示器变更后窗口完全跑出屏外
    pos = cfg.gui.mainPosition;
    try
        p = getpref('SimuTidy', 'mainWindowPos');
        if isnumeric(p) && numel(p) == 4 && all(isfinite(p))
            ss = get(0, 'ScreenSize');
            p(3) = min(max(p(3), 420), ss(3));      % 最小宽 420
            % 3.3.1：最小高抬到 700——gridlayout 固定行高合计 ~660，
            % 旧版记忆的 620 会裁掉底部；用旧偏好的用户被自动抬到可用高度
            % 3.4.0：700→800——新增"运行日志"区（行高合计 ~774），同理
            p(4) = min(max(p(4), 800), ss(4));
            p(1) = min(max(p(1), 80 - p(3)), ss(3) - 80);
            p(2) = min(max(p(2), 40 - p(4)), ss(4) - 40);
            pos = p;
        end
    catch
    end
end

function saveWindowPos(fig)
%saveWindowPos 关窗/重建前保存窗口位置与尺寸（3.3.0）
    try
        if isvalid(fig)
            setpref('SimuTidy', 'mainWindowPos', fig.Position);
        end
    catch
    end
end

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

function guiLogSink(sl, msg, level, logArea)
%guiLogSink 日志接收器（3.3.0 状态栏；3.4.0 扩展为状态栏+日志区双出口）
%   状态栏：完整原因文本，颜色按等级（warn=琥珀、error=红，info 不动状态栏）
%   日志区：info 及以上全部追加（新行插**顶部**——uitextarea 无自动滚动
%   API，追加到底部时最新内容不可见；插顶保证最新明细始终可见，代价是
%   时间倒序，为可见性取舍）。上限 200 行防无限增长
    if nargin < 4 || ~isvalid(logArea)
        return;
    end
    cfg = SimuTidy_config();
    if ~strcmp(level, 'info') && isvalid(sl)
        sl.Text = msg;
        if strcmp(level, 'error')
            sl.FontColor = cfg.colors.error;
        else
            sl.FontColor = cfg.colors.check;
        end
    end
    % 日志区追加（新行在顶），截断到 200 行
    lines = logArea.Value;
    if ischar(lines), lines = cellstr(lines); end
    logArea.Value = [{sprintf('[%s] %s', upper(level), msg)}; lines(1:min(end, 199))];
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
    saveWindowPos(fig);   % 3.3.0：重建前记住当前位置/尺寸
    setappdata(fig, 'SimuTidy_Alive', false);  % 3.4.1：先摘存活标记再删
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
    saveWindowPos(fig);   % 3.3.0：记住窗口位置/尺寸
    setappdata(fig, 'SimuTidy_Alive', false);  % 3.4.1：先摘存活标记再删
    if isvalid(t)
        try, stop(t); catch, end
        try, delete(t); catch, end
    end
    simutidy.internal.setLogSink([]);  % 3.3.0：sink 随窗口注销
    delete(fig);
end
