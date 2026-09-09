function report(label, okCount, failCount, failInfo)
%report 批量操作的统一汇总输出（3.1.0 收敛格式；3.3.0 接入分级日志）
%   输出规则：
%   - 全部成功 → [INFO] 一行
%   - 有失败 → [WARN] 汇总行 + 逐条 [WARN] 明细（GUI 状态栏同步显示首条）
%
%   输入：
%       label     - 操作名（如 '连线端口对齐'，不带"完成"二字）
%       okCount   - 成功条数
%       failCount - 失败条数
%       failInfo  - 1xN cell，逐条失败说明（与 print 顺序一致）

    if failCount == 0
        simutidy.internal.log('info', '%s完成：成功 %d 个。', label, okCount);
        return;
    end
    simutidy.internal.log('warn', '%s完成：成功 %d 个，失败 %d 个。', label, okCount, failCount);
    for i = 1:numel(failInfo)
        simutidy.internal.log('warn', '%s', failInfo{i});
    end
end
