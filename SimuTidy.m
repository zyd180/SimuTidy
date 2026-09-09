function SimuTidy()
%SimuTidy Simulink 建模辅助小工具 - 入口函数
%   版本：3.0.0
%
%   功能：
%       1. 导出当前模型为 HTML Web 视图（仅生成 zip，不解压不打开）
%       2. 连线端口对齐（以另一端端口为基准垂直移动选中模块，连线变直线）
%       3. 模块批量对齐与等间距分布（基准模块不动，仅动对应方向）
%       4. 模块大小统一（基准模块大小为准）
%       5. 信号线自动命名
%       6. 长连线批量拆分为 Goto/From（支持多选）
%       7. 高亮未连接端口
%       8. 更新Inport/Outport名称（信号线名，Inport无信号名用外层传入名）
%       9. 信号对象解析批量勾选
%
%   使用方法：
%       SimuTidy()                    - 打开 GUI 窗口
%       slExportWebView()        - 导出 Web 视图
%       slAlignLinePorts()       - 连线端口对齐
%       slAlignBlocks()          - 模块对齐
%       slUniformSize()          - 模块大小统一
%       slAutoNameSignals()      - 信号线命名
%       slSplitGotoFrom()        - 长连线拆 Goto/From
%       slHighlightUnconnected() - 高亮未连接端口
%       slUpdateBlockNames()      - 更新Inport/Outport为信号名（沿信号链追源）
%       SimuTidy_install()            - 安装到 Simulink 工具栏
%       SimuTidy_check()              - 排查安装问题
%
%   模块化结构：
%       SimuTidy.m                    - 入口函数（本文件）
%       SimuTidy_config.m             - 配置管理
%       SimuTidy_install.m            - 安装脚本
%       SimuTidy_check.m              - 安装检查
%       +simutidy/                    - 核心功能包（3.1.0 命名空间化，
%                                       simutidy.alignBlocks 等 10 个实体）
%       +simutidy/+internal/          - 包内共享工具（sys校验/碰撞/汇总/清洗）
%       sl*.m                         - slXxx 兼容薄包装（对外契约不变）
%       gui/SimuTidy_mainGUI.m        - 主GUI界面
%       gui/SimuTidy_nameDialog.m     - 命名对话框
%       gui/SimuTidy_onboarding.m     - 新手引导
%       utils/sltidy_*.m              - 工具函数
%
%   作者：Henry
%   版本日期：2026-09-08

    % 确保子目录在路径中
    % 3.1.0 命名空间化：核心实体在 +simutidy 包内，包随根目录在 path 上
    % 即可解析，无需单独 addpath；gui/utils 仍需单独加入
    rootPath = fileparts(mfilename('fullpath'));
    if ~isempty(rootPath)
        addpath(fullfile(rootPath, 'gui'));
        addpath(fullfile(rootPath, 'utils'));
    end

    % 启动主GUI
    SimuTidy_mainGUI();
end
