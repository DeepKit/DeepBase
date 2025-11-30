{ ============================================================================
  Studio.HelpPanel - Studio Tool Help Panel
  
  Version: 1.0
  Description: Provides help and usage instructions for each config page
  ============================================================================ }

unit Studio.HelpPanel;

interface

uses
  System.SysUtils,
  System.Classes,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.Graphics,
  Vcl.StdCtrls;

/// <summary>
/// Create a help label - displays help text at the top of each card
/// </summary>
function CreateHelpLabel(AParent: TWinControl; const AHelpText: string): TLabel;

/// <summary>
/// Get help text for configuration page
/// </summary>
function GetConfigurationHelp: string;

/// <summary>
/// Get help text for logs page
/// </summary>
function GetLogsHelp: string;

implementation

function CreateHelpLabel(AParent: TWinControl; const AHelpText: string): TLabel;
begin
  Result := TLabel.Create(AParent);
  Result.Parent := AParent;
  Result.Align := alTop;
  Result.Height := 60;
  Result.WordWrap := True;
  Result.Caption := AHelpText;
  Result.Font.Size := 9;
  Result.Font.Color := clNavy;
  Result.Layout := tlTop;
  Result.Alignment := taLeftJustify;
  Result.Margins.Left := 10;
  Result.Margins.Right := 10;
  Result.Margins.Top := 5;
  Result.Margins.Bottom := 5;
  Result.Transparent := False;
  Result.Color := $FFF0E0;  // Light orange background
  Result.ParentColor := False;
end;

function GetConfigurationHelp: string;
begin
  Result := 
    '[Configuration Settings] ' +
    'This page displays and manages application configuration settings stored in the database. ' +
    'Use "Refresh" to reload from database, "Add Key" to add new settings, ' +
    '"Delete" to remove selected settings.';
end;

function GetLogsHelp: string;
begin
  Result := 
    '[Application Logs] ' +
    'This page displays application runtime logs. ' +
    'Logs are captured from the application and stored for debugging and monitoring. ' +
    'Use "Refresh" to reload the latest logs.';
end;

end.
