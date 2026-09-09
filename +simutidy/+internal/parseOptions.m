function opt = parseOptions(args, allowed)
%parseOptions 名值对选项解析（3.3.0，批量函数的 'Progress' 等共用）
%   opt = simutidy.internal.parseOptions(varargin, {'Progress'})
%   返回 struct，字段名为小写选项名；重复选项后者覆盖；
%   未知选项/奇数参数直接报错（带 ID）
    if mod(numel(args), 2) ~= 0
        error('SimuTidy:badArgs', '名值对参数不完整。');
    end
    % 预置所有允许选项为 []：未传的选项统一落空值，
    % 消费方 opt.progress 直接可读（空=未启用），免去 isfield 判断
    opt = struct();
    for k = 1:numel(allowed)
        opt.(lower(allowed{k})) = [];
    end
    for k = 1:2:numel(args)
        name = lower(char(args{k}));
        if ~any(strcmp(lower(allowed), name))
            error('SimuTidy:unknownOption', '未知选项: %s', args{k});
        end
        opt.(name) = args{k+1};
    end
end
