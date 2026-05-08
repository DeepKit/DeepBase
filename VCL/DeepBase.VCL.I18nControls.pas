{ ============================================================================
  DeepBase.VCL.I18nControls - I18n-aware VCL Controls
  
  Version: 0.3
  Description: VCL controls that automatically translate via DeepBase.i18n.
               Controls auto-subscribe to language change notifications.
  ============================================================================ }

unit DeepBase.VCL.I18nControls;

interface

uses
  System.SysUtils,
  System.Classes,
  Vcl.StdCtrls,
  Vcl.Controls,
  Vcl.ComCtrls,
  Vcl.Buttons,
  Vcl.Menus,
  DeepBase.Manager,
  DeepBase.i18n;

type
  /// <summary>
  /// Auto-translating Label control.
  /// Automatically subscribes to language change notifications.
  /// </summary>
  TI18nLabel = class(TLabel)
  private
    FTextKey: string;
    FSubscribed: Boolean;
    procedure SetTextKey(const Value: string);
    procedure HandleLanguageChanged(Sender: TObject);
    procedure SubscribeToLanguageChange;
    procedure UnsubscribeFromLanguageChange;
  protected
    procedure Loaded; override;
    procedure UpdateCaption; virtual;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  published
    property TextKey: string read FTextKey write SetTextKey;
  end;

  /// <summary>
  /// Auto-translating Button control.
  /// Automatically subscribes to language change notifications.
  /// </summary>
  TI18nButton = class(TButton)
  private
    FTextKey: string;
    FSubscribed: Boolean;
    procedure SetTextKey(const Value: string);
    procedure HandleLanguageChanged(Sender: TObject);
    procedure SubscribeToLanguageChange;
    procedure UnsubscribeFromLanguageChange;
  protected
    procedure Loaded; override;
    procedure UpdateCaption; virtual;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  published
    property TextKey: string read FTextKey write SetTextKey;
  end;

  TI18nCheckBox = class(TCheckBox)
  private
    FTextKey: string;
    FSubscribed: Boolean;
    procedure SetTextKey(const Value: string);
    procedure HandleLanguageChanged(Sender: TObject);
    procedure SubscribeToLanguageChange;
    procedure UnsubscribeFromLanguageChange;
  protected
    procedure Loaded; override;
    procedure UpdateCaption; virtual;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  published
    property TextKey: string read FTextKey write SetTextKey;
  end;

  TI18nRadioButton = class(TRadioButton)
  private
    FTextKey: string;
    FSubscribed: Boolean;
    procedure SetTextKey(const Value: string);
    procedure HandleLanguageChanged(Sender: TObject);
    procedure SubscribeToLanguageChange;
    procedure UnsubscribeFromLanguageChange;
  protected
    procedure Loaded; override;
    procedure UpdateCaption; virtual;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  published
    property TextKey: string read FTextKey write SetTextKey;
  end;

  TI18nGroupBox = class(TGroupBox)
  private
    FTextKey: string;
    FSubscribed: Boolean;
    procedure SetTextKey(const Value: string);
    procedure HandleLanguageChanged(Sender: TObject);
    procedure SubscribeToLanguageChange;
    procedure UnsubscribeFromLanguageChange;
  protected
    procedure Loaded; override;
    procedure UpdateCaption; virtual;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  published
    property TextKey: string read FTextKey write SetTextKey;
  end;

  TI18nTabSheet = class(TTabSheet)
  private
    FTextKey: string;
    FSubscribed: Boolean;
    procedure SetTextKey(const Value: string);
    procedure HandleLanguageChanged(Sender: TObject);
    procedure SubscribeToLanguageChange;
    procedure UnsubscribeFromLanguageChange;
  protected
    procedure Loaded; override;
    procedure UpdateCaption; virtual;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  published
    property TextKey: string read FTextKey write SetTextKey;
  end;

  TI18nBitBtn = class(TBitBtn)
  private
    FTextKey: string;
    FSubscribed: Boolean;
    procedure SetTextKey(const Value: string);
    procedure HandleLanguageChanged(Sender: TObject);
    procedure SubscribeToLanguageChange;
    procedure UnsubscribeFromLanguageChange;
  protected
    procedure Loaded; override;
    procedure UpdateCaption; virtual;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  published
    property TextKey: string read FTextKey write SetTextKey;
  end;

  TI18nMenuItem = class(TMenuItem)
  private
    FTextKey: string;
    FSubscribed: Boolean;
    procedure SetTextKey(const Value: string);
    procedure HandleLanguageChanged(Sender: TObject);
    procedure SubscribeToLanguageChange;
    procedure UnsubscribeFromLanguageChange;
  protected
    procedure Loaded; override;
    procedure UpdateCaption; virtual;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  published
    property TextKey: string read FTextKey write SetTextKey;
  end;

