function txt = sltidy_getModelName()
%sltidy_getModelName 获取当前Simulink模型名称
%   txt = sltidy_getModelName()
%   返回格式化的模型名称文本，如果无模型打开则返回提示信息

    try
        mdl = bdroot;
        if isempty(mdl) || strcmp(mdl, '')
            txt = '当前模型: (无)';
        else
            txt = ['当前模型: ' mdl];
        end
    catch
        txt = '当前模型: (无)';
    end
end
