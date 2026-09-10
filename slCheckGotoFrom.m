function varargout = slCheckGotoFrom(varargin)
%slCheckGotoFrom 检查 Goto/From 标签配对问题（3.4.0 新增）
%   res = slCheckGotoFrom()        - 检查当前子系统
%   res = slCheckGotoFrom(sys)     - 指定子系统
%
%   检查项：悬空 Goto（无 From 引用）/ 无源 From / 跨层 local 标签引用。
%   返回 res（op/okCount/failCount/failItems），failItems 含可定位句柄；
%   不接输出时仅命令行汇总。实现见 simutidy.checkGotoFrom
    if nargout > 0
        [varargout{1:nargout}] = simutidy.checkGotoFrom(varargin{:});
    else
        simutidy.checkGotoFrom(varargin{:});
    end
end
