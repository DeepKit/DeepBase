{ ============================================================================
  DeepBase.VCL.BindableControls - VCL Bindable Controls
  
  Version: 0.3
  Description: VCL controls with built-in data binding support.
               Each control automatically notifies BindingManager on changes.
  
  Usage:
    EditName := TBindableEdit.Create(Self);
    EditName.Parent := Self;
    EditName.BindingManager := FBindings;
    FBindings.Bind(FUser, 'Name', EditName, 'Text', bmTwoWay);
  ============================================================================ }

unit DeepBase.VCL.BindableControls;

interface

uses
  System.SysUtils,
  System.Classes,
  Vcl.Controls,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.ComCtrls,
  DeepBase.DataBinding;

type
  /// <summary>
  /// Edit control with data binding support
  /// </summary>
  TBindableEdit = class(TEdit)
  private
    FBindingManager: TBindingManager;
    procedure SetBindingManager(const Value: TBindingManager);
  protected
    procedure Change; override;
  public
    property BindingManager: TBindingManager read FBindingManager write SetBindingManager;
  end;
  
  /// <summary>
  /// Memo control with data binding support
  /// </summary>
  TBindableMemo = class(TMemo)
  private
    FBindingManager: TBindingManager;
    procedure SetBindingManager(const Value: TBindingManager);
  protected
    procedure Change; override;
  public
    property BindingManager: TBindingManager read FBindingManager write SetBindingManager;
  end;
  
  /// <summary>
  /// CheckBox control with data binding support
  /// </summary>
  TBindableCheckBox = class(TCheckBox)
  private
    FBindingManager: TBindingManager;
    procedure SetBindingManager(const Value: TBindingManager);
  protected
    procedure Click; override;
  public
    property BindingManager: TBindingManager read FBindingManager write SetBindingManager;
  end;
  
  /// <summary>
  /// ComboBox control with data binding support
  /// </summary>
  TBindableComboBox = class(TComboBox)
  private
    FBindingManager: TBindingManager;
    procedure SetBindingManager(const Value: TBindingManager);
  protected
    procedure Change; override;
    procedure Select; override;
  public
    property BindingManager: TBindingManager read FBindingManager write SetBindingManager;
  end;
  
  /// <summary>
  /// Label control with data binding support (one-way target only)
  /// </summary>
  TBindableLabel = class(TLabel)
  private
    FBindingManager: TBindingManager;
  public
    property BindingManager: TBindingManager read FBindingManager write FBindingManager;
  end;
  
  /// <summary>
  /// SpinEdit-like control with data binding support
  /// </summary>
  TBindableSpinEdit = class(TCustomPanel)
  private
    FEdit: TEdit;
    FUpButton: TButton;
    FDownButton: TButton;
    FMinValue: Integer;
    FMaxValue: Integer;
    FValue: Integer;
    FIncrement: Integer;
    FBindingManager: TBindingManager;
    
    procedure SetValue(const AValue: Integer);
    procedure EditChange(Sender: TObject);
    procedure UpClick(Sender: TObject);
    procedure DownClick(Sender: TObject);
    procedure SetBindingManager(const AValue: TBindingManager);
  protected
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    
    property Value: Integer read FValue write SetValue;
    property MinValue: Integer read FMinValue write FMinValue;
    property MaxValue: Integer read FMaxValue write FMaxValue;
    property Increment: Integer read FIncrement write FIncrement;
    property BindingManager: TBindingManager read FBindingManager write SetBindingManager;
  end;
  
  /// <summary>
  /// TrackBar control with data binding support
  /// </summary>
  TBindableTrackBar = class(TTrackBar)
  private
    FBindingManager: TBindingManager;
    procedure SetBindingManager(const Value: TBindingManager);
  protected
    procedure Changed; override;
  public
    property BindingManager: TBindingManager read FBindingManager write SetBindingManager;
  end;
  
  /// <summary>
  /// RadioButton control with data binding support
  /// </summary>
  TBindableRadioButton = class(TRadioButton)
  private
    FBindingManager: TBindingManager;
    procedure SetBindingManager(const Value: TBindingManager);
  protected
    procedure SetChecked(Value: Boolean); override;
  public
    property BindingManager: TBindingManager read FBindingManager write SetBindingManager;
  end;
  
  /// <summary>
  /// DateTimePicker control with data binding support
  /// </summary>
  TBindableDateTimePicker = class(TDateTimePicker)
  private
    FBindingManager: TBindingManager;
    procedure SetBindingManager(const Value: TBindingManager);
  protected
    procedure Change; override;
  public
    property BindingManager: TBindingManager read FBindingManager write SetBindingManager;
  end;

implementation

{ TBindableEdit }

procedure TBindableEdit.SetBindingManager(const Value: TBindingManager);
begin
  FBindingManager := Value;
end;

procedure TBindableEdit.Change;
begin
  inherited;
  if Assigned(FBindingManager) then
    FBindingManager.NotifyTargetChanged(Self, 'Text');
