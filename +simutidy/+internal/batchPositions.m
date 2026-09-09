function posMat = batchPositions(handles)
%batchPositions 批量读取 Position → Nx4 矩阵（3.3.0 抽取）
%   背景：get_param(句柄向量, 'Position') 在多元素时返回 cell、单元素时
%   返回标量 1x4——单块子系统做碰撞缓存时会踩到单元素分支导致
%   cell2mat 崩溃（冒烟测试发现）。统一在此归一为矩阵。
    p = get_param(handles, 'Position');
    if iscell(p)
        posMat = cell2mat(p);
    else
        posMat = reshape(p, 1, 4);
    end
end
