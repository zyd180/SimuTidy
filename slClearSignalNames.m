function varargout = slClearSignalNames(varargin)
%slClearSignalNames 清除选中的信号线命名（3.4.0 新增）
%   slClearSignalNames()              - 清除当前子系统**选中**的信号线名称
%   slClearSignalNames(sys)           - 指定子系统
%
%   行为：只处理选中的线；一条都没选中时不做任何处理，仅 WARN 提醒
%   （不报错、不回落到全线清除——全线清除请用 slAutoNameSignals([], 'clear')）
%   实现：直转 simutidy.autoNameSignals([], 'clear_sel')，见该文件头说明
    % 零参时补一个空 sys 占位，否则下方拼接会把 'clear_sel' 误当 sys 传入
    if nargin < 1
        varargin = {[]};
    end
    if nargout > 0
        [varargout{1:nargout}] = simutidy.autoNameSignals(varargin{:}, 'clear_sel');
    else
        simutidy.autoNameSignals(varargin{:}, 'clear_sel');
    end
end
