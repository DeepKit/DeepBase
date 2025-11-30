{ ============================================================================
  UniBase.VCL.I18nControls - I18n-aware VCL Controls
  
  Version: 0.3
  Description: VCL controls that automatically translate via UniBase.i18n.
               Controls auto-subscribe to language change notifications.
  ============================================================================ }

unit UniBase.VCL.I18nControls;

interface

uses
  System.SysUtils,
  System.Classes,
  Vcl.StdCtrls,
  Vcl.Controls,
  UniBase.Manager,
  UniBase.i18n;

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
  if UniBase.Manager.UniBase.IsInitialized and 
     Assigned(UniBase.Manager.UniBase.I18n) then
  begin
    UniBase.Manager.UniBase.I18n.SubscribeLanguageChange(HandleLanguageChanged);
    FSubscribed := True;
  end;
end;

procedure TI18nLabel.UnsubscribeFromLanguageChange;
begin
  if not FSubscribed then
    Exit;
  if UniBase.Manager.UniBase.IsInitialized and 
     Assigned(UniBase.Manager.UniBase.I18n) then
  begin
    UniBase.Manager.UniBase.I18n.UnsubscribeLanguageChange(HandleLanguageChanged);
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
  if (FTextKey <> '') and UniBase.Manager.UniBase.IsInitialized then
  begin
    Caption := UniBase.Manager.UniBase.I18n.Translate(FTextKey);
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
  if UniBase.Manager.UniBase.IsInitialized and 
     Assigned(UniBase.Manager.UniBase.I18n) then
  begin
    UniBase.Manager.UniBase.I18n.SubscribeLanguageChange(HandleLanguageChanged);
    FSubscribed := True;
  end;
end;

procedure TI18nButton.UnsubscribeFromLanguageChange;
begin
  if not FSubscribed then
    Exit;
  if UniBase.Manager.UniBase.IsInitialized and 
     Assigned(UniBase.Manager.UniBase.I18n) then
  begin
    UniBase.Manager.UniBase.I18n.UnsubscribeLanguageChange(HandleLanguageChanged);
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
  if (FTextKey <> '') and UniBase.Manager.UniBase.IsInitialized then
  begin
    Caption := UniBase.Manager.UniBase.I18n.Translate(FTextKey);
  end;
end;

procedure TI18nButton.HandleLanguageChanged(Sender: TObject);
begin
  UpdateCaption;
end;

end.
