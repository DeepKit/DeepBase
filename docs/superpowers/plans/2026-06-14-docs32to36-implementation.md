# Docs 32-36 数据平台实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现 docs/32-36 (v0.7) 中定义的 5 个模块：外部数据库读取、SchemaAdapter、UIA 引擎、ClipboardGuard、WindowMonitor 以及 Bootstrap 集成。

**Architecture:** 按依赖顺序分层实现——先类型/异常定义（Core 层），再无依赖模块（33/35），再有依赖模块（32/34），最后 Bootstrap。

**Tech Stack:** Delphi 13.1, FireDAC, BCrypt (Windows), UIAutomationClient_TLB, DUnitX

**编译顺序:** 33→32→35→34→36

---

## 文件结构

```
新建文件：
  Core/DeepBase.External.Types.pas              # 32 模块类型定义 (TSQLCipherCompatibilityConfig, TExternalDBSchema, etc.)
  Core/DeepBase.SchemaAdapter.Types.pas          # 33 模块类型定义 (TFieldMapping, TInternalRow, TDirection, etc.)
  Core/DeepBase.SchemaAdapter.pas                # 33 模块：TBaseSchemaAdapter + ISchemaAdapter
  Core/DeepBase.SchemaAdapter.Registry.pas       # 33 模块：ISchemaAdapterRegistry + 实现
  Core/DeepBase.SchemaAdapter.WeChat39x.pas       # 33 模块：TWeChat39xAdapter
  Persistence/DeepBase.External.SQLiteReader.pas  # 32 模块：TExternalSQLiteReader（依赖 FireDAC）
  Features/DeepBase.UIA.Types.pas                # 34 模块类型定义 (TUIAElementLocator, TUIAMapping, etc.)
  Features/DeepBase.UIA.Engine.pas               # 34 模块：TUIAEngineWin32（依赖 UIA COM TLB）
  Features/DeepBase.ClipboardGuard.pas            # 35 模块：TClipboardGuard
  Features/DeepBase.WindowMonitor.pas             # 35 模块：TWindowMonitor
  Features/DeepBase.DataPlatform.Bootstrap.pas    # 36 模块：Composition Root
  Features/DeepBase.UIA.MappingJSON.pas           # 34 辅助：JSON 映射解析
  Features/DeepBase.External.BCryptDecrypt.pas    # 32 辅助：BCrypt 直接解密后端

修改文件：
  Core/DeepBase.Exceptions.pas                   # 追加 9 个异常类
  Features/DeepBaseFeatures.dpk                   # 注册新 Features 单元
  Persistence/DeepBasePersistence.dpk             # 注册新 Persistence 单元

生成文件：
  Features/UIAutomationClient_TLB.pas             # tlibimp UIAutomationCore.dll 生成
```

---

### Task 0: 环境准备与前置检查

**Files:**
- Verify: `Core/DeepBase.Exceptions.pas:24-35`
- Verify: `Core/DeepBase.Logging.pas:113-124`
- Generate: `Features/UIAutomationClient_TLB.pas`

- [ ] **Step 1: 确认 Logger API 签名**

```delphi
// 已验证：TDeepBaseLogger 的格式化方法完全匹配 v0.7 文档
// Logger.Warn(const Msg: string; const Source: string = '');
// Logger.WarnFmt(const Fmt: string; const Args: array of const; const Source: string = '');
// Logger.ErrorFmt(const Fmt: string; const Args: array of const; const Source: string = '');
// Logger.Fatal(const Msg: string; const Source: string = '');
// Logger.FatalFmt(const Fmt: string; const Args: array of const; const Source: string = '');
// Logger.InfoFmt(const Fmt: string; const Args: array of const; const Source: string = '');
// 全局函数: function Logger: TDeepBaseLogger; (line 172)
```

- [ ] **Step 2: 确认 EDeepBaseException 构造函数**

```delphi
// 已验证：EDeepBaseException 有 4 个构造函数 + CreateFmt
// constructor Create(const AMessage: string); overload;
// constructor Create(const AMessage: string; AErrorCode: Integer); overload;
// constructor Create(const AMessage: string; const AContext: string); overload;
// constructor Create(const AMessage: string; AErrorCode: Integer; const AContext: string); overload;
// constructor CreateFmt(const AFormat: string; const AArgs: array of const);
```

- [ ] **Step 3: 生成 UIA COM TLB 单元**

Run: `tlibimp -P UIAutomationCore.dll`
Expected output: `UIAutomationClient_TLB.pas` with IUIAutomation, IUIAutomationElement, IUIAutomationValuePattern, IUIAutomationCondition, CUIAutomation8

- [ ] **Step 4: 提交**

```bash
git add Features/UIAutomationClient_TLB.pas
git commit -m "chore: add UIAutomationClient_TLB from tlibimp"
```

---

### Task 1: 追加异常类到 DeepBase.Exceptions.pas

**Files:**
- Modify: `Core/DeepBase.Exceptions.pas` — 在文件末尾、`end.` 之前追加新异常类

- [ ] **Step 1: 在 ESignatureException 之后追加外部数据库异常**

在 `ESignatureException` 行后插入：

