{ ============================================================================
  DeepBase.HB.CommandPalette.Types - Core Types for Universal Command Palette
  
  Version: 1.0 (Delphi 13.1 on Win64 / Cross-Platform RTL)
  Description: Framework-agnostic type definitions and interfaces for universal
               Ctrl+K command palette, verb routing, and keyboard navigation.
  ============================================================================ }

unit DeepBase.HB.CommandPalette.Types;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  DeepBase.HB.Core;

type
  /// <summary>
  /// Single command item entry for universal command palette.
  /// </summary>
  THbCommandItem = record
    CommandID: string;        // Unique Command ID (e.g. 'cmd.deeprw.audit.gate_run')
    Caption: string;          // Action display text (e.g. '运行全量规则门禁体检')
    VerbGroup: string;        // Grouping category (e.g. '门禁体检', '证据管理', '导出分享')
    ShortcutText: string;     // Shortcut key hint (e.g. 'Ctrl+Shift+G')
    IconName: string;         // Icon identifier or emoji
    Enabled: Boolean;         // Whether item is clickable
    DisabledReason: string;   // Tooltip reason when disabled
    LastUsedAt: TDateTime;    // For MRU (Most Recently Used) ordering
    Payload: string;          // Optional custom parameter string
  end;

  /// <summary>
  /// Category group containing a list of command items.
  /// </summary>
  THbCommandGroup = record
    GroupName: string;
    Items: TArray<THbCommandItem>;
  end;

  /// <summary>
  /// Interface for host application to plug custom command providers.
  /// </summary>
  IHbCommandProvider = interface
    ['{E430B800-476C-4B9F-8409-F6A449CA8872}']
    function GetProviderName: string;
    function QueryCommands(const AKeyword: string): TArray<THbCommandItem>;
    procedure ExecuteCommand(const ACommandID: string; const APayload: string = '');
  end;

  /// <summary>
  /// Event callback when a command item is triggered.
  /// </summary>
  THbCommandExecuteEvent = procedure(Sender: TObject; const AItem: THbCommandItem) of object;

implementation

end.
