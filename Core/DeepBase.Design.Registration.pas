{ ============================================================================
  DeepBase.Design.Registration - 设计期组件注册（dclDeepBaseCore 专用）

  版本: 1.0
  说明:
    为 dclDeepBaseCore.dpk 提供 Register 入口，使 Core 包中的可设计组件
    出现在 IDE 组件面板上。

    UI2-012 fix: dclDeepBaseCore.dpk 此前缺少 contains 子句，导致 IDE 无法
    调用任何 Register 过程。VCL/FMX 可视化组件已在各自的 dclDeepBaseVCL /
    dclDeepBaseFMX 包中注册，因此本单元仅注册 Core 包内暴露的可设计组件。

  TODO(UI2-012):
    1. 创建 dclDeepBaseCore.dcr 资源文件，为每个组件提供 24x24 位图图标。
       目前缺失 .dcr，组件将以默认图标显示在面板上。
    2. 当 Core 包新增可设计组件时，请在此处的 Register 过程中同步注册。
  ============================================================================ }

unit DeepBase.Design.Registration;

interface

uses
  System.Classes;

procedure Register;

implementation

// UI2-012 fix: 提供设计期注册入口。Core 包目前未包含可设计组件（TTrayIcon
// 为静态类，非 TComponent 子类），VCL/FMX 可视化组件由对应的 dclDeepBaseVCL
// 与 dclDeepBaseFMX 包负责注册。一旦 Core 包新增可设计组件，请在下方
// RegisterComponents 调用中添加。

procedure Register;
begin
  // UI2-012 fix: 保留注册入口以便后续扩展。
  // RegisterComponents('DeepBase', [...]);
end;

end.
