{ ============================================================================
  DeepBase.Persistence.I18n.FireDAC - FireDAC adapter for i18n storage
  ============================================================================
  Registers FireDAC implementation for II18nStorage.
  ============================================================================ }

unit DeepBase.Persistence.I18n.FireDAC;

interface

uses
  DeepBase.Storage.Interfaces,
  FireDAC.Comp.Client;

function CreateI18nStorage(AConnection: TFDConnection): II18nStorage;
procedure RegisterI18nFireDACStorageFactory;

implementation

uses
  System.SysUtils,
  System.Generics.Collections,
  FireDAC.Stan.Param,
  DeepBase.i18n,
  DeepBase.Types;

type
  TFireDACI18nStorage = class(TInterfacedObject, II18nStorage)
  private
    FConnection: TFDConnection;
  public
    constructor Create(AConnection: TFDConnection);
    function ReadTranslation(const SourceText, LangCode: string): string;
    function ReadTranslations(const LangCode: string): TDictionary<string, string>;
    procedure RecordMissingTranslation(const SourceText, LangCode: string);
    function ReadLanguages(EnabledOnly: Boolean): TLanguageInfoArray;
    function ReadDefaultLanguage(const Fallback: string): string;
    procedure UpsertTranslation(const SourceText, LangCode,
      TranslatedText: string);
  end;

constructor TFireDACI18nStorage.Create(AConnection: TFDConnection);
begin
  inherited Create;
  FConnection := AConnection;
end;

function TFireDACI18nStorage.ReadTranslation(const SourceText,
  LangCode: string): string;
var
  Query: TFDQuery;
begin
  Result := '';
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;

  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text :=
      'SELECT TranslatedText FROM I18nTexts ' +
      'WHERE SourceText = :SourceText AND LangCode = :LangCode';
    Query.ParamByName('SourceText').AsString := SourceText;
    Query.ParamByName('LangCode').AsString := LangCode;
    Query.Open;

    if not Query.Eof then
      Result := Query.FieldByName('TranslatedText').AsString;
  finally
    Query.Free;
  end;
end;

function TFireDACI18nStorage.ReadTranslations(
  const LangCode: string): TDictionary<string, string>;
var
  Query: TFDQuery;
begin
  Result := TDictionary<string, string>.Create;
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;

  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text :=
      'SELECT SourceText, TranslatedText FROM I18nTexts WHERE LangCode = :LangCode';
    Query.ParamByName('LangCode').AsString := LangCode;
    Query.Open;

    while not Query.Eof do
    begin
      Result.AddOrSetValue(
        Query.FieldByName('SourceText').AsString,
        Query.FieldByName('TranslatedText').AsString);
      Query.Next;
    end;
  finally
    Query.Free;
  end;
end;

procedure TFireDACI18nStorage.RecordMissingTranslation(const SourceText,
  LangCode: string);
var
  Query: TFDQuery;
  NowStr: string;
begin
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;

  NowStr := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', Now);
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text :=
      'INSERT OR IGNORE INTO I18nTexts (SourceText, LangCode, LastUsedAt) ' +
      'VALUES (:SourceText, :LangCode, :LastUsedAt)';
    Query.ParamByName('SourceText').AsString := SourceText;
    Query.ParamByName('LangCode').AsString := LangCode;
    Query.ParamByName('LastUsedAt').AsString := NowStr;
    Query.ExecSQL;

    Query.SQL.Text :=
      'UPDATE I18nTexts SET LastUsedAt = :LastUsedAt ' +
      'WHERE SourceText = :SourceText AND LangCode = :LangCode';
    Query.ParamByName('SourceText').AsString := SourceText;
    Query.ParamByName('LangCode').AsString := LangCode;
    Query.ParamByName('LastUsedAt').AsString := NowStr;
    Query.ExecSQL;
  finally
    Query.Free;
  end;
end;

function TFireDACI18nStorage.ReadLanguages(
  EnabledOnly: Boolean): TLanguageInfoArray;
var
  Query: TFDQuery;
  List: TList<TLanguageInfo>;
  Info: TLanguageInfo;
begin
  SetLength(Result, 0);
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;

  List := TList<TLanguageInfo>.Create;
  try
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := FConnection;
      if EnabledOnly then
        Query.SQL.Text := 'SELECT * FROM Languages WHERE IsEnabled = 1 ORDER BY SortOrder'
      else
        Query.SQL.Text := 'SELECT * FROM Languages ORDER BY SortOrder';
      Query.Open;

      while not Query.Eof do
      begin
        Info.LangCode := Query.FieldByName('LangCode').AsString;
        Info.LangName := Query.FieldByName('LangName').AsString;
        Info.NativeName := Query.FieldByName('NativeName').AsString;
        Info.FlagIcon := Query.FieldByName('FlagIcon').AsString;
        if EnabledOnly then
          Info.IsEnabled := True
        else
          Info.IsEnabled := Query.FieldByName('IsEnabled').AsInteger = 1;
        Info.IsDefault := Query.FieldByName('IsDefault').AsInteger = 1;
        List.Add(Info);
        Query.Next;
      end;

      Result := List.ToArray;
    finally
      Query.Free;
    end;
  finally
    List.Free;
  end;
end;

function TFireDACI18nStorage.ReadDefaultLanguage(
  const Fallback: string): string;
var
  Query: TFDQuery;
begin
  Result := Fallback;
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;

  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'SELECT LangCode FROM Languages WHERE IsDefault = 1 LIMIT 1';
    Query.Open;

    if not Query.Eof then
      Result := Query.FieldByName('LangCode').AsString;
  finally
    Query.Free;
  end;
end;

procedure TFireDACI18nStorage.UpsertTranslation(const SourceText,
  LangCode, TranslatedText: string);
var
  Query: TFDQuery;
  NowStr: string;
begin
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;

  NowStr := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', Now);
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text :=
      'INSERT OR REPLACE INTO I18nTexts (SourceText, LangCode, TranslatedText, LastUsedAt) ' +
      'VALUES (:SourceText, :LangCode, :TranslatedText, :LastUsedAt)';
    Query.ParamByName('SourceText').AsString := SourceText;
    Query.ParamByName('LangCode').AsString := LangCode;
    Query.ParamByName('TranslatedText').AsString := TranslatedText;
    Query.ParamByName('LastUsedAt').AsString := NowStr;
    Query.ExecSQL;
  finally
    Query.Free;
  end;
end;

function CreateI18nStorage(AConnection: TFDConnection): II18nStorage;
begin
  Result := TFireDACI18nStorage.Create(AConnection);
end;

procedure RegisterI18nFireDACStorageFactory;
begin
  TDeepBaseI18n.SetConnectionStorageFactory(
    function(AConnection: TObject): II18nStorage
    var
      FDConnection: TFDConnection;
    begin
      if not (AConnection is TFDConnection) then
        raise EInvalidCast.Create(
          'Expected TFDConnection for i18n FireDAC storage.');
      FDConnection := TFDConnection(AConnection);
      Result := CreateI18nStorage(FDConnection);
    end);
end;

initialization
  RegisterI18nFireDACStorageFactory;

end.