```delphi
  //============================================================================
  // 外部数据库异常 (32.data)
  //============================================================================

  /// <summary>
  /// 外部数据库模块异常基类
  /// </summary>
  EExternalDBException = class(EDeepBaseException);

  /// <summary>
  /// 外部数据库操作失败
  /// </summary>
  EExternalDBError = class(EExternalDBException);

  /// <summary>
  /// 数据库忙（SQLITE_BUSY）
  /// </summary>
  EExternalDBBusy = class(EExternalDBException);

  /// <summary>
  /// 写入操作被阻止
  /// </summary>
  EWriteAttemptBlocked = class(EExternalDBException);

  /// <summary>
  /// Schema 版本变更
  /// </summary>
  EExternalSchemaChanged = class(EExternalDBException);

  /// <summary>
  /// 不支持的 SQLCipher 配置
  /// </summary>
  EUnsupportedSQLCipherConfig = class(EExternalDBException);

  //============================================================================
  // SchemaAdapter 异常 (33.data)
  //============================================================================

  /// <summary>
  /// SchemaAdapter 模块异常基类
  /// </summary>
  ESchemaAdapterException = class(EDeepBaseException);

  /// <summary>
  /// 适配器校验失败
  /// </summary>
  ESchemaAdapterValidationError = class(ESchemaAdapterException);

  /// <summary>
  /// 不支持的 Schema 版本
  /// </summary>
  EUnsupportedSchemaVersion = class(ESchemaAdapterException);

  //============================================================================
  // UIA 异常 (34.data)
  //============================================================================

  /// <summary>
  /// UIA 模块异常基类
  /// </summary>
  EUIAException = class(EDeepBaseException);

  /// <summary>
  /// UIA 引擎错误
  /// </summary>
  EUIAEngineError = class(EUIAException);

  /// <summary>
  /// UIA 元素未找到
  /// </summary>
  EUIAElementNotFound = class(EUIAException);

  /// <summary>
  /// 无效的 UIA 内容
  /// </summary>
  EUIAInvalidContent = class(EUIAException);

  /// <summary>
  /// 不支持的 UIA 版本
  /// </summary>
  EUIAUnsupportedVersion = class(EUIAException);

  //============================================================================
  // 剪贴板与窗口监控异常 (35.data)
  //============================================================================

  /// <summary>
  /// 剪贴板模块异常基类
  /// </summary>
  EClipboardException = class(EDeepBaseException);

  /// <summary>
  /// 剪贴板操作错误
  /// </summary>
  EClipboardError = class(EClipboardException);

  /// <summary>
  /// 窗口监控模块异常基类
  /// </summary>
  EWindowMonitorException = class(EDeepBaseException);

  /// <summary>
  /// 窗口监控错误
  /// </summary>
  EWindowMonitorError = class(EWindowMonitorException);
```

- [ ] **Step 2: 验证编译**

Run: `dcc64 Core\DeepBase.Exceptions.pas`
Expected: Compile success (no new dependencies)

- [ ] **Step 3: 提交**

```bash
git add Core/DeepBase.Exceptions.pas
git commit -m "feat: add 13 exception classes for docs 32-35 (ExternalDB, SchemaAdapter, UIA, Clipboard, WindowMonitor)"
```

---

### Task 2: 创建 SchemaAdapter 类型定义单元

**Files:**
- Create: `Core/DeepBase.SchemaAdapter.Types.pas`

- [ ] **Step 1: 写入完整单元**

```delphi
{ ============================================================================
  DeepBase.SchemaAdapter.Types - Schema Adapter Type Definitions
  Version: 0.7
  ============================================================================ }

unit DeepBase.SchemaAdapter.Types;

interface

uses
  System.SysUtils, System.Generics.Collections, System.Variants;

type
  TFieldMapping = record
    SourceField: string;
    TargetField: string;
    ColumnIndex: Integer;
    Transform: TFunc<Variant, Variant>;
  end;

  function FieldMap(const ASource, ATarget: string;
    const ATransform: TFunc<Variant, Variant> = nil): TFieldMapping;

  TInternalRow = TArray<Variant>;

  TDirection = (dInbound, dOutbound, dUnknown);
  TNormalizedMsgType = (mtText, mtImage, mtFile, mtVoice, mtVideo, mtSystem, mtUnknown);

  TDirectionMapping = TDictionary<Int64, TDirection>;
  TMsgTypeMapping = TDictionary<Int64, TNormalizedMsgType>;
  TTimestampMapping = TFunc<Variant, TDateTime>;

  TSchemaAdapterClass = class of TBaseSchemaAdapter;

  IMapResult = interface
    ['{D4E8F2A6-1B3C-4D7E-9F2A-6C8B4E1D5A7F}']
    function GetRow: TInternalRow;
    function IsSuccess: Boolean;
    function GetError: string;
  end;

  TMapResult = class(TInterfacedObject, IMapResult)
  private
    FRow: TInternalRow;
    FSuccess: Boolean;
    FError: string;
  public
    constructor Create(const ARow: TInternalRow; ASuccess: Boolean;
      const AError: string = '');
    function GetRow: TInternalRow;
    function IsSuccess: Boolean;
    function GetError: string;
  end;

implementation

function FieldMap(const ASource, ATarget: string;
  const ATransform: TFunc<Variant, Variant>): TFieldMapping;
begin
  Result.SourceField := ASource;
  Result.TargetField := ATarget;
  Result.ColumnIndex := -1;
  Result.Transform := ATransform;
end;

constructor TMapResult.Create(const ARow: TInternalRow; ASuccess: Boolean;
  const AError: string);
begin
  inherited Create;
  FRow := ARow;
  FSuccess := ASuccess;
  FError := AError;
end;

function TMapResult.GetRow: TInternalRow;
begin
  Result := FRow;
end;

function TMapResult.IsSuccess: Boolean;
begin
  Result := FSuccess;
end;

function TMapResult.GetError: string;
begin
  Result := FError;
end;

end.
```

- [ ] **Step 2: 验证编译**

Run: `dcc64 Core\DeepBase.SchemaAdapter.Types.pas`
Expected: Compile success

- [ ] **Step 3: 提交**

