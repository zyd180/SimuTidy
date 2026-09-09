function log(level, fmt, varargin)
%log 分级日志（3.3.0 统一日志系统，薄实现）
%   simutidy.internal.log('info', '对齐完成：%d', n)
%   等级：debug < info < warn < error；cfg.log.level 门控（默认 'info'，
%   即 debug 级静默；设为 'debug' 可在 SimuTidy_config_user.json 中打开）
%
%   输出：
%   - 命令行：格式化文案加 [LEVEL] 前缀（INFO/WARN/ERROR/DEBUG）
%   - GUI 状态栏：仅 warn/error 转发到注册的 sink（见 setLogSink 说明）
%
%   设计取舍（刻意从薄，别往厚里加）：
%   - 不落盘、不做多 sink、不做等级切换 UI——工具规模用不上；
%     需要时在此文件内扩展，消费方接口不变
%   - GUI sink 用 setappdata(0,...) 存放而非 persistent：无生命周期问题，
%     GUI 关闭时自行清除

    order = {'debug', 'info', 'warn', 'error'};
    lv = find(strcmp(order, level), 1);
    if isempty(lv)
        error('SimuTidy:badLogLevel', '未知日志等级: %s', level);
    end

    msg = sprintf(fmt, varargin{:});

    % 命令行输出（按 cfg.log.level 门控）
    try
        cfg = SimuTidy_config();
        cur = find(strcmp(order, cfg.log.level), 1);
    catch
        cur = 2;  % 配置读取失败按 info 处理，日志自身永不可让业务挂掉
    end
    if ~isempty(cur) && lv >= cur
        fprintf('[%s] %s\n', upper(level), msg);
    end

    % GUI 状态栏 sink：只收 warn/error
    if lv >= 3
        sink = getappdata(0, 'SimuTidy_LogSink');
        if ~isempty(sink)
            try
                sink(msg, level);
            catch
                % sink 出错静默，日志通道自身必须零故障
            end
        end
    end
end