implementation

{ TI18nLabel }

constructor TI18nLabel.Create(AOwner: TComponent);
begin
  inherited;
  FSubscribed := False;
end;

destructor TI18nLabel.Destroy;
begin
  UnsubscribeFromLanguageChange;
  inherited;
end;

procedure TI18nLabel.SubscribeToLanguageChange;
begin
  if FSubscribed then
    Exit;
  if (csDesigning in ComponentState) then
    Exit;
  if DeepBase.Manager.DeepBase.IsInitialized and 
     Assigned(DeepBase.Manager.DeepBase.I18n) then
  begin
    DeepBase.Manager.DeepBase.I18n.SubscribeLanguageChange(HandleLanguageChanged);
    FSubscribed := True;
  end;
end;

procedure TI18nLabel.UnsubscribeFromLanguageChange;
begin
  if not FSubscribed then
    Exit;
  if DeepBase.Manager.DeepBase.IsInitialized and 
     Assigned(DeepBase.Manager.DeepBase.I18n) then
  begin
    DeepBase.Manager.DeepBase.I18n.UnsubscribeLanguageChange(HandleLanguageChanged);
  end;
  FSubscribed := False;
end;

procedure TI18nLabel.SetTextKey(const Value: string);
begin
  FTextKey := Value;
  if not (csDesigning in ComponentState) then
    UpdateCaption;
end;

procedure TI18nLabel.Loaded;
begin
  inherited;
  if not (csDesigning in ComponentState) then
  begin
    SubscribeToLanguageChange;
    if FTextKey <> '' then
      UpdateCaption;
  end;
end;

procedure TI18nLabel.UpdateCaption;
begin
  if (FTextKey <> '') and DeepBase.Manager.DeepBase.IsInitialized then
  begin
    Caption := DeepBase.Manager.DeepBase.I18n.Translate(FTextKey);
  end;
end;

procedure TI18nLabel.HandleLanguageChanged(Sender: TObject);
begin
  UpdateCaption;
end;

{ TI18nButton }

constructor TI18nButton.Create(AOwner: TComponent);
begin
  inherited;
  FSubscribed := False;
end;

destructor TI18nButton.Destroy;
begin
  UnsubscribeFromLanguageChange;
  inherited;
end;

procedure TI18nButton.SubscribeToLanguageChange;
begin
  if FSubscribed then
    Exit;
  if (csDesigning in ComponentState) then
    Exit;
  if DeepBase.Manager.DeepBase.IsInitialized and 
     Assigned(DeepBase.Manager.DeepBase.I18n) then
  begin
    DeepBase.Manager.DeepBase.I18n.SubscribeLanguageChange(HandleLanguageChanged);
    FSubscribed := True;
  end;
end;

procedure TI18nButton.UnsubscribeFromLanguageChange;
begin
  if not FSubscribed then
    Exit;
  if DeepBase.Manager.DeepBase.IsInitialized and 
     Assigned(DeepBase.Manager.DeepBase.I18n) then
  begin
    DeepBase.Manager.DeepBase.I18n.UnsubscribeLanguageChange(HandleLanguageChanged);
  end;
  FSubscribed := False;
end;

procedure TI18nButton.SetTextKey(const Value: string);
begin
  FTextKey := Value;
  if not (csDesigning in ComponentState) then
    UpdateCaption;
end;

