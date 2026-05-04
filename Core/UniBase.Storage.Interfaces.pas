{ ============================================================================
  UniBase.Storage.Interfaces - Storage abstraction contracts

  Version: 0.3
  Description: Defines persistence interfaces consumed by Core modules.
               Concrete database implementations should live in Persistence/.
  ============================================================================ }

unit UniBase.Storage.Interfaces;

interface

uses
  System.Generics.Collections,
  UniBase.Types;

type
  /// <summary>
  /// Form state data shared by Core and Persistence.
  /// </summary>
  TFormStateData = record
    Left: Integer;
    Top: Integer;
    Width: Integer;
    Height: Integer;
    WindowState: Integer; // 0=Normal, 1=Minimized, 2=Maximized
    MonitorIndex: Integer;
    Extra: string;
    procedure Init;
    function IsValid: Boolean;
  end;

  /// <summary>
  /// Hotkey storage data shared by Core and Persistence.
  /// Shortcut fields use raw key codes (TShortCut-compatible Word values).
  /// </summary>
  THotkeyStorageData = record
    ActionName: string;
    Shortcut: Word;
    DefaultShortcut: Word;
    Category: string;
    Description: string;
    IsEnabled: Boolean;
    IsCustomized: Boolean;
  end;
  THotkeyStorageDataArray = TArray<THotkeyStorageData>;

  /// <summary>
  /// Exception report data shared by Core and Persistence.
  /// </summary>
  TExceptionReportData = record
    ReportTimeISO: string;
    ExceptionClass: string;
    MessageText: string;
    StackTrace: string;
  end;

  /// <summary>
  /// Log data shared by Core and Persistence.
  /// </summary>
  TLogStorageData = record
    TimestampISO: string;
    LevelText: string;
    Source: string;
    MessageText: string;
    StackTrace: string;
    ThreadId: Integer;
    Extra: string;
  end;

  /// <summary>
  /// Configuration storage contract.
  /// </summary>
  IConfigStorage = interface
    ['{9EFA8C2D-20A7-446E-8F08-684F22227D66}']
    function ReadValue(const Key: string; const Default: string = ''): string;
    procedure WriteValue(const Key, Value, Category, ValueType,
      Description: string);
    procedure LoadAll(AValues: TDictionary<string, string>);
    procedure LoadByCategory(const Category: string;
      AValues: TDictionary<string, string>);
    procedure DeleteValue(const Key: string);
    function ValueExists(const Key: string): Boolean;
  end;

  /// <summary>
  /// Form state storage contract.
  /// </summary>
  IFormStateStorage = interface
    ['{98383B1A-86CB-4783-90F2-6850D520C044}']
    procedure WriteState(const FormName: string; const Data: TFormStateData);
    function ReadState(const FormName: string; out Data: TFormStateData): Boolean;
    procedure DeleteState(const FormName: string);
    function StateExists(const FormName: string): Boolean;
    function ReadFormNames: TArray<string>;
    procedure ClearAll;
  end;

  /// <summary>
  /// MRU storage contract (reserved for ARCH-039 follow-up slices).
  /// </summary>
  IMRUStorage = interface
    ['{41750E83-A0F8-4C66-9000-F58D4A8A643D}']
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

  /// <summary>
  /// Hotkey storage contract.
  /// </summary>
  IHotkeyStorage = interface
    ['{1DB3FB39-C887-4C30-8E42-26453623EDFB}']
    function ReadEnabledHotkeys: THotkeyStorageDataArray;
    procedure RegisterDefaults(const Defaults: THotkeyStorageDataArray);
    procedure UpdateShortcut(const ActionName: string; Shortcut: Word;
      IsCustomized: Boolean);
    procedure ResetShortcut(const ActionName: string);
    procedure ResetAllShortcuts;
    function ReadAllHotkeys: THotkeyStorageDataArray;
    procedure DeleteHotkey(const ActionName: string);
  end;

  /// <summary>
  /// Theme storage contract.
  /// </summary>
  IThemeStorage = interface
    ['{17830484-BFD0-459A-B12F-949BCB18F67D}']
    function ReadEnabledThemes: TThemeInfoArray;
  end;

  /// <summary>
  /// I18n storage contract.
  /// </summary>
  II18nStorage = interface
    ['{74A347A3-6876-4CC0-B865-8AF1A54A4473}']
    function ReadTranslation(const SourceText, LangCode: string): string;
    function ReadTranslations(const LangCode: string): TDictionary<string, string>;
    procedure RecordMissingTranslation(const SourceText, LangCode: string);
    function ReadLanguages(EnabledOnly: Boolean): TLanguageInfoArray;
    function ReadDefaultLanguage(const Fallback: string): string;
    procedure UpsertTranslation(const SourceText, LangCode,
      TranslatedText: string);
  end;

  /// <summary>
  /// Security secret storage contract.
  /// </summary>
  ISecuritySecretStorage = interface
    ['{BB6B7D5A-6E07-4BF7-8F74-8DBD82F9170A}']
    procedure EnsureSecretsTable;
    function TryReadCipherBlob(const AName: string;
      out ACipherBlobBase64: string): Boolean;
    procedure UpsertSecret(const AName, ACipherBlobBase64, ADescription,
      AUpdatedAtIso8601: string);
    procedure DeleteSecret(const AName: string);
    function SecretExists(const AName: string): Boolean;
    function ReadSecretNames: TArray<string>;
  end;

  /// <summary>
  /// License storage contract.
  /// </summary>
  ILicenseStorage = interface
    ['{27CA4EFD-E79D-4F25-9900-4C88F1E1E2AD}']
    function ReadLicenseKey: string;
    procedure WriteLicenseKey(const LicenseKey: string);
    procedure DeleteLicenseKey;
  end;

  /// <summary>
  /// Logging storage contract.
  /// </summary>
  ILogStorage = interface
    ['{65195A45-0F85-4E0E-BE5D-3FAFCD64DF73}']
    procedure WriteLog(const Data: TLogStorageData);
    procedure PurgeOlderThan(const CutoffISO: string);
  end;

  /// <summary>
  /// Optional query contract for log storage.
  /// </summary>
  ILogQueryStorage = interface
    ['{5C9F9A2A-8E7D-47A5-9A80-7E2232E4A139}']
    function CountByLevel(const LevelText: string): Int64;
    function CountAll: Int64;
  end;

  /// <summary>
  /// Exception report storage contract (reserved for ARCH-039 follow-up slices).
  /// </summary>
  IExceptionReportStorage = interface
    ['{3F2BC0C1-6E95-4A95-9EF4-EA6EF5B7EC8A}']
    procedure WriteReport(const Data: TExceptionReportData);
  end;

  /// <summary>
  /// Schema storage contract (reserved for ARCH-039 follow-up slices).
  /// </summary>
  ISchemaStorage = interface
    ['{D8EB5CE5-3A14-4D11-9D3D-780F93C88CCF}']
    function TableExists(const TableName: string): Boolean;
    function ColumnExists(const TableName, ColumnName: string): Boolean;
    procedure ExecuteStatement(const SQL: string);
    function ReadSchemaVersion: string;
    procedure UpdateSchemaVersion(const SchemaVersion, LastUpgradeISO: string);
  end;

  /// <summary>
  /// Manager storage contract for schema/meta operations.
  /// Concrete FireDAC implementation should live in Persistence/.
  /// </summary>
  IManagerStorage = interface
    ['{21B9BAA2-DF0B-4DF1-BDFC-89EA287CD6C7}']
    function CountCoreTables(const TableNames: array of string): Integer;
    function TableExists(const TableName: string): Boolean;
    function ColumnExists(const TableName, ColumnName: string): Boolean;
    procedure ExecuteStatement(const SQL: string);
    procedure AddColumn(const TableName, ColumnName, ColumnDef: string);
    function ReadSchemaVersion: string;
    procedure UpdateSchemaInfo(const SchemaVersion, LastUpgradeIso8601: string);
    function ReadProjectInfo(const Key: string): string;
    procedure UpsertProjectInfo(const Key, Value: string);
  end;

implementation

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

end.
