{ ============================================================================
  UniBase.FMX.Dialogs - FMX Dialog Components
  
  Version: 1.0
  Description: FMX dialog components including message boxes, input dialogs,
               and update notifications.
  ============================================================================ }

unit UniBase.FMX.Dialogs;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Types,
  System.UITypes,
  FMX.Types,
  FMX.Forms,
  FMX.Controls,
  FMX.StdCtrls,
  FMX.Layouts,
  FMX.Objects,
  FMX.Edit,
  FMX.DialogService,
  UniBase.Types;

type
  /// <summary>
  /// FMX Message Dialog Type
  /// </summary>
  TFMXMessageType = (mtInfo, mtWarning, mtError, mtConfirm, mtQuestion);
  
  /// <summary>
  /// FMX Message Dialog Buttons
  /// </summary>
  TFMXDialogButtons = (dbOK, dbOKCancel, dbYesNo, dbYesNoCancel);
  
  /// <summary>
  /// FMX Dialog Result
  /// </summary>
  TFMXDialogResult = (drNone, drOK, drCancel, drYes, drNo);

/// <summary>
/// Show a message dialog (async, uses callback)
/// </summary>
procedure ShowFMXMessage(const AMessage: string; AType: TFMXMessageType = mtInfo;
  ACallback: TProc<TFMXDialogResult> = nil);

/// <summary>
/// Show a message dialog with custom title
/// </summary>
procedure ShowFMXMessageEx(const ATitle, AMessage: string; AType: TFMXMessageType;
  AButtons: TFMXDialogButtons; ACallback: TProc<TFMXDialogResult>);

/// <summary>
/// Show confirmation dialog (async)
/// </summary>
procedure ShowFMXConfirm(const AMessage: string; AOnYes: TProc; AOnNo: TProc = nil);

/// <summary>
/// Show input dialog (async)
/// </summary>
procedure ShowFMXInput(const ATitle, APrompt, ADefault: string; ACallback: TProc<string>);

/// <summary>
/// Convert TFMXMessageType to dialog service TMsgDlgType
/// </summary>
function FMXMessageTypeToMsgDlgType(AType: TFMXMessageType): TMsgDlgType;

/// <summary>
/// Convert TFMXDialogButtons to TMsgDlgButtons set
/// </summary>
function FMXDialogButtonsToMsgDlgButtons(AButtons: TFMXDialogButtons): TMsgDlgButtons;

implementation

function FMXMessageTypeToMsgDlgType(AType: TFMXMessageType): TMsgDlgType;
begin
  case AType of
    mtInfo: Result := TMsgDlgType.mtInformation;
    mtWarning: Result := TMsgDlgType.mtWarning;
    mtError: Result := TMsgDlgType.mtError;
    mtConfirm: Result := TMsgDlgType.mtConfirmation;
    mtQuestion: Result := TMsgDlgType.mtConfirmation;
  else
    Result := TMsgDlgType.mtInformation;
  end;
end;

function FMXDialogButtonsToMsgDlgButtons(AButtons: TFMXDialogButtons): TMsgDlgButtons;
begin
  case AButtons of
    dbOK: Result := [TMsgDlgBtn.mbOK];
    dbOKCancel: Result := [TMsgDlgBtn.mbOK, TMsgDlgBtn.mbCancel];
    dbYesNo: Result := [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo];
    dbYesNoCancel: Result := [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo, TMsgDlgBtn.mbCancel];
  else
    Result := [TMsgDlgBtn.mbOK];
  end;
end;

function ModalResultToFMXDialogResult(AModalResult: TModalResult): TFMXDialogResult;
begin
  case AModalResult of
    mrOk: Result := drOK;
    mrCancel: Result := drCancel;
    mrYes: Result := drYes;
    mrNo: Result := drNo;
  else
    Result := drNone;
  end;
end;

procedure ShowFMXMessage(const AMessage: string; AType: TFMXMessageType; ACallback: TProc<TFMXDialogResult>);
var
  Buttons: TMsgDlgButtons;
begin
  if AType = mtConfirm then
    Buttons := [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo]
  else
    Buttons := [TMsgDlgBtn.mbOK];
    
  TDialogService.MessageDialog(
    AMessage,
    FMXMessageTypeToMsgDlgType(AType),
    Buttons,
    TMsgDlgBtn.mbOK,
    0,
    procedure(const AResult: TModalResult)
    begin
      if Assigned(ACallback) then
        ACallback(ModalResultToFMXDialogResult(AResult));
    end
  );
end;

procedure ShowFMXMessageEx(const ATitle, AMessage: string; AType: TFMXMessageType;
  AButtons: TFMXDialogButtons; ACallback: TProc<TFMXDialogResult>);
var
  DefaultBtn: TMsgDlgBtn;
begin
  case AButtons of
    dbOK: DefaultBtn := TMsgDlgBtn.mbOK;
    dbOKCancel: DefaultBtn := TMsgDlgBtn.mbOK;
    dbYesNo: DefaultBtn := TMsgDlgBtn.mbYes;
    dbYesNoCancel: DefaultBtn := TMsgDlgBtn.mbYes;
  else
    DefaultBtn := TMsgDlgBtn.mbOK;
  end;
  
  TDialogService.MessageDialog(
    AMessage,
    FMXMessageTypeToMsgDlgType(AType),
    FMXDialogButtonsToMsgDlgButtons(AButtons),
    DefaultBtn,
    0,
    procedure(const AResult: TModalResult)
    begin
      if Assigned(ACallback) then
        ACallback(ModalResultToFMXDialogResult(AResult));
    end
  );
end;

procedure ShowFMXConfirm(const AMessage: string; AOnYes: TProc; AOnNo: TProc);
begin
  TDialogService.MessageDialog(
    AMessage,
    TMsgDlgType.mtConfirmation,
    [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo],
    TMsgDlgBtn.mbNo,
    0,
    procedure(const AResult: TModalResult)
    begin
      if AResult = mrYes then
      begin
        if Assigned(AOnYes) then
          AOnYes;
      end
      else
      begin
        if Assigned(AOnNo) then
          AOnNo;
      end;
    end
  );
end;

procedure ShowFMXInput(const ATitle, APrompt, ADefault: string; ACallback: TProc<string>);
begin
  TDialogService.InputQuery(
    ATitle,
    [APrompt],
    [ADefault],
    procedure(const AResult: TModalResult; const AValues: array of string)
    begin
      if (AResult = mrOk) and (Length(AValues) > 0) then
      begin
        if Assigned(ACallback) then
          ACallback(AValues[0]);
      end
      else
      begin
        if Assigned(ACallback) then
          ACallback('');
      end;
    end
  );
end;

end.
