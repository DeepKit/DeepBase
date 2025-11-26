{ ============================================================================
  UniBase.FormState - 窗体状态管理模块
  
  版本: 0.3
  说明: 提供窗体位置、尺寸和状态的持久化存储
  注意: 本模块为 Core 层，不依赖 VCL/FMX，具体 UI 绑定由上层组件实现
  ============================================================================ }

unit UniBase.FormState;

interface

uses
  System.SysUtils,
  System.Classes,
  FireDAC.Comp.Client,
  UniBase.Types;

type
  /// <summary>
  /// 窗体状态数据
  /// </summary>
  TFormStateData = record
    Left: Integer;
    Top: Integer;
    Width: Integer;
    Height: Integer;
    WindowState: Integer; // 0=Normal, 1=Minimized, 2=Maximized
    MonitorIndex: Integer;
    Extra: string;
  end;

  /// <summary>
  /// 窗体状态管理器
  /// </summary>
  TUniBaseFormState = class
  private
    FConnection: TFDConnection;
    FLock: TObject;
    
    procedure WriteToDB(const FormName: string; const Data: TFormStateData);
    function ReadFromDB(const FormName: string; out Data: TFormStateData): Boolean;
    
  public
    constructor Create(AConnection: TFDConnection; ALock: TObject);
    destructor Destroy; override;
    
    /// <summary>
    /// 保存窗体状态
    /// </summary>
    procedure SaveState(const FormName: string; const Data: TFormStateData);
    
    /// <summary>
    /// 恢复窗体状态
    /// </summary>
    function RestoreState(const FormName: string; out Data: TFormStateData): Boolean;
    
    /// <summary>
    /// 删除窗体状态
    /// </summary>
    procedure DeleteState(const FormName: string);
  end;

implementation

uses
  FireDAC.Stan.Param;

{ TUniBaseFormState }

constructor TUniBaseFormState.Create(AConnection: TFDConnection; ALock: TObject);
begin
  inherited Create;
  FConnection := AConnection;
  FLock := ALock;
end;

destructor TUniBaseFormState.Destroy;
begin
  inherited;
end;

procedure TUniBaseFormState.SaveState(const FormName: string; const Data: TFormStateData);
begin
  TMonitor.Enter(FLock);
  try
    WriteToDB(FormName, Data);
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TUniBaseFormState.RestoreState(const FormName: string; out Data: TFormStateData): Boolean;
begin
  TMonitor.Enter(FLock);
  try
    Result := ReadFromDB(FormName, Data);
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TUniBaseFormState.DeleteState(const FormName: string);
var
  Query: TFDQuery;
begin
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
    
  TMonitor.Enter(FLock);
  try
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := FConnection;
      Query.SQL.Text := 'DELETE FROM FormStates WHERE FormName = :FormName';
      Query.ParamByName('FormName').AsString := FormName;
      Query.ExecSQL;
    finally
      Query.Free;
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TUniBaseFormState.WriteToDB(const FormName: string; const Data: TFormStateData);
var
  Query: TFDQuery;
begin
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
    
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 
      'INSERT OR REPLACE INTO FormStates ' +
      '(FormName, Left, Top, Width, Height, WindowState, MonitorIndex, Extra) ' +
      'VALUES (:FormName, :Left, :Top, :Width, :Height, :WindowState, :MonitorIndex, :Extra)';
      
    Query.ParamByName('FormName').AsString := FormName;
    Query.ParamByName('Left').AsInteger := Data.Left;
    Query.ParamByName('Top').AsInteger := Data.Top;
    Query.ParamByName('Width').AsInteger := Data.Width;
    Query.ParamByName('Height').AsInteger := Data.Height;
    Query.ParamByName('WindowState').AsInteger := Data.WindowState;
    Query.ParamByName('MonitorIndex').AsInteger := Data.MonitorIndex;
    Query.ParamByName('Extra').AsString := Data.Extra;
    
    Query.ExecSQL;
  finally
    Query.Free;
  end;
end;

function TUniBaseFormState.ReadFromDB(const FormName: string; out Data: TFormStateData): Boolean;
var
  Query: TFDQuery;
begin
  Result := False;
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
    
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'SELECT * FROM FormStates WHERE FormName = :FormName';
    Query.ParamByName('FormName').AsString := FormName;
    Query.Open;
    
    if not Query.Eof then
    begin
      Data.Left := Query.FieldByName('Left').AsInteger;
      Data.Top := Query.FieldByName('Top').AsInteger;
      Data.Width := Query.FieldByName('Width').AsInteger;
      Data.Height := Query.FieldByName('Height').AsInteger;
      Data.WindowState := Query.FieldByName('WindowState').AsInteger;
      Data.MonitorIndex := Query.FieldByName('MonitorIndex').AsInteger;
      Data.Extra := Query.FieldByName('Extra').AsString;
      Result := True;
    end;
  finally
    Query.Free;
  end;
end;

end.
