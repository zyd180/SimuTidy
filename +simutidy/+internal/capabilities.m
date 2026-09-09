function cap = capabilities()
%capabilities 特性检测集中管理（3.1.0 兼容层抽象）
%   收敛原因：版本/许可证/组件能力判断此前散落各处——
%     - install 第5步: exist('slReloadToolstripConfig', 'file')
%     - exportWebView: license('test', 'Simulink_Report_Gen')
%   新增消费方容易各写一份、口径不一。统一从本函数取，未来
%   MATLAB 新版本特性检测只需改这里。
%
%   输出 struct 字段：
%       hasToolstrip - 是否支持 Toolstrip 定制（R2022b+，决定 SimuTidy 选项卡
%                      还是回退 Tools 菜单）
%       hasReportGen - 是否有 Simulink Report Generator 许可证
%                      （决定导出 Web 视图是否可用）
%       matlabVer    - MATLAB 版本字符串（诊断用）

    cap = struct();
    cap.hasToolstrip = exist('slReloadToolstripConfig', 'file') ~= 0;
    cap.hasReportGen = logical(license('test', 'Simulink_Report_Gen'));
    cap.matlabVer = version;
end
