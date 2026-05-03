{ ============================================================================
  UserAuthDemo - UniBase 用户认证与账务演示程序 (VCL)
  
  版本: 1.0
  说明: 演示 AipexBase 用户认证、余额充值、用量统计和账单功能
  ============================================================================ }

program UserAuthDemo;

uses
  Vcl.Forms,
  UserAuthDemo.MainForm in 'UserAuthDemo.MainForm.pas' {MainForm},
  UniBase.AipexBase.Client in '..\..\ThirdParty\AipexBase\UniBase.AipexBase.Client.pas',
  UniBase.VCL.LoginDialog in '..\..\VCL\UniBase.VCL.LoginDialog.pas',
  UniBase.VCL.RegisterDialog in '..\..\VCL\UniBase.VCL.RegisterDialog.pas',
  UniBase.VCL.ForgotPasswordDialog in '..\..\VCL\UniBase.VCL.ForgotPasswordDialog.pas',
  UniBase.VCL.UserProfileFrame in '..\..\VCL\UniBase.VCL.UserProfileFrame.pas',
  UniBase.VCL.BalanceFrame in '..\..\VCL\UniBase.VCL.BalanceFrame.pas',
  UniBase.VCL.UsageStatsFrame in '..\..\VCL\UniBase.VCL.UsageStatsFrame.pas',
  UniBase.VCL.BillingFrame in '..\..\VCL\UniBase.VCL.BillingFrame.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'UniBase 用户认证演示';
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
