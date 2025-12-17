{ ============================================================================
  UniBase 可视化验收测试工具
  
  版本: 1.0
  说明: 提供分步可视化的验收测试界面
  
  功能:
    - 按验收计划分阶段执行测试
    - 实时显示测试进度和结果
    - 支持手动确认和自动测试
    - 生成验收报告
  ============================================================================ }

program UniBaseAcceptanceTest;

uses
  Vcl.Forms,
  AcceptanceMain in 'AcceptanceMain.pas' {frmAcceptanceMain},
  AcceptanceRunner in 'AcceptanceRunner.pas',
  AcceptanceReport in 'AcceptanceReport.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'UniBase 可视化验收测试';
  Application.CreateForm(TfrmAcceptanceMain, frmAcceptanceMain);
  Application.Run;
end.
