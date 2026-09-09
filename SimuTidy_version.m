function [version, date] = SimuTidy_version()
%SimuTidy_version 获取SimuTidy版本信息
%   version = SimuTidy_version() - 返回版本号字符串
%   [version, date] = SimuTidy_version() - 返回版本号和日期
%
%   示例：
%       ver = SimuTidy_version()          % 返回 '2.0.0'
%       [ver, dt] = SimuTidy_version()    % 返回版本号和日期

    cfg = SimuTidy_config();
    version = cfg.version;
    date = cfg.versionDate;
    
    if nargout == 0
        fprintf('SimuTidy 版本: %s (%s)\n', version, date);
    end
end
