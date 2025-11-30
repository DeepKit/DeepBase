{ ============================================================================
  DataBindingDemo - Main Form
  
  Demonstrates UniBase.DataBinding functionality:
  - Observable objects with property change notification
  - One-way binding (source -> target)
  - Two-way binding (source <-> target)
  - Value converters
  - Observable collections
  ============================================================================ }

unit MainForm;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Variants,
  System.Classes,
  System.Rtti,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.ComCtrls,
  UniBase.DataBinding,
  UniBase.VCL.BindableControls;

type
  // Observable model class
  TPersonModel = class(TObservableObject)
  private
    FFirstName: string;
    FLastName: string;
    FAge: Integer;
    FActive: Boolean;
    FEmail: string;
    procedure SetFirstName(const Value: string);
    procedure SetLastName(const Value: string);
    procedure SetAge(const Value: Integer);
    procedure SetActive(const Value: Boolean);
    procedure SetEmail(const Value: string);
    function GetFullName: string;
  public
    property FirstName: string read FFirstName write SetFirstName;
    property LastName: string read FLastName write SetLastName;
    property FullName: string read GetFullName;
    property Age: Integer read FAge write SetAge;
    property Active: Boolean read FActive write SetActive;
    property Email: string read FEmail write SetEmail;
  end;
  
  // Value converter: Integer to String
  TIntToStringConverter = class(TInterfacedObject, IValueConverter)
  public
    function Convert(const Value: TValue): TValue;
    function ConvertBack(const Value: TValue): TValue;
  end;
  
  // Value converter: Boolean to String ("Yes"/"No")
  TBoolToYesNoConverter = class(TInterfacedObject, IValueConverter)
  public
    function Convert(const Value: TValue): TValue;
    function ConvertBack(const Value: TValue): TValue;
  end;

  TfrmMain = class(TForm)
    pnlTop: TPanel;
    grpModel: TGroupBox;
    lblFirstName: TLabel;
    lblLastName: TLabel;
    lblAge: TLabel;
    lblEmail: TLabel;
    edtFirstName: TEdit;
    edtLastName: TEdit;
    edtAge: TEdit;
    edtEmail: TEdit;
    chkActive: TCheckBox;
    grpBindings: TGroupBox;
    lblBoundFirstName: TLabel;
    lblBoundLastName: TLabel;
    lblBoundFullName: TLabel;
    lblBoundAge: TLabel;
    lblBoundActive: TLabel;
    edtBoundFirstName: TEdit;
    edtBoundLastName: TEdit;
    edtBoundFullName: TEdit;
    edtBoundAge: TEdit;
    edtBoundActive: TEdit;
    chkBoundActive: TCheckBox;
    pnlStatus: TPanel;
    lblModelStatus: TLabel;
    btnUpdateModel: TButton;
    btnResetModel: TButton;
    mmoLog: TMemo;
    grpInfo: TGroupBox;
    lblInfoTitle: TLabel;
    mmoInfo: TMemo;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnUpdateModelClick(Sender: TObject);
    procedure btnResetModelClick(Sender: TObject);
    procedure edtFirstNameChange(Sender: TObject);
    procedure edtLastNameChange(Sender: TObject);
    procedure edtAgeChange(Sender: TObject);
    procedure edtEmailChange(Sender: TObject);
    procedure chkActiveClick(Sender: TObject);
    procedure edtBoundFirstNameChange(Sender: TObject);
    procedure edtBoundLastNameChange(Sender: TObject);
    procedure chkBoundActiveClick(Sender: TObject);
  private
    FPerson: TPersonModel;
    FBindings: TBindingManager;
    
    procedure SetupBindings;
    procedure Log(const Msg: string);
    procedure OnPropertyChanged(const Args: TPropertyChangedEventArgs);
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.dfm}

{ TPersonModel }

procedure TPersonModel.SetFirstName(const Value: string);
begin
  SetField<string>(FFirstName, Value, 'FirstName');
  NotifyPropertyChanged('FullName'); // FullName depends on FirstName
