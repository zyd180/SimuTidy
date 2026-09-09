function varargout = progress(cmd, a, b, c)
%progress 批量操作进度对话框统一封装（3.3.0）
%   dlg  = progress('start', parentFig, total, title)
%   keep = progress('step', dlg, msg)    % 返回 false = 用户点了取消
%        = progress('done',  dlg)
%
%   设计取舍：
%   - parent 无效/为空时返回 []，step/done 全部退化为空操作——
%     命令行路径零弹窗零开销；只有 GUI 显式传窗口句柄才出现进度条
%   - 'Progress' 选项传"窗口句柄"而非布尔：uiprogressdlg 必须挂父窗口，
%     值即父窗，语义自然合一（见各批量函数的 varargin 解析）
%   - 计数状态存 persistent 而非对话框 appdata：实测 uiprogressdlg 返回
%     的对象不接受 setappdata；UI 单线程下同一时刻只有一个进度，够用

    persistent st
    if isempty(st)
        st = struct('dlg', [], 'total', 1, 'n', 0);
    end

    switch cmd
        case 'start'
            st = struct('dlg', [], 'total', max(1, b), 'n', 0);
            if ~isempty(a) && isvalid(a)
                st.dlg = uiprogressdlg(a, 'Title', 'SimuTidy', ...
                    'Message', c, 'CancelText', '取消', 'Value', 0);
            end
            varargout{1} = st.dlg;

        case 'step'
            keep = true;
            if ~isempty(st.dlg) && isvalid(st.dlg)
                st.n = st.n + 1;
                st.dlg.Value = st.n / st.total;
                st.dlg.Message = b;
                keep = ~st.dlg.CancelRequested;
            end
            varargout{1} = keep;

        case 'done'
            if ~isempty(st.dlg) && isvalid(st.dlg)
                close(st.dlg);
            end
            st = struct('dlg', [], 'total', 1, 'n', 0);
    end
end
