{ ============================================================================
  DeepBase.Manager.Operational - Operational helpers for TDeepBaseManager

  Version: 0.3
  Description: Retention and health-check logic extracted from the manager
               orchestration unit.
  ============================================================================ }

unit DeepBase.Manager.Operational;

interface

uses
  System.SysUtils,
  DeepBase.Types,
  DeepBase.Config,
  DeepBase.Logging,
  DeepBase.Storage.Interfaces;

type
  TDeepBaseManagerOperational = class
  public
    class function GetRetentionDays(const AConfig: TDeepBaseConfig;
      const SettingKey: string; DefaultValue: Integer): Integer; static;
    class function TableExists(const AStorage: IManagerStorage;
      AConnectionReady: Boolean; const TableName: string): Boolean; static;
    class function TableHasColumn(const AStorage: IManagerStorage;
      AConnectionReady: Boolean; const TableName, ColumnName: string): Boolean; static;
    class function ResolveTimeColumn(const AStorage: IManagerStorage;
      AConnectionReady: Boolean; const TableName, Preferred,
      Fallback: string): string; static;
    class procedure ArchiveAndTrimTable(const AStorage: IManagerStorage;
      AConnectionReady: Boolean; const TableName, TimeColumn: string;
      DaysToKeep: Integer); static;
    class procedure RunRetention(const AStorage: IManagerStorage;
      AConnectionReady: Boolean; const AConfig: TDeepBaseConfig;
      const ALogger: TDeepBaseLogger); static;
    class function HealthCheck(AIsInitialized: Boolean;
      AConnectionReady: Boolean; const ARootPath: string): THealthCheckResult; static;
  end;

implementation

uses
  System.DateUtils,
  System.IOUtils;

{ TDeepBaseManagerOperational }

class function TDeepBaseManagerOperational.GetRetentionDays(
  const AConfig: TDeepBaseConfig; const SettingKey: string;
  DefaultValue: Integer): Integer;
var
  RawValue: string;
begin
  Result := DefaultValue;
  if Assigned(AConfig) then
    RawValue := Trim(AConfig.GetConfig(SettingKey, IntToStr(DefaultValue)))
  else
    RawValue := IntToStr(DefaultValue);

  Result := StrToIntDef(RawValue, DefaultValue);
  if Result < 0 then
    Result := DefaultValue;
  if Result > 36500 then
    Result := 36500;
end;

class function TDeepBaseManagerOperational.TableExists(
  const AStorage: IManagerStorage; AConnectionReady: Boolean;
  const TableName: string): Boolean;
begin
  Result := False;
  if not AConnectionReady or (Trim(TableName) = '') then
    Exit;
  if not Assigned(AStorage) then
    Exit(False);

  Result := AStorage.TableExists(TableName);
end;

class function TDeepBaseManagerOperational.TableHasColumn(
  const AStorage: IManagerStorage; AConnectionReady: Boolean;
  const TableName, ColumnName: string): Boolean;
begin
  Result := False;
  if Trim(ColumnName) = '' then
    Exit;
  if not TableExists(AStorage, AConnectionReady, TableName) or
     not Assigned(AStorage) then
    Exit;

  Result := AStorage.ColumnExists(TableName, ColumnName);
end;

class function TDeepBaseManagerOperational.ResolveTimeColumn(
  const AStorage: IManagerStorage; AConnectionReady: Boolean;
  const TableName, Preferred, Fallback: string): string;
begin
  Result := '';
  if (Preferred <> '') and
     TableHasColumn(AStorage, AConnectionReady, TableName, Preferred) then
    Exit(Preferred);
  if (Fallback <> '') and
     TableHasColumn(AStorage, AConnectionReady, TableName, Fallback) then
    Exit(Fallback);
end;

class procedure TDeepBaseManagerOperational.ArchiveAndTrimTable(
  const AStorage: IManagerStorage; AConnectionReady: Boolean;
  const TableName, TimeColumn: string; DaysToKeep: Integer);
var
  ArchiveTable: string;
  CutoffIso: string;
  CutoffValue: string;