procedure TI18nButton.Loaded;
begin
  inherited;
  if not (csDesigning in ComponentState) then
  begin
    SubscribeToLanguageChange;
    if FTextKey <> '' then
      UpdateCaption;
  end;
end;

procedure TI18nButton.UpdateCaption;
begin
  if (FTextKey <> '') and DeepBase.Manager.DeepBase.IsInitialized then
  begin
    Caption := DeepBase.Manager.DeepBase.I18n.Translate(FTextKey);
  end;
end;

procedure TI18nButton.HandleLanguageChanged(Sender: TObject);
begin
  UpdateCaption;
end;

{ TI18nCheckBox }

constructor TI18nCheckBox.Create(AOwner: TComponent);
begin
  inherited;
  FSubscribed := False;
end;

destructor TI18nCheckBox.Destroy;
begin
  UnsubscribeFromLanguageChange;
  inherited;
end;

procedure TI18nCheckBox.SubscribeToLanguageChange;
begin
  if FSubscribed then Exit;
  if (csDesigning in ComponentState) then Exit;
  if DeepBase.Manager.DeepBase.IsInitialized and Assigned(DeepBase.Manager.DeepBase.I18n) then
  begin
    DeepBase.Manager.DeepBase.I18n.SubscribeLanguageChange(HandleLanguageChanged);
    FSubscribed := True;
  end;
end;

procedure TI18nCheckBox.UnsubscribeFromLanguageChange;
begin
  if not FSubscribed then Exit;
  if DeepBase.Manager.DeepBase.IsInitialized and Assigned(DeepBase.Manager.DeepBase.I18n) then
    DeepBase.Manager.DeepBase.I18n.UnsubscribeLanguageChange(HandleLanguageChanged);
  FSubscribed := False;
end;

procedure TI18nCheckBox.SetTextKey(const Value: string);
begin
  FTextKey := Value;
  if not (csDesigning in ComponentState) then UpdateCaption;
end;

procedure TI18nCheckBox.Loaded;
begin
  inherited;
  if not (csDesigning in ComponentState) then
  begin
    SubscribeToLanguageChange;
    if FTextKey <> '' then UpdateCaption;
  end;
end;

procedure TI18nCheckBox.UpdateCaption;
begin
  if (FTextKey <> '') and DeepBase.Manager.DeepBase.IsInitialized then
    Caption := DeepBase.Manager.DeepBase.I18n.Translate(FTextKey);
end;

procedure TI18nCheckBox.HandleLanguageChanged(Sender: TObject);
begin
  UpdateCaption;
end;

{ TI18nRadioButton }

constructor TI18nRadioButton.Create(AOwner: TComponent);
begin
  inherited;
  FSubscribed := False;
end;

destructor TI18nRadioButton.Destroy;
begin
  UnsubscribeFromLanguageChange;
  inherited;
end;

procedure TI18nRadioButton.SubscribeToLanguageChange;
begin
  if FSubscribed then Exit;
  if (csDesigning in ComponentState) then Exit;
  if DeepBase.Manager.DeepBase.IsInitialized and Assigned(DeepBase.Manager.DeepBase.I18n) then
  begin
    DeepBase.Manager.DeepBase.I18n.SubscribeLanguageChange(HandleLanguageChanged);
    FSubscribed := True;
  end;
end;

procedure TI18nRadioButton.UnsubscribeFromLanguageChange;
begin
  if not FSubscribed then Exit;
  if DeepBase.Manager.DeepBase.IsInitialized and Assigned(DeepBase.Manager.DeepBase.I18n) then
    DeepBase.Manager.DeepBase.I18n.UnsubscribeLanguageChange(HandleLanguageChanged);
  FSubscribed := False;
end;

procedure TI18nRadioButton.SetTextKey(const Value: string);
begin
  FTextKey := Value;
  if not (csDesigning in ComponentState) then UpdateCaption;
end;

procedure TI18nRadioButton.Loaded;
begin
  inherited;
  if not (csDesigning in ComponentState) then
  begin
    SubscribeToLanguageChange;
    if FTextKey <> '' then UpdateCaption;
  end;