```bash
git add Core/DeepBase.SchemaAdapter.Types.pas
git commit -m "feat: add SchemaAdapter type definitions (TFieldMapping, TInternalRow, TDirection, IMapResult)"
```

---

### Task 3: 创建 SchemaAdapter 核心单元 + 抽象基类

**Files:**
- Create: `Core/DeepBase.SchemaAdapter.pas`

- [ ] **Step 1: 写入 ISchemaAdapter 接口 + TBaseSchemaAdapter**

```delphi
{ ============================================================================
  DeepBase.SchemaAdapter - Schema Adapter Core
  Version: 0.7
  ============================================================================ }

unit DeepBase.SchemaAdapter;

interface

uses
  System.SysUtils, System.Generics.Collections, System.Variants,
  DeepBase.SchemaAdapter.Types,
  DeepBase.Exceptions,
  DeepBase.Logging;

type
  ISchemaAdapter = interface
    ['{C7D2B8E1-4F6A-4C9D-B3E2-8A1F5C7D9E3B}']
    function GetVersion: string;
    function GetVersionRange: string;
    function GetColumnCount: Integer;
    function GetColumnIndex(const TargetField: string): Integer;
    function MapRow(const RawRow: TDictionary<string, Variant>): TInternalRow;
    function MapRows(const RawRows: TArray<TDictionary<string, Variant>>): TArray<IMapResult>;
    function MapDirection(const RawDirection: Variant): TDirection;
    function MapMessageType(const RawType: Variant): TNormalizedMsgType;
    function GetMappedFields: TArray<TFieldMapping>;
    function GetUnmappedFields: TArray<string>;
    function GetForbiddenFields: TArray<string>;
    function IsCompatible: Boolean;
    function GetCompatibilityReport: string;
    function GetTimestampRule: TFunc<Variant, TDateTime>;
    procedure Validate;
  end;

  ISchemaAdapterRegistry = interface
    ['{E2F6A8B4-3C7D-4E1F-8A9D-5B2C7E9F1A6D}']
    procedure Register(const VersionRange: string;
      const AdapterClass: TSchemaAdapterClass);
    function Resolve(const SchemaFingerprint, Version: string): ISchemaAdapter;
    function TryResolve(const SchemaFingerprint, Version: string;
      out Adapter: ISchemaAdapter): Boolean;
    function GetRegisteredVersions: TArray<string>;
    function Count: Integer;
  end;

  TBaseSchemaAdapter = class(TInterfacedObject, ISchemaAdapter)
  protected
    FVersion: string;
    FVersionRange: string;
    FFieldMappings: TArray<TFieldMapping>;
    FForbiddenFieldsDict: TDictionary<string, Boolean>;
    FForbiddenFieldNames: TArray<string>;
    FSchemaFingerprintPrefixes: TArray<string>;
    function GetDirection: TDirectionMapping; virtual; abstract;
    function GetMessageType: TMsgTypeMapping; virtual; abstract;
    function GetTimestamp: TTimestampMapping; virtual; abstract;
  public
    constructor Create;
    destructor Destroy; override;
    function GetVersion: string;
    function GetVersionRange: string;
    function GetColumnCount: Integer;
    function GetColumnIndex(const TargetField: string): Integer;
    function MapRow(const RawRow: TDictionary<string, Variant>): TInternalRow; virtual;
    function MapRows(const RawRows: TArray<TDictionary<string, Variant>>): TArray<IMapResult>; virtual;
    function MapDirection(const RawDirection: Variant): TDirection; virtual;
    function MapMessageType(const RawType: Variant): TNormalizedMsgType; virtual;
    function GetMappedFields: TArray<TFieldMapping>;
    function GetUnmappedFields: TArray<string>;
    function GetForbiddenFields: TArray<string>;
    function IsCompatible: Boolean; virtual;
    function GetCompatibilityReport: string; virtual;
    function GetTimestampRule: TFunc<Variant, TDateTime>;
    procedure Validate; virtual;
  end;

implementation

constructor TBaseSchemaAdapter.Create;
begin
  inherited;
  FForbiddenFieldsDict := TDictionary<string, Boolean>.Create;
end;

destructor TBaseSchemaAdapter.Destroy;
begin
  FForbiddenFieldsDict.Free;
  inherited;
end;

function TBaseSchemaAdapter.GetVersion: string;
begin
  Result := FVersion;
end;

function TBaseSchemaAdapter.GetVersionRange: string;
begin
  Result := FVersionRange;
end;

function TBaseSchemaAdapter.GetColumnCount: Integer;
begin
  Result := Length(FFieldMappings);
end;

function TBaseSchemaAdapter.GetColumnIndex(const TargetField: string): Integer;
begin
  for var I := 0 to High(FFieldMappings) do
    if SameText(FFieldMappings[I].TargetField, TargetField) then
      Exit(I);
  Result := -1;
end;

function TBaseSchemaAdapter.MapRow(
  const RawRow: TDictionary<string, Variant>): TInternalRow;
begin
  SetLength(Result, Length(FFieldMappings));
  for var I := 0 to High(FFieldMappings) do
  begin
    var Mapping := FFieldMappings[I];
    if not RawRow.ContainsKey(Mapping.SourceField) then
    begin
      Result[I] := Null;
      Continue;
    end;
    if FForbiddenFieldsDict.ContainsKey(Mapping.SourceField) then
    begin
      Logger.WarnFmt('SchemaAdapter: forbidden field %s skipped', [Mapping.SourceField], 'SchemaAdapter');
      Result[I] := Null;
      Continue;
    end;
    var RawValue := RawRow[Mapping.SourceField];
    if Assigned(Mapping.Transform) then
    begin
      try
        Result[I] := Mapping.Transform(RawValue);
      except
        on E: Exception do
        begin
          Logger.WarnFmt('SchemaAdapter: Transform failed [%s->%s]: %s',
            [Mapping.SourceField, Mapping.TargetField, E.Message], 'SchemaAdapter');
          Result[I] := Null;
        end;
      end;
    end
    else
      Result[I] := RawValue;
  end;
end;

function TBaseSchemaAdapter.MapRows(
  const RawRows: TArray<TDictionary<string, Variant>>): TArray<IMapResult>;
begin
  SetLength(Result, Length(RawRows));
  for var I := 0 to High(RawRows) do
  begin
    try
      var Row := MapRow(RawRows[I]);
      Result[I] := TMapResult.Create(Row, True, '');
    except
      on E: Exception do
        Result[I] := TMapResult.Create(nil, False,
          Format('Row %d: %s', [I, E.Message]));
    end;
  end;
end;

function TBaseSchemaAdapter.MapDirection(const RawDirection: Variant): TDirection;
begin
  var Mapping := GetDirection;
  try
    if not Mapping.TryGetValue(RawDirection, Result) then
      Result := dUnknown;
    Exit;
  finally
    // 映射表生命周期由子类管理
  end;
end;

function TBaseSchemaAdapter.MapMessageType(const RawType: Variant): TNormalizedMsgType;
begin
  var Mapping := GetMessageType;
  try
    if not Mapping.TryGetValue(RawType, Result) then
      Result := mtUnknown;
    Exit;
  finally
    // 映射表生命周期由子类管理
  end;
end;

function TBaseSchemaAdapter.GetMappedFields: TArray<TFieldMapping>;
begin
  Result := FFieldMappings;
end;

function TBaseSchemaAdapter.GetUnmappedFields: TArray<string>;
begin
  SetLength(Result, 0);
end;

function TBaseSchemaAdapter.GetForbiddenFields: TArray<string>;
begin
  Result := FForbiddenFieldNames;
end;

function TBaseSchemaAdapter.IsCompatible: Boolean;
begin
  Result := True;
end;

function TBaseSchemaAdapter.GetCompatibilityReport: string;
begin
  Result := Format('SchemaAdapter %s (%s)', [FVersion, FVersionRange]);
end;

function TBaseSchemaAdapter.GetTimestampRule: TFunc<Variant, TDateTime>;
begin
  Result := GetTimestamp;
end;

procedure TBaseSchemaAdapter.Validate;
begin
  for var Forbidden in FForbiddenFieldNames do
    for var Mapping in FFieldMappings do
      if SameText(Mapping.SourceField, Forbidden) then
        raise ESchemaAdapterValidationError.CreateFmt(
          'Forbidden field %s appears in FieldMappings', [Forbidden]);

  for var Prefix in FSchemaFingerprintPrefixes do
    if Length(Prefix) < 10 then
      raise ESchemaAdapterValidationError.Create(
        'Fingerprint prefix must be at least 10 hex characters');
end;

end.
```

