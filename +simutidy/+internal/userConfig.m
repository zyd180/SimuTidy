function varargout = userConfig(cmd, vals)
%userConfig 用户级配置文件的统一读写口（3.3.0）
%   path = userConfig('path')          返回配置文件全路径
%   ok    = userConfig('write', vals)  校验并写入（vals 为嵌套 struct，
%                                      如 struct('goto', struct('gap', 77))）
%   wl    = userConfig('list')         返回白名单表 {键路径, MATLAB类型}
%
%   设计：
%   - 文件位于 userpath/SimuTidy_config_user.json，不随项目走（用户机器级）
%   - JSON 用**嵌套对象**格式（{"goto":{"gap":77}}）而非平铺点键——
%     jsondecode 会把点键名改写为合法标识符（'goto.gap'→'goto_gap'），
%     平铺方案无法往返，这是踩过坑后的定稿（3.3.0）
%   - 白名单以"组.字段"路径记账；写入端校验与读取端校验共用同一张表
%   - 写入失败返回 false 给对话框提示，不外抛

    persistent allowed
    if isempty(allowed)
        allowed = {
            'goto.defaultWidth',           'numeric'
            'goto.defaultHeight',          'numeric'
            'goto.gap',                    'numeric'
            'goto.tagVisibility',          'char'
            'naming.maxNameLength',        'numeric'
            'naming.replaceChars',         'char'
            'naming.replaceWith',          'char'
            'gui.refreshInterval',         'numeric'
            'gui.showOnboarding',          'logical'
            'simulink.updateAfterChange',  'logical'
            'log.level',                   'char'
        };
    end

    switch cmd
        case 'path'
            up = userpath;
            if isempty(up)
                up = fullfile(getenv('USERPROFILE'), 'Documents', 'MATLAB');
            end
            varargout{1} = fullfile(strtrim(up), 'SimuTidy_config_user.json');

        case 'list'
            varargout{1} = allowed;

        case 'write'
            % vals 为嵌套 struct。校验：白名单外的组/字段拒收；
            % 类型不符拒收；数值须有限。合法项重建为干净的嵌套 struct
            % 后 jsonencode（普通标识符可安全往返）
            clean = struct();
            groups = fieldnames(vals);
            for gi = 1:numel(groups)
                g = groups{gi};
                if ~isstruct(vals.(g))
                    warning('SimuTidy:badConfigGroup', ...
                        '配置组 "%s" 应为对象，已忽略。', g);
                    continue;
                end
                fk = fieldnames(vals.(g));
                for fi = 1:numel(fk)
                    key = [g '.' fk{fi}];
                    hit = find(strcmp(allowed(:, 1), key), 1);
                    if isempty(hit)
                        warning('SimuTidy:unknownConfigKey', ...
                            '设置项 "%s" 不在可配置清单中，已忽略。', key);
                        continue;
                    end
                    v = vals.(g).(fk{fi});
                    if ~isa(v, allowed{hit, 2})
                        warning('SimuTidy:badConfigType', ...
                            '设置项 "%s" 类型应为 %s，已忽略。', key, allowed{hit, 2});
                        continue;
                    end
                    if isnumeric(v) && ~all(isfinite(v(:)))
                        warning('SimuTidy:badConfigValue', ...
                            '设置项 "%s" 含非有限数值，已忽略。', key);
                        continue;
                    end
                    clean.(g).(fk{fi}) = v;
                end
            end

            % 注意：包函数内部不能用裸名自调用（'userConfig' 无法识别），
            % 必须全限定 simutidy.internal.userConfig
            fid = fopen(simutidy.internal.userConfig('path'), 'w');
            if fid == -1
                varargout{1} = false;
                return;
            end
            fwrite(fid, jsonencode(clean, 'PrettyPrint', true));
            fclose(fid);
            varargout{1} = ~isempty(fieldnames(clean));  % 全部被拒视为失败

        otherwise
            error('SimuTidy:badUserConfigCmd', '未知命令: %s', cmd);
    end
end
