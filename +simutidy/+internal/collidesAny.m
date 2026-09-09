function tf = collidesAny(rect, selfH, cacheH, cacheR)
%collidesAny 检查矩形是否与缓存中其他模块重叠（AABB 相交测试）
%   3.1.0 工程质量收敛：此前 slAlignLinePorts 与 slSplitGotoFrom 各持有
%   一份逐字节相同的副本，修改碰撞规则要同步改两处。统一为本实现后，
%   两处调用 simutidy.internal.collidesAny。
%
%   输入：
%       rect   - 1x4 [left top right bottom]
%       selfH  - 需从检查中排除的句柄（自身或同组块）
%       cacheH - 缓存的全部块句柄
%       cacheR - 与 cacheH 对应的 1x4 位置矩阵

    tf = any(~ismember(cacheH(:), selfH) & ...
             ~(cacheR(:, 3) < rect(1) | cacheR(:, 1) > rect(3) | ...
               cacheR(:, 4) < rect(2) | cacheR(:, 2) > rect(4)));
end
