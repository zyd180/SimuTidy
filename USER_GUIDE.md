# SimuTidy 使用手册

**SimuTidy — Simulink 建模辅助小工具**

版本：3.3.0（2026-09-09）

---

## 目录

- [1. 简介](#1-简介)
- [2. 系统要求](#2-系统要求)
- [3. 安装与卸载](#3-安装与卸载)
- [4. 启动方式](#4-启动方式)
- [5. 主窗口界面说明](#5-主窗口界面说明)
- [6. 功能详解](#6-功能详解)
  - [6.1 导出 Web 视图](#61-导出-web-视图)
  - [6.2 连线端口对齐](#62-连线端口对齐)
  - [6.3 模块对齐与分布](#63-模块对齐与分布)
  - [6.4 模块大小统一](#64-模块大小统一)
  - [6.5 信号线命名](#65-信号线命名)
  - [6.6 拆分 Goto/From（批量）](#66-拆分-gotofrom批量)
  - [6.7 高亮未连接端口](#67-高亮未连接端口)
  - [6.8 生成接口](#68-生成接口)
  - [6.9 更新模块名称](#69-更新模块名称)
  - [6.10 信号对象解析](#610-信号对象解析)
  - [6.11 模块重叠检测](#611-模块重叠检测)
  - [6.12 Goto/From 配对诊断](#612-gotofrom-配对诊断)
- [7. Simulink 工具栏](#7-simulink-工具栏)
- [8. 命令行参考](#8-命令行参考)
- [9. 配置文件详解](#9-配置文件详解)
- [10. 典型工作流示例](#10-典型工作流示例)
- [11. 故障排查](#11-故障排查)
- [12. 注意事项与已知限制](#12-注意事项与已知限制)
- [13. 版本历史](#13-版本历史)
- [14. 开发者信息](#14-开发者信息)

---

## 1. 简介

SimuTidy 是一款面向 Simulink 工程师的建模辅助小工具，用于快速整理和规范化 Simulink 模型。它把日常建模中重复、繁琐的手工操作（对齐、拉线、命名、拆线、补接口、批量改名等）做成了一键功能。

核心特点：

- **零依赖**：纯 MATLAB 代码实现，不需要任何第三方工具箱（仅"导出 Web 视图"需要 Simulink Report Generator 许可证）
- **GUI 与命令行双入口**：所有功能既能点按钮，也能在命令行直接调用
- **Simulink 深度集成**：安装后功能直接出现在 Simulink 的 Tools 菜单里
- **批量操作**：对齐、命名、拆线等功能均支持当前子系统的全部选中对象
- **碰撞感知**：Goto/From 拆分时会自动检查周围空间，绝不把布局搞乱

适用场景：基于模型的开发（MBD）、CAN 信号输出模型整理、大规模模型的美化与规范化、模型评审前的清理工作等。

---

## 2. 系统要求

| 项目 | 要求 |
|------|------|
| MATLAB | R2016b 或更高版本 |
| Simulink | 与 MATLAB 同版本 |
| 可选 | Simulink Report Generator（仅"导出 Web 视图"功能需要） |
| 权限 | 首次永久安装需要 MATLAB 路径写入权限（savepath） |

> 说明：理论上 SimuTidy 的核心功能兼容更早版本，但 GUI 使用了 `uifigure`/`uibutton` 的 Tooltip 属性，建议 R2016b 及以上。

---

## 3. 安装与卸载

### 3.1 一键部署（Windows，最简单）

双击根目录下的 **`SimuTidy_deploy.bat`**。脚本自动查找 MATLAB（要求 `matlab` 在系统 PATH 中，MATLAB R2019a+），以无界面模式调用 `SimuTidy_install` 完成全部 4 步安装，完成后按提示重启 MATLAB 即可。

> 手动部署等价命令：在 cmd 中执行
> `matlab -batch "addpath('SimuTidy根目录'); addpath('SimuTidy根目录\gui'); addpath('SimuTidy根目录\core'); addpath('SimuTidy根目录\utils'); SimuTidy_install"`

### 3.2 推荐：永久集成安装（在 MATLAB 内执行）

在 MATLAB 命令行执行：

```matlab
% 1. 将 SimuTidy 文件夹加入 MATLAB 路径（改成你的实际路径）
addpath('F:\OpenCode\SimuTidy');

% 2. 运行安装脚本
SimuTidy_install
```

安装脚本自动完成 4 步：

1. **添加路径**：将 SimuTidy 根目录及 gui/core/utils 三个子目录加入 MATLAB 路径并 `savepath` 永久保存
2. **生成菜单文件**：在 MATLAB 用户目录（userpath，通常为"文档\MATLAB"）下生成 `sl_customization.m`；若已存在同名文件会先自动备份为 `sl_customization.m.bak.时间戳`
3. **配置启动项**：向 startup.m 追加 SimuTidy 路径加载语句（已含 SimuTidy 配置则跳过，不会重复添加）
4. **刷新菜单**：立即执行 `sl_refresh_customizations`，无需重启

安装完成后打开任意 Simulink 模型，在菜单栏 **Tools（工具）→ SimuTidy** 即可看到全部功能。**建议重启 MATLAB 一次**确保启动项生效。

### 3.3 临时使用（不推荐，重启失效）

```matlab
addpath('F:\OpenCode\SimuTidy');
addpath('F:\OpenCode\SimuTidy\gui');
addpath('F:\OpenCode\SimuTidy\core');
addpath('F:\OpenCode\SimuTidy\utils');
sl_refresh_customizations
```

### 3.4 卸载

```matlab
SimuTidy_uninstall
% 然后重启 MATLAB
```

卸载脚本会：从路径移除 SimuTidy 并保存、删除 SimuTidy 生成的 `sl_customization.m`（只删 SimuTidy 自己生成的，检测到非 SimuTidy 内容会跳过保护）、清理 startup.m 中的 SimuTidy 配置行。

### 3.5 安装检查

菜单不显示或功能异常时，运行：

```matlab
SimuTidy_check
```

会输出 6 项排查报告（详见[故障排查](#11-故障排查)）。

---

## 4. 启动方式

SimuTidy 提供三种使用入口，功能完全一致，可任选或混用：

| 入口 | 方式 | 适合场景 |
|------|------|----------|
| GUI 窗口 | 命令行输入 `SimuTidy` 回车，或在 Simulink Tools 菜单点"SimuTidy 打开工具窗口" | 交互式整理，功能全 |
| Simulink 菜单 | 打开模型后 Tools 菜单底部的 SimuTidy 子菜单 | 已安装后的日常使用 |
| 命令行 | 直接调用 `slXxx()` 函数 | 脚本化、自动化处理 |

GUI 主窗口与 Simulink 模型窗口相互独立，可以同时摆放，选中模型中的对象后直接点 SimuTidy 按钮即可。

---

## 5. 主窗口界面说明

在 MATLAB 命令行输入 `SimuTidy` 打开主窗口。界面按功能分为 **5 个分区**：

```
┌─────────────── SimuTidy Simulink 辅助工具 ───────────────┐
│       当前模型: xxx（每 1 秒自动刷新）                │
├─ 视图与导出 ────────────────────────────────────────┤
│        [ 导出 Web 视图 (ZIP) ]                       │
├─ 模块整理 ──────────────────────────────────────────┤
│ [左对齐]   [右对齐]   [顶部对齐]   [底部对齐]         │
│ [水平居中] [垂直居中] [水平等间距][垂直等间距]        │
│ [大小统一                                        ]  │
├─ 连线整理 ──────────────────────────────────────────┤
│ [连线端口对齐                                      ] │
│ [信号线命名    ] [拆分 Goto/From  ] [信号对象解析]  │
├─ 接口与命名 ────────────────────────────────────────┤
│ [生成接口              ] [更新模块名称            ]  │
├─ 检查与诊断 ────────────────────────────────────────┤
│ [高亮未连接] [重叠检测] [Goto/From 配对诊断]        │
├─ 运行日志（3.4.0 新增，只读）──────────────────────┤
│ [INFO] 左对齐 完成，基准模块: GainA…（最新在顶）    │
│ …                                                   │
├────────────────────────────────────────────────────┤
│                       就绪                           │
└────────────────────────────────────────────────────┘
```

分区归属（按建模操作的对象与阶段划分）：

| 分区 | 包含功能 | 共同点 |
|------|----------|--------|
| 视图与导出 | 导出 Web 视图 | 模型的输出/存档，不修改模型 |
| 模块整理 | 8 种对齐/等间距、大小统一 | 作用对象是模块 |
| 连线整理 | 连线端口对齐、信号线命名、拆分 Goto/From | 作用对象是信号线及其两端 |
| 接口与命名 | 生成接口、更新模块名称 | 作用对象是 Inport/Outport 边界 |
| 检查与诊断 | 高亮未连接端口 | 只读检查，不修改模型 |

界面元素说明：

- **模型标签**：实时显示当前激活的 Simulink 模型名（`bdroot`），每 1 秒自动刷新；无模型时显示"当前模型: (无)"
- **鼠标悬停提示**：鼠标停留在任意功能按钮上会弹出 Tooltip，说明该功能的作用和使用前提
- **新手引导**：首次启动自动弹出 3 步功能导览；标题栏右侧"使用引导"按钮可随时重新查看；"不再自动显示"后可随时手动重开
- **页脚开发者信息**：窗口底部显示开发者与联系方式（Henry | 1378099981@qq.com | github.com/zyd180）
- **状态栏**：显示操作进行中/完成/错误信息。绿色 = 成功，红色 = 出错（错误信息会附上 MATLAB 异常消息）。出错不会影响模型已保存内容，可用 Ctrl+Z 在 Simulink 中撤销
- **运行日志区**（3.4.0 新增）：只读文本区，自动记录每次操作的完整明细（对齐基准、跳过原因、诊断发现等，带 `[INFO]/[WARN]` 前缀，**最新一条在最上面**），上限 200 行；不用再切 MATLAB 命令行就能回看操作历史
- **单例窗口**：重复执行 `SimuTidy` 不会开多个窗口，只会把已开的窗口置前

**通用操作流程**：在 Simulink 模型中框选/按住 Shift 选中目标对象 → 切到 SimuTidy 窗口点对应按钮 → 查看状态栏结果与 MATLAB 命令行输出。

---

## 6. 功能详解

以下功能说明中，"当前子系统"指当前激活的 Simulink 层级（`gcs`），即你正在浏览的模型层级。SimuTidy 只处理当前子系统内的对象，不会跨层误伤。

### 6.1 导出 Web 视图

**作用**：把当前模型导出为 HTML Web 视图 ZIP 包，方便用浏览器给没有 MATLAB 环境的人浏览模型（含层级导航、信号搜索）。

**使用步骤**：
1. 打开要导出的模型
2. 点击"导出 Web 视图 (ZIP)"按钮
3. 在当前工作目录（pwd）生成 `<模型名>_webview.zip`

**说明**：
- 需要 Simulink Report Generator 许可证，没有会直接报错提示
- 导出范围是当前模型及其下层所有子系统
- 只生成 ZIP，不解压也不自动打开浏览器

**命令行**：

```matlab
zipFile = slExportWebView();                             % 导出当前模型到当前目录
zipFile = slExportWebView('my_model');                   % 指定模型
zipFile = slExportWebView('my_model', 'D:\out');         % 指定输出目录（不存在会自动创建）
```

### 6.2 连线端口对齐

**作用**：把选中的模块垂直移动到与其连线另一端端口相同的高度，对齐后连线成为纯水平直线。用于快速消除模块错位造成的"楼梯形"连线。

**使用步骤**：
1. 在模型中选中要移动的模块（可多选；若同时选中某条连线，则该连线优先作为对齐依据）
2. 点击"连线端口对齐"

**处理逻辑**：
- **基准端不动**：连线另一端（对端）的端口是基准
- 只调整选中模块的**垂直位置（y）**，绝不改变水平位置（x）
- 模块垂直平移后，其端口与对端端口同高，对齐依据线变成一条纯水平直线
- 同一模块的其余连线在模块一侧拉直（以移动后的端口高度为准），远端不动
- 对齐依据线：优先取用户同时选中的连线，否则取模块第一条已连接的连线
- **只处理当前打开层级的选中模块/连线**：子层窗口中的选中对象不参与计算（3.4.0 修正，避免跨坐标系混算）
- 移动前做碰撞检查：垂直平移会与周围模块重叠时，**该模块被跳过**（不做任何修改）
- 汇总输出"对齐 X 个模块，跳过 Y 个"及跳过原因

**对齐前 / 对齐后**：

```
对齐前：  [另一端模块]──┐
         [选中模块]─────┘     ← 选中模块端口偏低

对齐后：  [另一端模块]══[选中模块]   ← 选中模块上移，连线水平
```

**命令行**：

```matlab
slAlignLinePorts()                    % 对齐当前子系统选中的模块
slAlignLinePorts('my_model/Subsys')   % 指定子系统
```

### 6.3 模块对齐与分布

**作用**：批量对齐选中的模块，支持 6 种对齐 + 2 种等间距分布。

**使用步骤**：
1. 选中 **至少 2 个**模块
2. 点击对应按钮

**8 种方式**：

- **6 种对齐**：基准模块 = 选中范围内最上方、最左边的模块，**基准模块位置始终不动**，只有其余模块向它看齐（命令行日志会明示基准块的名字）
- **2 种等间距**：锚点是**中心最小 / 中心最大**的两个块（首尾不动），其余块（含基准块）按中心等差分布

| 按钮 | 效果 |
|------|------|
| 左对齐 | 所有模块左边缘对齐基准模块左边缘（垂直位置不变） |
| 右对齐 | 所有模块右边缘对齐基准模块右边缘 |
| 顶部对齐 | 所有模块顶边对齐基准模块顶边 |
| 底部对齐 | 所有模块底边对齐基准模块底边 |
| 水平居中 | 所有模块的水平中心线对齐基准模块中心线 |
| 垂直居中 | 所有模块的垂直中心线对齐基准模块中心线 |
| 水平等间距 | 按各模块水平中心排序，在中心最小/最大的两块之间等间距分布 |
| 垂直等间距 | 按各模块垂直中心排序，在中心最小/最大的两块之间等间距分布 |

**说明**：
- 对齐只改 x 或只改 y，另一维不动，因此不会破坏你已排好的行/列
- **只处理当前打开层级的选中模块**：父层与子系统窗口同时有选中时，子层选中不参与计算（避免不同坐标系混算，3.4.0 修正）
- 等间距的目标位置会被 Simulink 吸附到 5px 网格，步长非 5 的倍数时是近似等距
- 选中的模块不足 2 个时报错提示

**命令行**：

```matlab
slAlignBlocks([], 'left');     % left/right/top/bottom/hcenter/vcenter/hspace/vspace
slAlignBlocks('my_model/Subsys', 'hspace');
```

### 6.4 模块大小统一

**作用**：把选中的模块统一成相同大小，**每个模块的中心点保持不变**。

**使用步骤**：
1. 选中至少 2 个模块
2. 点击"大小统一"

**目标尺寸规则**（GUI 按钮默认为 `base`，基准 = 所选块中最上最左的那个，命令行日志会明示其名字）：

| 模式 | 目标宽高 |
|------|----------|
| base（默认） | 以基准模块（最上最左）的宽高为准 |
| max | 选中模块中的最大宽、最大高 |
| min | 选中模块中的最小宽、最小高 |
| avg | 所有模块的平均宽高（四舍五入） |

**命令行**：

```matlab
slUniformSize();                 % base 模式
slUniformSize([], 'max');        % 以最大尺寸为准
slUniformSize([], 'min');
slUniformSize([], 'avg');
```

### 6.5 信号线命名

**作用**：为信号线自动命名，替代手工逐条双击输入。

**使用步骤**：
1. 选中要命名的信号线（不选则默认处理**当前子系统的全部信号线**）
2. 点击"信号线命名"打开对话框
3. 选择命名方式

**4 种命名方式**：

| 按钮 | 信号名来源 | 适用场景 |
|------|-----------|----------|
| 按源模块名命名 | 信号源模块的名称 | 常规信号，一条源出一个名 |
| 按源模块名+端口号命名 | `源名_outN`（N 为源模块输出端口号） | 一个模块输出多条信号需区分时 |
| 按输出端口 (Outport) 命名 | 目标 Outport 块的名称（目标不是 Outport 时回退为源模块名） | 接口连线，信号名 = 对外接口名 |
| 清除所选信号线命名（3.4.0 新增） | 只清空**选中**的信号线名；未选中任何线时不做任何处理，仅 WARN 提醒 | 只想清掉个别线的名字 |
| 清除所有信号线命名 | 弹窗二次确认后清空**当前层级全部**信号线名（无视选中状态，3.4.0 起默认确认） | 整层重来或清理 |

**说明**：
- 命名后自动打开线的 ShowName 显示
- 名字中的非法字符（`/ \ 空格 - < > ? * | " : .`）自动替换为下划线
- Simulink 名称上限 63 字符

**命令行**：

```matlab
slAutoNameSignals([], 'source');        % 按源模块名
slAutoNameSignals([], 'source_port');   % 按源模块名+端口号
slAutoNameSignals([], 'outport');       % 按输出端口
slAutoNameSignals([], 'clear');         % 清除命名（选中线优先，未选则全线）
slClearSignalNames();                   % 清除选中的信号线名（零选中只提醒）
slAutoNameSignals([], 'clear_all');     % 清除当前层级全部信号线名
```

### 6.6 拆分 Goto/From（批量）

**作用**：把选中的信号线替换为 Goto/From 标签对，消除模型中的长飞线，让图面干净整洁。**支持同时选中多条线批量拆分。**

**使用步骤**：
1. 在模型中选中一条或多条信号线（可框选多选）
2. 点击"拆分 Goto/From"

**每条线的处理结果**（以从左到右的信号线为例）：

```
拆分前：  [源模块] ═══════════长飞线═══════════ [目标模块]

拆分后：  [源模块]──40px──[Goto]      [From]──40px──[目标模块]
```

- **Goto** 放在源块右侧 40px 处，垂直居中于原线的起点高度
- **From** 放在目标块左侧 40px 处，垂直居中于原线的终点高度
- 中间的长线被删除，改由 Tag 传递信号

**尺寸规则**：
- Goto/From 的**高度**与该线所连的 Inport/Outport 块高度一致（保持与模型中细条块相同的视觉风格）；两端都不是 Inport/Outport 时用配置默认高度（30）
- **宽度**固定用配置默认值（60），不会继承长名字块的宽度

**空间不足时的自动推块**：
- 若源块与目标块之间的空隙放不下 Goto+From（需要约 240px），工具会自动把源块向左、目标块向右推开，刚好腾出位置
- 推块前会做**全模型碰撞检查**：尝试多种推开方案（对半推 → 只推目标 → 只推源，且逐档加大推开量），每种方案都要求源块新位置、目标块新位置、Goto、From 四者均不与模型中任何其他模块重叠才执行
- 所有方案都放不下时，**该条线被安全跳过**（不做任何修改），不会留下半拆的状态

**批量结果汇总**：处理完成后在命令行输出"成功 X 条，失败 Y 条"，并列出每条失败线的原因（没有源端口/没有目标端口/跨层连线/空间不足等）。单条失败不影响其他连线继续处理。

**命名规则**：
- Goto/From 的 Tag = 源模块名（非法字符已清洗）+ `_` + 3 位随机序号，如 `EMS_nEngAct_585`
- 块名 = `Goto_<Tag>` / `From_<Tag>`，与已有块重名时自动追加 `_1`、`_2`…
- Tag 作用域默认 local（同一子系统内有效）

**使用限制**：
- 源模块和目标模块必须在**同一个子系统**内（跨层连线请手动处理）
- 带分支的连线（一分多）只处理第一个目标分支，其余分支会被删除，请确认后再拆
- 一次只拆"线"对象；点选模块再拆是无效的（请直接选线或框选包含线的区域）

**命令行**：

```matlab
slSplitGotoFrom();                 % 拆分当前子系统选中的线（支持多选）
slSplitGotoFrom('my_model/Subsys');% 指定子系统
```

**反向连线**：信号从右向左流动的线同样支持，Goto/From 会自动按方向镜像放置。

### 6.7 高亮未连接端口

**作用**：快速找出模型里没接线的端口和悬空的信号线，标红提示。

**使用步骤**：
1. 点击"高亮未连接端口"
2. 模型中有未连接端口的模块和悬空线会标红
3. **再次运行会刷新高亮状态**：已连接的自动取消标红，保持未连接的红色
4. 清除全部高亮：命令行运行 `slHighlightUnconnected([], true)`

**检测内容**：
- 有任何未连接端口（输入/输出/使能/触发/状态等所有端口类型）的模块
- 没有源端口的悬空线、没有目标端口的悬空线

**结果反馈（3.4.0 起）**：
- 有发现项时弹出结果面板，逐条给出**分类原因**（如"1 个输入端口未连接""悬空信号线"）和**定位**按钮（打开所在系统并高亮该对象）
- 命令行接输出可得同一结构：`res = slHighlightUnconnected();`

**命令行**：

```matlab
slHighlightUnconnected();          % 高亮（每次运行先清后标，结果始终最新）
slHighlightUnconnected([], true);  % 清除全部高亮
```

### 6.8 生成接口

**作用**：为选中的 Subsystem 中**未连接的端口**自动补上 Inport/Outport 块并连线。典型场景：从别处复制来的子系统，边界上有一堆悬空端口，需要快速补齐接口层。

**使用步骤**：
1. 在父层中选中目标 Subsystem 模块（注意：是选中 Subsystem 本身，不是进入其内部）
2. 点击"生成接口"

**处理逻辑**：
- 遍历该 Subsystem 的每个端口，发现未连接（`Line == -1`）的：
  - **输入端口** → 在 Subsystem 左侧 220px 处新建 Inport 块，连线到该端口
  - **输出端口** → 在 Subsystem 右侧 50px 处新建 Outport 块，从该端口连线过来
- 新块垂直位置与对应端口对齐
- 颜色：Inport 浅蓝色（lightBlue）、Outport 粉色 [1, 0.333, 1]
- **块名（3.4.0 起）**：优先取子系统**内部对应端口块**的名称（内部叫 `Vin`，父层生成块也叫 `Vin`）；父层重名时追加 `_1`/`_2` 序号；内部块缺失时回落 `InportN`/`OutportN`
- 显示：名称默认显示（ShowName on + 图标显示端口号，与"更新模块名称"一致）
- 完成后自动 update 模型刷新端口显示（可在设置中关闭"操作后自动更新模型"跳过编译提速；关闭后下次更新图/仿真时自然生效）

**说明**：
- 每个悬空端口生成一个块；已连接的端口不动
- 支持一次处理多个悬空端口（批量）

**命令行**：

```matlab
slGeneratePorts();                  % 处理当前选中的 Subsystem
slGeneratePorts('my_model/SubX');   % 指定 Subsystem
```

### 6.9 更新模块名称

**作用**：把模型中 Inport/Outport 块的显示名批量改成与信号一致的名称，让接口层"见名知义"。

**使用步骤**：
1. 打开目标模型（默认处理整个当前模型，包含所有层级）
2. 点击"更新模块名称"

**命名来源（按优先级）**：

**Inport 块**：
1. 该块输出信号线的信号名
2. 无信号名时，取外层父级传进来的连线名（父层中连到对应端口的线名）
3. 仍没有则沿信号链向源端递归追溯：源是子系统时取其内部对应 Outport 块名，内部块是默认名（Outport1 之类）则继续深入，直到找到有意义的名字（递归深度上限 30 层）

**Outport 块**：
1. 该块输入信号线的信号名
2. 无信号名则沿输入线向源端递归追溯（同上）

**重名处理**：同层级的 Inport/Outport 视为同一命名空间，重名自动追加 `_1`、`_2` 序号；不同层级允许同名。

**其他行为**：
- 只改 Inport/Outport 的显示名，不改变端口编号和连接关系，不影响代码生成接口
- 改名后自动打开名称显示（ShowName on）
- 重复运行无副作用（已是目标名的块自动跳过）
- 实测支持 5000+ 端口块的大型模型全量改名

**命令行**：

```matlab
slUpdateBlockNames();                 % 更新当前模型全部层级
slUpdateBlockNames('my_model/SubX');  % 只更新指定子系统
```

### 6.10 信号对象解析

**作用**：为当前层级所有**有名字**的信号线批量勾选 Simulink 信号属性 **"信号名称必须解析为 Simulink 对象"**。勾选后，Simulink 在更新图时会强制校验这些信号名必须指向基础工作区中的对象（如 `Simulink.Signal` 数据对象），用于配合数据字典/数据对象管理做规范性校验。

**使用步骤**：
1. 打开目标层级（工具只处理当前层，不影响子层级）
2. 点击"信号对象解析"

**处理规则**：
- 无名字的信号线自动跳过（没有名字就无从解析）
- 已勾选的线跳过（幂等，重复运行无副作用）
- 若模型中存在选中的连线，则只处理选中的线
- 支持 `'off'` 模式整体取消勾选
- 勾选后自动更新图：**若信号名无法解析为对象，Simulink 诊断会报错——这正是该校验的目的**，按报错提示补建数据对象即可

**命令行**：

```matlab
slSetSignalResolve();               % 当前层级有名字的线批量勾选
slSetSignalResolve([], 'off');      % 整体取消勾选
slSetSignalResolve('my_model/SubX', 'on');
```

### 6.11 模块重叠检测

**作用**：检查当前层级中位置互相重叠的模块（AABB 碰撞框），用于排查复制粘贴/拖拽造成的压叠。

**使用步骤**：
1. 打开目标层级（检查当前层全部模块，与选中状态无关）
2. 点击"重叠检测"

**结果**：
- 有重叠时弹出结果面板，每处重叠一条（原因写明搭档块名），点"定位"打开所在系统并高亮
- 无重叠时仅命令行提示，不弹面板

**命令行**：

```matlab
res = slCheckOverlaps();            % 当前子系统；res.failItems 含可定位句柄
res = slCheckOverlaps('my_model/SubX');
```

### 6.12 Goto/From 配对诊断

**作用**：检查 Goto/From 标签配对问题。错配的 Tag 通常到仿真时才报错，本功能提前暴露。

**使用步骤**：
1. 打开目标层级
2. 点击"Goto/From 配对诊断"

**检查项**：

| 问题 | 说明 |
|------|------|
| 悬空 Goto | 当前层的 Goto 在全模型范围内没有任何 From 引用 |
| 无源 From | 当前层的 From 在全模型范围内找不到对应 Goto |
| 跨层 local 引用 | From 引用了其他子系统里 `TagVisibility='local'` 的 Goto——local 仅本层可见，仿真会报错 |

**结果**：同重叠检测，发现项在结果面板逐条定位。

**已知边界**：不做编译校验（同 Tag 多 Goto 等复杂语义交给 Simulink 仿真诊断），只覆盖上述三类确定性问题。

**命令行**：

```matlab
res = slCheckGotoFrom();            % 当前子系统
res = slCheckGotoFrom('my_model/SubX');
```

---

## 7. Simulink 工具栏

SimuTidy 提供两种 Simulink 集成入口：

### 7.1 SimuTidy 选项卡（R2022b+，推荐）

打开模型后，顶部工具条在**格式**与 **APP** 之间会出现 **SimuTidy** 选项卡，布局与 APP 栏一致（大按钮 + 底部分区标题）：

```
| 打开SimuTidy窗口 | 模块对齐▾  大小统一 | 连线端口对齐  信号线命名  拆分Goto/From | 生成接口  更新模块名称  高亮未连接 |
 └─ 工具      └────────── 模块整理 ──────────  └──────── 连线整理 ────────  └────── 接口与诊断 ──────
```

- 第一个按钮：打开 SimuTidy 主工具窗口
- "模块对齐"为下拉按钮，点开选择 8 种对齐/等间距方式
- 其余功能均为一键大按钮，与主窗口功能一一对应
- 全部按钮带自定义分区色图标（透明背景 PNG，存于 `resources/icons/`），由 `utils/SimuTidy_makeIcons.m` 脚本生成；改图标后重跑该脚本并执行 `slReloadToolstripConfig` 即可

### 7.2 Tools 菜单（兼容入口）

菜单栏 **Tools → SimuTidy** 提供 10 个菜单项（与 GUI 一一对应）：

```
Tools
 └─ SimuTidy
     ├─ SimuTidy 打开工具窗口
     ├─ 导出 Web 视图 (ZIP)
      ├─ 连线端口对齐
     ├─ 模块对齐            ▸ 左对齐 / 右对齐 / 顶部对齐 / 底部对齐
     │                        水平居中 / 垂直居中 / 水平等间距 / 垂直等间距
     ├─ 模块大小统一
     ├─ 信号线命名          ▸ 按源模块名 / 按源模块名+端口号 / 按输出端口 / 清除所有命名
     ├─ 长连线拆 Goto/From
     ├─ 高亮未连接端口
     ├─ 生成接口
     └─ 更新模块名称
```

菜单操作直接作用于当前模型窗口中选中的对象，无需打开 SimuTidy 主窗口。

---

## 8. 命令行参考

所有核心功能可直接命令行调用，便于写脚本批量处理多个模型：

| 函数 | 语法 | 说明 |
|------|------|------|
| `SimuTidy` | `SimuTidy()` | 打开主 GUI 窗口 |
| `slExportWebView` | `zip = slExportWebView(model, folder)` | 导出 Web 视图 ZIP |
| `slAlignLinePorts` | `slAlignLinePorts(sys)` | 连线端口对齐：垂直移动选中模块与另一端端口对齐 |
| `slAlignBlocks` | `slAlignBlocks(sys, type)` | 对齐，type: left/right/top/bottom/hcenter/vcenter/hspace/vspace |
| `slUniformSize` | `slUniformSize(sys, mode)` | 大小统一，mode: base/max/min/avg |
| `slAutoNameSignals` | `slAutoNameSignals(sys, mode)` | 信号命名，mode: source/source_port/outport/clear/clear_sel/clear_all |
| `slClearSignalNames` | `slClearSignalNames(sys)` | 清除**选中**信号线命名（未选中仅提醒，不清全线） |
| `slSplitGotoFrom` | `slSplitGotoFrom(sys)` | 批量拆分选中线为 Goto/From |
| `slHighlightUnconnected` | `slHighlightUnconnected(sys, clearFlag)` | 高亮未连接端口 |
| `slSetSignalResolve` | `slSetSignalResolve(sys, mode)` | 信号对象解析批量勾选，mode: on/off |
| `slCheckOverlaps` | `res = slCheckOverlaps(sys)` | 当前层模块重叠检测（res 可定位） |
| `slCheckGotoFrom` | `res = slCheckGotoFrom(sys)` | Goto/From 配对诊断（res 可定位） |
| `slGeneratePorts` | `slGeneratePorts(sys)` | 为 Subsystem 生成接口 |
| `slUpdateBlockNames` | `slUpdateBlockNames(sys)` | 批量更新 Inport/Outport 名称 |
| `SimuTidy_install` | `SimuTidy_install()` | 永久安装到 Simulink 菜单 |
| `SimuTidy_uninstall` | `SimuTidy_uninstall()` | 卸载 |
| `SimuTidy_check` | `msg = SimuTidy_check()` | 安装排查报告 |
| `SimuTidy_version` | `[v, d] = SimuTidy_version()` | 查询版本号和日期 |

说明：
- `sys` 参数缺省时的默认值：大多数功能取当前子系统 `gcs`；`slExportWebView` 和 `slUpdateBlockNames` 取整个模型 `bdroot`
- 第一个参数传 `[]` 表示使用默认子系统，例如 `slAlignBlocks([], 'left')`

**批量脚本示例**：

```matlab
% 批量整理一个模型的完整流程
mdl = 'COUT_CanSigOut';
load_system(mdl);

% 1. 信号线按源模块名命名
slAutoNameSignals(mdl, 'source');

% 2. 更新全部 Inport/Outport 名称为信号名
slUpdateBlockNames(mdl);

% 3. 检查遗漏的未连接端口
slHighlightUnconnected(mdl);

% 4. 导出 Web 视图存档
slExportWebView(mdl, 'D:\review');

close_system(mdl, 0);
```

---

## 9. 配置文件详解

所有可调参数集中在 `SimuTidy_config.m`，修改后立即全局生效（无需重启）。

```matlab
cfg = SimuTidy_config();

%% 版本信息
cfg.version      = '2.5.0';       % 版本号
cfg.versionDate  = '2026-09-08';  % 版本日期

%% Goto/From 模块配置
cfg.goto.defaultWidth   = 60;      % Goto/From 固定宽度
cfg.goto.defaultHeight  = 30;      % 两端都不是 Inport/Outport 时的默认高度
cfg.goto.gap            = 40;      % 与源/目标模块的间距（也是 Goto/From 之间最小间距）
cfg.goto.tagVisibility  = 'local'; % Tag 作用域：local（本层）/ scoped / global

%% 信号命名配置
cfg.naming.maxNameLength = 63;                          % Simulink 名称长度上限
cfg.naming.replaceChars  = '[\/\s\-\<\>\?\*\|\"\:\.]';  % 非法字符正则
cfg.naming.replaceWith   = '_';                         % 替换字符

%% GUI 配置
cfg.gui.mainPosition    = [500, 280, 400, 620];  % 主窗口位置（实际以代码内为准）
cfg.gui.refreshInterval = 1;  % 模型标签刷新间隔（秒）
cfg.gui.showOnboarding = true;  % 逍次启动自动弹出新手引导

%% 颜色配置
cfg.colors.panelTitle = [0.267 0.294 0.322];  % 面板标题文字
cfg.colors.export     = [0.169 0.365 0.561];  % 视图与导出 深海蓝
cfg.colors.module     = [0.243 0.486 0.651];  % 模块整理-普通 钢青蓝
cfg.colors.moduleDark = [0.180 0.376 0.514];  % 模块整理-主操作 深钢青
cfg.colors.line       = [0.180 0.545 0.455];  % 连线整理-普通 青绿
cfg.colors.lineDark   = [0.137 0.439 0.361];  % 连线整理-主操作 深青绿
cfg.colors.port       = [0.420 0.373 0.647];  % 接口与命名-普通 靛紫
cfg.colors.portDark   = [0.329 0.290 0.522];  % 接口与命名-主操作 深靛紫
cfg.colors.check      = [0.788 0.541 0.176];  % 检查与诊断 琥珀
cfg.colors.success    = [0.224 0.569 0.310];  % 状态-成功
cfg.colors.error      = [0.780 0.290 0.259];  % 状态-出错
...

%% Simulink API 配置
cfg.simulink.updateAfterChange = true;  % 改完后是否自动 update 模型（信号对象解析、生成接口）
```

常用自定义场景：

- **改 Goto/From 宽度**：修改 `cfg.goto.defaultWidth`（例如窄间距模型可改为 40）
- **改间距**：修改 `cfg.goto.gap`（推荐 20~60）
- **Tag 全局可见**：`cfg.goto.tagVisibility = 'global'`（需注意跨子系统 Tag 冲突）
- **关闭自动 update**：`cfg.simulink.updateAfterChange = false`（大型模型 update 很慢时可关掉，最后手动 Ctrl+D；影响"信号对象解析"的即时校验与"生成接口"的即时端口刷新）

---

## 10. 典型工作流示例

### 场景 A：整理一个接手来的"脏"模型

```
1. SimuTidy 打开主窗口
2. 高亮未连接端口          → 找出所有没接好的地方，逐个补线
3. 更新模块名称            → Inport/Outport 全部改成信号名，接口层见名知义
4. 信号线命名（按源模块名）→ 全部信号线自动命名
5. 逐层框选模块 → 对齐/等间距/大小统一 → 图面整齐
6. 连线端口对齐            → 消除错位连线
7. 框选长飞线 → 拆分 Goto/From → 长线变标签
8. 导出 Web 视图           → 发给同事评审
```

### 场景 B：整理 CAN 信号输出模型（如 COUT_CanSigOut 类）

```
1. 进入信号映射子系统（大量 Inport → 中间块 → Outport）
2. 框选全部 Inport→中间块 的长连线（可配合多次局部框选）
3. 点击"拆分 Goto/From"批量拆分（空间不足的会安全跳过并提示）
4. 同样处理 中间块→Outport 的线
5. 对跳过的线：稍微手动挪一下模块腾出空间，再次拆分
6. 更新模块名称，让 Inport/Outport 显示真实信号名
```

### 场景 C：为子系统补接口层

```
1. 把整理好的子系统复制到新模型
2. 选中该 Subsystem → 生成接口 → 悬空端口自动补 Inport/Outport 并连线
3. 更新模块名称 → 新补的接口块自动按信号名改名
```

---

## 11. 故障排查

### 11.1 一键排查

```matlab
SimuTidy_check
```

报告包含 6 项：SimuTidy.m 位置、SimuTidy_config.m 位置、sl_customization.m 位置及是否 SimuTidy 生成、路径上全部 sl_customization.m（发现多个会提示冲突）、gui/core/utils 子目录存在性、userpath 设置。

### 11.2 常见问题

**问题：Tools 菜单里没有 SimuTidy**

- 运行 `sl_refresh_customizations` 后重开模型
- `SimuTidy_check` 检查 sl_customization.m 是否存在；**若路径上存在多个 sl_customization.m，Simulink 只加载路径顺序靠前的第一个**，把 SimuTidy 的移到最前：`addpath('SimuTidy路径','-begin'); savepath;`
- 确认 userpath 中生成的是 SimuTidy 版本（含"SimuTidy 打开工具窗口"字样）

**问题：点菜单报"未定义函数"**

- SimuTidy 子目录不在路径中。重跑 `SimuTidy_install`，或手动：`addpath('SimuTidy根目录','SimuTidy\gui','SimuTidy\core','SimuTidy\utils','-begin'); savepath`

**问题：导出 Web 视图报许可证错误**

- 该功能需要 Simulink Report Generator。在 MATLAB 中运行 `license('test','Simulink_Report_Gen')` 检查，返回 0 表示无许可，其余功能不受影响

**问题：拆分 Goto/From 后命令行显示"周围空间不足"**

- 该线源块与目标块之间及周围确实没有空间放下 Goto+From，工具已安全跳过（该线保持原样）
- 解决：手动把两端的模块稍微挪开再重新选中该线拆分；或调小 `cfg.goto.gap` 后重试

**问题：拆分 Goto/From 报"源模块和目标模块不在同一个子系统内"**

- 跨层连线无法直接拆分，请先进入相应层级分别处理，或手动建 Goto/From

**问题：对齐/拉线后模型显示异常**

- 执行 Ctrl+D（Update Diagram）刷新显示
- 不满意直接 Ctrl+Z 撤销

**问题：GUI 模型标签一直显示"(无)"**

- 说明当前没有激活的 Simulink 模型。请先打开/切换到一个模型，标签 1 秒内自动刷新

---

## 12. 注意事项与已知限制

1. **所有修改均可 Ctrl+Z 撤销**；SimuTidy 不会自动保存模型，确认满意后请自行保存（Ctrl+S）
2. **拆分 Goto/From 的分支线**：一条线分出多个目标时只处理第一个分支，其余分支随原线删除，拆分前请确认
3. **跨层连线**不能直接拆分为 Goto/From
4. **推块可能破坏严格列对齐**：碰撞感知推块保证"不重叠"，但不保证推开后仍与相邻模块对齐；对列对齐要求严格的图，建议手动微调后再拆
5. **Goto/From 宽度固定 60**：不随名字长度变化；名字特别长的信号建议接受默认宽度，或自行调大 `cfg.goto.defaultWidth`
6. **生成接口块名默认取内部接口名**：优先用子系统内部对应端口块的名称（父层重名自动加 `_N` 后缀，内部块缺失时回落 `InportN`/`OutportN`）；如需统一按信号名命名，生成后运行"更新模块名称"
7. 大型模型上"更新模块名称"会遍历全部层级块，首次运行可能需要数十秒
8. SimuTidy 的所有操作只作用于**当前子系统层**（slUpdateBlockNames 和 slExportWebView 例外，作用于整个模型）
9. 在 Simulink 模型处于仿真运行/调试状态时请勿使用本工具，先停止仿真

---

## 13. 版本历史

| 版本 | 日期 | 主要变化 |
|------|------|----------|
| 2.8.0 | 2026-09-08 | 新增"信号对象解析"批量勾选（信号名称必须解析为 Simulink 对象），GUI/Toolstrip 同步 |
| 2.7.1 | 2026-09-08 | 新增新手引导（首次启动 3 步功能导览 + 使用引导按钮）；修复 uifigure 句柄隐藏导致的单例失效 |
| 2.7.0 | 2026-09-08 | 新增 Simulink Toolstrip「SimuTidy」选项卡（顶部工具条，格式与APP之间），大按钮+分区布局+自定义图标，下拉收纳对齐方式 |
| 2.6.1 | 2026-09-08 | UI 配色重新设计：靛青专业系低饱和分区配色，分区即配色，颜色集中到配置文件 |
| 2.6.0 | 2026-09-08 | "拉直选中连线"升级为"连线端口对齐"：以另一端端口为基准垂直移动选中模块，连线变水平直线；带碰撞检查与安全跳过；修复多选碰撞误判与连线二次平移问题 |
| 2.5.1 | 2026-09-08 | 主界面按功能重新分区（视图与导出/模块整理/连线整理/接口与命名/检查与诊断），窗口加宽，按钮统一网格布局 |
| 2.5.0 | 2026-09-08 | Goto/From 支持多选批量拆分；尺寸改为与 Inport/Outport 等高 + 固定宽；新增碰撞感知自动推块与安全跳过；GUI 按钮悬停提示 |
| 2.4.0 | 2026-09-05 | 更新模块名称：沿信号链追溯源端名，支持深层级模型全量改名 |
| 2.3.0 | 2026-09-05 | 更新模块名称（信号线名/外层传入名）；GUI 按钮与 Tools 菜单集成 |
| 2.2.0 | 2026-09-04 | 生成接口（自动补 Inport/Outport 并连线，带颜色）；高亮刷新逻辑优化 |
| 2.1.0 | 2026-09-04 | 永久集成安装、卸载脚本、版本查询、完整工具栏菜单 |
| 2.0.0 | 2026-09-04 | 模块化重构（15 个模块）、配置集中管理、安装/检查脚本、修复多项 bug |
| 1.0.0 | 2026-08-10 | 初始版本：GUI + 8 项核心功能 + 工具栏集成 |

详细变更见 [CHANGELOG.md](CHANGELOG.md)。

---

## 14. 开发者信息

- **开发者**：Henry
- **邮箱**：1378099981@qq.com
- **GitHub**：<https://github.com/zyd180>

使用问题与功能建议欢迎通过邮箱或 GitHub 联系。

---

*SimuTidy — 让 Simulink 模型整理一键完成。*