end;

procedure TPersonModel.SetLastName(const Value: string);
begin
  SetField<string>(FLastName, Value, 'LastName');
  NotifyPropertyChanged('FullName'); // FullName depends on LastName
end;

procedure TPersonModel.SetAge(const Value: Integer);
begin
  SetField<Integer>(FAge, Value, 'Age');
end;

procedure TPersonModel.SetActive(const Value: Boolean);
begin
  SetField<Boolean>(FActive, Value, 'Active');
end;

procedure TPersonModel.SetEmail(const Value: string);
begin
  SetField<string>(FEmail, Value, 'Email');
end;

function TPersonModel.GetFullName: string;
begin
  Result := Trim(FFirstName + ' ' + FLastName);
end;

{ TIntToStringConverter }

function TIntToStringConverter.Convert(const Value: TValue): TValue;
begin
  if Value.IsType<Integer> then
    Result := TValue.From<string>(IntToStr(Value.AsInteger))
  else
    Result := Value;
end;

function TIntToStringConverter.ConvertBack(const Value: TValue): TValue;
var
  S: string;
  I: Integer;
begin
  if Value.IsType<string> then
  begin
    S := Value.AsString;
    if TryStrToInt(S, I) then
      Result := TValue.From<Integer>(I)
    else
      Result := TValue.From<Integer>(0);
  end
  else
    Result := Value;
end;

{ TBoolToYesNoConverter }

function TBoolToYesNoConverter.Convert(const Value: TValue): TValue;
begin
  if Value.IsType<Boolean> then
  begin
    if Value.AsBoolean then
      Result := TValue.From<string>('Yes')
    else
      Result := TValue.From<string>('No');
  end
  else
    Result := Value;
end;

function TBoolToYesNoConverter.ConvertBack(const Value: TValue): TValue;
begin
  if Value.IsType<string> then
    Result := TValue.From<Boolean>(SameText(Value.AsString, 'Yes'))
  else
    Result := Value;
end;

{ TfrmMain }

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  // Create model
  FPerson := TPersonModel.Create;
  FPerson.FirstName := 'John';
  FPerson.LastName := 'Doe';
  FPerson.Age := 30;
  FPerson.Email := 'john.doe@example.com';
  FPerson.Active := True;
  
  // Listen to property changes for logging
  FPerson.AddPropertyChangedHandler(OnPropertyChanged);
  
  // Create binding manager
  FBindings := TBindingManager.Create;
  
  // Setup bindings
  SetupBindings;
  
  // Initialize UI from model
  edtFirstName.Text := FPerson.FirstName;
  edtLastName.Text := FPerson.LastName;
  edtAge.Text := IntToStr(FPerson.Age);
  edtEmail.Text := FPerson.Email;
  chkActive.Checked := FPerson.Active;
  
  // Info text
  mmoInfo.Lines.Clear;
  mmoInfo.Lines.Add('This demo shows data binding between a Model and UI:');
  mmoInfo.Lines.Add('');
  mmoInfo.Lines.Add('Left panel: Direct model manipulation');
  mmoInfo.Lines.Add('- Changes update the model, which triggers bindings');
  mmoInfo.Lines.Add('');
  mmoInfo.Lines.Add('Right panel: Bound controls');
  mmoInfo.Lines.Add('- One-way: FullName, Age (read-only from model)');
  mmoInfo.Lines.Add('- Two-way: FirstName, LastName, Active');
  mmoInfo.Lines.Add('');
  mmoInfo.Lines.Add('Try editing in either panel to see sync!');
  
  Log('DataBinding Demo initialized');
  Log(Format('Model: %s, Age: %d, Active: %s', 
    [FPerson.FullName, FPerson.Age, BoolToStr(FPerson.Active, True)]));
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  FBindings.Free;
  FPerson.Free;
end;

procedure TfrmMain.SetupBindings;
var
  IntToStr: IValueConverter;
  BoolToYesNo: IValueConverter;