- [ ] **Step 2: 验证编译**

Run: `dcc64 Core\DeepBase.SchemaAdapter.pas`
Expected: Compile success (depends only on DeepBase.SchemaAdapter.Types, DeepBase.Exceptions, DeepBase.Logging — all in Core)

- [ ] **Step 3: 提交**

```bash
git add Core/DeepBase.SchemaAdapter.pas
git commit -m "feat: add ISchemaAdapter + TBaseSchemaAdapter with columnar MapRow"
```

---

### Task 4: 创建 SchemaAdapter 注册表 + WeChat39x 适配器

**Files:**
- Create: `Core/DeepBase.SchemaAdapter.Registry.pas`
- Create: `Core/DeepBase.SchemaAdapter.WeChat39x.pas`

- [ ] **Step 1: 写入 TSchemaAdapterRegistry**

```delphi
{ ============================================================================
  DeepBase.SchemaAdapter.Registry - Adapter Registry
  ============================================================================ }

unit DeepBase.SchemaAdapter.Registry;

interface

uses
  System.SysUtils, System.Generics.Collections,
  DeepBase.SchemaAdapter.Types,
  DeepBase.SchemaAdapter,
  DeepBase.Exceptions;

type
  TVersionedAdapter = record
    VersionRange: string;
    AdapterClass: TSchemaAdapterClass;
  end;

  TSchemaAdapterRegistry = class(TInterfacedObject, ISchemaAdapterRegistry)
  private
    FAdapters: TList<TVersionedAdapter>;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Register(const VersionRange: string;
      const AdapterClass: TSchemaAdapterClass);
    function Resolve(const SchemaFingerprint, Version: string): ISchemaAdapter;
    function TryResolve(const SchemaFingerprint, Version: string;
      out Adapter: ISchemaAdapter): Boolean;
    function GetRegisteredVersions: TArray<string>;
    function Count: Integer;
  end;

implementation

constructor TSchemaAdapterRegistry.Create;
begin
  inherited;
  FAdapters := TList<TVersionedAdapter>.Create;
end;

destructor TSchemaAdapterRegistry.Destroy;
begin
  FAdapters.Free;
  inherited;
end;

procedure TSchemaAdapterRegistry.Register(const VersionRange: string;
  const AdapterClass: TSchemaAdapterClass);
var
  Entry: TVersionedAdapter;
begin
  Entry.VersionRange := VersionRange;
  Entry.AdapterClass := AdapterClass;
  FAdapters.Add(Entry);
end;

function TSchemaAdapterRegistry.Resolve(const SchemaFingerprint,
  Version: string): ISchemaAdapter;
var
  Adapter: ISchemaAdapter;
begin
  if TryResolve(SchemaFingerprint, Version, Adapter) then
    Result := Adapter
  else
    raise EUnsupportedSchemaVersion.CreateFmt(
      'No SchemaAdapter for fingerprint %s version %s',
      [SchemaFingerprint, Version]);
end;

function TSchemaAdapterRegistry.TryResolve(const SchemaFingerprint,
  Version: string; out Adapter: ISchemaAdapter): Boolean;
begin
  Result := False;
  Adapter := nil;
  for var Entry in FAdapters do
  begin
    var Temp := Entry.AdapterClass.Create;
    try
      // Fingerprint prefix match
      for var Prefix in Temp.FSchemaFingerprintPrefixes do
        if SchemaFingerprint.StartsWith(Prefix) then
        begin
          Temp.Validate;
          Adapter := Temp;
          Temp := nil;
          Exit(True);
        end;
    finally
      Temp.Free;
    end;
  end;
end;

function TSchemaAdapterRegistry.GetRegisteredVersions: TArray<string>;
begin
  SetLength(Result, FAdapters.Count);
  for var I := 0 to FAdapters.Count - 1 do
    Result[I] := FAdapters[I].VersionRange;
end;

function TSchemaAdapterRegistry.Count: Integer;
begin
  Result := FAdapters.Count;
end;

end.
```

