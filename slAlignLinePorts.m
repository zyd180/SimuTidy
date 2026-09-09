function varargout = slAlignLinePorts(varargin)
%slAlignLinePorts 兼容包装（3.1.0 命名空间化：实体已迁至 +simutidy 包）
%   本文件仅为向后兼容保留：签名、输出、报错行为与 3.0.0 完全一致，
%   GUI、Toolstrip JSON、sl_customization 菜单及用户既有脚本均无需改动。
%   新代码请直接调用 simutidy.alignLinePorts；本包装不得再添加任何新逻辑。
    if nargout > 0
        [varargout{1:nargout}] = simutidy.alignLinePorts(varargin{:});
    else
        simutidy.alignLinePorts(varargin{:});
    end
end