begin
  IntToStr := TIntToStringConverter.Create;
  BoolToYesNo := TBoolToYesNoConverter.Create;
  
  // Two-way bindings (model <-> UI)
  FBindings.Bind(FPerson, 'FirstName', edtBoundFirstName, 'Text', bmTwoWay);
  FBindings.Bind(FPerson, 'LastName', edtBoundLastName, 'Text', bmTwoWay);
  FBindings.Bind(FPerson, 'Active', chkBoundActive, 'Checked', bmTwoWay);
  
  // One-way bindings (model -> UI only)
  FBindings.Bind(FPerson, 'FullName', edtBoundFullName, 'Text', bmOneWay);
  FBindings.Bind(FPerson, 'Age', edtBoundAge, 'Text', bmOneWay, IntToStr);
  FBindings.Bind(FPerson, 'Active', edtBoundActive, 'Text', bmOneWay, BoolToYesNo);
  
  Log(Format('Created %d bindings', [FBindings.BindingCount]));
end;

procedure TfrmMain.Log(const Msg: string);
begin
  mmoLog.Lines.Add(Format('[%s] %s', [FormatDateTime('hh:nn:ss', Now), Msg]));
end;

procedure TfrmMain.OnPropertyChanged(const Args: TPropertyChangedEventArgs);
begin
  Log(Format('Property changed: %s', [Args.PropertyName]));
  lblModelStatus.Caption := Format('Model: %s | Age: %d | Active: %s', 
    [FPerson.FullName, FPerson.Age, BoolToStr(FPerson.Active, True)]);
end;

procedure TfrmMain.edtFirstNameChange(Sender: TObject);
begin
  FPerson.FirstName := edtFirstName.Text;
end;

procedure TfrmMain.edtLastNameChange(Sender: TObject);
begin
  FPerson.LastName := edtLastName.Text;
end;

procedure TfrmMain.edtAgeChange(Sender: TObject);
var
  Age: Integer;
begin
  if TryStrToInt(edtAge.Text, Age) then
    FPerson.Age := Age;
end;

procedure TfrmMain.edtEmailChange(Sender: TObject);
begin
  FPerson.Email := edtEmail.Text;
end;

procedure TfrmMain.chkActiveClick(Sender: TObject);
begin
  FPerson.Active := chkActive.Checked;
end;

procedure TfrmMain.edtBoundFirstNameChange(Sender: TObject);
begin
  // Two-way binding: notify that target changed
  FBindings.NotifyTargetChanged(edtBoundFirstName, 'Text');
end;

procedure TfrmMain.edtBoundLastNameChange(Sender: TObject);
begin
  FBindings.NotifyTargetChanged(edtBoundLastName, 'Text');
end;

procedure TfrmMain.chkBoundActiveClick(Sender: TObject);
begin
  FBindings.NotifyTargetChanged(chkBoundActive, 'Checked');
end;

procedure TfrmMain.btnUpdateModelClick(Sender: TObject);
begin
  // Programmatically update model - bindings will sync UI
  FPerson.FirstName := 'Jane';
  FPerson.LastName := 'Smith';
  FPerson.Age := 25;
  FPerson.Active := not FPerson.Active;
  
  // Update direct controls too
  edtFirstName.Text := FPerson.FirstName;
  edtLastName.Text := FPerson.LastName;
  edtAge.Text := IntToStr(FPerson.Age);
  chkActive.Checked := FPerson.Active;
  
  Log('Model updated programmatically');
end;

procedure TfrmMain.btnResetModelClick(Sender: TObject);
begin
  FPerson.FirstName := 'John';
  FPerson.LastName := 'Doe';
  FPerson.Age := 30;
  FPerson.Email := 'john.doe@example.com';
  FPerson.Active := True;
  
  edtFirstName.Text := FPerson.FirstName;
  edtLastName.Text := FPerson.LastName;
  edtAge.Text := IntToStr(FPerson.Age);
  edtEmail.Text := FPerson.Email;
  chkActive.Checked := FPerson.Active;
  
  Log('Model reset to defaults');
end;

end.