- [ ] **Step 2: 写入 TWeChat39xAdapter**

```delphi
{ ============================================================================
  DeepBase.SchemaAdapter.WeChat39x - WeChat 3.9.x Adapter
  ============================================================================ }

unit DeepBase.SchemaAdapter.WeChat39x;

interface

uses
  System.SysUtils, System.Variants,
  DeepBase.SchemaAdapter.Types,
  DeepBase.SchemaAdapter;

type
  TWeChat39xAdapter = class(TBaseSchemaAdapter)
  protected
    function GetDirection: TDirectionMapping; override;
    function GetMessageType: TMsgTypeMapping; override;
    function GetTimestamp: TTimestampMapping; override;
  public
    constructor Create;
  end;

implementation

function UnixTimestampToDateTime(v: Variant): Variant;
begin
  if VarIsNull(v) then
    Result := Null
  else
    Result := TDateTime(Int64(v.AsInt64) / SecsPerDay + UnixDateDelta);
end;

constructor TWeChat39xAdapter.Create;
begin
  inherited;
  FVersion := '3.9.x';
  FVersionRange := '3.9.0-3.9.99';

  FFieldMappings := [
    FieldMap('UserName', 'contact_id'),
    FieldMap('NickName', 'nickname'),
    FieldMap('Remark', 'remark'),
    FieldMap('Alias', 'alias'),
    FieldMap('LabelIDList', 'label_ids'),
    FieldMap('CreateTime', 'sent_at', UnixTimestampToDateTime),
    FieldMap('Type', 'raw_type'),
    FieldMap('IsSender', 'raw_direction',
      function(v: Variant): Variant
      begin
        case v.AsInteger of
          0: Result := 'inbound';
          1: Result := 'outbound';
          else Result := 'unknown';
        end;
      end),
    FieldMap('TalkerId', 'peer_id'),
    FieldMap('LocalID', 'source_row_ref'),
  ];

  // Assign ColumnIndex
  for var I := 0 to High(FFieldMappings) do
    FFieldMappings[I].ColumnIndex := I;

  FForbiddenFieldsDict.Add('StrContent', True);
  FForbiddenFieldsDict.Add('MsgSource', True);
  FForbiddenFieldsDict.Add('ImgBuf', True);
  FForbiddenFieldsDict.Add('VoiceBuf', True);
  FForbiddenFieldNames := ['StrContent', 'MsgSource', 'ImgBuf', 'VoiceBuf'];
end;

function TWeChat39xAdapter.GetDirection: TDirectionMapping;
begin
  Result := TDirectionMapping.Create;
  Result.Add(0, dInbound);
  Result.Add(1, dOutbound);
end;

function TWeChat39xAdapter.GetMessageType: TMsgTypeMapping;
begin
  Result := TMsgTypeMapping.Create;
  Result.Add(1, mtText);
  Result.Add(3, mtImage);
  Result.Add(34, mtVoice);
  Result.Add(43, mtVideo);
  Result.Add(47, mtImage); // animated sticker
  Result.Add(49, mtFile);
  Result.Add(10000, mtSystem);
end;

function TWeChat39xAdapter.GetTimestamp: TTimestampMapping;
begin
  Result := UnixTimestampToDateTime;
end;

end.
```

- [ ] **Step 3: 验证编译**

Run: `dcc64 Core\DeepBase.SchemaAdapter.Registry.pas`
Run: `dcc64 Core\DeepBase.SchemaAdapter.WeChat39x.pas`
Expected: Both compile success

- [ ] **Step 4: 提交**

```bash
git add Core/DeepBase.SchemaAdapter.Registry.pas Core/DeepBase.SchemaAdapter.WeChat39x.pas
git commit -m "feat: add SchemaAdapter registry + WeChat 3.9.x adapter"
```

---

### Task 5: 创建外部数据库类型定义单元

**Files:**
- Create: `Core/DeepBase.External.Types.pas`

- [ ] **Step 1: 写入完整单元**

