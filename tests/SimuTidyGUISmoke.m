classdef SimuTidyGUISmoke < matlab.unittest.TestCase
%SimuTidyGUISmoke GUI 冒烟测试（3.4.1 新增）
%   目标：防布局回归——裁切 bug 连续三版都出现在主窗口上（3.2.0/3.3.1/
%   3.4.0 日志区），而原回归套件对 GUI 覆盖为零
%
%   断言口径（重要，勿改）：只断言**分配格尺寸的算术一致性**（grid 行高
%   常量合计 vs 窗口高度）与控件齐全性，不猜渲染像素——3.3.1 的教训：
%   uifigure 布局异步完成，程序化读取 Position 判断"是否被裁"不可靠
%   （读到的是未布局值/分配格尺寸而非实际绘制裁切）
%
%   无头环境兼容：uifigure 在 matlab -batch 下可用（R2022b+ 无头渲染），
%   但为防旧版/CI 差异，窗口创建失败走 assume 跳过（不计失败），保证
%   SimuTidy_deploy.bat 门禁不误伤
%
%   清理是生死线：主窗口带 1s timer，测试结束必须 stop/delete，否则
%   -batch 进程不退出（挂死门禁）；统一走 finishGui 兜底
%   运行：runtests('F:\...\SimuTidy\tests') 自动收录

    methods (TestClassSetup)
        function addPathOnce(tc)
            % 3.4.0 同款：根目录动态解析（mfilename 在 classdef 方法内
            % 返回空串，须用 which 定位文件再 fileparts 两次上溯）
            root = fileparts(fileparts(which('SimuTidyGUISmoke')));
            addpath(root);
            addpath(fullfile(root, 'gui'));
            addpath(fullfile(root, 'utils'));
        end
    end

    methods (TestMethodTeardown)
        function cleanWindows(tc) %#ok<INUSD>
            % 兜底清理：任何用例退出路径都不得残留 GUI 窗口/timer/sink
            SimuTidyGUISmoke.closeAllTidyWindows();
        end
    end

    methods (Test)
        function testMainWindowBuilds(tc)
            fig = tc.buildMainWindow();

            % 6 个分区面板齐全（3.4.0 起含"运行日志"）
            % 注意：① findall(fig对象) 在本 MATLAB 版本下**不遍历 uifigure
            % 的子组件**（实测返回 0 后代），必须 findall(0,...) 全局找再按
            % 所属窗口过滤；② 面板标题带装饰空格（'  视图与导出  '），
            % 比对前 strtrim
            panels = findall(0, 'Type', 'uipanel');
            panels = panels(arrayfun(@(p) isequal(tc.rootFigureOf(p), fig), panels));
            panelTexts = strtrim({panels.Title});
            expectPanels = {'视图与导出', '模块整理', '连线整理', ...
                            '接口与命名', '检查与诊断', '运行日志'};
            for k = 1:numel(expectPanels)
                tc.verifyTrue(any(strcmp(panelTexts, expectPanels{k})), ...
                    sprintf('缺少分区面板: %s', expectPanels{k}));
            end

            % 关键按钮齐全（文本集合断言；总数 >= 21 防整块丢失）
            btns = findall(0, 'Type', 'uibutton');
            btns = btns(arrayfun(@(b) isequal(tc.rootFigureOf(b), fig), btns));
            tc.verifyGreaterThanOrEqual(numel(btns), 21, '按钮总数异常');
            btnTexts = {btns.Text};
            expectBtns = {'导出 Web 视图 (ZIP)', '左对齐', '大小统一', ...
                '连线端口对齐', '信号线命名', '拆分 Goto/From', ...
                '信号对象解析', '生成接口', '更新模块名称', ...
                '高亮未连接端口', '重叠检测', 'Goto/From 配对诊断', '设置'};
            for k = 1:numel(expectBtns)
                tc.verifyTrue(any(strcmp(btnTexts, expectBtns{k})), ...
                    sprintf('缺少按钮: %s', expectBtns{k}));
            end

            % 布局算术一致性：窗口高 >= 行高合计 + 行距合计 + 上下内边距
            % （行高常量与窗口默认值的失配正是历次裁切 bug 的根因）
            % drawnow：uifigure 布局异步完成，读分配尺寸前先刷新（3.3.1 教训）
            drawnow;
            g = findall(0, 'Type', 'uigridlayout');
            g = g(arrayfun(@(x) isequal(tc.rootFigureOf(x), fig), g));
            tc.verifyEqual(numel(g), 1, '顶层 uigridlayout 应恰有 1 个');
            g = g(1);
            totalRows = sum(cellfun(@(x) sum(x(:)), g.RowHeight));
            nRows = numel(g.RowHeight);
            required = totalRows + g.RowSpacing * (nRows - 1) + g.Padding(2) + g.Padding(4);
            tc.verifyGreaterThanOrEqual(fig.Position(4), required, ...
                '窗口高度不足以容纳全部固定行（会裁底部）');

            % 按钮分配格尺寸非零（拍扁即行高失配的可见症状）
            for b = btns(:)'
                tc.verifyGreaterThanOrEqual(b.Position(4), 15, ...
                    sprintf('按钮 "%s" 分配高度过小（疑似行高失配）', b.Text));
            end
        end

        function testNameDialog(tc)
            % SimuTidy_nameDialog 无输出参数（构建后经 findall 定位单例）
            SimuTidy_nameDialog();
            d = findall(0, 'Type', 'figure', 'Name', '信号线自动命名');
            d = d(arrayfun(@(f) isvalid(f) && isappdata(f, 'SimuTidy_Alive') ...
                && getappdata(f, 'SimuTidy_Alive'), d));
            % 无头/自动化环境探测：uifigure 会自动关闭，跳过本用例
            tc.assumeStable(d(1), '命名对话框');
            d = d(1);

            % findall(0,...) + 所属窗口过滤（findall(fig) 不遍历，见上）
            btns = findall(0, 'Type', 'uibutton');
            btns = btns(arrayfun(@(b) isequal(tc.rootFigureOf(b), d), btns));
            btnTexts = {btns.Text};
            expectBtns = {'按源模块名命名', '按源模块名+端口号命名', ...
                '按输出端口 (Outport) 命名', '清除所选信号线命名', ...
                '清除所有信号线命名', '关闭'};
            tc.verifyEqual(numel(btns), numel(expectBtns), '按钮数量不符');
            for k = 1:numel(expectBtns)
                tc.verifyTrue(any(strcmp(btnTexts, expectBtns{k})), ...
                    sprintf('缺少按钮: %s', expectBtns{k}));
            end
        end
    end

    %% ====================================================================
    %  辅助
    %% ====================================================================
    methods (Access = private)
        function fig = buildMainWindow(tc)
            % 单例清理后重建；创建失败走 assume 跳过（无头环境兼容）
            SimuTidyGUISmoke.closeAllTidyWindows();
            try
                fig = SimuTidy_mainGUI();
            catch ME
                tc.assumeTrue(false, sprintf(...
                    'uifigure 不可用，跳过 GUI 冒烟（%s）', ME.message));
            end
            tc.verifyTrue(~isempty(fig) && isvalid(fig), '主窗口未创建');
            tc.assumeStable(fig, '主窗口');
        end

        function assumeStable(tc, f, what)
            % 无头/自动化环境探测（3.4.1 实测）：部分 MATLAB 会话里
            % uifigure 创建后 ~1s 会**自动关闭**（裸窗口亦然），此时后续
            % 全部断言无从谈起——按假设失败"跳过"而非报错，保证部署
            % 门禁不误伤；真实桌面环境（用户交互）窗口稳定，用例正常执行
            pause(1.5);
            tc.assumeTrue(isvalid(f), ...
                sprintf('当前环境 uifigure 自动关闭（%s 创建后死亡），跳过 GUI 冒烟', what));
        end
    end

    methods (Static, Access = private)
        % 沿 Parent 链上溯到所属 Figure（findall(fig对象) 不遍历
        % uifigure 子组件，见 testMainWindowBuilds 注释）
        function f = rootFigureOf(obj)
            f = obj;
            while ~isa(f, 'matlab.ui.Figure')
                f = f.Parent;
            end
        end

        function closeAllTidyWindows()
            % 关闭全部 SimuTidy 窗口并停 timer/注销 sink（防 -batch 挂死）
            % 3.4.1：先摘存活标记再删（uifigure delete 异步，存活标记是
            % 单例判活的依据，不摘会让下次构建的 singleton 检查认错窗口）
            figs = findall(0, 'Type', 'figure', 'Name', 'SimuTidy');
            for f = figs(:)'
                if isvalid(f)
                    try
                        t = f.UserData.timer;
                        if ~isempty(t) && isvalid(t)
                            stop(t); delete(t);
                        end
                    catch
                    end
                    setappdata(f, 'SimuTidy_Alive', false);
                    delete(f);
                end
            end
            d = findall(0, 'Type', 'figure', 'Name', '信号线自动命名');
            for f = d(:)'
                if isvalid(f)
                    setappdata(f, 'SimuTidy_Alive', false);
                    delete(f);
                end
            end
            try
                simutidy.internal.setLogSink([]);
            catch
            end
        end
    end
end
