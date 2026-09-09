function report(label, okCount, failCount, failInfo)
%report 批量操作的统一汇总输出（3.1.0 工程质量收敛）
%   收敛原因：此前各批量函数自行拼接"成功 N 失败 M + 逐条原因"的
%   fprintf，格式互不一致。统一后：
%     - 全部成功：只报一行成功数
%     - 有失败：追加逐条 failInfo 明细
%
%   输入：
%       label     - 操作名（如 '连线端口对齐'，不带"完成"二字）
%       okCount   - 成功条数
%       failCount - 失败条数
%       failInfo  - 1xN cell，逐条失败说明（与 print 顺序一致）

    if failCount == 0
        fprintf('%s完成：成功 %d 个。\n', label, okCount);
        return;
    end
    fprintf('%s完成：成功 %d 个，失败 %d 个。\n', label, okCount, failCount);
    for i = 1:numel(failInfo)
        fprintf('%s\n', failInfo{i});
    end
end