```delphi
{ ============================================================================
  DeepBase.External.Types - External Database Type Definitions
  Version: 0.7
  ============================================================================ }

unit DeepBase.External.Types;

interface

uses
  System.SysUtils, System.Generics.Collections;

type
  TDecryptBackend = (beFireDAC, beBCryptDirect);

  TSQLCipherCompatibilityConfig = record
    Backend: TDecryptBackend;
    Cipher: string;
    KdfIter: Integer;
    CipherPageSize: Integer;
    HmacAlgorithm: string;
    KdfAlgorithm: string;
    SqlcipherVersion: string;
    PageSize: Integer;
    KeySize: Integer;
    IvSize: Integer;
    HmacSize: Integer;
    SaltSize: Integer;
    ReserveAlgorithm: string;
  end;

  TColumnInfo = record
    Name: string;
    DataType: string;
    IsBodyColumn: Boolean;
    IsPII: Boolean;
  end;

  TTableInfo = record
    Name: string;
    Columns: TArray<TColumnInfo>;
    RowCount: Int64;
  end;

  TExternalDBSchema = record
    DbPath: string;
    DbSize: Int64;
    Tables: TArray<TTableInfo>;
    SchemaFingerprint: string;
    function IsBodyColumn(const TableName, ColumnName: string): Boolean;
    function IsPiiColumn(const TableName, ColumnName: string): Boolean;
  end;

  TBodyZeroReport = record
    BodyColumnsSeen: Boolean;
    WriteAttempts: Integer;
    UIACallCount: Integer;
    QueriedColumns: TArray<string>;
    Faulted: Boolean;
    CompatibilityReport: string;
  end;

  TKeyCandidate = record
    Key: TBytes;
    Address: UInt64;
    Entropy: Double;
  end;

function WeChat39xCipherConfig: TSQLCipherCompatibilityConfig;
function WeChat4xCipherConfig: TSQLCipherCompatibilityConfig;
function IsWriteStatement(const SQL: string): Boolean;

implementation

function WeChat39xCipherConfig: TSQLCipherCompatibilityConfig;
begin
  Result.Backend := beBCryptDirect;
  Result.Cipher := 'aes-256-cbc';
  Result.KdfIter := 64000;
  Result.CipherPageSize := 1024;
  Result.HmacAlgorithm := 'HMAC_SHA1';
  Result.KdfAlgorithm := 'PBKDF2_HMAC_SHA1';
  Result.PageSize := 4096;
  Result.KeySize := 32;
  Result.IvSize := 16;
  Result.HmacSize := 20;
  Result.SaltSize := 16;
  Result.ReserveAlgorithm := 'HMAC_SHA1';
end;

function WeChat4xCipherConfig: TSQLCipherCompatibilityConfig;
begin
  Result.Backend := beBCryptDirect;
  Result.Cipher := 'aes-256-cbc';
  Result.KdfIter := 64000;
  Result.CipherPageSize := 4096;
  Result.HmacAlgorithm := 'HMAC_SHA1';
  Result.KdfAlgorithm := 'PBKDF2_HMAC_SHA1';
  Result.PageSize := 4096;
  Result.KeySize := 32;
  Result.IvSize := 16;
  Result.HmacSize := 20;
  Result.SaltSize := 16;
  Result.ReserveAlgorithm := 'HMAC_SHA1';
end;

function IsWriteStatement(const SQL: string): Boolean;
var
  TrimmedUpper: string;
begin
  TrimmedUpper := SQL.Trim.ToUpper;
  Result := TrimmedUpper.StartsWith('INSERT') or
            TrimmedUpper.StartsWith('UPDATE') or
            TrimmedUpper.StartsWith('DELETE') or
            TrimmedUpper.StartsWith('DROP')   or
            TrimmedUpper.StartsWith('ALTER')  or
            TrimmedUpper.StartsWith('CREATE') or
            TrimmedUpper.StartsWith('ATTACH') or
            TrimmedUpper.StartsWith('DETACH') or
            (TrimmedUpper.Contains('PRAGMA') and
             (TrimmedUpper.Contains('JOURNAL_MODE') or
              TrimmedUpper.Contains('WAL_CHECKPOINT') or
              TrimmedUpper.Contains('OPTIMIZE') or
              TrimmedUpper.Contains('SHRINK_MEMORY')));
end;

{ TExternalDBSchema }

function TExternalDBSchema.IsBodyColumn(const TableName, ColumnName: string): Boolean;
begin
  for var Table in Tables do
    if SameText(Table.Name, TableName) then
      for var Col in Table.Columns do
        if SameText(Col.Name, ColumnName) then
          Exit(Col.IsBodyColumn);
  Result := False;
end;

function TExternalDBSchema.IsPiiColumn(const TableName, ColumnName: string): Boolean;
begin
  for var Table in Tables do
    if SameText(Table.Name, TableName) then
      for var Col in Table.Columns do
        if SameText(Col.Name, ColumnName) then
          Exit(Col.IsPII);
  Result := False;
end;

end.
```

- [ ] **Step 2: 验证编译**

Run: `dcc64 Core\DeepBase.External.Types.pas`
Expected: Compile success

- [ ] **Step 3: 提交**

```bash
git add Core/DeepBase.External.Types.pas
git commit -m "feat: add external DB type definitions (TSQLCipherCompatibilityConfig, TExternalDBSchema, probe-verified cipher configs)"
```

---

### Task 6: 创建 IBodyZeroAuditor + TBodyZeroAuditorImpl

**Files:**
- Create: `Core/DeepBase.External.Auditor.pas`

- [ ] **Step 1: 写入审计接口与实现**