end;

procedure TI18nRadioButton.UpdateCaption;
begin
  if (FTextKey <> '') and DeepBase.Manager.DeepBase.IsInitialized then
    Caption := DeepBase.Manager.DeepBase.I18n.Translate(FTextKey);
end;

procedure TI18nRadioButton.HandleLanguageChanged(Sender: TObject);
begin
  UpdateCaption;
end;

{ TI18nGroupBox }

constructor TI18nGroupBox.Create(AOwner: TComponent);
begin
  inherited;
  FSubscribed := False;
end;

destructor TI18nGroupBox.Destroy;
begin
  UnsubscribeFromLanguageChange;
  inherited;
end;

procedure TI18nGroupBox.SubscribeToLanguageChange;
begin
  if FSubscribed then Exit;
  if (csDesigning in ComponentState) then Exit;
  if DeepBase.Manager.DeepBase.IsInitialized and Assigned(DeepBase.Manager.DeepBase.I18n) then
  begin
    DeepBase.Manager.DeepBase.I18n.SubscribeLanguageChange(HandleLanguageChanged);
    FSubscribed := True;
  end;
end;

procedure TI18nGroupBox.UnsubscribeFromLanguageChange;
begin
  if not FSubscribed then Exit;
  if DeepBase.Manager.DeepBase.IsInitialized and Assigned(DeepBase.Manager.DeepBase.I18n) then
    DeepBase.Manager.DeepBase.I18n.UnsubscribeLanguageChange(HandleLanguageChanged);
  FSubscribed := False;
end;

procedure TI18nGroupBox.SetTextKey(const Value: string);
begin
  FTextKey := Value;
  if not (csDesigning in ComponentState) then UpdateCaption;
end;

procedure TI18nGroupBox.Loaded;
begin
  inherited;
  if not (csDesigning in ComponentState) then
  begin
    SubscribeToLanguageChange;
    if FTextKey <> '' then UpdateCaption;
  end;
end;

procedure TI18nGroupBox.UpdateCaption;
begin
  if (FTextKey <> '') and DeepBase.Manager.DeepBase.IsInitialized then
    Caption := DeepBase.Manager.DeepBase.I18n.Translate(FTextKey);
end;

procedure TI18nGroupBox.HandleLanguageChanged(Sender: TObject);
begin
  UpdateCaption;
end;

{ TI18nTabSheet }

constructor TI18nTabSheet.Create(AOwner: TComponent);
begin
  inherited;
  FSubscribed := False;
end;

destructor TI18nTabSheet.Destroy;
begin
  UnsubscribeFromLanguageChange;
  inherited;
end;

procedure TI18nTabSheet.SubscribeToLanguageChange;
begin
  if FSubscribed then Exit;
  if (csDesigning in ComponentState) then Exit;
  if DeepBase.Manager.DeepBase.IsInitialized and Assigned(DeepBase.Manager.DeepBase.I18n) then
  begin
    DeepBase.Manager.DeepBase.I18n.SubscribeLanguageChange(HandleLanguageChanged);
    FSubscribed := True;
  end;
end;

procedure TI18nTabSheet.UnsubscribeFromLanguageChange;
begin
  if not FSubscribed then Exit;
  if DeepBase.Manager.DeepBase.IsInitialized and Assigned(DeepBase.Manager.DeepBase.I18n) then
    DeepBase.Manager.DeepBase.I18n.UnsubscribeLanguageChange(HandleLanguageChanged);
  FSubscribed := False;
end;

procedure TI18nTabSheet.SetTextKey(const Value: string);
begin
  FTextKey := Value;
  if not (csDesigning in ComponentState) then UpdateCaption;
end;

procedure TI18nTabSheet.Loaded;
begin
  inherited;
  if not (csDesigning in ComponentState) then
  begin
    SubscribeToLanguageChange;
    if FTextKey <> '' then UpdateCaption;
  end;
end;

procedure TI18nTabSheet.UpdateCaption;
begin
  if (FTextKey <> '') and DeepBase.Manager.DeepBase.IsInitialized then
    Caption := DeepBase.Manager.DeepBase.I18n.Translate(FTextKey);
