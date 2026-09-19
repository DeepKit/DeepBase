# EHAI Delphi 公共层符号基准 (Delphi Symbol Baseline)

> **生成机制**：由 `Scripts/gen_ehai_symbol_baseline.py` 自动从 Delphi 源码机械提取生成（禁止手工伪造与维护）。
> **生成时间 (UTC)**：`2026-09-19T06:46:34Z`
> **基准状态**：`APPROVED ENGINEERING BASELINE v0` / 机器可校验唯一真相源 (SSOT)
> **法源契约**：`EHAI-Language-Neutral-Realization-Contract-v0.md`

## 源文件指纹 (Source Fingerprints)

| 源文件 | 相对路径 | SHA256 校验和 |
| :--- | :--- | :--- |
| `DeepBase.EHAI.Types` | `Core/DeepBase.EHAI.Types.pas` | `de9a32082dbf86ff1943c33677a89746eae187f646c116fd465dda9cbb2d0799` |
| `DeepBase.HB.Choice.Types` | `Core/DeepBase.HB.Choice.Types.pas` | `963fedd0ea91402085391af2b9ed69fa137c23ffd46b340bfe8996dd059ee79e` |

---

## Unit: `DeepBase.EHAI.Types`
- **源路径**：`Core/DeepBase.EHAI.Types.pas`

### 1. 枚举类型 (Enumerations - 共 8 个)

#### `TEhaiInvolvementProfile`
```pascal
TEhaiInvolvementProfile = (
  eipInform,
  eipProvide,
  eipJudge,
  eipAuthorize,
  eipAct
);
```

#### `TEhaiSource`
```pascal
TEhaiSource = (
  esHuman,
  esAI,
  esInferred,
  esRule,
  esTool,
  esSystem
);
```

#### `TEhaiMetaAction`
```pascal
TEhaiMetaAction = (
  emaChoose,
  emaRegenerate,
  emaReframe,
  emaExit
);
```

#### `TEhaiOverrideKind`
```pascal
TEhaiOverrideKind = (
  eokNone,
  eokCandidateReject,
  eokAlternativeExpression,
  eokFrameRejection
);
```

#### `TEhaiInformState`
```pascal
TEhaiInformState = (
  eisAvailable,
  eisPresented,
  eisAcknowledged,
  eisAgreed
);
```

#### `TEhaiSemanticEffectKind`
```pascal
TEhaiSemanticEffectKind = (
  eseInformOnly,
  eseDataProvided,
  eseJudgmentMade,
  eseAuthorized,
  eseActionReported
);
```

#### `TEhaiAuthorityBasisKind`
```pascal
TEhaiAuthorityBasisKind = (
  eabExplicitConfirmation,
  eabPriorAuthorization,
  eabStandingAuthorization,
  eabRuleDerivedAuthority
);
```

#### `TEhaiCardinality`
```pascal
TEhaiCardinality = (
  ecSingle,
  ecMultiple
);
```

### 2. 结构体类型 (Records - 共 6 个)

#### `TEhaiAuthorityBasis`
```pascal
TEhaiAuthorityBasis = record
  // 字段 (Fields)
  Kind: TEhaiAuthorityBasisKind;
  AuthorityHolder: string;
  ScopeBoundary: string;
  CeilingAmount: Double;
  ConditionExpr: string;
  EstablishedAt: TDateTime;
  ExpiresAt: TDateTime;
  // 方法与工厂签名 (Methods & Factory Signatures)
  class function CreateExplicit(const AHolder, AScope: string): TEhaiAuthorityBasis; static;
  class function CreateStanding(const AHolder, AScope, ACondition: string; ACeiling: Double = 0.0; AExpiresAt: TDateTime = 0.0): TEhaiAuthorityBasis; static;
  class function CreateRuleDerived(const ARuleId, AScope: string): TEhaiAuthorityBasis; static;
  function IsValidAt(ATimestamp: TDateTime): Boolean;
  function Covers(const AScope: string; AAmount: Double = 0.0): Boolean;
end;
```