end;

{ TBindableMemo }

procedure TBindableMemo.SetBindingManager(const Value: TBindingManager);
begin
  FBindingManager := Value;
end;

procedure TBindableMemo.Change;
begin
  inherited;
  if Assigned(FBindingManager) then
    FBindingManager.NotifyTargetChanged(Self, 'Text');
end;

{ TBindableCheckBox }

procedure TBindableCheckBox.SetBindingManager(const Value: TBindingManager);
begin
  FBindingManager := Value;
end;

procedure TBindableCheckBox.Click;
begin
  inherited;
  if Assigned(FBindingManager) then
    FBindingManager.NotifyTargetChanged(Self, 'Checked');
end;

{ TBindableComboBox }

procedure TBindableComboBox.SetBindingManager(const Value: TBindingManager);
begin
  FBindingManager := Value;
end;

procedure TBindableComboBox.Change;
begin
  inherited;
  if Assigned(FBindingManager) then
  begin
    FBindingManager.NotifyTargetChanged(Self, 'Text');
    FBindingManager.NotifyTargetChanged(Self, 'ItemIndex');
  end;
end;

procedure TBindableComboBox.Select;
begin
  inherited;
  if Assigned(FBindingManager) then
  begin
    FBindingManager.NotifyTargetChanged(Self, 'Text');
    FBindingManager.NotifyTargetChanged(Self, 'ItemIndex');
  end;
end;

{ TBindableSpinEdit }

constructor TBindableSpinEdit.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  
  BevelOuter := bvNone;
  Width := 100;
  Height := 25;
  
  FMinValue := 0;
  FMaxValue := 100;
  FValue := 0;
  FIncrement := 1;
  
  FEdit := TEdit.Create(Self);
  FEdit.Parent := Self;
  FEdit.Align := alClient;
  FEdit.Text := '0';
  FEdit.OnChange := EditChange;
  
  FUpButton := TButton.Create(Self);
  FUpButton.Parent := Self;
  FUpButton.Width := 20;
  FUpButton.Align := alRight;
  FUpButton.Caption := '+';
  FUpButton.OnClick := UpClick;
  
  FDownButton := TButton.Create(Self);
  FDownButton.Parent := Self;
  FDownButton.Width := 20;
  FDownButton.Align := alRight;
  FDownButton.Caption := '-';
  FDownButton.OnClick := DownClick;
end;

procedure TBindableSpinEdit.Resize;
begin
  inherited;
end;

procedure TBindableSpinEdit.SetValue(const AValue: Integer);
var
  NewValue: Integer;
begin
  NewValue := AValue;
  if NewValue < FMinValue then NewValue := FMinValue;
  if NewValue > FMaxValue then NewValue := FMaxValue;
  
  if FValue <> NewValue then
  begin
    FValue := NewValue;
    FEdit.Text := IntToStr(FValue);
    
    if Assigned(FBindingManager) then
      FBindingManager.NotifyTargetChanged(Self, 'Value');
  end;
end;

procedure TBindableSpinEdit.SetBindingManager(const AValue: TBindingManager);
begin
  FBindingManager := AValue;
end;

procedure TBindableSpinEdit.EditChange(Sender: TObject);
var
  NewValue: Integer;
begin
  if TryStrToInt(FEdit.Text, NewValue) then
    SetValue(NewValue);
end;

procedure TBindableSpinEdit.UpClick(Sender: TObject);
begin
  SetValue(FValue + FIncrement);
end;

procedure TBindableSpinEdit.DownClick(Sender: TObject);
begin
  SetValue(FValue - FIncrement);
end;

{ TBindableTrackBar }

procedure TBindableTrackBar.SetBindingManager(const Value: TBindingManager);
begin
  FBindingManager := Value;
end;

procedure TBindableTrackBar.Changed;
begin
  inherited;
  if Assigned(FBindingManager) then
    FBindingManager.NotifyTargetChanged(Self, 'Position');
end;

{ TBindableRadioButton }

procedure TBindableRadioButton.SetBindingManager(const Value: TBindingManager);
begin
  FBindingManager := Value;
end;

procedure TBindableRadioButton.SetChecked(Value: Boolean);
begin
  inherited;
  if Assigned(FBindingManager) then
    FBindingManager.NotifyTargetChanged(Self, 'Checked');
end;

{ TBindableDateTimePicker }

procedure TBindableDateTimePicker.SetBindingManager(const Value: TBindingManager);
begin
  FBindingManager := Value;
end;

procedure TBindableDateTimePicker.Change;
begin
  inherited;
  if Assigned(FBindingManager) then
  begin
    FBindingManager.NotifyTargetChanged(Self, 'Date');
    FBindingManager.NotifyTargetChanged(Self, 'Time');
    FBindingManager.NotifyTargetChanged(Self, 'DateTime');
  end;
end;

end.
