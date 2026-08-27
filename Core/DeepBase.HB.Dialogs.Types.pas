{ ============================================================================
  DeepBase.HB.Dialogs.Types - Cross-Framework Types for HB Dialogs & Wizards

  Version: 1.0 (Delphi 13.1 on Win64 / Cross-Platform RTL)
  Description: Shared type definitions for THbDialog, THbSummaryBar,
               THbWaterfallWizard (Vertical & Horizontal Accordion).
  ============================================================================ }

unit DeepBase.HB.Dialogs.Types;

interface

uses
  System.SysUtils,
  System.Classes,
  System.UITypes,
  DeepBase.HB.Core;

type
  /// <summary>
  /// Semantic kind of modern dialog.
  /// </summary>
  THbDialogKind = (
    dkInfo,          // Information notice
    dkSuccess,       // Operation successful
    dkWarning,       // Non-blocking warning
    dkDanger,        // High-risk interception (P0 Fail-Closed)
    dkConfirm,       // General binary confirmation
    dkPrompt,        // Single-line text input
    dkPromptReason   // Multi-line justification / reject reason input
  );

  /// <summary>
  /// Dialog result action.
  /// </summary>
  THbDialogResult = (
    drNone,
    drOk,            // Confirm / Allow
    drCancel,        // Cancel / Reject / Dismiss
    drOnce,          // Allow once / Temporary override
    drDefer,         // Stash / Defer to queue
    drCustom         // Custom extension action
  );

  /// <summary>
  /// THbDialogOptions: Detailed configuration structure for THbDialog.
  /// </summary>
  THbDialogOptions = record
    Kind: THbDialogKind;
    Title: string;
    Subtitle: string;
    Summary: string;
    BoundaryNotice: string;
    PromptLabel: string;
    DefaultInput: string;
    IsInputMultiline: Boolean;
    ShowEvidenceFold: Boolean;
    EvidenceText: string;
    OkCaption: string;
    CancelCaption: string;
    OnceCaption: string;
    DeferCaption: string;
    IsDestructive: Boolean;
  end;

  /// <summary>
  /// Layout orientation for waterfall accordion wizard.
  /// </summary>
  THbWaterfallOrientation = (
    woVertical,      // Vertical stacked list (standard waterfall)
    woHorizontal     // Horizontal strip accordion (expanding columns)
  );

  /// <summary>
  /// Lifecycle state of a wizard step.
  /// </summary>
  THbStepState = (
    ssPending,       // Waiting for upstream prerequisites
    ssActive,        // Currently active and expanded
    ssCompleted,     // Finished and validated with summary
    ssError          // Validation failed
  );

  /// <summary>
  /// Data snapshot for a single step in a wizard.
  /// </summary>
  THbStepItem = record
    Index: Integer;
    StepKey: string;
    Title: string;
    SummaryText: string;
    State: THbStepState;
    IsExpanded: Boolean;
    ConfigPath: string;
    DataJson: string;
  end;

implementation

end.
