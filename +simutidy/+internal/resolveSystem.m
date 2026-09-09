function sysPath = resolveSystem(sys)
%resolveSystem 归一化并校验 sys 参数（3.1.0 工程质量收敛）
%   收敛原因：此前 7 个核心函数各自复制粘贴同一段样板：
%       if nargin < 1 || isempty(sys), sys = gcs; end
%       if isempty(sys) || ~ishandle(get_param(sys, 'Handle')), error(...); end
%   修改校验逻辑需要改 7 处，容易漏改导致行为不一致。
%
%   输入：sys - 子系统路径或句柄（可为空，空则取 gcs）
%   输出：sysPath - 校验通过的字符串路径
%   报错：SimuTidy:invalidSystem（3.1.0 起错误带 ID，便于上层捕获）

    if nargin < 1 || isempty(sys)
        sys = gcs;
    end
    if isempty(sys) || ~ishandle(get_param(sys, 'Handle'))
        error('SimuTidy:invalidSystem', '无效的子系统句柄或路径。');
    end
    sysPath = char(sys);
end
