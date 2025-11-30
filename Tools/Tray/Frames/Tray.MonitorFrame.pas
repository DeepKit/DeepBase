{ ============================================================================
  Tray.MonitorFrame - System Monitor UI Frame
  
  Version: 1.0
  Description: Displays real-time system resource usage with progress bars
               and text labels.
  ============================================================================ }

unit Tray.MonitorFrame;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Classes,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.ComCtrls,
  Tray.SysMonitor;

type
  TMonitorFrame = class(TFrame)
  private
    FMonitor: TSysMonitor;
    
    { CPU }
    FLblCPU: TLabel;
    FPrgCPU: TProgressBar;
    FLblCPUValue: TLabel;
    
    { Memory }
    FLblMemory: TLabel;
    FPrgMemory: TProgressBar;
    FLblMemoryValue: TLabel;
    
    { Disk }
    FLblDisk: TLabel;
    FPrgDisk: TProgressBar;
    FLblDiskValue: TLabel;
    
    { Process info }
    FLblProcesses: TLabel;
    FLblProcessesValue: TLabel;
    
    procedure CreateUI;
    procedure OnStatsUpdate(const Stats: TSystemStats);
    function GetBarColor(Percent: Double): TColor;
    
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    
    procedure StartMonitoring;
    procedure StopMonitoring;
  end;

implementation

{$R *.dfm}

const
  LABEL_WIDTH = 60;
  BAR_HEIGHT = 16;
  ROW_HEIGHT = 50;
  MARGIN = 8;

{ TMonitorFrame }

constructor TMonitorFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FMonitor := TSysMonitor.Create;
  FMonitor.OnUpdate := OnStatsUpdate;
  
  Color := $002D2D2D;  // Dark background
  
  CreateUI;
end;

destructor TMonitorFrame.Destroy;
begin
  FMonitor.Stop;
  FMonitor.Free;
  inherited;
end;

procedure TMonitorFrame.CreateUI;
var
  Y: Integer;
