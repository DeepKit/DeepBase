{ ============================================================================
  DeepBase.VCL.DeepShell.Types

  Plain records / enums / helpers used by the DeepShell desktop frame.
  No VCL or DeepBase dependency beyond RTL primitives.
  See docs/72.vcl.DeepShell-核心接口与服务契约.md
  ============================================================================ }

unit DeepBase.VCL.DeepShell.Types;

interface

uses
  System.SysUtils,
  System.Classes;

type
  // ---------------------------------------------------------------------------
  // Stable references and context
  // ---------------------------------------------------------------------------

  /// <summary>
  /// Stable reference to a domain object. Shell never holds business TObject.
  /// Providers materialise the real object from (ProviderId, Id).
  /// </summary>
  TShellObjectRef = record
    Id: string;
    Kind: string;
    ProviderId: string;
    DisplayName: string;
    class function Empty: TShellObjectRef; static;
    function IsEmpty: Boolean;
    class function Make(const AId, AKind, AProviderId, ADisplayName: string): TShellObjectRef; static;
  end;

  TShellContext = record
    ProjectId: string;
    ProjectPath: string;
    ObjectRef: TShellObjectRef;
    ViewId: string;
    ViewType: string;
    Revision: Int64;
    class function Empty: TShellContext; static;
  end;

  // ---------------------------------------------------------------------------
  // Commands
  // ---------------------------------------------------------------------------

  /// <summary>
  /// Risk levels for commands. Aligned with governance L0..L3.
  /// </summary>
  TShellRiskLevel = type Integer;

const
  rlReadOnly  = 0; // L0
  rlLow       = 1; // L1
  rlMedium    = 2; // L2 - evidence required
  rlHigh      = 3; // L3 - gate + accountability

type
  /// <summary>
  /// Command descriptor. Stored by value inside CommandManager;
  /// runtime state changes must go through UpdateCommandState.
  /// </summary>
  TShellCommand = record
    Id: string;
    Caption: string;
    Hint: string;
    Category: string;
    ShortcutText: string;
    Visible: Boolean;
    Enabled: Boolean;
    Checked: Boolean;
    CapabilityId: string;
    GateKey: string;
    RiskLevel: TShellRiskLevel;
    PurposeKey: string;
    RequiresEvidence: Boolean;
    /// <summary>
    /// Optional handler. Stored alongside the record by CommandManager.
    /// Captured by the fluent ShellCommand builder.
    /// </summary>
    Handler: TProc;
    class function Make(const AId, ACaption: string): TShellCommand; static;
  end;

  // ---------------------------------------------------------------------------
  // Layout / panel state
  // ---------------------------------------------------------------------------

  TShellPanelState = record
    PanelId: string;
    Visible: Boolean;
    Collapsed: Boolean;
    Size: Integer;
    LastExpandedSize: Integer;
    ActiveTabId: string;
    class function Make(const APanelId: string): TShellPanelState; static;
  end;

  TShellToolWindowState = record
    WindowId: string;
    Visible: Boolean;
    Pinned: Boolean;
    Locked: Boolean;
    Left: Integer;
    Top: Integer;
    Width: Integer;
    Height: Integer;
    ActiveTabId: string;
    class function Make(const AWindowId: string): TShellToolWindowState; static;
  end;

  TShellLayoutState = record
    LayoutKey: string;
    UpdatedAt: TDateTime;
    WriterInstanceId: string;
    MainLeft: Integer;
    MainTop: Integer;
    MainWidth: Integer;
    MainHeight: Integer;
    Maximized: Boolean;
    TopPanel: TShellPanelState;
    MiddlePanel: TShellPanelState;
    BottomPanel: TShellPanelState;
    LeftToolWindow: TShellToolWindowState;
    RightToolWindow: TShellToolWindowState;
    CurrentViewId: string;
    CurrentTabId: string;
    class function Empty: TShellLayoutState; static;
  end;

  // ---------------------------------------------------------------------------
  // Recent / MRU
  // ---------------------------------------------------------------------------

  TShellRecentKind = (rkProject, rkFile, rkView, rkCommand);

  TShellRecentItem = record
    Kind: TShellRecentKind;
    ItemKey: string;
    ProjectId: string;
    Path: string;
    DisplayName: string;
    LayoutKey: string;
    LastOpenedAt: TDateTime;
    Invalid: Boolean;
  end;

  // ---------------------------------------------------------------------------
  // Views (main host)
  // ---------------------------------------------------------------------------

  TShellViewKind = (
    svkControl,
    svkFrame,
    svkHtml,
    svkMarkdown,
    svkText,
    svkExternal
  );

  TShellViewInfo = record
    ViewId: string;
    ViewKind: TShellViewKind;
    Title: string;
    Content: string;
    class function Make(const AViewId: string; AKind: TShellViewKind;
      const ATitle, AContent: string): TShellViewInfo; static;
  end;

  // ---------------------------------------------------------------------------
  // Inspector data
  // ---------------------------------------------------------------------------

  TShellProperty = record
    Name: string;
    Value: string;
    Group: string;
    ReadOnly: Boolean;
  end;

  TShellRelation = record
    Name: string;
    TargetRef: TShellObjectRef;
    Kind: string;
  end;

  TShellIssueSeverity = (sisInfo, sisWarning, sisError);

  TShellIssue = record
    Id: string;
    Severity: TShellIssueSeverity;
    Summary: string;
    Detail: string;
    SourceRef: TShellObjectRef;
  end;

  // ---------------------------------------------------------------------------
  // Status / diagnostics
  // ---------------------------------------------------------------------------

  TShellStatusKind = (sskInfo, sskWarning, sskError, sskProgress, sskDiagnostic);

  TShellStatusEntry = record
    Kind: TShellStatusKind;
    Source: string;
    MessageText: string;
    Detail: string;
    PercentComplete: Integer;
    TaskId: string;
    Timestamp: TDateTime;
  end;

  // ---------------------------------------------------------------------------
  // Governance result (extension; doc only sketches Boolean+Message)
  // ---------------------------------------------------------------------------

  TShellGateOutcome = (sgoAllowed, sgoDeniedSoft, sgoDeniedHard);

  TShellGateResult = record
    Outcome: TShellGateOutcome;
    ReasonCode: string;
    MessageText: string;
    Detail: string;
    class function AllowedDefault: TShellGateResult; static;
    class function Deny(AOutcome: TShellGateOutcome;
      const AReasonCode, AMessage: string): TShellGateResult; static;
    function Allowed: Boolean;
  end;