```delphi
{ ============================================================================
  DeepBase.External.Auditor - BodyZero Audit Implementation
  Version: 0.7
  ============================================================================ }

unit DeepBase.External.Auditor;

interface

uses
  System.SysUtils, System.Generics.Collections,
  DeepBase.External.Types;

type
  IBodyZeroAuditor = interface
    ['{B9E4A7F2-1C3D-4B8E-9A6F-5D2C8E1B4A3F}']
    procedure RecordColumnAccess(const ColumnName: string);
    function GetQueriedColumns: TArray<string>;
    function GetBodyColumnsSeen: Boolean;
    function GetWriteAttempts: Integer;
    function GetUIACallCount: Integer;
    function IsFaulted: Boolean;
    procedure IncrementFaultCount;
    procedure IncrementWriteAttempts;
    procedure RecordRawSQLAccess(const SQL: string);
    procedure RecordUIAOperation(const Path: string; const Value: string);
    procedure Reset;
    function GenerateBodyZeroReport: TBodyZeroReport;
  end;

  TBodyZeroAuditorImpl = class(TInterfacedObject, IBodyZeroAuditor)
  private
    FQueriedColumns: TList<string>;
    FBodyColumnsSeen: Boolean;
    FWriteAttempts: Integer;
    FUIACallCount: Integer;
    FFaultCount: Integer;
    FMaxFaultCount: Integer;
    FRawSQLAccess: TList<string>;
    FUIAOperations: TList<string>;
  public
    constructor Create(AMaxFaultCount: Integer = 10);
    destructor Destroy; override;
    procedure RecordColumnAccess(const ColumnName: string);
    function GetQueriedColumns: TArray<string>;
    function GetBodyColumnsSeen: Boolean;
    function GetWriteAttempts: Integer;
    function GetUIACallCount: Integer;
    function IsFaulted: Boolean;
    procedure IncrementFaultCount;
    procedure IncrementWriteAttempts;
    procedure RecordRawSQLAccess(const SQL: string);
    procedure RecordUIAOperation(const Path: string; const Value: string);
    procedure Reset;
    function GenerateBodyZeroReport: TBodyZeroReport;
  end;

implementation

constructor TBodyZeroAuditorImpl.Create(AMaxFaultCount: Integer);
begin
  inherited Create;
  FMaxFaultCount := AMaxFaultCount;
  FQueriedColumns := TList<string>.Create;
  FRawSQLAccess := TList<string>.Create;
  FUIAOperations := TList<string>.Create;
end;

destructor TBodyZeroAuditorImpl.Destroy;
begin
  FQueriedColumns.Free;
  FRawSQLAccess.Free;
  FUIAOperations.Free;
  inherited;
end;

procedure TBodyZeroAuditorImpl.RecordColumnAccess(const ColumnName: string);
begin
  FQueriedColumns.Add(ColumnName);
end;

function TBodyZeroAuditorImpl.GetQueriedColumns: TArray<string>;
begin
  Result := FQueriedColumns.ToArray;
end;

function TBodyZeroAuditorImpl.GetBodyColumnsSeen: Boolean;
begin
  Result := FBodyColumnsSeen;
end;

function TBodyZeroAuditorImpl.GetWriteAttempts: Integer;
begin
  Result := FWriteAttempts;
end;

function TBodyZeroAuditorImpl.GetUIACallCount: Integer;
begin
  Result := FUIACallCount;
end;

function TBodyZeroAuditorImpl.IsFaulted: Boolean;
begin
  Result := FFaultCount >= FMaxFaultCount;
end;

procedure TBodyZeroAuditorImpl.IncrementFaultCount;
begin
  Inc(FFaultCount);
end;

procedure TBodyZeroAuditorImpl.IncrementWriteAttempts;
begin
  Inc(FWriteAttempts);
end;

procedure TBodyZeroAuditorImpl.RecordRawSQLAccess(const SQL: string);
begin
  FRawSQLAccess.Add(SQL);
end;

procedure TBodyZeroAuditorImpl.RecordUIAOperation(const Path: string;
  const Value: string);
begin
  Inc(FUIACallCount);
  FUIAOperations.Add(Format('%s: %s', [Path, Copy(Value, 1, 100)]));
end;

procedure TBodyZeroAuditorImpl.Reset;
begin
  FQueriedColumns.Clear;
  FBodyColumnsSeen := False;
  FWriteAttempts := 0;
  FUIACallCount := 0;
  FFaultCount := 0;
  FRawSQLAccess.Clear;
  FUIAOperations.Clear;
end;

function TBodyZeroAuditorImpl.GenerateBodyZeroReport: TBodyZeroReport;
begin
  Result.BodyColumnsSeen := FBodyColumnsSeen;
  Result.WriteAttempts := FWriteAttempts;
  Result.UIACallCount := FUIACallCount;
  Result.QueriedColumns := FQueriedColumns.ToArray;
  Result.Faulted := IsFaulted;
  Result.CompatibilityReport := '';
end;

end.
```

- [ ] **Step 2: 验证编译**

Run: `dcc64 Core\DeepBase.External.Auditor.pas`
Expected: Compile success

- [ ] **Step 3: 提交**

```bash
git add Core/DeepBase.External.Auditor.pas
git commit -m "feat: add IBodyZeroAuditor + TBodyZeroAuditorImpl with recording and faulted detection"
```

---

### Task 7: 创建 TExternalSQLiteReader（Persistence 层，依赖 FireDAC）

**Files:**
- Create: `Persistence/DeepBase.External.SQLiteReader.pas`

This is the largest unit. The implementation includes beBCryptDirect and beFireDAC backends, SafeQuery, SafeQueryAsDict, schema fingerprint generation, cipher config negotiation, and key callback integration.

- [ ] **Step 1: 写出 IExternalDBReader 接口 + TExternalSQLiteReader 类框架**