begin
  if (DaysToKeep = 0) or
     not TableExists(AStorage, AConnectionReady, TableName) or
     (TimeColumn = '') then
    Exit;

  ArchiveTable := TableName + '_Archive';
  CutoffIso := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss',
    IncDay(Now, -DaysToKeep));
  CutoffValue := QuotedStr(CutoffIso);

  if Assigned(AStorage) then
  begin
    AStorage.ExecuteStatement(Format(
      'CREATE TABLE IF NOT EXISTS %s AS SELECT * FROM %s WHERE 1 = 0',
      [ArchiveTable, TableName]));
    AStorage.ExecuteStatement(Format(
      'INSERT INTO %s SELECT * FROM %s WHERE %s < %s',
      [ArchiveTable, TableName, TimeColumn, CutoffValue]));
    AStorage.ExecuteStatement(Format(
      'DELETE FROM %s WHERE %s < %s',
      [TableName, TimeColumn, CutoffValue]));
  end;
end;

class procedure TDeepBaseManagerOperational.RunRetention(
  const AStorage: IManagerStorage; AConnectionReady: Boolean;
  const AConfig: TDeepBaseConfig; const ALogger: TDeepBaseLogger);
const
  KEY_LAST_RUN = 'Maintenance.Retention.LastRunDate';
  KEY_LOGS_DAYS = 'Maintenance.Retention.LogsDays';
  KEY_LLMCALLS_DAYS = 'Maintenance.Retention.LLMCallsDays';
  KEY_EXCEPTION_DAYS = 'Maintenance.Retention.ExceptionReportsDays';
  DEFAULT_LOGS_DAYS = 30;
  DEFAULT_LLMCALLS_DAYS = 90;
  DEFAULT_EXCEPTION_DAYS = 180;
var
  TodayTag: string;
begin
  if not AConnectionReady then
    Exit;

  TodayTag := FormatDateTime('yyyy-mm-dd', Date);
  if Assigned(AConfig) and
     SameText(Trim(AConfig.GetConfig(KEY_LAST_RUN, '')), TodayTag) then
    Exit;

  try
    ArchiveAndTrimTable(AStorage, AConnectionReady, 'Logs',
      ResolveTimeColumn(AStorage, AConnectionReady, 'Logs', 'LogTime',
        'CreatedAt'),
      GetRetentionDays(AConfig, KEY_LOGS_DAYS, DEFAULT_LOGS_DAYS));
    ArchiveAndTrimTable(AStorage, AConnectionReady, 'LLMCalls',
      ResolveTimeColumn(AStorage, AConnectionReady, 'LLMCalls', 'CallTime',
        'RequestTime'),
      GetRetentionDays(AConfig, KEY_LLMCALLS_DAYS, DEFAULT_LLMCALLS_DAYS));
    ArchiveAndTrimTable(AStorage, AConnectionReady, 'ExceptionReports',
      ResolveTimeColumn(AStorage, AConnectionReady, 'ExceptionReports',
        'OccurredAt', 'ReportTime'),
      GetRetentionDays(AConfig, KEY_EXCEPTION_DAYS, DEFAULT_EXCEPTION_DAYS));
  except
    on E: Exception do
      if Assigned(ALogger) then
        ALogger.Warn('Operational retention failed: ' + E.Message,
          'DeepBase.Manager');
  end;

  if Assigned(AConfig) then
    AConfig.SetConfig(KEY_LAST_RUN, TodayTag);
end;

class function TDeepBaseManagerOperational.HealthCheck(
  AIsInitialized: Boolean; AConnectionReady: Boolean;
  const ARootPath: string): THealthCheckResult;
begin
  Result.Init;

  if not AIsInitialized then
  begin
    Result.AddMessage('DeepBase not initialized');
    Result.TrimMessages;
    Exit;
  end;

  if AConnectionReady then
  begin
    Result.ConfigDBOk := True;
    Result.AddMessage('ConfigDB: OK');
  end
  else
  begin
    Result.AddMessage('ConfigDB: Not connected');
  end;

  if TDirectory.Exists(TPath.Combine(ARootPath, 'assets')) then
  begin
    Result.AssetsDirOk := True;
    Result.AddMessage('Assets directory: OK');
  end
  else
  begin
    Result.AddMessage('Assets directory: Not found (optional)');
    Result.AssetsDirOk := True;
  end;

  Result.LLMConnectionOk := False;
  Result.AddMessage('LLM: Not configured (Phase 2)');

  Result.IsHealthy := Result.ConfigDBOk;
  Result.TrimMessages;
end;

end.