implementation

{ TShellObjectRef }

class function TShellObjectRef.Empty: TShellObjectRef;
begin
  Result := Default(TShellObjectRef);
end;

function TShellObjectRef.IsEmpty: Boolean;
begin
  Result := (Id = '') and (Kind = '') and (ProviderId = '');
end;

class function TShellObjectRef.Make(const AId, AKind, AProviderId,
  ADisplayName: string): TShellObjectRef;
begin
  Result.Id := AId;
  Result.Kind := AKind;
  Result.ProviderId := AProviderId;
  Result.DisplayName := ADisplayName;
end;

{ TShellContext }

class function TShellContext.Empty: TShellContext;
begin
  Result := Default(TShellContext);
  Result.ObjectRef := TShellObjectRef.Empty;
end;

{ TShellCommand }

class function TShellCommand.Make(const AId, ACaption: string): TShellCommand;
begin
  Result := Default(TShellCommand);
  Result.Id := AId;
  Result.Caption := ACaption;
  Result.Visible := True;
  Result.Enabled := True;
  Result.Checked := False;
  Result.RiskLevel := rlReadOnly;
end;

{ TShellPanelState }

class function TShellPanelState.Make(const APanelId: string): TShellPanelState;
begin
  Result := Default(TShellPanelState);
  Result.PanelId := APanelId;
  Result.Visible := True;
  Result.Collapsed := False;
  Result.Size := 0;
  Result.LastExpandedSize := 0;
end;

{ TShellToolWindowState }

class function TShellToolWindowState.Make(const AWindowId: string): TShellToolWindowState;
begin
  Result := Default(TShellToolWindowState);
  Result.WindowId := AWindowId;
end;

{ TShellLayoutState }

class function TShellLayoutState.Empty: TShellLayoutState;
begin
  Result := Default(TShellLayoutState);
  Result.TopPanel := TShellPanelState.Make('top');
  Result.MiddlePanel := TShellPanelState.Make('middle');
  Result.BottomPanel := TShellPanelState.Make('bottom');
  Result.LeftToolWindow := TShellToolWindowState.Make('structure');
  Result.RightToolWindow := TShellToolWindowState.Make('inspector');
end;

{ TShellViewInfo }

class function TShellViewInfo.Make(const AViewId: string; AKind: TShellViewKind;
  const ATitle, AContent: string): TShellViewInfo;
begin
  Result := Default(TShellViewInfo);
  Result.ViewId := AViewId;
  Result.ViewKind := AKind;
  Result.Title := ATitle;
  Result.Content := AContent;
end;

{ TShellGateResult }

class function TShellGateResult.AllowedDefault: TShellGateResult;
begin
  Result := Default(TShellGateResult);
  Result.Outcome := sgoAllowed;
end;

class function TShellGateResult.Deny(AOutcome: TShellGateOutcome;
  const AReasonCode, AMessage: string): TShellGateResult;
begin
  Result := Default(TShellGateResult);
  Result.Outcome := AOutcome;
  Result.ReasonCode := AReasonCode;
  Result.MessageText := AMessage;
end;

function TShellGateResult.Allowed: Boolean;
begin
  Result := Outcome = sgoAllowed;
end;

end.
