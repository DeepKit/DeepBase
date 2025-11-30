{ ============================================================================
  Tray.SysMonitor - System Resource Monitor Module
  
  Version: 1.0
  Description: Provides real-time monitoring of CPU, memory, and disk usage.
  ============================================================================ }

unit Tray.SysMonitor;

interface

uses
  Winapi.Windows,
  System.SysUtils,
  System.Classes;

type
  TSystemStats = record
    CPUUsage: Double;           // 0-100%
    MemoryTotal: Int64;         // Total physical memory (bytes)
    MemoryUsed: Int64;          // Used physical memory (bytes)
    MemoryUsagePercent: Double; // 0-100%
    DiskTotal: Int64;           // Total disk space (bytes) - system drive
    DiskFree: Int64;            // Free disk space (bytes)
    DiskUsagePercent: Double;   // 0-100%
    ProcessCount: Integer;      // Running process count
    ThreadCount: Integer;       // Total thread count
    HandleCount: Integer;       // Total handle count
  end;
  
  TOnStatsUpdate = procedure(const Stats: TSystemStats) of object;
  
  TSysMonitorThread = class(TThread)
  private
    FInterval: Integer;
    FStats: TSystemStats;
    FOnUpdate: TOnStatsUpdate;
    FLastIdleTime: Int64;
    FLastKernelTime: Int64;
    FLastUserTime: Int64;
    FFirstRun: Boolean;
    
    procedure DoUpdate;
    procedure QueryCPU;
    procedure QueryMemory;
    procedure QueryDisk;
    procedure QueryProcesses;
  protected
    procedure Execute; override;
  public
    constructor Create(AInterval: Integer = 1000);
    
    property OnUpdate: TOnStatsUpdate read FOnUpdate write FOnUpdate;
    property Stats: TSystemStats read FStats;
  end;
  
  TSysMonitor = class
  private
    FThread: TSysMonitorThread;
    FStats: TSystemStats;
    FOnUpdate: TOnStatsUpdate;
    FRunning: Boolean;
    
    procedure HandleUpdate(const AStats: TSystemStats);
  public
    constructor Create;
    destructor Destroy; override;
    
    procedure Start(AInterval: Integer = 1000);
    procedure Stop;
    
    function GetCurrentStats: TSystemStats;
    
    { Formatting helpers }
    class function FormatBytes(ABytes: Int64): string;
    class function FormatPercent(APercent: Double): string;
    
    property Stats: TSystemStats read FStats;
    property Running: Boolean read FRunning;
    property OnUpdate: TOnStatsUpdate read FOnUpdate write FOnUpdate;
  end;

implementation

// Windows API declaration for GetSystemTimes
function _GetSystemTimes(var lpIdleTime, lpKernelTime, lpUserTime: TFileTime): BOOL; stdcall;
  external kernel32 name 'GetSystemTimes';

{ TSysMonitorThread }

constructor TSysMonitorThread.Create(AInterval: Integer);
begin
  inherited Create(True);
  FInterval := AInterval;
  FFirstRun := True;
  FreeOnTerminate := False;
  ZeroMemory(@FStats, SizeOf(FStats));
end;

procedure TSysMonitorThread.Execute;
begin
  while not Terminated do
  begin
    QueryCPU;
    QueryMemory;
    QueryDisk;
    QueryProcesses;
    
    Synchronize(DoUpdate);
    
    Sleep(FInterval);
  end;
end;

procedure TSysMonitorThread.DoUpdate;
begin
  if Assigned(FOnUpdate) then
    FOnUpdate(FStats);
end;

procedure TSysMonitorThread.QueryCPU;
var
  IdleTime, KernelTime, UserTime: TFileTime;
  Idle, Kernel, User: Int64;
  IdleDiff, KernelDiff, UserDiff: Int64;
  SysTime: Int64;
begin
  if _GetSystemTimes(IdleTime, KernelTime, UserTime) then
  begin
    Idle := Int64(IdleTime.dwHighDateTime) shl 32 or IdleTime.dwLowDateTime;
    Kernel := Int64(KernelTime.dwHighDateTime) shl 32 or KernelTime.dwLowDateTime;
    User := Int64(UserTime.dwHighDateTime) shl 32 or UserTime.dwLowDateTime;
    
    if not FFirstRun then
    begin
      IdleDiff := Idle - FLastIdleTime;
      KernelDiff := Kernel - FLastKernelTime;
      UserDiff := User - FLastUserTime;
      
      SysTime := KernelDiff + UserDiff;
      
      if SysTime > 0 then
        FStats.CPUUsage := (1.0 - (IdleDiff / SysTime)) * 100.0
      else
        FStats.CPUUsage := 0;
        
      // Clamp
      if FStats.CPUUsage < 0 then FStats.CPUUsage := 0;
      if FStats.CPUUsage > 100 then FStats.CPUUsage := 100;
    end
    else
      FFirstRun := False;
    
    FLastIdleTime := Idle;
    FLastKernelTime := Kernel;
    FLastUserTime := User;
  end;
