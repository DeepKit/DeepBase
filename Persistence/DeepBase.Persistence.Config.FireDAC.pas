{ ============================================================================
  DeepBase.Persistence.Config.FireDAC - FireDAC adapter for config storage
  ============================================================================
  Registers FireDAC implementation for IConfigStorage.
  ============================================================================ }

unit DeepBase.Persistence.Config.FireDAC;

interface

uses
  DeepBase.Storage.Interfaces,
  FireDAC.Comp.Client;

function CreateConfigStorage(AConnection: TFDConnection): IConfigStorage;
procedure RegisterConfigStorageFactory;

implementation

uses
  System.SysUtils,
  System.Generics.Collections,
  DeepBase.Config;

type
  TFireDACConfigStorage = class(TInterfacedObject, IConfigStorage)
  private
    FConnection: TFDConnection;
  public
    constructor Create(AConnection: TFDConnection);
    function ReadValue(const Key: string; const Default: string = ''): string;
    procedure WriteValue(const Key, Value, Category, ValueType,
      Description: string);
    procedure LoadAll(AValues: TDictionary<string, string>);
    procedure LoadByCategory(const Category: string;
      AValues: TDictionary<string, string>);
    procedure DeleteValue(const Key: string);
    function ValueExists(const Key: string): Boolean;
  end;

constructor TFireDACConfigStorage.Create(AConnection: TFDConnection);
begin
  inherited Create;
  FConnection := AConnection;
end;

function TFireDACConfigStorage.ReadValue(const Key: string;
  const Default: string): string;
var
  Query: TFDQuery;
begin
  Result := Default;
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;

  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'SELECT Value FROM Settings WHERE Key = :Key';
    Query.ParamByName('Key').AsString := Key;
    Query.Open;
    if not Query.Eof then
      Result := Query.FieldByName('Value').AsString;
  finally
    Query.Free;
  end;
end;

procedure TFireDACConfigStorage.WriteValue(const Key, Value, Category,
  ValueType, Description: string);
var
  Query: TFDQuery;
begin
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;

  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text :=
      'INSERT OR REPLACE INTO Settings (Key, Value, Category, ValueType, Description) ' +
      'VALUES (:Key, :Value, :Category, :ValueType, :Description)';
    Query.ParamByName('Key').AsString := Key;
    Query.ParamByName('Value').AsString := Value;
    Query.ParamByName('Category').AsString := Category;
    Query.ParamByName('ValueType').AsString := ValueType;
    Query.ParamByName('Description').AsString := Description;
    Query.ExecSQL;
  finally
    Query.Free;
  end;
end;

procedure TFireDACConfigStorage.LoadAll(AValues: TDictionary<string, string>);
var
  Query: TFDQuery;
begin
  if not Assigned(AValues) then
    Exit;
  AValues.Clear;
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;

  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'SELECT Key, Value FROM Settings';
    Query.Open;

    while not Query.Eof do
    begin
      AValues.AddOrSetValue(
        Query.FieldByName('Key').AsString,
        Query.FieldByName('Value').AsString
      );
      Query.Next;
    end;
  finally
    Query.Free;
  end;
end;

procedure TFireDACConfigStorage.LoadByCategory(const Category: string;
  AValues: TDictionary<string, string>);
var
  Query: TFDQuery;
begin
  if not Assigned(AValues) then
    Exit;
  AValues.Clear;
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;

  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'SELECT Key, Value FROM Settings WHERE Category = :Category';
    Query.ParamByName('Category').AsString := Category;
    Query.Open;

    while not Query.Eof do
    begin
      AValues.Add(
        Query.FieldByName('Key').AsString,
        Query.FieldByName('Value').AsString
      );
      Query.Next;
    end;
  finally
    Query.Free;
  end;
end;

procedure TFireDACConfigStorage.DeleteValue(const Key: string);
var
  Query: TFDQuery;
begin
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;

  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'DELETE FROM Settings WHERE Key = :Key';
    Query.ParamByName('Key').AsString := Key;
    Query.ExecSQL;
  finally
    Query.Free;
  end;
end;

function TFireDACConfigStorage.ValueExists(const Key: string): Boolean;
var
  Query: TFDQuery;
begin
  Result := False;
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;

  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'SELECT 1 FROM Settings WHERE Key = :Key';
    Query.ParamByName('Key').AsString := Key;
    Query.Open;
    Result := not Query.Eof;
  finally
    Query.Free;
  end;
end;

function CreateConfigStorage(AConnection: TFDConnection): IConfigStorage;
begin
  Result := TFireDACConfigStorage.Create(AConnection);
end;

procedure RegisterConfigStorageFactory;
begin
  TDeepBaseConfig.SetConnectionStorageFactory(
    function(AConnection: TObject): IConfigStorage
    var
      FDConnection: TFDConnection;
    begin
      if not (AConnection is TFDConnection) then
        raise EInvalidCast.Create(
          'Expected TFDConnection for Config FireDAC storage.');
      FDConnection := TFDConnection(AConnection);
      Result := CreateConfigStorage(FDConnection);
    end);
end;

initialization
  RegisterConfigStorageFactory;

end.