#### `TEhaiContextBinding`
```pascal
TEhaiContextBinding = record
  // 字段 (Fields)
  ContextId: string;
  ContextTitle: string;
  StepInfo: string;
  ObservableObjectRef: string;
  ScopeBoundary: string;
  AuthorityHolder: string;
  CreatedAt: TDateTime;
  // 方法与工厂签名 (Methods & Factory Signatures)
  class function Create(const AContextId, ATitle, AStepInfo, AObjectRef, AScope, AAuthority: string): TEhaiContextBinding; static;
  function IsValid: Boolean;
  function IsEqual(const Other: TEhaiContextBinding): Boolean;
end;
```

#### `TEhaiCandidate`
```pascal
TEhaiCandidate = record
  // 字段 (Fields)
  Key: Integer;
  Text: string;
  Description: string;
  IsRecommended: Boolean;
  Enabled: Boolean;
  Payload: NativeInt;
  // 方法与工厂签名 (Methods & Factory Signatures)
  class function Create(AKey: Integer; const AText: string; const ADesc: string = ''; AIsRecommended: Boolean = False; AEnabled: Boolean = True; APayload: NativeInt = 0): TEhaiCandidate; static;
end;
```

#### `TEhaiCandidateSpace`
```pascal
TEhaiCandidateSpace = record
  // 字段 (Fields)
  FItems: TArray<TEhaiCandidate>;
  FRecommendedKey: Integer;
  FHasNoReliableCandidates: Boolean;
  FNoReliableMessage: string;
  FCardinality: TEhaiCardinality;
  // 方法与工厂签名 (Methods & Factory Signatures)
  class function CreateEmpty(ACardinality: TEhaiCardinality = ecSingle): TEhaiCandidateSpace; static;
  class function CreateBounded(const AOptions: array of string; ARecommendedKey: Integer = 1; ACardinality: TEhaiCardinality = ecSingle): TEhaiCandidateSpace; static;
  procedure AddOption(AKey: Integer; const AText: string; const ADesc: string = ''; AIsRecommended: Boolean = False; APayload: NativeInt = 0);
  procedure SetNoReliableCandidates(const AMessage: string);
  procedure Clear;
  function Count: Integer;
  function GetItem(Index: Integer): TEhaiCandidate;
  function FindByKey(AKey: Integer; out ACandidate: TEhaiCandidate): Boolean;
  // 属性 (Properties)
  property Items[Index: Integer]: TEhaiCandidate read GetItem; default;
  property RecommendedKey: Integer read FRecommendedKey;
  property HasNoReliableCandidates: Boolean read FHasNoReliableCandidates;
  property NoReliableMessage: string read FNoReliableMessage;
  property Cardinality: TEhaiCardinality read FCardinality write FCardinality;
end;
```

