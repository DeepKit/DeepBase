{ ============================================================================
  UniBase.FormState - Form State Management Module
  
  Version: 1.0
  Description: Provides persistent storage for form position, size and state.
  Note: This is a Core layer module, does not depend on VCL/FMX. Actual UI
        binding is implemented by upper layer components.
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
  /// Form state data
  /// </summary>
  TFormStateData = record
    Left: Integer;
    Top: Integer;
    Width: Integer;
    Height: Integer;
    WindowState: Integer; // 0=Normal, 1=Minimized, 2=Maximized
    MonitorIndex: Integer;
    Extra: string;
    
    /// <summary>
    /// Initialize to default values
    /// </summary>
    procedure Init;
    
    /// <summary>
    /// Check if data is valid
    /// </summary>
    function IsValid: Boolean;
  end;

  /// <summary>
  /// Form state manager
  /// </summary>
  TUniBaseFormState = class
  private
    FConnection: TFDConnection;
    FLock: TObject;
    FOwnsLock: Boolean;
    
    procedure WriteToDB(const FormName: string; const Data: TFormStateData);
    function ReadFromDB(const FormName: string; out Data: TFormStateData): Boolean;
    
  public
    constructor Create(AConnection: TFDConnection; ALock: TObject = nil);
    destructor Destroy; override;
    
    /// <summary>
    /// Save form state
    /// </summary>
    procedure SaveState(const FormName: string; const Data: TFormStateData);
    
    /// <summary>
    /// Restore form state
    /// </summary>
    function RestoreState(const FormName: string; out Data: TFormStateData): Boolean;
    
    /// <summary>
    /// Delete form state
    /// </summary>
    procedure DeleteState(const FormName: string);
    
    /// <summary>
    /// Check if state exists
    /// </summary>
    function HasState(const FormName: string): Boolean;
    
    /// <summary>
    /// Get all saved form names
    /// </summary>
    function GetAllFormNames: TArray<string>;
    
    /// <summary>
    /// Clear all states
    /// </summary>
    procedure ClearAll;
  end;

implementation

uses
  FireDAC.Stan.Param;

{ TFormStateData }

procedure TFormStateData.Init;
begin
  Left := 100;
  Top := 100;
  Width := 800;
  Height := 600;
  WindowState := 0;
  MonitorIndex := 0;
  Extra := '';
end;

function TFormStateData.IsValid: Boolean;
begin
  Result := (Width > 0) and (Height > 0);
end;

{ TUniBaseFormState }

constructor TUniBaseFormState.Create(AConnection: TFDConnection; ALock: TObject);
begin
  inherited Create;
  FConnection := AConnection;
  if ALock <> nil then
  begin
    FLock := ALock;
    FOwnsLock := False;
  end
  else
  begin
    FLock := TObject.Create;
    FOwnsLock := True;
  end;
end;

destructor TUniBaseFormState.Destroy;
begin
  if FOwnsLock then
    FLock.Free;
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
  Data.Init;
  
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
      Result := Data.IsValid;
    end;
  finally
    Query.Free;
  end;
end;

function TUniBaseFormState.HasState(const FormName: string): Boolean;
var
  Query: TFDQuery;
begin
  Result := False;
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
    
  TMonitor.Enter(FLock);
  try
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := FConnection;
      Query.SQL.Text := 'SELECT 1 FROM FormStates WHERE FormName = :FormName';
      Query.ParamByName('FormName').AsString := FormName;
      Query.Open;
      Result := not Query.Eof;
    finally
      Query.Free;
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TUniBaseFormState.GetAllFormNames: TArray<string>;
var
  Query: TFDQuery;
  List: TArray<string>;
begin
  Result := nil;
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
    
  TMonitor.Enter(FLock);
  try
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := FConnection;
      Query.SQL.Text := 'SELECT FormName FROM FormStates ORDER BY FormName';
      Query.Open;
      
      SetLength(List, 0);
      while not Query.Eof do
      begin
        SetLength(List, Length(List) + 1);
        List[High(List)] := Query.FieldByName('FormName').AsString;
        Query.Next;
      end;
      Result := List;
    finally
      Query.Free;
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TUniBaseFormState.ClearAll;
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
      Query.SQL.Text := 'DELETE FROM FormStates';
      Query.ExecSQL;
    finally
      Query.Free;
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

end.
