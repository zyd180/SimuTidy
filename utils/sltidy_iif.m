function out = sltidy_iif(cond, a, b)
%sltidy_iif 三元运算符辅助函数
%   out = sltidy_iif(cond, a, b)
%   如果cond为true，返回a，否则返回b

    if cond
        out = a;
    else
        out = b;
    end
end
