{ ============================================================================
  UniBase.Persistence.MRU.FireDAC - FireDAC adapter for MRU storage
  ============================================================================
  Registers FireDAC implementation for IMRUStorage.
  ============================================================================ }

unit UniBase.Persistence.MRU.FireDAC;

interface

uses
  UniBase.Storage.Interfaces,
  FireDAC.Comp.Client;

function CreateMRUStorage(AConnection: TFDConnection): IMRUStorage;
procedure RegisterMRUStorageFactory;

implementation

uses
  System.SysUtils,
  System.DateUtils,
  System.Generics.Collections,
  FireDAC.Stan.Param,
  UniBase.MRU,
  UniBase.Types;

type
  TFireDACMRUStorage = class(TInterfacedObject, IMRUStorage)
  private
    FConnection: TFDConnection;
  public
    constructor Create(AConnection: TFDConnection);
    procedure Upsert(const Category, ItemKey, DisplayName: string;
      IconIndex: Integer);
    procedure Delete(const Category, ItemKey: string);
    procedure Clear(const Category: string);
    function ReadItems(const Category: string; MaxItems: Integer): TMRUItemArray;
    procedure SetPinned(const Category, ItemKey: string; IsPinned: Boolean);
    function IsPinned(const Category, ItemKey: string): Boolean;
    function Count(const Category: string): Integer;
    function AccessCount(const Category, ItemKey: string): Integer;
  end;

constructor TFireDACMRUStorage.Create(AConnection: TFDConnection);
begin
  inherited Create;
  FConnection := AConnection;
end;

procedure TFireDACMRUStorage.Upsert(const Category, ItemKey,
  DisplayName: string; IconIndex: Integer);
var
  Query: TFDQuery;
  ActualDisplayName: string;
  NowStr: string;
  ExistingCount: Integer;
begin
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
  if (Category = '') or (ItemKey = '') then
    Exit;

  ActualDisplayName := DisplayName;
  if ActualDisplayName = '' then
    ActualDisplayName := ItemKey;

  NowStr := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss.zzz', Now);

  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'SELECT AccessCount FROM MRU WHERE Category = :Cat AND ItemKey = :Key';
    Query.ParamByName('Cat').AsString := Category;
    Query.ParamByName('Key').AsString := ItemKey;
    Query.Open;

    if Query.Eof then
    begin
      Query.Close;
      Query.SQL.Text :=
        'INSERT INTO MRU (Category, ItemKey, DisplayName, IconIndex, LastAccess, AccessCount, IsPinned) ' +
        'VALUES (:Cat, :Key, :Display, :Icon, :NowTime, 1, 0)';
      Query.ParamByName('Cat').AsString := Category;
      Query.ParamByName('Key').AsString := ItemKey;
      Query.ParamByName('Display').AsString := ActualDisplayName;
      Query.ParamByName('Icon').AsInteger := IconIndex;
      Query.ParamByName('NowTime').AsString := NowStr;
      Query.ExecSQL;
    end
    else
    begin
      ExistingCount := Query.FieldByName('AccessCount').AsInteger;
      Query.Close;
      Query.SQL.Text :=
        'UPDATE MRU SET DisplayName = :Display, IconIndex = :Icon, ' +
        'LastAccess = :NowTime, AccessCount = :Count WHERE Category = :Cat AND ItemKey = :Key';
      Query.ParamByName('Cat').AsString := Category;
      Query.ParamByName('Key').AsString := ItemKey;
      Query.ParamByName('Display').AsString := ActualDisplayName;
      Query.ParamByName('Icon').AsInteger := IconIndex;
      Query.ParamByName('NowTime').AsString := NowStr;
      Query.ParamByName('Count').AsInteger := ExistingCount + 1;
      Query.ExecSQL;
    end;
  finally
    Query.Free;
  end;
end;

procedure TFireDACMRUStorage.Delete(const Category, ItemKey: string);
var
  Query: TFDQuery;
begin
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;

  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'DELETE FROM MRU WHERE Category = :Cat AND ItemKey = :Key';
    Query.ParamByName('Cat').AsString := Category;
    Query.ParamByName('Key').AsString := ItemKey;
    Query.ExecSQL;
  finally
    Query.Free;
  end;
end;

procedure TFireDACMRUStorage.Clear(const Category: string);
var
  Query: TFDQuery;
begin
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;

  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'DELETE FROM MRU WHERE Category = :Category';
    Query.ParamByName('Category').AsString := Category;
    Query.ExecSQL;
  finally
    Query.Free;
  end;
