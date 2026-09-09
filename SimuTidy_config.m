function cfg = SimuTidy_config()
%SimuTidy_config SimuTidy工具配置文件
%   所有可调参数集中管理，修改此文件即可全局生效
%   3.3.0：新增用户级覆盖（userpath/SimuTidy_config_user.json），
%   坏文件一次性告警（persistent 防刷屏，见文件末尾）

    persistent warnedBad   % 用户配置解析失败的"只告警一次"标志（函数顶部声明）

    %% 版本信息
    cfg.version = '3.2.0';
    cfg.versionDate = '2026-09-08';
    
    %% Goto/From模块配置
    cfg.goto.defaultWidth = 60;
    cfg.goto.defaultHeight = 30;
    cfg.goto.gap = 40;
    cfg.goto.tagVisibility = 'local';
    
    %% 信号命名配置
    cfg.naming.maxNameLength = 63;  % Simulink名称长度限制
    cfg.naming.replaceChars = '[\/\s\-\<\>\?\*\|\"\:\.]';
    cfg.naming.replaceWith = '_';
    
    %% GUI配置
    cfg.gui.mainPosition = [500, 120, 460, 620];
    % 3.1.0 清理：原 cfg.gui.alignDialogPos 已随死代码 SimuTidy_alignDialog
    % 一并删除（该对话框无任何调用方，主窗口自带对齐按钮组）
    cfg.gui.nameDialogPos = [520, 360, 320, 300];
    % 3.2.0：bgColor 移入主题调色板（见下方"主题配置"），此处不再直接定义；
    % gui 代码继续读 cfg.gui.bgColor（字段路径兼容 2.6.1 以来写法）
    cfg.gui.refreshInterval = 1;  % 模型标签刷新间隔（秒）
    cfg.gui.showOnboarding = true;  % 首次启动自动弹出新手引导

    %% 主题配置（3.2.0：浅色/深色双调色板，两套字段名完全一致）
    % 设计：消费方只读 cfg.colors.*（兼容 2.6.1 以来的既有字段名），
    % GUI 代码零改动换肤。主题由用户偏好 getpref('SimuTidy','theme') 决定
    % （主窗口"主题"按钮切换），偏好缺失/非法一律回落浅色（零迁移成本）。
    cfg.themes.light = struct( ...
        'bgColor',    [0.961 0.969 0.976], ...  % 窗口背景 浅灰白 #F5F7F9
        'text',       [0.2 0.2 0.2], ...        % 主文字（窗口标题）
        'textSubtle', [0.4 0.4 0.4], ...        % 次要文字（模型标签/引导正文）
        'textFaint',  [0.55 0.55 0.55], ...     % 弱文字（状态栏/开发者信息）
        'btnGrey',    [0.58 0.58 0.58], ...     % 中性灰按钮（关闭/清除/跳过）
        'panelTitle', [0.267 0.294 0.322], ...  % 面板标题文字 #444B52
        'export',     [0.169 0.365 0.561], ...  % 视图与导出 深海蓝 #2B5D8F
        'module',     [0.243 0.486 0.651], ...  % 模块整理-普通 钢青蓝 #3E7CA6
        'moduleDark', [0.180 0.376 0.514], ...  % 模块整理-主操作 深钢青 #2E6083
        'line',       [0.180 0.545 0.455], ...  % 连线整理-普通 青绿 #2E8B74
        'lineDark',   [0.137 0.439 0.361], ...  % 连线整理-主操作 深青绿 #23705C
        'port',       [0.420 0.373 0.647], ...  % 接口与命名-普通 靛紫 #6B5FA5
        'portDark',   [0.329 0.290 0.522], ...  % 接口与命名-主操作 深靛紫 #544A85
        'check',      [0.788 0.541 0.176], ...  % 检查与诊断 琥珀 #C98A2D
        'success',    [0.224 0.569 0.310], ...  % 状态-成功 #39914F
        'error',      [0.780 0.290 0.259]);     % 状态-出错 #C74A42
    % 深色取值原则：背景压到 #1E2227 系；分区色整体提亮一档（暗底上保持
    % "分区即配色"可辨识度）；文字全反转；成功/错误提高明度保对比度
    cfg.themes.dark = struct( ...
        'bgColor',    [0.118 0.133 0.153], ...  % 窗口背景 深灰蓝 #1E2227
        'text',       [0.88 0.90 0.92], ...
        'textSubtle', [0.70 0.73 0.78], ...
        'textFaint',  [0.52 0.56 0.62], ...
        'btnGrey',    [0.30 0.33 0.38], ...
        'panelTitle', [0.85 0.87 0.90], ...
        'export',     [0.35 0.58 0.82], ...
        'module',     [0.42 0.64 0.82], ...
        'moduleDark', [0.33 0.55 0.74], ...
        'line',       [0.30 0.68 0.58], ...
        'lineDark',   [0.24 0.58 0.49], ...
        'port',       [0.56 0.51 0.78], ...
        'portDark',   [0.46 0.41 0.66], ...
        'check',      [0.90 0.65 0.30], ...
        'success',    [0.35 0.72 0.45], ...
        'error',      [0.90 0.44 0.40]);

    % 解析当前主题
    themeName = 'light';
    try
        themeName = getpref('SimuTidy', 'theme');
    catch
    end
    if ~any(strcmp(themeName, {'light', 'dark'}))
        themeName = 'light';
    end
    cfg.themeName = char(themeName);
    cfg.colors = cfg.themes.(cfg.themeName);
    % 兼容字段：gui 代码原样读 cfg.gui.bgColor（字段路径保持 2.6.1 写法）
    cfg.gui.bgColor = cfg.colors.bgColor;

    %% 日志配置（3.3.0 统一日志系统）
    cfg.log.level = 'info';   % debug/info/warn/error

    %% 用户级配置覆盖（3.3.0，必须放在所有默认值之后：代码默认 < 用户 JSON）
    % 文件：userpath/SimuTidy_config_user.json；白名单/类型校验与写入端
    % 共用 +internal/userConfig 的同一张表。
    % 防刷屏设计：config() 被每次功能调用/日志输出触发，坏文件只告警一次；
    % 非白名单键/类型不符静默跳过（手编文件的兜底，不值得每次刷警告）
    uf = simutidy.internal.userConfig('path');
    if isfile(uf)
        if isempty(warnedBad), warnedBad = false; end
        try
            data = jsondecode(fileread(uf));
            if isstruct(data)
                wl = simutidy.internal.userConfig('list');
                % 嵌套格式：{"goto":{"gap":77}} → 遍历 组/字段 两级，
                % 每项过白名单+类型校验（与写入端同一张表，口径不分叉）
                groups = fieldnames(data);
                for gi = 1:numel(groups)
                    g = groups{gi};
                    if ~isfield(cfg, g) || ~isstruct(data.(g)), continue; end
                    fk = fieldnames(data.(g));
                    for fi = 1:numel(fk)
                        key = [g '.' fk{fi}];
                        hit = find(strcmp(wl(:, 1), key), 1);
                        if isempty(hit), continue; end
                        v = data.(g).(fk{fi});
                        if ~isa(v, wl{hit, 2}), continue; end
                        cfg.(g).(fk{fi}) = v;
                    end
                end
            end
        catch ME
            if ~warnedBad
                warnedBad = true;
                warning('SimuTidy:badUserConfig', ...
                    '用户配置文件解析失败，已忽略（%s）', ME.message);
            end
        end
    end
    
    %% Simulink API配置
    % 3.1.0 语义变更：此开关只对"需要编译校验"的操作生效（信号对象解析、
    % 生成接口）。纯几何操作（对齐/大小统一/端口对齐）不再触发 update——
    % 移动块后 Simulink 自动重排连线，编译刷新纯属浪费（500 块实测单次
    % ~0.16s）。变更理由详见 CHANGELOG 3.1.0 性能优化条目。
    cfg.simulink.updateAfterChange = true;  % 修改后是否自动更新模型
end
