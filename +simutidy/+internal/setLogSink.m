function setLogSink(fn)
%setLogSink 注册/清除 GUI 日志接收器（3.3.0）
%   simutidy.internal.setLogSink(@(msg, level) ...)  注册（warn/error 会调用）
%   simutidy.internal.setLogSink([])                  清除
%
%   存放位置：setappdata(0, 'SimuTidy_LogSink', fn)——不用 persistent，
%   免除生命周期管理；GUI 关窗时由主窗口负责清除。
%   主窗口注册的 sink 把消息打到状态栏（warn=琥珀色，error=红色）

    if nargin < 1
        fn = [];
    end
    setappdata(0, 'SimuTidy_LogSink', fn);
end
