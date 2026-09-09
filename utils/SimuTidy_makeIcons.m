function SimuTidy_makeIcons(variant)
%SimuTidy_makeIcons 重新生成 Toolstrip 图标（resources/icons/*.png）
%   SimuTidy_makeIcons()        - 浅色调色板，输出 resources/icons/
%   SimuTidy_makeIcons('dark')  - 深色调色板（亮色变体），输出 resources/icons_dark/
%                                 16/24 两档像素、同文件名
%
%   说明：
%       - 纯基础 MATLAB 实现（imwrite 为基础函数），无需任何工具箱
%       - 图形为扁平实心像素块，透明背景（RGBA），配色取自 SimuTidy_config 主题调色板
%       - 修改图标设计后重跑本脚本即可全部重新生成
%
%   3.2.0 深色变体说明（最小交付，见 CHANGELOG）：
%       icons_dark/ 只是"能力储备"——Toolstrip JSON 的图标路径仍指向
%       icons/；若确认深色 MATLAB 环境需要，把 simutidyTab_actions.json
%       中 "icons/" 前缀改为 "icons_dark/" 并执行 slReloadToolstripConfig
%       即可整体切换（约半天工作量，未随本版实现自动切换）

    % 输出目录与调色板按变体决定（无参 = 浅色 = 既有行为，兼容旧调用）
    if nargin < 1 || isempty(variant)
        variant = 'light';
    end
    assert(any(strcmp(variant, {'light', 'dark'})), ...
        'variant 只能是 ''light'' 或 ''dark''。');

    rootDir = fullfile(fileparts(mfilename('fullpath')), '..');
    outSub = sltidy_iif(strcmp(variant, 'dark'), 'icons_dark', 'icons');
    outDir = fullfile(rootDir, 'resources', outSub);
    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end

    cfg = SimuTidy_config();
    pal = cfg.themes.(variant);   % 直接取指定主题的调色板（与用户当前偏好解耦）
    col.export = pal.export;
    col.module = pal.module;
    col.moduleDark = pal.moduleDark;
    col.line = pal.line;
    col.lineDark = pal.lineDark;
    col.port = pal.port;
    col.portDark = pal.portDark;
    col.check = pal.check;

    % 3.2.0 修复（2.7.0 起潜伏的存量 bug）：调色板是 0~1 浮点，直接赋给
    % uint8 画布会被截断成 0（uint8(0.169)=0），导致所有图标自诞生起
    % 就是近黑色。必须先按 255 缩放取整再进画布
    flds = fieldnames(col);
    for i = 1:numel(flds)
        col.(flds{i}) = uint8(round(col.(flds{i}) * 255));
    end

    % 图标名 → 所属分区色
    map = { ...
        'openTidy',   'export'; ...
        'align',     'module'; ...
        'align_l',   'module'; ...
        'align_r',   'module'; ...
        'align_t',   'module'; ...
        'align_b',   'module'; ...
        'align_hc',  'module'; ...
        'align_vc',  'module'; ...
        'align_hs',  'module'; ...
        'align_vs',  'module'; ...
        'size',      'moduleDark'; ...
        'portalign', 'lineDark'; ...
        'name',      'line'; ...
        'split',     'lineDark'; ...
        'genport',   'port'; ...
        'updname',   'portDark'; ...
        'highlight', 'check'; ...
        'resolve',   'lineDark'};

    n = 0;
    for k = 1:size(map, 1)
        for s = [16, 24]
            c = drawIcon(map{k, 1}, s, col.(map{k, 2}));
            imwrite(c(:, :, 1:3), fullfile(outDir, sprintf('%s_%d.png', map{k, 1}, s)), ...
                    'PNG', 'Alpha', double(c(:, :, 4)) / 255);
            n = n + 1;
        end
    end
    fprintf('图标生成完毕：共 %d 个 PNG（%d 图标 × 2 尺寸）\n', n, n/2);
end

%% ========================================================================
%  图标绘制
%% ========================================================================
function c = drawIcon(name, s, col)
%drawIcon 在 s×s 透明画布上按 16 网格设计坐标绘制图标
    c = zeros(s, s, 4, 'uint8');

    switch name
        case 'openTidy'
            % 窗口：外框 + 标题条
            c = outlineRect(c, 2, 3, 13, 13, col, 1);
            c = fillRect(c, 2, 3, 13, 5, col);

        case 'align'
            % 下拉主图标：左侧基准竖线 + 3 条横条
            c = fillRect(c, 3, 2, 3.8, 13, col);
            c = fillRect(c, 5, 3, 12, 4, col);
            c = fillRect(c, 5, 7, 12, 8, col);
            c = fillRect(c, 5, 11, 12, 12, col);

        case 'align_l'
            c = fillRect(c, 3, 2, 3.8, 13, col);
            c = fillRect(c, 5, 3, 13, 4, col);
            c = fillRect(c, 5, 7, 13, 8, col);
            c = fillRect(c, 5, 11, 13, 12, col);

        case 'align_r'
            c = drawIcon('align_l', s, col);
            c = c(:, end:-1:1, :);

        case 'align_t'
            c = fillRect(c, 2, 3, 13, 3.8, col);
            c = fillRect(c, 3, 5, 4, 13, col);
            c = fillRect(c, 7, 5, 8, 13, col);
            c = fillRect(c, 11, 5, 12, 13, col);

        case 'align_b'
            c = drawIcon('align_t', s, col);
            c = c(end:-1:1, :, :);

        case 'align_hc'
            c = fillRect(c, 7, 2, 8, 13, col);
            c = fillRect(c, 1, 3, 6, 4, col);
            c = fillRect(c, 1, 7, 6, 8, col);
            c = fillRect(c, 1, 11, 6, 12, col);
            c = fillRect(c, 9, 3, 14, 4, col);
            c = fillRect(c, 9, 7, 14, 8, col);
            c = fillRect(c, 9, 11, 14, 12, col);

        case 'align_vc'
            c = fillRect(c, 2, 7, 13, 8, col);
            c = fillRect(c, 3, 1, 4, 6, col);
            c = fillRect(c, 7, 1, 8, 6, col);
            c = fillRect(c, 11, 1, 12, 6, col);
            c = fillRect(c, 3, 9, 4, 14, col);
            c = fillRect(c, 7, 9, 8, 14, col);
            c = fillRect(c, 11, 9, 12, 14, col);

        case 'align_hs'
            c = fillRect(c, 2, 3, 3, 12, col);
            c = fillRect(c, 7, 3, 8, 12, col);
            c = fillRect(c, 12, 3, 13, 12, col);

        case 'align_vs'
            c = fillRect(c, 3, 2, 12, 3, col);
            c = fillRect(c, 3, 7, 12, 8, col);
            c = fillRect(c, 3, 12, 12, 13, col);

        case 'size'
            % 小实心方块 + 大空心方块（统一大小语义）
            c = fillRect(c, 1, 8, 6, 13, col);
            c = outlineRect(c, 7, 1, 14, 8, col, 1);

        case 'portalign'
            % 左右端口方块 + 中间水平直线
            c = fillRect(c, 1, 6, 4, 9, col);
            c = fillRect(c, 11, 6, 14, 9, col);
            c = fillRect(c, 4, 7, 11, 8, col);

        case 'name'
            % 信号线折角 + 标签块
            c = fillRect(c, 6, 1, 14, 6, col);
            c = fillRect(c, 1, 11.5, 9, 12.5, col);
            c = fillRect(c, 8.5, 7, 9.5, 12.5, col);

        case 'split'
            % 线断开 + 右向箭头 + 标签块（Goto/From 语义）
            c = fillRect(c, 0, 7, 3, 8, col);
            c = fillRect(c, 4, 5, 5.5, 10, col);
            c = fillRect(c, 5.5, 6, 6.5, 9, col);
            c = fillRect(c, 7, 7, 9, 8, col);
            c = fillRect(c, 10, 5, 14.5, 10, col);

        case 'genport'
            % 中心端口方块 + 双向外伸箭头
            c = fillRect(c, 6, 6, 9, 9, col);
            c = fillRect(c, 2, 7, 6, 8, col);
            c = fillRect(c, 0, 5.5, 2, 9.5, col);
            c = fillRect(c, 9, 7, 13, 8, col);
            c = fillRect(c, 13, 5.5, 15, 9.5, col);

        case 'updname'
            % 文本行 + 斜置铅笔
            c = fillRect(c, 2, 3, 10, 4, col);
            c = fillRect(c, 2, 6, 8, 7, col);
            for i = 0:5
                c = fillRect(c, 8+i, 12-i, 9.5+i, 13-i, col);
            end
            c = fillRect(c, 13.5, 6, 15, 7.5, col);

        case 'highlight'
            % 空心圆环（未连接端点语义）
            cx = s/2; cy = s/2;
            r1 = s * 0.36; r2 = s * 0.17;
            for yy = 1:s
                for xx = 1:s
                    d = (xx - 0.5 - cx)^2 + (yy - 0.5 - cy)^2;
                    if d <= r1^2 && d >= r2^2
                        c(yy, xx, 1:3) = reshape(col, 1, 1, 3);
                        c(yy, xx, 4) = 255;
                    end
                end
            end

        case 'resolve'
            % 信号线 + 右下角对勾角标（信号名解析为对象语义）
            c = fillRect(c, 1, 3, 13, 4, col);
            c = fillRect(c, 1, 8, 6, 9, col);
            c = drawDiag(c, 7.5, 9.5, 9.5, 12, col, 1.2);
            c = drawDiag(c, 9.5, 12, 14, 7, col, 1.2);

        otherwise
            error('未知图标: %s', name);
    end
end

%% ========================================================================
%  图元绘制辅助（设计坐标 0~16，x 向右、y 向下，含透明通道）
%% ========================================================================
function c = fillRect(c, x1, y1, x2, y2, col)
%fillRect 实心矩形（设计坐标含端点）
    s = size(c, 1);
    xa = max(1, floor(x1 * s / 16) + 1);
    xb = min(s, ceil(x2 * s / 16));
    ya = max(1, floor(y1 * s / 16) + 1);
    yb = min(s, ceil(y2 * s / 16));
    if xa > xb || ya > yb
        return;
    end
    c(ya:yb, xa:xb, 1:3) = repmat(reshape(col, 1, 1, 3), yb - ya + 1, xb - xa + 1);
    c(ya:yb, xa:xb, 4) = 255;
end

function c = drawDiag(c, x1, y1, x2, y2, col, th)
%drawDiag 斜线段（沿连线以小方块步进绘制）
    n = max(2, ceil(max(abs(x2 - x1), abs(y2 - y1)) / 0.4));
    for i = 0:n
        xx = x1 + (x2 - x1) * i / n;
        yy = y1 + (y2 - y1) * i / n;
        c = fillRect(c, xx - th/2, yy - th/2, xx + th/2, yy + th/2, col);
    end
end

function c = outlineRect(c, x1, y1, x2, y2, col, t)
%outlineRect 空心矩形（四边描边，厚度 t 为设计单位）
    c = fillRect(c, x1, y1, x2, y1 + t, col);          % 上边
    c = fillRect(c, x1, y2 - t, x2, y2, col);          % 下边
    c = fillRect(c, x1, y1, x1 + t, y2, col);          % 左边
    c = fillRect(c, x2 - t, y1, x2, y2, col);          % 右边
end
