{ ============================================================================
  UniBase.VCL.UnlockDialog - Lightweight Unlock Dialog
  
  Version: 0.1
  Description:
    VCL dialog for entering and applying lightweight unlock codes managed by
    TUniBaseUnlock. Intended for simple "follow / share" flows where the user
    scans a QR code, receives an unlock code, and pastes it into the dialog.

    This dialog is code-only (no .dfm) to keep integration simple for tools
    and templates. Host applications can call:

      if TUnlockDialog.Execute('TK', QRPath) then
        // Unlock succeeded

  ============================================================================ }

unit UniBase.VCL.UnlockDialog;

interface

uses
  System.SysUtils,
  System.Classes,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.ExtCtrls,
  Vcl.StdCtrls,
  Vcl.Graphics,
  Vcl.Buttons,
  Vcl.Clipbrd,
  Vcl.Imaging.pngimage,
  UniBase.Unlock;

type
  /// <summary>
  /// Unlock dialog form.
  /// </summary>
  TUnlockDialog = class(TForm)
  private
    // Layout panels
    FHeaderPanel: TPanel;
    FContentPanel: TPanel;
    FButtonsPanel: TPanel;

    // Header controls
    FLblTitle: TLabel;
    FLblSubtitle: TLabel;

    // Content controls
    FImgQRCode: TImage;
    FLblQRCodeHint: TLabel;
    FLblCode: TLabel;
    FEdtCode: TEdit;
    FBtnPaste: TButton;
    FLblStatus: TLabel;

    // Buttons
    FBtnUnlock: TButton;
    FBtnCancel: TButton;

    // State
    FUnlock: TUniBaseUnlock;
    FOwnsUnlock: Boolean;
    FProductCode: string;
    FQRCodePath: string;
    FLastInfo: TUnlockInfo;

    procedure CreateControls;
    procedure LayoutControls;

    procedure HandleUnlockClick(Sender: TObject);
    procedure HandleCancelClick(Sender: TObject);
    procedure HandlePasteClick(Sender: TObject);
    procedure HandleCodeChange(Sender: TObject);

    procedure LoadQRCodeIfNeeded;
    procedure UpdateStatus(const Msg: string; IsError: Boolean);
  protected
    procedure DoShow; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    /// <summary>Result of last ApplyCode call (valid even if Execute returns False).</summary>
    property LastInfo: TUnlockInfo read FLastInfo;

    /// <summary>
    /// Show unlock dialog.
    ///
    /// @param ProductCode  Product code prefix (e.g. 'TK' for TwoKeyRun).
    /// @param QRCodePath   Optional path to QR code image; if empty the image is hidden.
    /// @param Unlock       Optional shared TUniBaseUnlock instance; if nil a temporary
    ///                     instance bound to ProductCode is created and freed internally.
    ///
    /// Returns True if unlock succeeded (code valid and applied, level stored).
    /// </summary>
    class function Execute(const ProductCode: string; const QRCodePath: string = '';
      Unlock: TUniBaseUnlock = nil): Boolean;
  end;

implementation

{ TUnlockDialog }

constructor TUnlockDialog.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);

  Caption := 'Unlock Features';
  Width := 520;
  Height := 380;
  Position := poMainFormCenter;
  BorderStyle := bsDialog;

  FUnlock := nil;
  FOwnsUnlock := False;
  FProductCode := '';
  FQRCodePath := '';
  FillChar(FLastInfo, SizeOf(FLastInfo), 0);

  CreateControls;
  LayoutControls;
end;

destructor TUnlockDialog.Destroy;
begin
  if FOwnsUnlock and Assigned(FUnlock) then
    FreeAndNil(FUnlock);
  inherited;
end;

procedure TUnlockDialog.CreateControls;
begin
  // Header panel
  FHeaderPanel := TPanel.Create(Self);
  FHeaderPanel.Parent := Self;
  FHeaderPanel.Align := alTop;
  FHeaderPanel.Height := 64;
  FHeaderPanel.BevelOuter := bvNone;
  FHeaderPanel.Color := clWhite;
  FHeaderPanel.ParentBackground := False;

  FLblTitle := TLabel.Create(Self);
  FLblTitle.Parent := FHeaderPanel;
  FLblTitle.Caption := 'Unlock Advanced Features';
  FLblTitle.Font.Size := 14;
  FLblTitle.Font.Style := [fsBold];

  FLblSubtitle := TLabel.Create(Self);
  FLblSubtitle.Parent := FHeaderPanel;
  FLblSubtitle.Caption :=
    '1. Scan the QR code to follow.' + sLineBreak +
    '2. Get the unlock code and paste it below.';
  FLblSubtitle.Font.Color := clGray;

  // Content panel
  FContentPanel := TPanel.Create(Self);
  FContentPanel.Parent := Self;
  FContentPanel.Align := alClient;
  FContentPanel.BevelOuter := bvNone;

  FImgQRCode := TImage.Create(Self);
  FImgQRCode.Parent := FContentPanel;
  FImgQRCode.Stretch := True;
  FImgQRCode.Proportional := True;
  FImgQRCode.Center := True;

  FLblQRCodeHint := TLabel.Create(Self);
  FLblQRCodeHint.Parent := FContentPanel;
  FLblQRCodeHint.Caption := 'Scan this QR code to follow the official account.';

  FLblCode := TLabel.Create(Self);
  FLblCode.Parent := FContentPanel;
  FLblCode.Caption := 'Unlock Code:';

  FEdtCode := TEdit.Create(Self);
  FEdtCode.Parent := FContentPanel;
  FEdtCode.OnChange := HandleCodeChange;

  FBtnPaste := TButton.Create(Self);
  FBtnPaste.Parent := FContentPanel;
  FBtnPaste.Caption := 'Paste';
  FBtnPaste.OnClick := HandlePasteClick;

  FLblStatus := TLabel.Create(Self);
  FLblStatus.Parent := FContentPanel;
  FLblStatus.Caption := '';
  FLblStatus.Font.Color := clGray;
  FLblStatus.WordWrap := True;

  // Buttons panel
  FButtonsPanel := TPanel.Create(Self);
  FButtonsPanel.Parent := Self;
  FButtonsPanel.Align := alBottom;
  FButtonsPanel.Height := 52;
  FButtonsPanel.BevelOuter := bvNone;

  FBtnUnlock := TButton.Create(Self);
  FBtnUnlock.Parent := FButtonsPanel;
  FBtnUnlock.Caption := 'Unlock';
  FBtnUnlock.Default := True;
  FBtnUnlock.Enabled := False;
  FBtnUnlock.OnClick := HandleUnlockClick;

  FBtnCancel := TButton.Create(Self);
  FBtnCancel.Parent := FButtonsPanel;
  FBtnCancel.Caption := 'Cancel';
  FBtnCancel.Cancel := True;
  FBtnCancel.OnClick := HandleCancelClick;