begin
  Y := MARGIN;
  
  // === CPU Section ===
  FLblCPU := TLabel.Create(Self);
  FLblCPU.Parent := Self;
  FLblCPU.Caption := 'CPU';
  FLblCPU.Font.Color := clWhite;
  FLblCPU.Font.Size := 9;
  FLblCPU.Left := MARGIN;
  FLblCPU.Top := Y;
  FLblCPU.Width := LABEL_WIDTH;
  
  FLblCPUValue := TLabel.Create(Self);
  FLblCPUValue.Parent := Self;
  FLblCPUValue.Caption := '0%';
  FLblCPUValue.Font.Color := clWhite;
  FLblCPUValue.Font.Size := 9;
  FLblCPUValue.Alignment := taRightJustify;
  FLblCPUValue.AutoSize := False;
  FLblCPUValue.Width := 60;
  FLblCPUValue.Left := Self.Width - FLblCPUValue.Width - MARGIN;
  FLblCPUValue.Top := Y;
  FLblCPUValue.Anchors := [akTop, akRight];
  
  Inc(Y, 18);
  
  FPrgCPU := TProgressBar.Create(Self);
  FPrgCPU.Parent := Self;
  FPrgCPU.Left := MARGIN;
  FPrgCPU.Top := Y;
  FPrgCPU.Width := Self.Width - 2 * MARGIN;
  FPrgCPU.Height := BAR_HEIGHT;
  FPrgCPU.Max := 100;
  FPrgCPU.Position := 0;
  FPrgCPU.Anchors := [akLeft, akTop, akRight];
  
  Inc(Y, ROW_HEIGHT);
  
  // === Memory Section ===
  FLblMemory := TLabel.Create(Self);
  FLblMemory.Parent := Self;
  FLblMemory.Caption := 'Memory';
  FLblMemory.Font.Color := clWhite;
  FLblMemory.Font.Size := 9;
  FLblMemory.Left := MARGIN;
  FLblMemory.Top := Y;
  FLblMemory.Width := LABEL_WIDTH;
  
  FLblMemoryValue := TLabel.Create(Self);
  FLblMemoryValue.Parent := Self;
  FLblMemoryValue.Caption := '0 / 0 GB';
  FLblMemoryValue.Font.Color := clWhite;
  FLblMemoryValue.Font.Size := 9;
  FLblMemoryValue.Alignment := taRightJustify;
  FLblMemoryValue.AutoSize := False;
  FLblMemoryValue.Width := 120;
  FLblMemoryValue.Left := Self.Width - FLblMemoryValue.Width - MARGIN;
  FLblMemoryValue.Top := Y;
  FLblMemoryValue.Anchors := [akTop, akRight];
  
  Inc(Y, 18);
  
  FPrgMemory := TProgressBar.Create(Self);
  FPrgMemory.Parent := Self;
  FPrgMemory.Left := MARGIN;
  FPrgMemory.Top := Y;
  FPrgMemory.Width := Self.Width - 2 * MARGIN;
  FPrgMemory.Height := BAR_HEIGHT;
  FPrgMemory.Max := 100;
  FPrgMemory.Position := 0;
  FPrgMemory.Anchors := [akLeft, akTop, akRight];
  
  Inc(Y, ROW_HEIGHT);
  
  // === Disk Section ===
  FLblDisk := TLabel.Create(Self);
  FLblDisk.Parent := Self;
  FLblDisk.Caption := 'Disk';
  FLblDisk.Font.Color := clWhite;
  FLblDisk.Font.Size := 9;
  FLblDisk.Left := MARGIN;
  FLblDisk.Top := Y;
  FLblDisk.Width := LABEL_WIDTH;
  
  FLblDiskValue := TLabel.Create(Self);
  FLblDiskValue.Parent := Self;
  FLblDiskValue.Caption := '0 / 0 GB';
  FLblDiskValue.Font.Color := clWhite;
  FLblDiskValue.Font.Size := 9;
  FLblDiskValue.Alignment := taRightJustify;
  FLblDiskValue.AutoSize := False;
  FLblDiskValue.Width := 120;
  FLblDiskValue.Left := Self.Width - FLblDiskValue.Width - MARGIN;
  FLblDiskValue.Top := Y;
  FLblDiskValue.Anchors := [akTop, akRight];
  
  Inc(Y, 18);
  
  FPrgDisk := TProgressBar.Create(Self);
  FPrgDisk.Parent := Self;
  FPrgDisk.Left := MARGIN;
  FPrgDisk.Top := Y;
  FPrgDisk.Width := Self.Width - 2 * MARGIN;
  FPrgDisk.Height := BAR_HEIGHT;
  FPrgDisk.Max := 100;
  FPrgDisk.Position := 0;
  FPrgDisk.Anchors := [akLeft, akTop, akRight];
  
  Inc(Y, ROW_HEIGHT);
  
  // === Process Info Section ===
  FLblProcesses := TLabel.Create(Self);
  FLblProcesses.Parent := Self;
  FLblProcesses.Caption := 'Processes';
  FLblProcesses.Font.Color := clWhite;
  FLblProcesses.Font.Size := 9;
  FLblProcesses.Left := MARGIN;
  FLblProcesses.Top := Y;
  
  FLblProcessesValue := TLabel.Create(Self);
  FLblProcessesValue.Parent := Self;
  FLblProcessesValue.Caption := '0 processes, 0 threads';
  FLblProcessesValue.Font.Color := clSilver;
  FLblProcessesValue.Font.Size := 9;
  FLblProcessesValue.Alignment := taRightJustify;
  FLblProcessesValue.AutoSize := False;
  FLblProcessesValue.Width := 180;
  FLblProcessesValue.Left := Self.Width - FLblProcessesValue.Width - MARGIN;
  FLblProcessesValue.Top := Y;
  FLblProcessesValue.Anchors := [akTop, akRight];
end;

procedure TMonitorFrame.OnStatsUpdate(const Stats: TSystemStats);
begin
  // CPU
  FPrgCPU.Position := Round(Stats.CPUUsage);
  FLblCPUValue.Caption := TSysMonitor.FormatPercent(Stats.CPUUsage);
  
  // Memory
  FPrgMemory.Position := Round(Stats.MemoryUsagePercent);
  FLblMemoryValue.Caption := Format('%s / %s',
    [TSysMonitor.FormatBytes(Stats.MemoryUsed),
     TSysMonitor.FormatBytes(Stats.MemoryTotal)]);
  
  // Disk
  FPrgDisk.Position := Round(Stats.DiskUsagePercent);
  FLblDiskValue.Caption := Format('%s free / %s',
    [TSysMonitor.FormatBytes(Stats.DiskFree),
     TSysMonitor.FormatBytes(Stats.DiskTotal)]);
  
  // Processes
  FLblProcessesValue.Caption := Format('%d processes, %d threads',
    [Stats.ProcessCount, Stats.ThreadCount]);
end;

function TMonitorFrame.GetBarColor(Percent: Double): TColor;
begin
  if Percent >= 90 then
    Result := clRed
  else if Percent >= 70 then
    Result := $000080FF  // Orange
  else
    Result := clGreen;
end;

procedure TMonitorFrame.StartMonitoring;
begin
  FMonitor.Start(1000);  // Update every second
end;

procedure TMonitorFrame.StopMonitoring;
begin
  FMonitor.Stop;
end;

end.