end;

procedure TSysMonitorThread.QueryMemory;
var
  MemStatus: TMemoryStatusEx;
begin
  ZeroMemory(@MemStatus, SizeOf(MemStatus));
  MemStatus.dwLength := SizeOf(MemStatus);
  
  if GlobalMemoryStatusEx(MemStatus) then
  begin
    FStats.MemoryTotal := MemStatus.ullTotalPhys;
    FStats.MemoryUsed := MemStatus.ullTotalPhys - MemStatus.ullAvailPhys;
    
    if FStats.MemoryTotal > 0 then
      FStats.MemoryUsagePercent := (FStats.MemoryUsed / FStats.MemoryTotal) * 100.0
    else
      FStats.MemoryUsagePercent := 0;
  end;
end;

procedure TSysMonitorThread.QueryDisk;
var
  FreeBytesAvailable, TotalBytes, TotalFreeBytes: Int64;
  SystemDrive: string;
begin
  // Get system drive (usually C:)
  SetLength(SystemDrive, MAX_PATH);
  GetWindowsDirectory(PChar(SystemDrive), MAX_PATH);
  SystemDrive := Copy(SystemDrive, 1, 3);  // e.g., "C:\"
  
  if GetDiskFreeSpaceEx(PChar(SystemDrive), FreeBytesAvailable, TotalBytes, @TotalFreeBytes) then
  begin
    FStats.DiskTotal := TotalBytes;
    FStats.DiskFree := TotalFreeBytes;
    
    if FStats.DiskTotal > 0 then
      FStats.DiskUsagePercent := ((FStats.DiskTotal - FStats.DiskFree) / FStats.DiskTotal) * 100.0
    else
      FStats.DiskUsagePercent := 0;
  end;
end;

procedure TSysMonitorThread.QueryProcesses;
var
  ProcessIds: array[0..1023] of DWORD;
  BytesReturned: DWORD;
begin
  // Simple process count estimate using EnumProcesses-like approach
  // For now, just set a placeholder
  FStats.ProcessCount := 0;
  FStats.ThreadCount := 0;
  FStats.HandleCount := 0;
end;

{ TSysMonitor }

constructor TSysMonitor.Create;
begin
  inherited Create;
  FThread := nil;
  FRunning := False;
  ZeroMemory(@FStats, SizeOf(FStats));
end;

destructor TSysMonitor.Destroy;
begin
  Stop;
  inherited;
end;

procedure TSysMonitor.HandleUpdate(const AStats: TSystemStats);
begin
  FStats := AStats;
  if Assigned(FOnUpdate) then
    FOnUpdate(AStats);
end;

procedure TSysMonitor.Start(AInterval: Integer);
begin
  if FRunning then
    Exit;
  
  FThread := TSysMonitorThread.Create(AInterval);
  FThread.OnUpdate := HandleUpdate;
  FThread.Start;
  FRunning := True;
end;

procedure TSysMonitor.Stop;
begin
  if not FRunning then
    Exit;
  
  if Assigned(FThread) then
  begin
    FThread.Terminate;
    FThread.WaitFor;
    FreeAndNil(FThread);
  end;
  
  FRunning := False;
end;

function TSysMonitor.GetCurrentStats: TSystemStats;
begin
  Result := FStats;
end;

class function TSysMonitor.FormatBytes(ABytes: Int64): string;
const
  KB = Int64(1024);
  MB = KB * 1024;
  GB = MB * 1024;
  TB = GB * 1024;
begin
  if ABytes >= TB then
    Result := Format('%.2f TB', [ABytes / TB])
  else if ABytes >= GB then
    Result := Format('%.2f GB', [ABytes / GB])
  else if ABytes >= MB then
    Result := Format('%.2f MB', [ABytes / MB])
  else if ABytes >= KB then
    Result := Format('%.2f KB', [ABytes / KB])
  else
    Result := Format('%d B', [ABytes]);
end;

class function TSysMonitor.FormatPercent(APercent: Double): string;
begin
  Result := Format('%.1f%%', [APercent]);
end;

end.
