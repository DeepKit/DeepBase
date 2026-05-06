{ ============================================================================
  UniBase.Persistence.Theme.FireDAC - FireDAC adapter for theme storage
  ============================================================================
  Registers FireDAC implementation for IThemeStorage.
  ============================================================================ }

unit UniBase.Persistence.Theme.FireDAC;

interface

uses
  UniBase.Storage.Interfaces,
  FireDAC.Comp.Client;

function CreateThemeStorage(AConnection: TFDConnection): IThemeStorage;
procedure RegisterThemeFireDACStorageFactory;

implementation

uses
  System.SysUtils,
  System.Generics.Collections,
  Data.DB,
  UniBase.Types,
  UniBase.Theme;

type
  TFireDACThemeStorage = class(TInterfacedObject, IThemeStorage)
  private
    FConnection: TFDConnection;
  public
    constructor Create(AConnection: TFDConnection);
    function ReadEnabledThemes: TThemeInfoArray;
  end;

constructor TFireDACThemeStorage.Create(AConnection: TFDConnection);
begin
  inherited Create;
  FConnection := AConnection;
end;

function TFireDACThemeStorage.ReadEnabledThemes: TThemeInfoArray;
var
  Query: TFDQuery;
  List: TList<TThemeInfo>;
  Info: TThemeInfo;
begin
  List := TList<TThemeInfo>.Create;
  try
    if (FConnection = nil) or (not FConnection.Connected) then
      Exit(List.ToArray);

    Query := TFDQuery.Create(nil);
    try
      Query.Connection := FConnection;
      Query.SQL.Text :=
        'SELECT ThemeName, StyleFile, IsDark, IsBuiltIn ' +
        'FROM Themes WHERE IsEnabled = 1 ORDER BY SortOrder';
      Query.Open;

      while not Query.Eof do
      begin
        Info.Name := Query.FieldByName('ThemeName').AsString;
        if Query.FindField('StyleFile') <> nil then
          Info.StyleFile := Query.FieldByName('StyleFile').AsString
        else
          Info.StyleFile := '';
        Info.IsDark := Query.FieldByName('IsDark').AsInteger <> 0;
        Info.IsBuiltIn := Query.FieldByName('IsBuiltIn').AsInteger <> 0;
        List.Add(Info);
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

function CreateThemeStorage(AConnection: TFDConnection): IThemeStorage;
begin
  Result := TFireDACThemeStorage.Create(AConnection);
end;

procedure RegisterThemeFireDACStorageFactory;
begin
  TUniBaseTheme.SetConnectionStorageFactory(
    function(AConnection: TObject): IThemeStorage
    var
      FDConnection: TFDConnection;
    begin
      if not (AConnection is TFDConnection) then
        raise EInvalidCast.Create(
          'Expected TFDConnection for Theme FireDAC storage.');
      FDConnection := TFDConnection(AConnection);
      Result := CreateThemeStorage(FDConnection);
    end);
end;

initialization
  RegisterThemeFireDACStorageFactory;

end.