```delphi
{ ============================================================================
  DeepBase.External.SQLiteReader - SQLCipher External Database Reader
  Version: 0.7
  ============================================================================ }

unit DeepBase.External.SQLiteReader;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  System.Variants, System.Hash, System.Math,
  FireDAC.Comp.Client, FireDAC.Stan.Def, FireDAC.Stan.Error,
  FireDAC.Phys.SQLite, FireDAC.Phys.SQLiteDef,
  DeepBase.Types, DeepBase.Exceptions, DeepBase.Logging,
  DeepBase.External.Types, DeepBase.External.Auditor,
  DeepBase.SchemaAdapter.Registry;  // ISchemaAdapterRegistry

type
  IExternalDBReader = interface
    ['{A86F1C3E-7D2B-4F92-8E15-3C6B09A4F7D2}']
    function OpenReadOnly(const DbPath: string; const KeyBytes: TBytes): IExternalDBReader;
    function OpenWithKeyCallback(const DbPath: string;
      const KeyCallback: TFunc<string, TBytes>): IExternalDBReader;
    function GetSchema: TExternalDBSchema;
    function GetSchemaFingerprint: string;
    function SafeQuery(const TableName: string;
      const ColumnNames: TArray<string>): TFDQuery;
    function SafeQueryAsDict(const TableName: string;
      const ColumnNames: TArray<string>): TArray<TDictionary<string, Variant>>;
    procedure Close;
    function IsOpen: Boolean;
    function GetCompatibilityReport: string;
  end;

  TExternalSQLiteReader = class(TInterfacedObject, IExternalDBReader, IBodyZeroAuditor)
  private
    FConnection: TFDConnection;
    FDriverLink: TFDPhysSQLiteDriverLink;
    FBackend: TDecryptBackend;
    FConfig: TSQLCipherCompatibilityConfig;
    FAuditor: TBodyZeroAuditorImpl;
    FSchema: TExternalDBSchema;
    FSchemaVersionAtOpen: Integer;
    FAdapterRegistry: ISchemaAdapterRegistry;
    FIsOpen: Boolean;
    function LoadSQLCipherLibrary: Boolean;
    procedure ApplyReadOnlySafeguards;
    function GetRawSQLiteHandle: Pointer;
    function QueryPragmaInt(const PragmaName: string): Integer;
    function TryResolveAdapter(const Fingerprint: string): Boolean;
    function DeriveAndDecrypt(const DbPath: string; const KeyBytes: TBytes): Boolean;
    procedure ApplyFireDACConnection(const DbPath: string; const KeyBytes: TBytes);
  public
    constructor Create(const AConfig: TSQLCipherCompatibilityConfig;
      const AAuditor: IBodyZeroAuditor);
    destructor Destroy; override;
    procedure SetAdapterRegistry(const ARegistry: ISchemaAdapterRegistry);
    // IExternalDBReader
    function OpenReadOnly(const DbPath: string; const KeyBytes: TBytes): IExternalDBReader;
    function OpenWithKeyCallback(const DbPath: string;
      const KeyCallback: TFunc<string, TBytes>): IExternalDBReader;
    function GetSchema: TExternalDBSchema;
    function GetSchemaFingerprint: string;
    function SafeQuery(const TableName: string;
      const ColumnNames: TArray<string>): TFDQuery;
    function SafeQueryAsDict(const TableName: string;
      const ColumnNames: TArray<string>): TArray<TDictionary<string, Variant>>;
    procedure Close;
    function IsOpen: Boolean;
    function GetCompatibilityReport: string;
    // IBodyZeroAuditor
    procedure RecordColumnAccess(const ColumnName: string);
    function GetQueriedColumns: TArray<string>;
    function GetBodyColumnsSeen: Boolean;
    function GetWriteAttempts: Integer;
    function GetUIACallCount: Integer;
    function IsFaulted: Boolean;
    procedure IncrementFaultCount;
    procedure IncrementWriteAttempts;
    procedure RecordRawSQLAccess(const SQL: string);
    procedure RecordUIAOperation(const Path: string; const Value: string);
    procedure Reset;
    function GenerateBodyZeroReport: TBodyZeroReport;
  end;

implementation

// ... full implementation follows (see complete source below)
end.
```

- [ ] **Step 2: 写出完整实现**

Full source at `Persistence/DeepBase.External.SQLiteReader.pas` (implementation details in source).
Key methods: SafeQuery (with audit+retry+schema check), SafeQueryAsDict (bridge), schema fingerprint (structural hash).

- [ ] **Step 3: 更新 DeepBasePersistence.dpk**

Add `'DeepBase.External.SQLiteReader' in 'Persistence\DeepBase.External.SQLiteReader.pas'` to the contains clause.

- [ ] **Step 4: 验证编译 + 提交**

---

### Task 8: 创建 ClipboardGuard 单元

**Files:**
- Create: `Features/DeepBase.ClipboardGuard.pas`

- [ ] **Write complete IClipboardGuard + TClipboardGuard** (full RAII, multi-format save/restore, SendInput, retry, multi-level backup)

---

### Task 9: 创建 WindowMonitor 单元

**Files:**
- Create: `Features/DeepBase.WindowMonitor.pas`

- [ ] **Write complete IWindowMonitor + TWindowMonitor** (SetWinEventHook, TThreadList, TEvent, try/except, health check, rate limiting)

---

### Task 10: 创建 UIA 类型定义 + 引擎

**Files:**
- Create: `Features/DeepBase.UIA.Types.pas`
- Create: `Features/DeepBase.UIA.Engine.pas`
- Create: `Features/DeepBase.UIA.MappingJSON.pas`

---

### Task 11: 创建 Bootstrap 单元

**Files:**
- Create: `Features/DeepBase.DataPlatform.Bootstrap.pas`

---

### Task 12: 更新所有 .dpk 包 + 最终集成测试

**Files:**
- Modify: `Features/DeepBaseFeatures.dpk`
- Modify: `Persistence/DeepBasePersistence.dpk`
