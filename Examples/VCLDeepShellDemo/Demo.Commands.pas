{ ============================================================================
  Demo.Commands

  Helper that registers demo business commands. Real apps register their own
  commands in TMainForm.RegisterCommands.
  ============================================================================ }

unit Demo.Commands;

interface

uses
  System.SysUtils,
  System.UITypes,
  Vcl.Controls,
  Vcl.Dialogs,
  DeepBase.VCL.DeepShell;

procedure RegisterDemoCommands(const ACommands: IShellCommandManager;
  const AStatus: IShellStatusManager);

implementation

procedure RegisterDemoCommands(const ACommands: IShellCommandManager;
  const AStatus: IShellStatusManager);
begin
  ACommands.RegisterCommand(
    ShellCommand('demo.scan.run', 'Run Scan')
      .Category('Run')
      .Shortcut('F5')
      .RiskLevel(rlLow)
      .OnExecute(procedure
        begin
          AStatus.TaskStart('scan-1', 'demo.scan', 'Scan started');
          AStatus.Progress('scan-1', 'demo.scan', 50, 'Scanning...');
          AStatus.TaskFinish('scan-1', 'Scan finished (fake)');
        end));

  ACommands.RegisterCommand(
    ShellCommand('demo.delete', 'Delete Selected')
      .Category('Edit')
      .RiskLevel(rlHigh)
      .GateKey('demo.delete_gate')
      .PurposeKey('demo.manage')
      .OnExecute(procedure
        begin
          if MessageDlg('Delete selected? (demo)', mtConfirmation,
              [mbYes, mbNo], 0) = mrYes then
            AStatus.Info('demo.edit', 'Deleted (fake)');
        end));

  ACommands.RegisterCommand(
    ShellCommand('demo.welcome', 'Welcome')
      .Category('Help')
      .OnExecute(procedure
        begin
          ShowMessage('DeepShell demo. Try View / Structure to open the' +
            sLineBreak + 'left tool window, then View / Toggle Bottom for' +
            sLineBreak + 'logs.');
        end));
end;

end.
