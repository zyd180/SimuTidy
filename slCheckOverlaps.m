function varargout = slCheckOverlaps(varargin)
%slCheckOverlaps 检查当前层级互相重叠的模块（3.4.0 新增）
%   res = slCheckOverlaps()        - 检查当前子系统
%   res = slCheckOverlaps(sys)     - 指定子系统
%
%   返回 res（op/okCount/failCount/failItems），failItems 含可定位句柄；
%   不接输出时仅命令行汇总。实现见 simutidy.checkOverlaps
    if nargout > 0
        [varargout{1:nargout}] = simutidy.checkOverlaps(varargin{:});
    else
        simutidy.checkOverlaps(varargin{:});
    end
end