#### `TEhaiInteractionAction`
```pascal
TEhaiInteractionAction = record
  // 字段 (Fields)
  MetaAction: TEhaiMetaAction;
  Key: Integer;
  SelectedKeys: TArray<Integer>;
  Text: string;
  Profile: TEhaiInvolvementProfile;
  Source: TEhaiSource;
  OverrideKind: TEhaiOverrideKind;
  Context: TEhaiContextBinding;
  AuthorityBasis: TEhaiAuthorityBasis;
  Payload: NativeInt;
  Timestamp: TDateTime;
  // 方法与工厂签名 (Methods & Factory Signatures)
  class function CreateCandidate(AKey: Integer; const AText: string; AProfile: TEhaiInvolvementProfile; const AContext: TEhaiContextBinding; APayload: NativeInt = 0; ASource: TEhaiSource = esHuman): TEhaiInteractionAction; static;
  class function CreateMultiCandidate(const ASelectedKeys: array of Integer; AProfile: TEhaiInvolvementProfile; const AContext: TEhaiContextBinding; APayload: NativeInt = 0; ASource: TEhaiSource = esHuman): TEhaiInteractionAction; static;
  class function CreateRegenerate(const AProfile: TEhaiInvolvementProfile; const AContext: TEhaiContextBinding; APayload: NativeInt = 0; ASource: TEhaiSource = esHuman): TEhaiInteractionAction; overload; static;
  class function CreateRegenerate(const AContext: TEhaiContextBinding; APayload: NativeInt = 0; ASource: TEhaiSource = esHuman): TEhaiInteractionAction; overload; static; deprecated 'Use overload with explicit AProfile parameter';
  class function CreateOverride(AOverrideKind: TEhaiOverrideKind; const AText: string; const AProfile: TEhaiInvolvementProfile; const AContext: TEhaiContextBinding; APayload: NativeInt = 0; ASource: TEhaiSource = esHuman): TEhaiInteractionAction; overload; static;
  class function CreateOverride(AOverrideKind: TEhaiOverrideKind; const AText: string; const AContext: TEhaiContextBinding; APayload: NativeInt = 0; ASource: TEhaiSource = esHuman): TEhaiInteractionAction; overload; static; deprecated 'Use overload with explicit AProfile parameter';
  class function CreateExit(const AProfile: TEhaiInvolvementProfile; const AContext: TEhaiContextBinding; APayload: NativeInt = 0; ASource: TEhaiSource = esHuman): TEhaiInteractionAction; overload; static;
  class function CreateExit(const AContext: TEhaiContextBinding; APayload: NativeInt = 0; ASource: TEhaiSource = esHuman): TEhaiInteractionAction; overload; static; deprecated 'Use overload with explicit AProfile parameter';
end;
```

#### `TEhaiTraceRecord`
```pascal
TEhaiTraceRecord = record
  // 字段 (Fields)
  TraceId: string;
  Source: TEhaiSource;
  ActorIdentity: string;
  Action: TEhaiInteractionAction;
  SemanticEffect: TEhaiSemanticEffectKind;
  IsCommitted: Boolean;
  RecordedAt: TDateTime;
  // 方法与工厂签名 (Methods & Factory Signatures)
  class function Create(const ATraceId, AActor: string; const AAction: TEhaiInteractionAction; AEffect: TEhaiSemanticEffectKind; AIsCommitted: Boolean): TEhaiTraceRecord; static;
end;
```

### 3. 接口类型 (Interfaces - 共 3 个)

#### `IEhaiContextBound`
```pascal
IEhaiContextBound = interface
  ['{8A3F1B2C-9E4D-4F5A-8B6C-7D8E9F0A1B2C}']
  function GetContextBinding: TEhaiContextBinding;
end;
```

#### `IEhaiSourceTraceable`
```pascal
IEhaiSourceTraceable = interface
  ['{9B4E2C3D-0F5E-4A6B-9C7D-8E9F0A1B2C3D}']
  function GetSource: TEhaiSource;
  function GetActorIdentity: string;
end;
```

#### `IEhaiInteractionContract`
```pascal
IEhaiInteractionContract = interface
  ['{AC5F3D4E-1A6F-4B7C-AD8E-9F0A1B2C3D4E}']
  function ProcessAction(const AAction: TEhaiInteractionAction; out ATrace: TEhaiTraceRecord): Boolean;
  function ValidateCommitment(const AAction: TEhaiInteractionAction; const AAuthority: TEhaiAuthorityBasis): Boolean;
end;
```

### 5. 顶层工具函数 (Utility Functions - 共 6 个)
```pascal
function EhaiKeyToMetaAction(AKey: Integer): TEhaiMetaAction;
function EhaiMetaActionToKey(AAction: TEhaiMetaAction): Integer;
function EhaiOverrideKindToStr(AKind: TEhaiOverrideKind): string;
function EhaiProfileToStr(AProfile: TEhaiInvolvementProfile): string;
function EhaiSourceToStr(ASource: TEhaiSource): string;
function EhaiCheckContextDrift(const AInitialBinding, ACurrentBinding: TEhaiContextBinding): Boolean;
```

---

## Unit: `DeepBase.HB.Choice.Types`
- **源路径**：`Core/DeepBase.HB.Choice.Types.pas`

