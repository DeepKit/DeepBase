{ ============================================================================
  DeepBase.Persistence.FormState.FireDAC - FireDAC adapter for form state
  ============================================================================
  Moves SQL/FireDAC details out of Core. Core keeps only repository contracts.
  ============================================================================ }

unit DeepBase.Persistence.FormState.FireDAC;

interface

uses
  DeepBase.Storage.Interfaces,
  FireDAC.Comp.Client;

function CreateFormStateStorage(AConnection: TFDConnection): IFormStateStorage;
procedure RegisterFormStateStorageFactory;

implementation

uses
  System.SysUtils,
  FireDAC.Stan.Param,
  DeepBase.FormState,
  DeepBase.Types;

type
  TFireDACFormStateStorage = class(TInterfacedObject, IFormStateStorage)
  private
    FConnection: TFDConnection;
  public
    constructor Create(AConnection: TFDConnection);
    procedure WriteState(const FormName: string; const Data: TFormStateData);
    function ReadState(const FormName: string; out Data: TFormStateData): Boolean;
    procedure DeleteState(const FormName: string);
    function StateExists(const FormName: string): Boolean;
    function ReadFormNames: TArray<string>;
    procedure ClearAll;
  end;

constructor TFireDACFormStateStorage.Create(AConnection: TFDConnection);
begin
  inherited Create;
  FConnection := AConnection;
end;

procedure TFireDACFormStateStorage.WriteState(const FormName: string;
  const Data: TFormStateData);
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

function TFireDACFormStateStorage.ReadState(const FormName: string;
  out Data: TFormStateData): Boolean;
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

procedure TFireDACFormStateStorage.DeleteState(const FormName: string);
var
  Query: TFDQuery;
begin
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;

  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'DELETE FROM FormStates WHERE FormName = :FormName';
    Query.ParamByName('FormName').AsString := FormName;
    Query.ExecSQL;
  finally
    Query.Free;
  end;
end;

function TFireDACFormStateStorage.StateExists(const FormName: string): Boolean;
var
  Query: TFDQuery;
begin
  Result := False;
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;

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
end;

function TFireDACFormStateStorage.ReadFormNames: TArray<string>;
var
  Query: TFDQuery;
begin
  SetLength(Result, 0);
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;

  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'SELECT FormName FROM FormStates ORDER BY FormName';
    Query.Open;

    while not Query.Eof do
    begin
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := Query.FieldByName('FormName').AsString;
      Query.Next;
    end;
  finally
    Query.Free;
  end;
end;

procedure TFireDACFormStateStorage.ClearAll;
var
  Query: TFDQuery;
begin
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;

  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'DELETE FROM FormStates';
    Query.ExecSQL;
  finally
    Query.Free;
  end;
end;

function CreateFormStateStorage(AConnection: TFDConnection): IFormStateStorage;
begin
  Result := TFireDACFormStateStorage.Create(AConnection);
end;

procedure RegisterFormStateStorageFactory;
begin
  TDeepBaseFormState.SetConnectionStorageFactory(
    function(AConnection: TObject): IFormStateStorage
    var
      FDConnection: TFDConnection;
    begin
      if not (AConnection is TFDConnection) then
        raise EInvalidCast.Create(
          'Expected TFDConnection for FormState FireDAC storage.');
      FDConnection := TFDConnection(AConnection);
      Result := CreateFormStateStorage(FDConnection);
    end);
end;

initialization
  RegisterFormStateStorageFactory;

end.
