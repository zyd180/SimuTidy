classdef SimuTidyRegression < matlab.unittest.TestCase
%SimuTidyRegression 3.1.0 架构重构的安全网回归测试
%   原则：锁定“重构前”的现有行为（含怪癖），不测理想行为。
%   重构（Phase 1 性能 / Phase 2 命名空间化）前后必须全部通过。
%   运行：runtests('F:\OpenCode\SimuTidy\tests')
%
%   注意的既有行为约定（改动须先改此处再改实现）：
%     - 高亮/对齐等操作后模型不需要编译（update）也能断言几何结果
%     - 高亮范围在 3.1.0 修正为仅当前层，因此本套件只断言当前层
%     - 批量操作的 fprintf 汇总文案不作断言（允许 Phase 2 收敛格式）

    properties
        ModelName = ''
        sinkMsgs = {}   % 3.3.0 日志 sink 捕获（TestCase 是 handle 类，闭包可写回）
        ROOT = ''       % 3.4.0 修复：改为动态解析（原 Constant 硬编码
                        % 'F:\OpenCode\SimuTidy'，换机器/clone 到其他路径
                        % 即挂；Constant 属性必须是常量表达式，无法在声明处
                        % 调 mfilename，故移到 TestClassSetup 里赋值）
    end

    methods (TestClassSetup)
        function addPathOnce(tc)
            % 3.1.0 命名空间化后实体在 +simutidy 包内：包无需单独加路径，
            % 根目录在 path 上即可；gui/utils 仍需单独 addpath
            % 3.4.0 修复：根目录从本文件位置动态解析——注意两个坑（实测）：
            % 1) mfilename 在 classdef 方法内返回**空串**，不能用于定位
            % 2) which('SimuTidyRegression') 返回 classdef 文件全路径
            %    （tests/ 下），需 fileparts 两次上溯到项目根
            % 仓库 clone 到任意路径测试均可跑
            tc.ROOT = fileparts(fileparts(which('SimuTidyRegression')));
            addpath(tc.ROOT);
            addpath(fullfile(tc.ROOT, 'gui'));
            addpath(fullfile(tc.ROOT, 'utils'));
        end
    end

    methods (TestMethodTeardown)
        function closeModel(tc)
            % 所有测试模型均不保存（new_system 后从未 save），直接丢弃
            bdclose(tc.ModelName);
        end
    end

    methods (TestMethodSetup)
        function freshModel(tc)
            % 每个用例一个干净的无名模型，命名加随机尾巴防残留冲突
            tc.ModelName = ['TST_' char(randi(26)+96) char(randi(26)+96) ...
                             num2str(randi(9999))];
            if bdIsLoaded(tc.ModelName), bdclose(tc.ModelName); end
            new_system(tc.ModelName);
            open_system(tc.ModelName);
        end
    end

    %% ====================================================================
    %  工具
    %% ====================================================================
    methods (Access = private)
        function addAndConnect(tc, srcPos, dstPos)
            % 两个 Gain 块加一条线，返回 [srcH dstH lineH]
            mdl = tc.ModelName;
            add_block('built-in/Gain', [mdl '/GainA'], 'Position', srcPos);
            add_block('built-in/Gain', [mdl '/GainB'], 'Position', dstPos);
            add_line(mdl, 'GainA/1', 'GainB/1', 'autorouting', 'on');
        end

        function selectBlocks(tc, names)
            % 注意：names 必须按行迭代（列 cell 在 for 下会整列一次迭代）
            for i = 1:numel(names)
                set_param([tc.ModelName '/' names{i}], 'Selected', 'on');
            end
        end

        function selectLines(tc)
            lh = find_system(tc.ModelName, 'FindAll', 'on', 'Type', 'line');
            for h = lh(:)'
                set_param(h, 'Selected', 'on');
            end
        end

        function captureSink(tc, msg, lv)
            tc.sinkMsgs{end+1} = sprintf('%s|%s', lv, msg); %#ok<AGROW>
        end

        function assertThrows(tc, fcn)
            % 既有错误无 ID，只断言“抛了异常”，不断言文案
            threw = false;
            try
                fcn();
            catch
                threw = true;
            end
            tc.verifyTrue(threw, '预期应抛出异常，但没有。');
        end
    end

    %% ====================================================================
    %  1. 模块对齐（8 模式）
    %% ====================================================================
    methods (Test)
        function testAlignEightModes(tc)
            mdl = tc.ModelName;
            % 基准 = 最上最左 = GainA(50,50)；其余错位摆放
            add_block('built-in/Gain', [mdl '/GainA'], 'Position', [50  50  90  90]);
            add_block('built-in/Gain', [mdl '/GainB'], 'Position', [300 200 350 250]);
            add_block('built-in/Gain', [mdl '/GainC'], 'Position', [500 300 560 360]);

            cases = {
                'left',    [50  200 100 250;  50  300 110 360];
                'right',   [40  200 90  250;  30  300 90  360];
                'top',     [300 50  350 100;  500 50  560 110];
                'bottom',  [300 40  350 90;   500 30  560 90];
                'hcenter', [45  200 95  250;  40  300 100 360];
                'vcenter', [300 45  350 95;   500 40  560 100];
            };
            for c = 1:size(cases, 1)
                type = cases{c, 1};
                want = cases{c, 2};
                % 重摆位置
                set_param([mdl '/GainA'], 'Position', [50 50 90 90]);
                set_param([mdl '/GainB'], 'Position', [300 200 350 250]);
                set_param([mdl '/GainC'], 'Position', [500 300 560 360]);
                tc.selectBlocks({'GainA'; 'GainB'; 'GainC'});
                slAlignBlocks(mdl, type);
                pb = get_param([mdl '/GainB'], 'Position');
                pc = get_param([mdl '/GainC'], 'Position');
                tc.verifyEqual([pb; pc], want, sprintf('模式 %s 结果不符', type));
                tc.verifyEqual(get_param([mdl '/GainA'], 'Position'), ...
                    [50 50 90 90], '基准模块被移动了');
            end

            % 等间距：按中心排序分布在首尾之间（只断言中心等差）
            set_param([mdl '/GainA'], 'Position', [50 50 90 90]);
            set_param([mdl '/GainB'], 'Position', [200 200 240 240]);
            set_param([mdl '/GainC'], 'Position', [500 300 560 360]);
            tc.selectBlocks({'GainA'; 'GainB'; 'GainC'});
            slAlignBlocks(mdl, 'hspace');
            pa = get_param([mdl '/GainA'], 'Position');
            pb = get_param([mdl '/GainB'], 'Position');
            pc = get_param([mdl '/GainC'], 'Position');
            cxA = mean(pa([1 3]));
            cxB = mean(pb([1 3]));
            cxC = mean(pc([1 3]));
            tc.verifyEqual((cxB - cxA), (cxC - cxB), '水平等间距不成等差');
        end

        function testAlignErrorsOnFewSelections(tc)
            tc.addAndConnect([100 100 140 140], [300 100 340 140]);
            f = @() slAlignBlocks(tc.ModelName, 'left'); % 0 选中 → 报错
            tc.assertThrows(f);
        end

        function testHspaceMovesBaseForEvenSpacing(tc)
            % 3.4.0 修复锁定：等间距不再跳过基准块——基准在中间时必须
            % 参与分布，否则等距被破坏（修复前实测 250/185/215）。
            % 注意：Simulink 会把块位置吸附到 5px 网格，步长必须取网格
            % 整数倍才能精确断言（首例 650/3 就踩过，间距变 215/220/215）
            mdl = tc.ModelName;
            add_block('built-in/Gain', [mdl '/L'],    'Position', [50  200 90  240]); % 中心 70 端点
            add_block('built-in/Gain', [mdl '/Base'], 'Position', [300 50  340 90]);  % 中心 320，最上=基准
            add_block('built-in/Gain', [mdl '/M2'],   'Position', [500 200 540 240]); % 中心 520 中间
            add_block('built-in/Gain', [mdl '/R'],    'Position', [650 300 690 340]); % 中心 670 端点（步长 200，5 的倍数）
            tc.selectBlocks({'L'; 'Base'; 'M2'; 'R'});
            slAlignBlocks(mdl, 'hspace');
            cx = zeros(1, 4);
            names = {'L', 'Base', 'M2', 'R'};
            for k = 1:4
                p = get_param([mdl '/' names{k}], 'Position');
                cx(k) = mean(p([1 3]));
            end
            tc.verifyEqual((cx(2) - cx(1)), (cx(3) - cx(2)), '前段间距不等', 'AbsTol', 1e-6);
            tc.verifyEqual((cx(3) - cx(2)), (cx(4) - cx(3)), '后段间距不等', 'AbsTol', 1e-6);
        end

        function testAlignAndSizeIgnoreCrossLayerSelection(tc)
            % 3.4.0 修复锁定：只处理当前层（SearchDepth=1），子层选中块
            % 不被混入父层坐标系计算（修复前会一起移动/改尺寸）
            mdl = tc.ModelName;
            add_block('built-in/Gain', [mdl '/Top1'], 'Position', [100 100 140 140]);
            add_block('built-in/Gain', [mdl '/Top2'], 'Position', [300 200 340 240]);
            add_block('built-in/SubSystem', [mdl '/SUB'], 'Position', [200 400 260 460]);
            add_block('built-in/Gain', [mdl '/SUB/Inner'], 'Position', [30 30 100 100]);
            tc.selectBlocks({'Top1'; 'Top2'; 'SUB/Inner'});
            innerPos = get_param([mdl '/SUB/Inner'], 'Position');

            slAlignBlocks(mdl, 'left');
            tc.verifyEqual(get_param([mdl '/Top1'], 'Position'), [100 100 140 140], '基准被移动');
            tc.verifyEqual(get_param([mdl '/Top2'], 'Position'), [100 200 140 240], '顶层对齐未生效');
            tc.verifyEqual(get_param([mdl '/SUB/Inner'], 'Position'), innerPos, ...
                '子层块不应被父层对齐操作改动');

            slUniformSize(mdl, 'base');
            tc.verifyEqual(get_param([mdl '/SUB/Inner'], 'Position'), innerPos, ...
                '子层块不应被父层大小统一改动');
        end
    end

    %% ====================================================================
    %  2. 大小统一
    %% ====================================================================
    methods (Test)
        function testUniformSizeKeepsCenters(tc)
            mdl = tc.ModelName;
            add_block('built-in/Gain', [mdl '/GainA'], 'Position', [50 50 90 90]);
            add_block('built-in/Gain', [mdl '/GainB'], 'Position', [300 200 380 260]);
            tc.selectBlocks({'GainA'; 'GainB'});
            slUniformSize(mdl, 'base');
            pa = get_param([mdl '/GainA'], 'Position');
            pb = get_param([mdl '/GainB'], 'Position');
            % B 尺寸变成 A 的 40x40，中心保持 (340, 230)
            tc.verifyEqual(pb, [320 210 360 250]);
            tc.verifyEqual(pa, [50 50 90 90], '基准被改动了');
        end
    end

    %% ====================================================================
    %  3. 连线端口对齐
    %% ====================================================================
    methods (Test)
        function testAlignLinePortsVerticalOnly(tc)
            mdl = tc.ModelName;
            tc.addAndConnect([100 100 140 140], [300 200 340 240]);
            set_param([mdl '/GainB'], 'Selected', 'on');
            slAlignLinePorts(mdl);
            pa = get_param([mdl '/GainA'], 'Position'); % 基准端不动
            pb = get_param([mdl '/GainB'], 'Position');
            tc.verifyEqual(pa, [100 100 140 140], '基准模块被移动');
            tc.verifyEqual(pb(1), 300, '水平位置不应改变');
            tc.verifyEqual(pb(2), 100, '应与另一端端口同高(y=100)');
            tc.verifyEqual(pb(4), 140, '应与另一端端口同高(y=140)');
        end

        function testAlignLinePortsAlreadyAlignedSkips(tc)
            mdl = tc.ModelName;
            tc.addAndConnect([100 100 140 140], [300 100 340 140]);
            set_param([mdl '/GainB'], 'Selected', 'on');
            % 已对齐：函数按“跳过”处理（打印汇总），不报错、不移动
            slAlignLinePorts(mdl);
            tc.verifyEqual(get_param([mdl '/GainB'], 'Position'), [300 100 340 140]);
        end
    end

    %% ====================================================================
    %  4. 信号线命名
    %% ====================================================================
    methods (Test)
        function testAutoNameModes(tc)
            mdl = tc.ModelName;
            tc.addAndConnect([100 100 140 140], [300 100 340 140]);
            lh = find_system(mdl, 'FindAll', 'on', 'Type', 'line');

            slAutoNameSignals(mdl, 'source');
            tc.verifyEqual(get_param(lh, 'Name'), 'GainA');

            slAutoNameSignals(mdl, 'source_port');
            tc.verifyEqual(get_param(lh, 'Name'), 'GainA_out1');

            % 非法字符清洗：块名含 '.' 与空格 → 全部替换为 '_'
            set_param([mdl '/GainA'], 'Name', 'A B.C');
            slAutoNameSignals(mdl, 'source');
            tc.verifyEqual(get_param(lh, 'Name'), 'A_B_C');

            slAutoNameSignals(mdl, 'clear');
            tc.verifyEqual(get_param(lh, 'Name'), '');
        end

        function testClearSelectedAndAllModes(tc)
            % 3.4.0 新增清除类模式锁定：
            %   clear_sel 只清选中的线，没选中时不做处理仅提醒（不报错）
            %   clear_all 无视选中状态清当前层全部线
            mdl = tc.ModelName;
            % 串联两条线：A→B→C，各命名 sig1/sig2
            add_block('built-in/Gain', [mdl '/A'], 'Position', [50 50 90 90]);
            add_block('built-in/Gain', [mdl '/B'], 'Position', [200 50 240 90]);
            add_block('built-in/Gain', [mdl '/C'], 'Position', [350 50 390 90]);
            add_line(mdl, 'A/1', 'B/1', 'autorouting', 'on');
            add_line(mdl, 'B/1', 'C/1', 'autorouting', 'on');
            lh = find_system(mdl, 'FindAll', 'on', 'Type', 'line');
            set_param(lh(1), 'Name', 'sig1');
            set_param(lh(2), 'Name', 'sig2');

            % 场景1：只选第一条线 → 只清它，另一条保留
            set_param(lh(1), 'Selected', 'on');
            simutidy.autoNameSignals(mdl, 'clear_sel');
            tc.verifyEqual(get_param(lh(1), 'Name'), '', '选中线未被清除');
            tc.verifyEqual(get_param(lh(2), 'Name'), 'sig2', '未选中线不应被清除');

            % 场景2：全部取消选中 → 不做处理不报错，名字原样保留
            set_param(lh(1), 'Selected', 'off');
            set_param(lh(2), 'Selected', 'off');
            threw = false;
            try
                simutidy.autoNameSignals(mdl, 'clear_sel');
            catch
                threw = true;
            end
            tc.verifyFalse(threw, '零选中不应抛错（应只提醒）');
            tc.verifyEqual(get_param(lh(2), 'Name'), 'sig2', '零选中不应有改动');

            % 场景3：clear_all 无视选中状态清当前层全部
            simutidy.autoNameSignals(mdl, 'clear_all');
            tc.verifyEqual(get_param(lh(2), 'Name'), '', 'clear_all 未清全部线');
        end

        function testAutoNameOutportMode(tc)
            mdl = tc.ModelName;
            % 线接到 Outport 块：按输出端口命名应取 Outport 块名
            add_block('built-in/Gain', [mdl '/GainA'], 'Position', [100 100 140 140]);
            add_block('built-in/Outport', [mdl '/OUT1'], 'Position', [300 105 330 125]);
            add_line(mdl, 'GainA/1', 'OUT1/1', 'autorouting', 'on');
            slAutoNameSignals(mdl, 'outport');
            lh = find_system(mdl, 'FindAll', 'on', 'Type', 'line');
            tc.verifyEqual(get_param(lh, 'Name'), 'OUT1');

            % 目标不是 Outport 块时回落为源块名
            set_param([mdl '/OUT1'], 'Name', 'RENAMED');
            set_param(find_system(mdl, 'FindAll', 'on', 'Type', 'line'), 'Name', '');
            slAutoNameSignals(mdl, 'source');
            tc.verifyEqual(get_param(lh, 'Name'), 'GainA');
        end
    end

    %% ====================================================================
    %  5. Goto/From 拆分
    %% ====================================================================
    methods (Test)
        function testSplitGotoFrom(tc)
            mdl = tc.ModelName;
            tc.addAndConnect([100 100 140 140], [500 100 540 140]);
            tc.selectLines();
            slSplitGotoFrom(mdl);

            blks = get_param(find_system(mdl, 'FindAll', 'on', ...
                'SearchDepth', 1, 'Type', 'block'), 'Name');
            tc.verifyEqual(numel(blks), 4, '应新增 Goto/From 共 2 块');
            gotoName = blks{find(strncmp(blks, 'Goto_', 5), 1)};
            fromName = blks{find(strncmp(blks, 'From_', 5), 1)};
            gh = getSimulinkBlockHandle([mdl '/' gotoName]);
            fh = getSimulinkBlockHandle([mdl '/' fromName]);

            % GotoTag 一致，且标签含源块名（清洗后）
            tc.verifyEqual(get_param(gh, 'GotoTag'), get_param(fh, 'GotoTag'));
            tc.verifySubstring(get_param(gh, 'GotoTag'), 'GainA');

            % 原 1 线 → 拆分后 2 线（源→Goto、From→目标）
            tc.verifyEqual(numel(find_system(mdl, 'FindAll', 'on', 'Type', 'line')), 2);

            % 源→Goto 与 From→目标 各占一端
            srcLine = get_param(get_param(gh, 'PortHandles').Inport, 'Line');
            tc.verifyNotEqual(srcLine, -1, 'Goto 未接线');
            dstLine = get_param(get_param(fh, 'PortHandles').Outport, 'Line');
            tc.verifyNotEqual(dstLine, -1, 'From 未接线');
        end

        function testSplitGotoFromMultiBranch(tc)
            % 3.4.1 分支支持锁定：1 源 3 目标 → Goto ×1 + From ×3（同
            % Tag），每个目标块仍有输入；修复前 delete_line 删整条线，
            % 只有第一分支被拆、其余分支随原线消失
            mdl = tc.ModelName;
            add_block('built-in/Constant', [mdl '/C'],  'Position', [50 130 90 150]);
            add_block('built-in/Gain',    [mdl '/D1'],  'Position', [300 50 340 70]);
            add_block('built-in/Gain',    [mdl '/D2'],  'Position', [300 150 340 170]);
            add_block('built-in/Gain',    [mdl '/D3'],  'Position', [300 250 340 270]);
            add_line(mdl, 'C/1', 'D1/1', 'autorouting', 'on');
            add_line(mdl, 'C/1', 'D2/1', 'autorouting', 'on');
            add_line(mdl, 'C/1', 'D3/1', 'autorouting', 'on');
            tc.selectLines();

            res = simutidy.splitGotoFrom(mdl);
            tc.verifyEqual(res.okCount, 1, '3 分支线应一次性完整拆分（去重后 1 条）');
            tc.verifyEqual(res.failCount, 0, '空间充足不应有失败分支');

            % 块清点：C/D1/D2/D3 + Goto ×1 + From ×3 = 8
            blks = find_system(mdl, 'FindAll', 'on', 'SearchDepth', 1, 'Type', 'block');
            tc.verifyEqual(numel(blks), 8, '应新增 Goto ×1 + From ×3');
            gotoH = blks(strcmp(get_param(blks, 'BlockType'), 'Goto'));
            fromH = blks(strcmp(get_param(blks, 'BlockType'), 'From'));
            tc.verifyEqual(numel(gotoH), 1, '应只建 1 个 Goto');
            tc.verifyEqual(numel(fromH), 3, '应建 3 个 From');
            % Tag 全一致（get_param 多句柄返回的 cell 朝向不定，统一转列
            % 向量再拼，规避 char/cell 与行/列双重不一致）
            tags = [cellstr(get_param(gotoH, 'GotoTag')); ...
                    reshape(cellstr(get_param(fromH, 'GotoTag')), [], 1)];
            tc.verifyEqual(numel(unique(tags)), 1, 'Goto 与 3 个 From 的 GotoTag 应一致');

            % 每个目标块输入线完好
            for d = {'D1', 'D2', 'D3'}
                ph = get_param([mdl '/' d{1}], 'PortHandles');
                tc.verifyNotEqual(get_param(ph.Inport(1), 'Line'), -1, ...
                    sprintf('%s 的输入线丢失', d{1}));
            end
            % 线数 = 源→Goto 1 + From→目标 3
            tc.verifyEqual(numel(find_system(mdl, 'FindAll', 'on', 'Type', 'line')), 4);
        end

        function testSplitGotoTagNameCollision(tc)
            % 3.4.1 命名规则锁定：Tag 默认 = 清洗后的源块名（无随机数）；
            % 撞已有 Tag 时追加确定性序号 _1
            mdl = tc.ModelName;
            tc.addAndConnect([100 100 140 140], [500 100 540 140]);
            % 预置一个 Tag='GainA' 的 Goto，制造撞名
            add_block('built-in/Goto', [mdl '/G_Pre'], 'GotoTag', 'GainA', ...
                'Position', [700 100 740 120]);
            tc.selectLines();
            slSplitGotoFrom(mdl);

            gotoH = find_system(mdl, 'FindAll', 'on', 'SearchDepth', 1, ...
                'BlockType', 'Goto');
            tags = cellstr(get_param(gotoH, 'GotoTag'));
            tc.verifyEqual(numel(tags), 2, '应共 2 个 Goto（预置 + 新建）');
            tc.verifyTrue(any(strcmp(tags, 'GainA')), '预置 Tag 不应被改动');
            tc.verifyTrue(any(strcmp(tags, 'GainA_1')), ...
                '新 Goto 的 Tag 应为撞名后缀 GainA_1');
        end

        function testSplitErrorsWithoutSelection(tc)
            tc.addAndConnect([100 100 140 140], [300 100 340 140]);
            tc.assertThrows(@() slSplitGotoFrom(tc.ModelName));
        end
    end

    %% ====================================================================
    %  6. 信号对象解析
    %% ====================================================================
    methods (Test)
        function testSetSignalResolveOnOff(tc)
            mdl = tc.ModelName;
            tc.addAndConnect([100 100 140 140], [300 100 340 140]);
            lh = find_system(mdl, 'FindAll', 'on', 'Type', 'line');
            set_param(lh, 'Name', 'sig1');
            srcPort = get_param(lh, 'SrcPortHandle');

            slSetSignalResolve(mdl, 'on');
            tc.verifyEqual(get_param(srcPort, 'MustResolveToSignalObject'), 'on');

            % 幂等：再设一次仍为 on（不重复计数也无副作用）
            slSetSignalResolve(mdl, 'on');
            tc.verifyEqual(get_param(srcPort, 'MustResolveToSignalObject'), 'on');

            slSetSignalResolve(mdl, 'off');
            tc.verifyEqual(get_param(srcPort, 'MustResolveToSignalObject'), 'off');

            % 未命名线跳过：不抛错
            set_param(lh, 'Name', '');
            slSetSignalResolve(mdl, 'on');
            tc.verifyEqual(get_param(srcPort, 'MustResolveToSignalObject'), 'off');
        end
    end

    %% ====================================================================
    %  7. 高亮未连接端口（当前层）
    %% ====================================================================
    methods (Test)
        function testHighlightRunsOnCurrentLayer(tc)
            mdl = tc.ModelName;
            % A 连线完整；B 悬空输入
            tc.addAndConnect([100 100 140 140], [300 200 340 240]);
            add_block('built-in/Gain', [mdl '/GainC'], 'Position', [500 100 540 140]);
            % 不应抛错；清理模式同样可用
            slHighlightUnconnected(mdl);
            slHighlightUnconnected(mdl);
            slHighlightUnconnected(mdl, true);
        end

        function testHighlightResClassification(tc)
            % 3.4.0 升级锁定：res 逐项分类 + 可定位句柄
            mdl = tc.ModelName;
            tc.addAndConnect([100 100 140 140], [300 200 340 240]); % A→B 完整
            add_block('built-in/Gain', [mdl '/LonelyIn'], 'Position', [500 100 540 140]);  % 只缺输入
            add_block('built-in/Outport', [mdl '/LonelyOut'], 'Position', [700 100 730 120]); % 只缺输出
            % 多输入块（Logic 默认 2 输入全悬空）：锁定 get_param 多句柄
            % 返回 cell 的归一路径（用户实测：cell 直接 == -1 抛 'eq' 未定义）
            add_block('built-in/Logic', [mdl '/MultiIn'], ...
                'Position', [900 100 940 140]);

            res = simutidy.highlightUnconnected(mdl);
            % 既有语义：任何有未连接端口的模块都算发现——A 输入悬空、
            % B 输出悬空也算，加上两个孤立块与多输入块共 5 项
            tc.verifyEqual(res.failCount, 5, '应发现 5 个问题模块');
            % 5 块 + 1 线共 6 个对象：5 个块全有问题，唯一连接完好的是
            % A→B 那条线 → okCount = 1
            tc.verifyEqual(res.okCount, 1, 'okCount 应为连接完好的对象数');
            reasons = {res.failItems.reason};
            % 注意用 startsWith 而非 strncmp(n)：n 超过前缀长度时必然不等
            tc.verifyTrue(any(startsWith(reasons, '2 个输入端口')), '应报 2 个输入端口未连接');
            tc.verifyTrue(any(startsWith(reasons, '1 个输入端口')), '应报输入端口未连接');
            tc.verifyTrue(any(startsWith(reasons, '1 个输出端口')), '应报输出端口未连接');
            for k = 1:res.failCount
                tc.verifyTrue(ishandle(res.failItems(k).handle), '发现项句柄应有效');
            end
            % 清除模式返回零发现 res
            res2 = simutidy.highlightUnconnected(mdl, true);
            tc.verifyEqual(res2.failCount, 0, '清除模式应返回零发现');
        end

        function testHighlightWithProgressOption(tc)
            % 3.4.0 修复锁定：'Progress' 名值对路径（GUI 三参调用）不再
            % 抛"clearFlag 无法识别"——clearFlag 默认值须先于条件分支
            % 赋值（存量 bug：3.3.0 引入，回归只测过 1/2 参）
            mdl = tc.ModelName;
            tc.addAndConnect([100 100 140 140], [300 200 340 240]);
            threw = false;
            try
                res = simutidy.highlightUnconnected(mdl, 'Progress', []);
            catch
                threw = true;
            end
            tc.verifyFalse(threw, 'Progress 选项路径不应报 clearFlag 未定义');
            tc.verifyEqual(res.failCount, 2, 'Progress 路径检查结果应正确');
            res2 = simutidy.highlightUnconnected(mdl, true, 'Progress', []);
            tc.verifyEqual(res2.failCount, 0, 'clearFlag 与 Progress 共存应可用');
        end

        function testCheckOverlaps(tc)
            % 3.4.0 新增：AABB 重叠对检测
            mdl = tc.ModelName;
            add_block('built-in/Gain', [mdl '/OA'], 'Position', [50 50 90 90]);
            add_block('built-in/Gain', [mdl '/OB'], 'Position', [70 70 110 110]);  % 与 OA 重叠
            add_block('built-in/Gain', [mdl '/OC'], 'Position', [300 300 340 340]); % 独立
            res = simutidy.checkOverlaps(mdl);
            tc.verifyEqual(res.failCount, 1, '应发现 1 处重叠');
            tc.verifyEqual(get_param(res.failItems(1).handle, 'Name'), 'OA', '句柄应指向重叠对之一');
            tc.verifySubstring(res.failItems(1).reason, 'OB', '原因应写明搭档块名');
            tc.verifyEqual(res.okCount, 1, '仅 OC 无重叠');
            tc.verifyEqual(res.op, '模块重叠检测');
        end

        function testCheckGotoFrom(tc)
            % 3.4.0 新增：配对诊断四场景
            mdl = tc.ModelName;
            % T1：悬空 Goto（无 From）；T3/T3：正常配对；SUB/T4 local + 顶层 From：跨层 local
            add_block('built-in/Goto', [mdl '/G_T1'], 'GotoTag', 'T1', 'Position', [50 50 90 70]);
            add_block('built-in/Goto', [mdl '/G_T3'], 'GotoTag', 'T3', 'Position', [50 100 90 120]);
            add_block('built-in/From', [mdl '/F_T3'], 'GotoTag', 'T3', 'Position', [150 100 190 120]);
            add_block('built-in/From', [mdl '/F_T2'], 'GotoTag', 'T2', 'Position', [150 150 190 170]); % 无源 From
            add_block('built-in/SubSystem', [mdl '/SUB'], 'Position', [300 50 360 110]);
            add_block('built-in/Goto', [mdl '/SUB/G_T4'], 'GotoTag', 'T4', ...
                'TagVisibility', 'local', 'Position', [30 30 70 50]);
            add_block('built-in/From', [mdl '/F_T4'], 'GotoTag', 'T4', 'Position', [150 200 190 220]);

            res = simutidy.checkGotoFrom(mdl);
            tc.verifyEqual(res.failCount, 3, '应发现悬空 Goto/无源 From/跨层 local 三处');
            reasons = {res.failItems.reason};
            tc.verifyTrue(any(contains(reasons, 'T1')), '应报悬空 Goto T1');
            tc.verifyTrue(any(contains(reasons, 'T2')), '应报无源 From T2');
            tc.verifyTrue(any(contains(reasons, 'T4')), '应报跨层 local T4');
            % 正常配对的 T3 不应出现在发现项中
            tc.verifyFalse(any(contains(reasons, 'T3')), '正常配对 T3 不应被误报');
        end
    end

    %% ====================================================================
    %  8. 生成接口
    %% ====================================================================
    methods (Test)
        function testGeneratePorts(tc)
            mdl = tc.ModelName;
            % 子系统内含 Inport/Outport，但父层端口全部悬空。
            % 3.4.0 命名规则更新：父层新块名 = 内部对应端口块名
            % （原规则锁定 Inport2/Outport2 跳号怪癖，已随命名规则更新废除）
            add_block('built-in/SubSystem', [mdl '/SUB'], 'Position', [300 100 360 160]);
            add_block('built-in/Inport',  [mdl '/SUB/Vin'],  'Position', [30 28 60 42]);
            add_block('built-in/Outport', [mdl '/SUB/Vout'], 'Position', [270 28 300 42]);
            add_block('built-in/Gain', [mdl '/SUB/G'], 'Position', [100 30 140 60]);
            add_line([mdl '/SUB'], 'Vin/1', 'G/1', 'autorouting', 'on');
            add_line([mdl '/SUB'], 'G/1', 'Vout/1', 'autorouting', 'on');

            slGeneratePorts([mdl '/SUB']);

            % 新块直接沿用内部名 Vin/Vout（不再是 InportN/OutportN）
            tc.verifyTrue(getSimulinkBlockHandle([mdl '/Vin']) ~= -1, '未生成 Vin');
            tc.verifyTrue(getSimulinkBlockHandle([mdl '/Vout']) ~= -1, '未生成 Vout');
            % 3.4.0 显示约定：默认显示模块名称（ShowName on + 图标显示端口号，
            % 与 updateBlockNames 一致）
            tc.verifyEqual(get_param([mdl '/Vin'], 'ShowName'), 'on', '模块名未显示');
            tc.verifyEqual(get_param([mdl '/Vin'], 'IconDisplay'), 'Port number', ...
                '图标应显示端口号');
            % FindAll 递归全层：SUB 内部 2 线 + 父层新增 2 线 = 4
            tc.verifyEqual(numel(find_system(mdl, 'FindAll', 'on', 'Type', 'line')), 4);
        end

        function testGeneratePortsConflictAndFallback(tc)
            % 3.4.0 命名规则的两条兜底路径：
            %   1) 冲突后缀：父层已存在同名块 → 新块追加 _1
            %   2) 清洗：内部名含非法字符（空格/点）→ 按 sanitizeName 规则替换
            mdl = tc.ModelName;
            % 占名块：内部 Inport 也叫 'V in.1' → 清洗后 preferred='V_in_1'，
            % 先放一个同名 Gain 占住 'V_in_1' → 期望生成 'V_in_1_1'
            add_block('built-in/Gain', [mdl '/V_in_1'], 'Position', [500 100 540 140]);
            add_block('built-in/SubSystem', [mdl '/SUB'], 'Position', [300 100 360 160]);
            add_block('built-in/Inport', [mdl '/SUB/V in.1'], 'Position', [30 28 60 42]);
            add_block('built-in/Gain', [mdl '/SUB/G'], 'Position', [100 30 140 60]);
            add_line([mdl '/SUB'], 'V in.1/1', 'G/1', 'autorouting', 'on');

            slGeneratePorts([mdl '/SUB']);
            tc.verifyTrue(getSimulinkBlockHandle([mdl '/V_in_1_1']) ~= -1, ...
                '清洗+冲突后缀路径未按预期生成 V_in_1_1');
            % 内部块名缺省回落路径较难构造（删内部 Inport 会连带删端口），
            % 逻辑上仅 preferred 为空时走 sprintf 兜底，此处不强行覆盖
        end
    end

    %% ====================================================================
    %  9. 更新模块名称（追溯链）
    %% ====================================================================
    methods (Test)
        function testUpdateBlockNamesTrace(tc)
            mdl = tc.ModelName;
            % Gain 命名 MyGain：避免与 Outport 追溯到的名字撞车，隔离“重名加序号”场景
            add_block('built-in/Inport', [mdl '/In1'],     'Position', [50 100 80 120]);
            add_block('built-in/Gain',   [mdl '/MyGain'],  'Position', [200 100 240 140]);
            add_block('built-in/Outport',[mdl '/Out1'],    'Position', [400 105 430 125]);
            l1 = add_line(mdl, 'In1/1', 'MyGain/1', 'autorouting', 'on');
            l2 = add_line(mdl, 'MyGain/1', 'Out1/1', 'autorouting', 'on');

            % 场景1：Inport 取其输出线名；Outport 输入线无名 → 追溯到源块名。
            % 已知怪癖（锁定现状，3.1.0 不修）：追溯名 MyGain 与既有 Gain 块同名，
            % nameConflict 只查 Inport/Outport 命名空间 → 视为不冲突 → set_param
            % 实际抛"名称已被占用" → 被 renameBlock 的 try/catch 吞掉 → Out1 保持原名
            set_param(l1, 'Name', 'sigIn');
            set_param(l2, 'Name', '');
            slUpdateBlockNames(mdl);
            tc.verifyEqual(get_param([mdl '/sigIn'], 'Name'), 'sigIn', ...
                'In1 应改为输出线名（原路径已失效，用新名引用）');
            tc.verifyEqual(get_param([mdl '/Out1'], 'Name'), 'Out1', ...
                '已知怪癖：与既有非IO块同名时静默失败，Out1 保持原名');

            % 场景2：目标名与同层 Inport 现名互斥（Inport/Outport 同命名空间）
            % → 自动追加序号 _1（此路径正常工作）
            set_param(l2, 'Name', 'sigIn');
            slUpdateBlockNames(mdl);
            tc.verifyEqual(get_param([mdl '/sigIn_1'], 'Name'), 'sigIn_1');

            % 图标显示端口号 + 显示名称（既有约定）
            tc.verifyEqual(get_param([mdl '/sigIn'], 'IconDisplay'), 'Port number');
            tc.verifyEqual(get_param([mdl '/sigIn'], 'ShowName'), 'on');
        end
    end

    %% ====================================================================
    %  10. 导出 Web 视图（许可证门控 + 错误路径）
    %% ====================================================================
    methods (Test)
        function testExportWebViewErrorPath(tc)
            if ~license('test', 'Simulink_Report_Gen')
                % 无许可证：仅验证“能抛许可证错误”，功能测试跳过
                tc.assertThrows(@() slExportWebView('NoSuchModel_XYZ'));
                return;
            end
            % 有许可证：未加载模型必须报错
            tc.assertThrows(@() slExportWebView('NoSuchModel_XYZ'));
        end

        function testZeroArgInvocations(tc)
            % 3.1.0 回归测试：零参调用路径（依赖 gcs）。
            % 背景：迁移 +simutidy 包时 nargin 守卫被误搬进 resolveSystem，
            % 零参调用在传参点即抛"输入参数的数目不足"（用户报告的
            % Tools 菜单/Toolstrip 全挂就是这个）。本用例锁定修复。
            % 前提：gcs 必须指向测试模型（open_system 会设置）
            mdl = tc.ModelName;
            tc.addAndConnect([100 100 140 140], [500 100 540 140]);
            open_system(mdl);
            tc.verifyEqual(gcs, mdl, 'gcs 未指向测试模型，零参测试前提不成立');

            % 零参对齐（全选）
            hl = find_system(mdl, 'FindAll', 'on', 'Type', 'block');
            for h = hl(:)'
                set_param(h, 'Selected', 'on');
            end
            slAlignBlocks();
            pA = get_param([mdl '/GainA'], 'Position');
            pB = get_param([mdl '/GainB'], 'Position');
            tc.verifyEqual(pA(1), pB(1), '零参左对齐未生效');

            % 零参拆分（选线）
            tc.selectLines();
            slSplitGotoFrom();
            tc.verifyEqual(numel(find_system(mdl, 'SearchDepth', 1, ...
                'Type', 'block')), 4, '零参拆分未生效');

            % 零参高亮 / 信号对象解析 / 端口对齐（只要求不抛"输入参数不足"）
            slHighlightUnconnected();
            slSetSignalResolve();
            set_param([mdl '/GainB'], 'Selected', 'on');
            slAlignLinePorts();

            % 零参命名 + 大小统一（选 2 块）
            tc.selectBlocks({'GainA', 'GainB'});
            slAutoNameSignals();
            lines = find_system(mdl, 'FindAll', 'on', 'Type', 'line');
            names = get_param(lines, 'Name');
            tc.verifyTrue(any(strcmp(names, 'GainA')), '零参命名未生效');
            slUniformSize();
            % 注意比尺寸不比位置：上面的零参拆分会自动推块，A/B 位置本来
            % 就不同；大小统一的契约是"尺寸一致、中心不变"
            pA2 = get_param([mdl '/GainA'], 'Position');
            pB2 = get_param([mdl '/GainB'], 'Position');
            sA = [pA2(3) - pA2(1), pA2(4) - pA2(2)];
            sB = [pB2(3) - pB2(1), pB2(4) - pB2(2)];
            tc.verifyEqual(sA, sB, '零参大小统一未生效');
        end
    end

    %% ====================================================================
    %  11. 用户级配置 / 统一日志（3.3.0）
    %% ====================================================================
    methods (Test)
        function testUserConfigOverride(tc)
            % 白名单覆盖生效 + 非白名单键跳过 + 坏文件回落默认。
            % 3.3.1：走 SIMUTIDY_USERCONFIG 环境变量把配置文件重定向到
            % 临时目录——绝不碰真实用户文件（教训：旧版在真实路径上做
            % 备份/还原，文件锁导致坏 JSON 残留，用户启动即报警告）
            up = fullfile(tempdir, 'SimuTidy_test_config.json');
            setenv('SIMUTIDY_USERCONFIG', up);
            % 收尾不走 onCleanup：TestCase 的双参方法会被框架误认成
            % 参数化测试。临时文件即使断言失败漏删也只是 tempdir 垃圾，
            % 下次运行 fopen('w') 会覆盖

            json = ['{' newline ...
                '  "goto": {"gap": 77, "gapBad": "x"},' newline ...
                '  "log": {"level": "debug"},' newline ...
                '  "gui": {"showOnboarding": false},' newline ...
                '  "unknown": {"key": 1}' newline ...
                '}'];
            fid = fopen(up, 'w'); fwrite(fid, json); fclose(fid);

            cfg = SimuTidy_config();
            tc.verifyEqual(cfg.goto.gap, 77, '白名单覆盖未生效');
            tc.verifyEqual(cfg.log.level, 'debug', '日志等级覆盖未生效');
            tc.verifyEqual(cfg.gui.showOnboarding, false, '逻辑覆盖未生效');
            tc.verifyEqual(cfg.goto.tagVisibility, 'local', ...
                '非白名单字段不应影响默认值');

            % 坏 JSON：不抛错、回落默认
            fid = fopen(up, 'w'); fwrite(fid, '{bad json'); fclose(fid);
            cfg2 = SimuTidy_config();
            tc.verifyEqual(cfg2.goto.gap, 40, '坏文件应回落默认值');

            % 收尾：清环境变量 + 删临时文件
            setenv('SIMUTIDY_USERCONFIG', '');
            if isfile(up), delete(up); end
        end

        function testLogSink(tc)
            % 3.4.0 变更锁定：sink 转发 **info 及以上**（原只转 warn/error，
            % 为 GUI 日志区提供操作明细）；debug 仍不转发；清除后停止
            tc.sinkMsgs = {};
            simutidy.internal.setLogSink(@(msg, lv) tc.captureSink(msg, lv));
            cleaner = onCleanup(@() simutidy.internal.setLogSink([]));

            simutidy.internal.log('warn', 'tw%d', 1);
            simutidy.internal.log('info', 'yes-capture');
            simutidy.internal.log('error', 'tw%d', 2);
            simutidy.internal.log('debug', 'no-capture');
            tc.verifyEqual(numel(tc.sinkMsgs), 3, 'sink 应收 info/warn/error 共 3 条');
            tc.verifyEqual(tc.sinkMsgs{2}, 'info|yes-capture', 'info 应转发');

            simutidy.internal.setLogSink([]);
            simutidy.internal.log('warn', 'after-clear');
            tc.verifyEqual(numel(tc.sinkMsgs), 3, '清除后不应再转发');
        end

        function testResultFeedback(tc)
            % 3.3.0 结果反馈：批量操作可选输出 res（GUI 面板依赖此结构）
            mdl = tc.ModelName;
            % 成功路径：拆分 res 全零失败
            tc.addAndConnect([100 100 140 140], [500 100 540 140]);
            tc.selectLines();
            res = simutidy.splitGotoFrom(mdl);
            tc.verifyEqual(res.failCount, 0, '正常拆分不应有失败');
            tc.verifyEqual(res.okCount, 1);
            tc.verifyEqual(res.op, 'Goto/From 批量拆分');

            % 失败路径：选中无连线块 → 端口对齐失败并带可定位句柄
            add_block('built-in/Gain', [mdl '/Lonely'], 'Position', [100 300 140 340]);
            set_param([mdl '/Lonely'], 'Selected', 'on');
            res2 = simutidy.alignLinePorts(mdl);
            tc.verifyEqual(res2.failCount, 1, '无连线块应失败');
            % 句柄是 double，有效性用 ishandle（isvalid 只用于对象）
            tc.verifyTrue(ishandle(res2.failItems(1).handle), '失败对象句柄应有效');
            tc.verifyEqual(get_param(res2.failItems(1).handle, 'Name'), 'Lonely', ...
                '句柄应指向失败对象本身');
            tc.verifySubstring(res2.failItems(1).reason, '连线');
        end
    end
end
