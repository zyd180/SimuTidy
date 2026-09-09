function cfg = SimuTidy_config()
%SimuTidy_config SimuTidy工具配置文件
%   所有可调参数集中管理，修改此文件即可全局生效

    %% 版本信息
    cfg.version = '3.0.0';
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
    cfg.gui.alignDialogPos = [520, 380, 320, 340];
    cfg.gui.nameDialogPos = [520, 360, 320, 300];
    cfg.gui.bgColor = [0.961 0.969 0.976];  % 窗口背景 浅灰白 #F5F7F9
    cfg.gui.refreshInterval = 1;  % 模型标签刷新间隔（秒）
    cfg.gui.showOnboarding = true;  % 首次启动自动弹出新手引导

    %% 颜色配置（靛青专业系：低饱和分区配色，分区即配色）
    cfg.colors.panelTitle = [0.267 0.294 0.322];  % 面板标题文字 #444B52
    cfg.colors.export     = [0.169 0.365 0.561];  % 视图与导出 深海蓝 #2B5D8F
    cfg.colors.module     = [0.243 0.486 0.651];  % 模块整理-普通 钢青蓝 #3E7CA6
    cfg.colors.moduleDark = [0.180 0.376 0.514];  % 模块整理-主操作 深钢青 #2E6083
    cfg.colors.line       = [0.180 0.545 0.455];  % 连线整理-普通 青绿 #2E8B74
    cfg.colors.lineDark   = [0.137 0.439 0.361];  % 连线整理-主操作 深青绿 #23705C
    cfg.colors.port       = [0.420 0.373 0.647];  % 接口与命名-普通 靛紫 #6B5FA5
    cfg.colors.portDark   = [0.329 0.290 0.522];  % 接口与命名-主操作 深靛紫 #544A85
    cfg.colors.check      = [0.788 0.541 0.176];  % 检查与诊断 琥珀 #C98A2D
    cfg.colors.success    = [0.224 0.569 0.310];  % 状态-成功 #39914F
    cfg.colors.error      = [0.780 0.290 0.259];  % 状态-出错 #C74A42
    
    %% Simulink API配置
    cfg.simulink.updateAfterChange = true;  % 修改后是否自动更新模型
end
