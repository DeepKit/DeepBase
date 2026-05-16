{ ============================================================================
  DeepBase.SQL.Utils - SQL Safety Utilities

  Version: 1.0
  Description: Shared SQL identifier validation to prevent SQL injection
               in dynamic table/column name usage.
  ============================================================================ }

unit DeepBase.SQL.Utils;

interface

uses
  System.SysUtils;

type
  TSQLUtils = class
  public
    /// <summary>
    /// Returns True if AName is a valid SQL identifier:
    /// starts with letter or underscore, contains only [a-zA-Z0-9_],
    /// max 128 characters.
    /// </summary>
    class function IsValidIdentifier(const AName: string): Boolean; static;

    /// <summary>
    /// Raises EArgumentException if AName is not a valid SQL identifier.
    /// AContext is included in the error message for diagnostics.
    /// </summary>
    class procedure ValidateIdentifier(const AName, AContext: string); static;
  end;

implementation

uses
  System.Character;

class function TSQLUtils.IsValidIdentifier(const AName: string): Boolean;
begin
  if (AName = '') or (AName.Length > 128) then
    Exit(False);
  // First character must be letter or underscore
  if not (AName[1].IsLetter or (AName[1] = '_')) then
    Exit(False);
  // Remaining characters: letter, digit, or underscore
  for var I := 2 to AName.Length do
  begin
    if not (AName[I].IsLetterOrDigit or (AName[I] = '_')) then
      Exit(False);
  end;
  Result := True;
end;

class procedure TSQLUtils.ValidateIdentifier(const AName, AContext: string);
begin
  if not IsValidIdentifier(AName) then
    raise EArgumentException.CreateFmt(
      'Invalid SQL identifier in %s: "%s"', [AContext, AName]);
end;

end.
