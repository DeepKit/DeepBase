{ ============================================================================
  DeepBase.HB.Choice.Types - Unified 0-9 Choice Deck Contract Types

  Version: 1.0 (Delphi 13.1 on Win64 / Cross-Platform RTL)
  Description: Core contract types for THbChoiceDeck:
               - 1-7 Contextual option candidates (Key 1 can be Recommended)
               - 8 Fixed control: Regenerate
               - 9 Fixed control: Custom Input ("Myself", not "Other")
               - 0 Fixed control: Navigate Back (Navigation, not Rejection)
               - 4 Semantic color tokens binding
  ============================================================================ }

unit DeepBase.HB.Choice.Types;

{$WARN IMPLICIT_STRING_CAST OFF}

interface

uses
  System.SysUtils,
  System.Classes,
  DeepBase.HB.Core;

type
  /// <summary>
  /// Semantic classification for 0-9 choice options.
  /// </summary>
  THbChoiceKind = (
    ckOption,      // 1..7 Contextual option candidates
    ckRegenerate,  // 8 Global fixed: Regenerate / Redo
    ckInput,       // 9 Global fixed: Custom user input
    ckBack         // 0 Global fixed: Navigate back / Return
  );

  /// <summary>
  /// Single choice option item.
  /// </summary>
  THbChoiceItem = record
    Key: Integer;             // 0..9
    Text: string;             // Option title/summary
    Description: string;      // Optional secondary details
    Kind: THbChoiceKind;      // Option kind
    IsRecommended: Boolean;   // True for key 1 (Recommended, not "Best")
    Enabled: Boolean;
    Tag: NativeInt;
    class function Create(AKey: Integer; const AText: string;
      const ADesc: string = ''; AIsRecommended: Boolean = False;
      AEnabled: Boolean = True): THbChoiceItem; static;
  end;

  THbChoiceEvent = procedure(Sender: TObject; AKey: Integer) of object;
  THbChoiceInputEvent = procedure(Sender: TObject; const AInputText: string) of object;

function GetDefaultChoiceKind(AKey: Integer): THbChoiceKind;
function GetDefaultKeyLabel(AKey: Integer): string;

implementation

{ THbChoiceItem }

class function THbChoiceItem.Create(AKey: Integer; const AText, ADesc: string;
  AIsRecommended, AEnabled: Boolean): THbChoiceItem;
begin
  Result.Key := AKey;
  Result.Text := AText;
  Result.Description := ADesc;
  Result.Kind := GetDefaultChoiceKind(AKey);
  Result.IsRecommended := AIsRecommended;
  Result.Enabled := AEnabled;
  Result.Tag := 0;
end;

function GetDefaultChoiceKind(AKey: Integer): THbChoiceKind;
begin
  case AKey of
    8: Result := ckRegenerate;
    9: Result := ckInput;
    0: Result := ckBack;
  else
    Result := ckOption;
  end;
end;

function GetDefaultKeyLabel(AKey: Integer): string;
begin
  case AKey of
    8: Result := '重新生成';
    9: Result := '自己输入';
    0: Result := '返回';
  else
    Result := '';
  end;
end;

end.