end;

function TFireDACMRUStorage.ReadItems(const Category: string;
  MaxItems: Integer): TMRUItemArray;
var
  Query: TFDQuery;
  List: TList<TMRUItem>;
  Item: TMRUItem;
begin
  SetLength(Result, 0);
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;

  List := TList<TMRUItem>.Create;
  try
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := FConnection;
      Query.SQL.Text :=
        'SELECT ItemKey, DisplayName, LastAccess, AccessCount, IconIndex, IsPinned ' +
        'FROM MRU WHERE Category = :Cat ' +
        'ORDER BY IsPinned DESC, LastAccess DESC ' +
        'LIMIT :Max';
      Query.ParamByName('Cat').AsString := Category;
      Query.ParamByName('Max').AsInteger := MaxItems;
      Query.Open;

      while not Query.Eof do
      begin
        Item.ItemKey := Query.FieldByName('ItemKey').AsString;
        Item.DisplayName := Query.FieldByName('DisplayName').AsString;
        if Item.DisplayName = '' then
          Item.DisplayName := Item.ItemKey;
        try
          Item.LastAccess := ISO8601ToDate(
            Query.FieldByName('LastAccess').AsString, False);
        except
          Item.LastAccess := Now;
        end;
        Item.AccessCount := Query.FieldByName('AccessCount').AsInteger;
        Item.IconIndex := Query.FieldByName('IconIndex').AsInteger;
        List.Add(Item);
        Query.Next;
      end;
    finally
      Query.Free;
    end;
    Result := List.ToArray;
  finally
    List.Free;
  end;
end;

procedure TFireDACMRUStorage.SetPinned(const Category, ItemKey: string;
  IsPinned: Boolean);
var
  Query: TFDQuery;
begin
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;

  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text :=
      'UPDATE MRU SET IsPinned = :Pinned WHERE Category = :Cat AND ItemKey = :Key';
    Query.ParamByName('Pinned').AsInteger := Ord(IsPinned);
    Query.ParamByName('Cat').AsString := Category;
    Query.ParamByName('Key').AsString := ItemKey;
    Query.ExecSQL;
  finally
    Query.Free;
  end;
end;

function TFireDACMRUStorage.IsPinned(const Category, ItemKey: string): Boolean;
var
  Query: TFDQuery;
begin
  Result := False;
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;

  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text :=
      'SELECT IsPinned FROM MRU WHERE Category = :Cat AND ItemKey = :Key';
    Query.ParamByName('Cat').AsString := Category;
    Query.ParamByName('Key').AsString := ItemKey;
    Query.Open;
    if not Query.Eof then
      Result := Query.FieldByName('IsPinned').AsInteger <> 0;
  finally
    Query.Free;
  end;
end;

function TFireDACMRUStorage.Count(const Category: string): Integer;
var
  Query: TFDQuery;
begin
  Result := 0;
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;

  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'SELECT COUNT(*) FROM MRU WHERE Category = :Cat';
    Query.ParamByName('Cat').AsString := Category;
    Query.Open;
    Result := Query.Fields[0].AsInteger;
  finally
    Query.Free;
  end;
end;

function TFireDACMRUStorage.AccessCount(const Category,
  ItemKey: string): Integer;
var
  Query: TFDQuery;
begin
  Result := 0;
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;

  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text :=
      'SELECT AccessCount FROM MRU WHERE Category = :Cat AND ItemKey = :Key';
    Query.ParamByName('Cat').AsString := Category;
    Query.ParamByName('Key').AsString := ItemKey;
    Query.Open;
    if not Query.Eof then
      Result := Query.FieldByName('AccessCount').AsInteger;
  finally
    Query.Free;
  end;
end;

function CreateMRUStorage(AConnection: TFDConnection): IMRUStorage;
begin
  Result := TFireDACMRUStorage.Create(AConnection);
end;

procedure RegisterMRUStorageFactory;
begin
  TUniBaseMRU.SetConnectionStorageFactory(
    function(AConnection: TObject): IMRUStorage
    var
      FDConnection: TFDConnection;
    begin
      if not (AConnection is TFDConnection) then
        raise EInvalidCast.Create(
          'Expected TFDConnection for MRU FireDAC storage.');
      FDConnection := TFDConnection(AConnection);
      Result := CreateMRUStorage(FDConnection);
    end);
end;

initialization
  RegisterMRUStorageFactory;

end.
