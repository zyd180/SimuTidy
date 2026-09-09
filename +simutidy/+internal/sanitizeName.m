function out = sanitizeName(name)
%sanitizeName 按 SimuTidy_config 的规则清洗名称中的非法字符
%   3.1.0 工程质量收敛：此前 3 处（autoNameSignals / splitGotoFrom /
%   updateBlockNames）各自执行相同的 regexprep。清洗规则只应有一处定义，
%   修改 cfg.naming.replaceChars 后所有调用方行为自动一致。
%
%   说明：不会去掉首尾空白；空输入返回空输出

    cfg = SimuTidy_config();
    out = regexprep(char(name), cfg.naming.replaceChars, cfg.naming.replaceWith);
end
