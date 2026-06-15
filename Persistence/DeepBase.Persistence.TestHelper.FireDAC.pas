{ ============================================================================
  DeepBase.Persistence.TestHelper.FireDAC
  ============================================================================
  FireDAC snapshot storage adapter for DeepBase.TestHelper.
  ============================================================================ }

unit DeepBase.Persistence.TestHelper.FireDAC;

interface

uses
  DeepBase.TestHelper,
  FireDAC.Comp.Client;

function CreateTestSnapshotFireDACStorage(
  AConnection: TFDConnection): ITestSnapshotStorage;
procedure RegisterTestSnapshotStorageFactory;

implementation

uses
  System.SysUtils;

type
  TFireDACTestSnapshotStorage = class(TInterfacedObject, ITestSnapshotStorage)
  private
    FConnection: TFDConnection;
  public
    constructor Create(AConnection: TFDConnection);
    procedure WriteSnapshot(const TestName, FormClass, StateJSON,
      ScreenshotPath: string);
    function TryReadSnapshot(const TestName: string; out StateJSON: string): Boolean;
    procedure DeleteSnapshot(const TestName: string);
    function ReadSnapshotNames: TArray<string>;
  end;

constructor TFireDACTestSnapshotStorage.Create(AConnection: TFDConnection);
begin
  inherited Create;
  FConnection := AConnection;
end;

procedure TFireDACTestSnapshotStorage.WriteSnapshot(const TestName, FormClass,
  StateJSON, ScreenshotPath: string);
var
  Query: TFDQuery;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text :=
      'INSERT OR REPLACE INTO TestSnapshots (TestName, FormClass, StateJSON, ScreenshotPath, CreatedAt) ' +
      'VALUES (:Name, :FormClass, :State, :Screenshot, CURRENT_TIMESTAMP)';
    Query.ParamByName('Name').AsString := TestName;
    Query.ParamByName('FormClass').AsString := FormClass;
    Query.ParamByName('State').AsString := StateJSON;
    Query.ParamByName('Screenshot').AsString := ScreenshotPath;
    Query.ExecSQL;
  finally
    Query.Free;
  end;
end;

function TFireDACTestSnapshotStorage.TryReadSnapshot(const TestName: string;
  out StateJSON: string): Boolean;
var
  Query: TFDQuery;
begin
  Result := False;
  StateJSON := '';

  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'SELECT StateJSON FROM TestSnapshots WHERE TestName = :Name';
    Query.ParamByName('Name').AsString := TestName;
    Query.Open;
    if not Query.IsEmpty then
    begin
      StateJSON := Query.FieldByName('StateJSON').AsString;
      Result := True;
    end;
  finally
    Query.Free;
  end;
end;

procedure TFireDACTestSnapshotStorage.DeleteSnapshot(const TestName: string);
var
  Query: TFDQuery;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'DELETE FROM TestSnapshots WHERE TestName = :Name';
    Query.ParamByName('Name').AsString := TestName;
    Query.ExecSQL;
  finally
    Query.Free;
  end;
end;

function TFireDACTestSnapshotStorage.ReadSnapshotNames: TArray<string>;
var
  Query: TFDQuery;
  L: TArray<string>;
  Count: Integer;
begin
  SetLength(L, 0);
  Count := 0;

  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'SELECT DISTINCT TestName FROM TestSnapshots ORDER BY TestName';
    Query.Open;
    while not Query.Eof do
    begin
      SetLength(L, Count + 1);
      L[Count] := Query.FieldByName('TestName').AsString;
      Inc(Count);
      Query.Next;
    end;
  finally
    Query.Free;
  end;

  Result := L;
end;

function CreateTestSnapshotFireDACStorage(
  AConnection: TFDConnection): ITestSnapshotStorage;
begin
  Result := TFireDACTestSnapshotStorage.Create(AConnection);
end;

procedure RegisterTestSnapshotStorageFactory;
begin
  TDeepBaseTestHelper.SetSnapshotStorageFactory(
    function(AConnection: TObject): ITestSnapshotStorage
    begin
      if not (AConnection is TFDConnection) then
        raise EInvalidCast.Create(
          'Expected TFDConnection for TestHelper FireDAC snapshot storage.');
      Result := CreateTestSnapshotFireDACStorage(TFDConnection(AConnection));
    end);
end;

initialization
  RegisterTestSnapshotStorageFactory;

end.
