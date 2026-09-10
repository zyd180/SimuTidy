function setLogSink(fn)
%setLogSink 注册/清除 GUI 日志接收器（3.3.0；3.4.0 扩展转发范围）
%   simutidy.internal.setLogSink(@(msg, level) ...)  注册（info 及以上会调用）
%   simutidy.internal.setLogSink([])                  清除
%
%   存放位置：setappdata(0, 'SimuTidy_LogSink', fn)——不用 persistent，
%   免除生命周期管理；GUI 关窗时由主窗口负责清除。
%   主窗口注册的 sink：状态栏显示 warn/error（带色），日志区追加全部
%   info 及以上明细（3.4.0，见 SimuTidy_mainGUI.guiLogSink）
%   3.4.0 变更：转发范围 warn/error → info 及以上（日志区需要操作明细）

    if nargin < 1
        fn = [];
    end
    setappdata(0, 'SimuTidy_LogSink', fn);
end