end;

procedure TI18nTabSheet.HandleLanguageChanged(Sender: TObject);
begin
  UpdateCaption;
end;

{ TI18nBitBtn }

constructor TI18nBitBtn.Create(AOwner: TComponent);
begin
  inherited;
  FSubscribed := False;
end;

destructor TI18nBitBtn.Destroy;
begin
  UnsubscribeFromLanguageChange;
  inherited;
end;

procedure TI18nBitBtn.SubscribeToLanguageChange;
begin
  if FSubscribed then Exit;
  if (csDesigning in ComponentState) then Exit;
  if DeepBase.Manager.DeepBase.IsInitialized and Assigned(DeepBase.Manager.DeepBase.I18n) then
  begin
    DeepBase.Manager.DeepBase.I18n.SubscribeLanguageChange(HandleLanguageChanged);
    FSubscribed := True;
  end;
end;

procedure TI18nBitBtn.UnsubscribeFromLanguageChange;
begin
  if not FSubscribed then Exit;
  if DeepBase.Manager.DeepBase.IsInitialized and Assigned(DeepBase.Manager.DeepBase.I18n) then
    DeepBase.Manager.DeepBase.I18n.UnsubscribeLanguageChange(HandleLanguageChanged);
  FSubscribed := False;
end;

procedure TI18nBitBtn.SetTextKey(const Value: string);
begin
  FTextKey := Value;
  if not (csDesigning in ComponentState) then UpdateCaption;
end;

procedure TI18nBitBtn.Loaded;
begin
  inherited;
  if not (csDesigning in ComponentState) then
  begin
    SubscribeToLanguageChange;
    if FTextKey <> '' then UpdateCaption;
  end;
end;

procedure TI18nBitBtn.UpdateCaption;
begin
  if (FTextKey <> '') and DeepBase.Manager.DeepBase.IsInitialized then
    Caption := DeepBase.Manager.DeepBase.I18n.Translate(FTextKey);
end;

procedure TI18nBitBtn.HandleLanguageChanged(Sender: TObject);
begin
  UpdateCaption;
end;

{ TI18nMenuItem }

constructor TI18nMenuItem.Create(AOwner: TComponent);
begin
  inherited;
  FSubscribed := False;
end;

destructor TI18nMenuItem.Destroy;
begin
  UnsubscribeFromLanguageChange;
  inherited;
end;

procedure TI18nMenuItem.SubscribeToLanguageChange;
begin
  if FSubscribed then Exit;
  if (csDesigning in ComponentState) then Exit;
  if DeepBase.Manager.DeepBase.IsInitialized and Assigned(DeepBase.Manager.DeepBase.I18n) then
  begin
    DeepBase.Manager.DeepBase.I18n.SubscribeLanguageChange(HandleLanguageChanged);
    FSubscribed := True;
  end;
end;

procedure TI18nMenuItem.UnsubscribeFromLanguageChange;
begin
  if not FSubscribed then Exit;
  if DeepBase.Manager.DeepBase.IsInitialized and Assigned(DeepBase.Manager.DeepBase.I18n) then
    DeepBase.Manager.DeepBase.I18n.UnsubscribeLanguageChange(HandleLanguageChanged);
  FSubscribed := False;
end;

procedure TI18nMenuItem.SetTextKey(const Value: string);
begin
  FTextKey := Value;
  if not (csDesigning in ComponentState) then UpdateCaption;
end;

procedure TI18nMenuItem.Loaded;
begin
  inherited;
  if not (csDesigning in ComponentState) then
  begin
    SubscribeToLanguageChange;
    if FTextKey <> '' then UpdateCaption;
  end;
end;

procedure TI18nMenuItem.UpdateCaption;
begin
  if (FTextKey <> '') and DeepBase.Manager.DeepBase.IsInitialized then
    Caption := DeepBase.Manager.DeepBase.I18n.Translate(FTextKey);
end;

procedure TI18nMenuItem.HandleLanguageChanged(Sender: TObject);
begin
  UpdateCaption;
end;

end.
