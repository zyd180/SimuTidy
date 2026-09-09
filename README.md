# SimuTidy - Simulink 建模辅助工具

[![MATLAB](https://img.shields.io/badge/MATLAB-R2016b%2B-blue.svg)](https://www.mathworks.com/products/matlab.html)
[![Simulink](https://img.shields.io/badge/Simulink-R2016b%2B-orange.svg)](https://www.mathworks.com/products/simulink.html)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

SimuTidy 是一款 Simulink 建模辅助小工具，提供模块对齐、连线优化、信号命名等功能，帮助工程师快速整理 Simulink 模型。

> 详细使用说明见 [USER_GUIDE.md](USER_GUIDE.md)（使用手册）。

## 开发者

- **开发者**：Henry
- **邮箱**：1378099981@qq.com
- **GitHub**：<https://github.com/zyd180>

## 功能特性

| 功能 | 说明 |
|------|------|
| **导出 Web 视图** | 将模型导出为 HTML Web 视图 ZIP 包 |
| **连线端口对齐** | 以连线另一端端口为基准，垂直移动选中模块使端口同高，连线变水平直线 |
| **模块对齐** | 支持左/右/上/下/居中对齐，以及水平/垂直等间距分布 |
| **模块大小统一** | 统一选中模块的大小，支持多种模式 |
| **信号线命名** | 按源模块名、端口号或输出端口自动命名信号线 |
| **Goto/From 拆分** | 选中信号线批量拆分为 Goto/From 对（支持多选，空间不足自动推块） |
| **信号对象解析** | 当前层级有名字的信号线批量勾选"信号名称必须解析为 Simulink 对象" |
| **高亮未连接端口** | 高亮显示模型中未连接的端口 |
| **生成接口** | 自动为Subsystem未连接端口添加Inport/Outport并连线 |
| **更新模块名称** | Inport/Outport改为信号名，沿信号链追溯源端名，改名后图标显示端口号 |

## 系统要求

- MATLAB R2016b 或更高版本（Toolstrip 选项卡需 R2022b+，旧版自动回退 Tools 菜单）
- Simulink
- （可选）Simulink Report Generator - 用于导出 Web 视图功能

## 安装

### 推荐：一键部署（Windows）

双击根目录下的 **`SimuTidy_deploy.bat`** 即可，脚本会自动调用 MATLAB 静默完成全部安装（需要 R2019a+，且 `matlab` 在系统 PATH 中）。

### 或：永久集成安装

```matlab
% 1. 将 SimuTidy 文件夹添加到 MATLAB 路径
addpath('C:\path\to\SimuTidy');

% 2. 运行永久安装脚本
SimuTidy_install
```

安装脚本会自动：
- 将 SimuTidy 路径保存到永久路径
- 生成 `sl_customization.m` 到用户目录
- 添加启动配置到 `startup.m`
- 自动刷新 Simulink 菜单

**重启 MATLAB 后，SimuTidy 将自动加载到 Simulink 工具栏。**

### 临时安装（不推荐）

```matlab
addpath('C:\path\to\SimuTidy');
addpath('C:\path\to\SimuTidy\gui');
addpath('C:\path\to\SimuTidy\core');
addpath('C:\path\to\SimuTidy\utils');
sl_refresh_customizations
```

### 卸载

```matlab
SimuTidy_uninstall
% 重启 MATLAB
```

## 使用方法

### 打开 GUI

```matlab
SimuTidy
```

### 命令行使用

```matlab
% 导出 Web 视图
slExportWebView()

% 连线端口对齐（垂直移动选中模块，与连线另一端端口对齐）
slAlignLinePorts()

% 模块对齐
slAlignBlocks([], 'left')     % 左对齐
slAlignBlocks([], 'right')    % 右对齐
slAlignBlocks([], 'hspace')   % 水平等间距

% 模块大小统一
slUniformSize()               % 以基准模块为准
slUniformSize([], 'max')      % 以最大模块为准

% 信号线命名
slAutoNameSignals([], 'source')       % 按源模块名
slAutoNameSignals([], 'source_port')  % 按源模块+端口号
slAutoNameSignals([], 'outport')      % 按输出端口
slAutoNameSignals([], 'clear')        % 清除命名

% Goto/From 拆分（支持多选批量拆分）
slSplitGotoFrom()

% 信号对象解析（批量勾选"信号名称必须解析为 Simulink 对象"）
slSetSignalResolve()                 % 勾选
slSetSignalResolve([], 'off')        % 取消勾选

% 生成接口（选中Subsystem后运行）
slGeneratePorts()

% 高亮未连接端口
slHighlightUnconnected()
slHighlightUnconnected([], true)  % 清除高亮

% 更新模块名称（Inport/Outport改为信号名，沿信号链追溯源端名，图标显示端口号）
slUpdateBlockNames()
slUpdateBlockNames('my_model/Subsystem')  % 指定子系统
```

### Simulink 工具栏

安装后有两种入口：

**SimuTidy 选项卡**（R2022b+）：打开模型后，顶部工具条在"格式"和"APP"之间会出现 **SimuTidy** 选项卡，包含全部功能的工具条按钮（第一个按钮为"打开 SimuTidy 窗口"），布局与 APP 栏一致。

**Tools 菜单**（兼容入口）：在 Simulink 模型的 **Tools** 菜单底部也会显示 SimuTidy 工具栏：

- **打开 SimuTidy 窗口** - 打开主 GUI
- **导出 Web 视图** - 快速导出
- **连线端口对齐** - 一键对齐端口
- **模块对齐** - 子菜单包含所有对齐选项
- **信号线命名** - 子菜单包含所有命名选项

## 目录结构

```
SimuTidy/
├── SimuTidy.m                    # 入口函数
├── SimuTidy_config.m             # 配置文件
├── SimuTidy_install.m            # 安装脚本
├── SimuTidy_check.m              # 安装检查
├── gui/                     # GUI 模块
│   ├── SimuTidy_mainGUI.m        # 主界面
│   ├── SimuTidy_alignDialog.m    # 对齐对话框
│   └── SimuTidy_nameDialog.m     # 命名对话框
├── core/                    # 核心功能
│   ├── slExportWebView.m
│   ├── slAlignLinePorts.m
│   ├── slAlignBlocks.m
│   ├── slUniformSize.m
│   ├── slAutoNameSignals.m
│   ├── slSplitGotoFrom.m
│   ├── slSetSignalResolve.m
│   ├── slHighlightUnconnected.m
│   ├── slGeneratePorts.m
│   └── slUpdateBlockNames.m
├── utils/                   # 工具函数
│   ├── sltidy_iif.m
│   └── sltidy_getModelName.m
├── README.md                # 本文件
└── CHANGELOG.md             # 更新日志
```

## 配置

编辑 `SimuTidy_config.m` 可自定义以下参数：

```matlab
cfg = SimuTidy_config();

% Goto/From 模块配置
cfg.goto.defaultWidth = 60;    % 默认宽度
cfg.goto.defaultHeight = 30;   % 默认高度
cfg.goto.gap = 40;             % 与源/目标模块的间距

% 信号命名配置
cfg.naming.maxNameLength = 63; % Simulink 名称长度限制

% GUI 配置
cfg.gui.refreshInterval = 1;   % 模型标签刷新间隔（秒）
```

## 故障排查

运行以下命令检查安装状态：

```matlab
SimuTidy_check
```

常见问题：

1. **菜单不显示**
   - 运行 `sl_refresh_customizations`
   - 检查 `sl_customization.m` 是否在用户目录中

2. **功能不可用**
   - 确保 SimuTidy 文件夹及其子目录都在 MATLAB 路径中
   - 运行 `SimuTidy_check` 查看详细状态

## 版本历史

详见 [CHANGELOG.md](CHANGELOG.md)

## 许可证

MIT License

## 贡献

欢迎提交 Issue 和 Pull Request。

## 致谢

感谢所有 Simulink 用户的反馈和建议。
