{ ============================================================================
  DeepBase.HB.Gate.Types - Core Types for Compiler-Style Gate Panel
  
  Version: 1.0 (Delphi 13.1 on Win64 / Cross-Platform RTL)
  Description: Framework-agnostic type definitions for quality/protocol gate checks,
               severity indicators, violation logs, and remedy actions.
  ============================================================================ }

unit DeepBase.HB.Gate.Types;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  DeepBase.HB.Core;

type
  /// <summary>
  /// Gate check rule severity levels.
  /// </summary>
  THbGateSeverity = (sePass, seNotice, seWarning, seError);

  /// <summary>
  /// Single row item representing a gate check result.
  /// </summary>
  THbGateRowItem = record
    RuleID: string;            // Rule identifier (e.g. 'R01', 'INV-12')
    Severity: THbGateSeverity;  // Pass, Notice, Warning, Error
    Title: string;             // One-line summary conclusion
    TargetText: string;        // Triggered target object summary / excerpt
    ReasonText: string;        // Detailed explanation of why rule triggered
    FixHint: string;           // Recommended remediation steps
    JumpRef: string;           // Navigation reference string (e.g. 'claim:c12#anchor3')
    ContextSnippet: string;    // Raw snippet or proof context
    IsExpanded: Boolean;       // Accordion expanded state in UI
    WaiverStatus: string;      // Optional exemption status string
  end;

  /// <summary>
  /// Statistical summary across all gate rules.
  /// </summary>
  THbGateSummaryStats = record
    TotalCount: Integer;
    PassCount: Integer;
    NoticeCount: Integer;
    WarningCount: Integer;
    ErrorCount: Integer;
    function IsAllPassed: Boolean;
    function HasBlockingErrors: Boolean;
  end;

  /// <summary>
  /// Event fired when a user clicks jump navigation link.
  /// </summary>
  THbGateJumpEvent = procedure(Sender: TObject; const AJumpRef: string) of object;

  /// <summary>
  /// Event fired when a user executes a remedy / waiver action on a rule.
  /// </summary>
  THbGateActionEvent = procedure(Sender: TObject; const ARuleID: string; const AActionKey: string) of object;

implementation

{ THbGateSummaryStats }

function THbGateSummaryStats.IsAllPassed: Boolean;
begin
  Result := (ErrorCount = 0) and (WarningCount = 0);
end;

function THbGateSummaryStats.HasBlockingErrors: Boolean;
begin
  Result := (ErrorCount > 0);
end;

end.