### 1. 枚举类型 (Enumerations - 共 6 个)

#### `THbChoiceKind`
```pascal
THbChoiceKind = (
  ckOption,
  ckRegenerate,
  ckInput,
  ckBack
);
```

#### `THbChoiceActionKind`
```pascal
THbChoiceActionKind = (
  cakCandidate,
  cakRegenerate,
  cakFreeInput,
  cakBack
);
```

#### `THbChoiceInputSource`
```pascal
THbChoiceInputSource = (
  cisMouse,
  cisKeyboard,
  cisNumPad,
  cisVoice,
  cisAccessibility,
  cisProgrammatic
);
```

#### `THbChoiceLayoutMode`
```pascal
THbChoiceLayoutMode = (
  clmDeck,
  clmRow,
  clmNumberedList,
  clmInline
);
```

#### `THbChoiceState`
```pascal
THbChoiceState = (
  csReady,
  csChoosing,
  csRegenerating,
  csFreeInput,
  csLoading,
  csNoReliableCandidates,
  csDisabled,
  csError
);
```

#### `THbChoiceFreeInputMode`
```pascal
THbChoiceFreeInputMode = (
  fimBuiltIn,
  fimExternal
);
```

### 2. 结构体类型 (Records - 共 2 个)

#### `THbChoiceItem`
```pascal
THbChoiceItem = record
  // 字段 (Fields)
  Key: Integer;
  Text: string;
  Description: string;
  Kind: THbChoiceKind;
  IsRecommended: Boolean;
  Enabled: Boolean;
  Tag: NativeInt;
  Payload: NativeInt;
  IsSelected: Boolean;
  OverrideKind: TEhaiOverrideKind;
  Source: TEhaiSource;
  // 方法与工厂签名 (Methods & Factory Signatures)
  class function Create(AKey: Integer; const AText: string; const ADesc: string = ''; AIsRecommended: Boolean = False; AEnabled: Boolean = True; APayload: NativeInt = 0; AIsSelected: Boolean = False; AOverrideKind: TEhaiOverrideKind = eokNone; ASource: TEhaiSource = esHuman): THbChoiceItem; static;
end;
```

#### `THbChoiceAction`
```pascal
THbChoiceAction = record
  // 字段 (Fields)
  Kind: THbChoiceActionKind;
  Key: Integer;
  SelectedKeys: TArray<Integer>;
  Text: string;
  Payload: NativeInt;
  InputSource: THbChoiceInputSource;
  OverrideKind: TEhaiOverrideKind;
  Source: TEhaiSource;
  Profile: TEhaiInvolvementProfile;
  ContextId: string;
  // 方法与工厂签名 (Methods & Factory Signatures)
  class function Create(AKind: THbChoiceActionKind; AKey: Integer; const AText: string; APayload: NativeInt; ASource: THbChoiceInputSource): THbChoiceAction; overload; static;
  class function Create(AKind: THbChoiceActionKind; AKey: Integer; const AText: string; APayload: NativeInt; ASource: THbChoiceInputSource; AOverrideKind: TEhaiOverrideKind; ASemanticSource: TEhaiSource = esHuman; AProfile: TEhaiInvolvementProfile = eipJudge; const AContextId: string = ''): THbChoiceAction; overload; static;
  class function CreateMulti(const ASelectedKeys: array of Integer; APayload: NativeInt; ASource: THbChoiceInputSource; AProfile: TEhaiInvolvementProfile = eipJudge; const AContextId: string = ''): THbChoiceAction; static;
end;
```

### 5. 顶层工具函数 (Utility Functions - 共 4 个)
```pascal
function GetDefaultChoiceKind(AKey: Integer): THbChoiceKind;
function ChoiceKindToActionKind(AKind: THbChoiceKind): THbChoiceActionKind;
function ActionKindToChoiceKind(AKind: THbChoiceActionKind): THbChoiceKind;
function GetDefaultKeyLabel(AKey: Integer): string;
```

---