end;

procedure TUnlockDialog.LayoutControls;
begin
  // Header
  FLblTitle.SetBounds(16, 10, 360, 24);
  FLblSubtitle.SetBounds(16, 32, ClientWidth - 32, 32);

  // Content: QR on left, code on right
  FImgQRCode.SetBounds(16, 16, 160, 160);
  FLblQRCodeHint.SetBounds(16, 180, 200, 32);

  FLblCode.SetBounds(200, 24, 100, 16);
  FEdtCode.SetBounds(200, 42, ClientWidth - 260, 24);
  FBtnPaste.SetBounds(ClientWidth - 76, 42, 60, 24);

  FLblStatus.SetBounds(200, 80, ClientWidth - 216, 60);

  // Buttons
  FBtnCancel.SetBounds(ClientWidth - 92, 12, 80, 28);
  FBtnUnlock.SetBounds(ClientWidth - 184, 12, 80, 28);
end;

procedure TUnlockDialog.DoShow;
begin
  inherited;
  LoadQRCodeIfNeeded;
  FEdtCode.SetFocus;
end;

procedure TUnlockDialog.HandleCodeChange(Sender: TObject);
begin
  FBtnUnlock.Enabled := Trim(FEdtCode.Text) <> '';
  FLblStatus.Caption := '';
end;

procedure TUnlockDialog.HandlePasteClick(Sender: TObject);
begin
  if Clipboard.AsText <> '' then
  begin
    FEdtCode.Text := Clipboard.AsText;
    HandleCodeChange(nil);
  end;
end;

procedure TUnlockDialog.HandleUnlockClick(Sender: TObject);
var
  Code: string;
begin
  if not Assigned(FUnlock) then
  begin
    UpdateStatus('Internal error: unlock manager not assigned.', True);
    Exit;
  end;

  Code := Trim(FEdtCode.Text);
  if Code = '' then
  begin
    UpdateStatus('Please enter an unlock code.', True);
    Exit;
  end;

  UpdateStatus('Validating unlock code...', False);
  Application.ProcessMessages;

  if FUnlock.ApplyCode(Code, FLastInfo) then
  begin
    UpdateStatus('Unlock successful. Thank you for your support!', False);
    FLblStatus.Font.Color := clGreen;
    ModalResult := mrOk;
  end
  else
  begin
    case FLastInfo.Status of
      uvsEmptyCode:
        UpdateStatus('Code is empty.', True);
      uvsInvalidFormat:
        UpdateStatus('Code format is invalid.', True);
      uvsProductMismatch:
        UpdateStatus('Code does not match this product.', True);
      uvsExpired:
        UpdateStatus('Code has expired. Please request a new code.', True);
      uvsInvalidChecksum:
        UpdateStatus('Code is incorrect. Please check and try again.', True);
    else
      UpdateStatus('Unlock failed.', True);
    end;
  end;
end;

procedure TUnlockDialog.HandleCancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

procedure TUnlockDialog.LoadQRCodeIfNeeded;
var
  PNG: TPngImage;
begin
  if (FQRCodePath = '') or (not FileExists(FQRCodePath)) then
  begin
    FImgQRCode.Visible := False;
    FLblQRCodeHint.Visible := False;
    Exit;
  end;

  FImgQRCode.Visible := True;
  FLblQRCodeHint.Visible := True;

  PNG := TPngImage.Create;
  try
    PNG.LoadFromFile(FQRCodePath);
    FImgQRCode.Picture.Assign(PNG);
  finally
    PNG.Free;
  end;
end;

procedure TUnlockDialog.UpdateStatus(const Msg: string; IsError: Boolean);
begin
  FLblStatus.Caption := Msg;
  if IsError then
    FLblStatus.Font.Color := clRed
  else
    FLblStatus.Font.Color := clGray;
end;

class function TUnlockDialog.Execute(const ProductCode: string; const QRCodePath: string;
  Unlock: TUniBaseUnlock): Boolean;
var
  Dlg: TUnlockDialog;
begin
  Result := False;
  Dlg := TUnlockDialog.Create(Application);
  try
    Dlg.FProductCode := ProductCode;
    Dlg.FQRCodePath := QRCodePath;

    if Assigned(Unlock) then
    begin
      Dlg.FUnlock := Unlock;
      Dlg.FOwnsUnlock := False;
    end
    else
    begin
      Dlg.FUnlock := TUniBaseUnlock.Create(ProductCode);
      Dlg.FOwnsUnlock := True;
    end;

    Result := Dlg.ShowModal = mrOk;
  finally
    Dlg.Free;
  end;
end;

end.
