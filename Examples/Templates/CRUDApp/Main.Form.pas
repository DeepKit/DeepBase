unit Main.Form;

{*******************************************************************************
  CRUD Application Template - Main Form
  
  This is the main application window demonstrating:
  - Customer list display with grid
  - Search functionality
  - CRUD operations (Add, Edit, Delete)
  - Status bar with statistics
  
  DeepBase features demonstrated:
  - Configuration management
  - Logging
  - I18n (internationalization)
  - Theme support
*******************************************************************************}

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Variants,
  System.Classes,
  System.Generics.Collections,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.ComCtrls,
  Vcl.Grids,
  Vcl.Menus,
  Vcl.ActnList,
  Entity.Customer;

type
  TMainForm = class(TForm)
    PnlTop: TPanel;
    PnlBottom: TPanel;
    StatusBar: TStatusBar;
    EdtSearch: TEdit;
    BtnSearch: TButton;
    BtnAdd: TButton;
    BtnEdit: TButton;
    BtnDelete: TButton;
    BtnRefresh: TButton;
    GridCustomers: TStringGrid;
    LblSearch: TLabel;
    MainMenu: TMainMenu;
    MnuFile: TMenuItem;
    MnuFileExit: TMenuItem;
    MnuEdit: TMenuItem;
    MnuEditAdd: TMenuItem;
    MnuEditEdit: TMenuItem;
    MnuEditDelete: TMenuItem;
    N1: TMenuItem;
    MnuEditRefresh: TMenuItem;
    MnuHelp: TMenuItem;
    MnuHelpAbout: TMenuItem;
    ActionList: TActionList;
    ActAdd: TAction;
    ActEdit: TAction;
    ActDelete: TAction;
    ActRefresh: TAction;
    ActExit: TAction;
    CmbStatus: TComboBox;
    LblStatus: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure ActAddExecute(Sender: TObject);
    procedure ActEditExecute(Sender: TObject);
    procedure ActDeleteExecute(Sender: TObject);
    procedure ActRefreshExecute(Sender: TObject);
    procedure ActExitExecute(Sender: TObject);
    procedure GridCustomersSelectCell(Sender: TObject; ACol, ARow: Integer;
      var CanSelect: Boolean);
    procedure GridCustomersDblClick(Sender: TObject);
    procedure EdtSearchChange(Sender: TObject);
    procedure CmbStatusChange(Sender: TObject);
    procedure MnuHelpAboutClick(Sender: TObject);
  private
    FCustomers: TObjectList<TCustomer>;
    FSelectedRow: Integer;
    FSearchTimer: TTimer;
    
    procedure LoadCustomers;
    procedure DisplayCustomers;
    procedure UpdateStatusBar;
    procedure UpdateButtonStates;
    procedure SetupGrid;
    function GetSelectedCustomer: TCustomer;
    procedure OnSearchTimer(Sender: TObject);
    procedure SaveFormState;
    procedure LoadFormState;
  public
    property SelectedCustomer: TCustomer read GetSelectedCustomer;
  end;

var
  MainForm: TMainForm;

implementation

{$R *.dfm}

uses
  Data.Module,
  Form.CustomerEdit,
  DeepBase.Manager,
  DeepBase.Config,
  DeepBase.Logging;

const
  COL_ID = 0;
  COL_NAME = 1;
  COL_EMAIL = 2;
  COL_PHONE = 3;
  COL_CITY = 4;
  COL_STATUS = 5;
  
  STATUS_ALL = 0;
  STATUS_ACTIVE = 1;
  STATUS_INACTIVE = 2;
  STATUS_SUSPENDED = 3;

{ TMainForm }

procedure TMainForm.FormCreate(Sender: TObject);
begin
  FCustomers := TObjectList<TCustomer>.Create(False);  // Don't own - DataMod owns
  FSelectedRow := -1;
  
  // Setup search timer for delayed search
  FSearchTimer := TTimer.Create(Self);
  FSearchTimer.Interval := 300;  // 300ms delay
  FSearchTimer.Enabled := False;
  FSearchTimer.OnTimer := OnSearchTimer;
  
  // Setup status filter
  CmbStatus.Items.Clear;
  CmbStatus.Items.Add('All');
  CmbStatus.Items.Add('Active');
  CmbStatus.Items.Add('Inactive');
  CmbStatus.Items.Add('Suspended');
  CmbStatus.ItemIndex := STATUS_ALL;
  
  SetupGrid;
  LoadFormState;
  
  Log.Info('Main form created');
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  SaveFormState;
  FSearchTimer.Free;
  FCustomers.Free;
  Log.Info('Main form destroyed');
end;

procedure TMainForm.FormShow(Sender: TObject);
begin
  LoadCustomers;
end;

procedure TMainForm.SetupGrid;
begin
  GridCustomers.ColCount := 6;
  GridCustomers.RowCount := 2;
  GridCustomers.FixedRows := 1;
  GridCustomers.FixedCols := 0;
  GridCustomers.Options := GridCustomers.Options + [goRowSelect, goColSizing];
  GridCustomers.DefaultRowHeight := 22;
  
  // Set column headers
  GridCustomers.Cells[COL_ID, 0] := 'ID';
  GridCustomers.Cells[COL_NAME, 0] := 'Name';
  GridCustomers.Cells[COL_EMAIL, 0] := 'Email';
  GridCustomers.Cells[COL_PHONE, 0] := 'Phone';
  GridCustomers.Cells[COL_CITY, 0] := 'City';
  GridCustomers.Cells[COL_STATUS, 0] := 'Status';
  
  // Set column widths
  GridCustomers.ColWidths[COL_ID] := 0;  // Hidden
  GridCustomers.ColWidths[COL_NAME] := 180;
  GridCustomers.ColWidths[COL_EMAIL] := 200;
  GridCustomers.ColWidths[COL_PHONE] := 120;
  GridCustomers.ColWidths[COL_CITY] := 120;
  GridCustomers.ColWidths[COL_STATUS] := 80;
end;

procedure TMainForm.LoadCustomers;
var
  SearchText: string;
  StatusFilter: Integer;
  AllCustomers: TObjectList<TCustomer>;
  Customer: TCustomer;
begin
  FCustomers.Clear;
  SearchText := Trim(EdtSearch.Text);
  StatusFilter := CmbStatus.ItemIndex;
  
  try
    // Get customers based on search
    if SearchText <> '' then
      AllCustomers := DataMod.SearchCustomers(SearchText)
    else
      AllCustomers := DataMod.GetAllCustomers;
    
    try
      // Filter by status if needed
      for Customer in AllCustomers do
      begin
        case StatusFilter of
          STATUS_ALL:
            FCustomers.Add(Customer);
          STATUS_ACTIVE:
            if Customer.StatusEnum = csActive then
              FCustomers.Add(Customer);
          STATUS_INACTIVE:
            if Customer.StatusEnum = csInactive then
              FCustomers.Add(Customer);
          STATUS_SUSPENDED:
            if Customer.StatusEnum = csSuspended then
              FCustomers.Add(Customer);
        end;
      end;
    finally
      // Note: Customers are owned by AllCustomers, don't free them
      // We just reference them in FCustomers
    end;
  except
    on E: Exception do
    begin
      Log.Error('Failed to load customers: %s', [E.Message]);
      MessageDlg('Failed to load customers: ' + E.Message, mtError, [mbOK], 0);
    end;
  end;
  
  DisplayCustomers;
  UpdateStatusBar;
  UpdateButtonStates;
end;

procedure TMainForm.DisplayCustomers;
var
  I: Integer;
  Customer: TCustomer;
  StatusText: string;
begin
  if FCustomers.Count = 0 then
  begin
    GridCustomers.RowCount := 2;
    for I := 0 to GridCustomers.ColCount - 1 do
      GridCustomers.Cells[I, 1] := '';
    Exit;
  end;
  
  GridCustomers.RowCount := FCustomers.Count + 1;
  
  for I := 0 to FCustomers.Count - 1 do
  begin
    Customer := FCustomers[I];
    
    case Customer.StatusEnum of
      csActive: StatusText := 'Active';
      csInactive: StatusText := 'Inactive';
      csSuspended: StatusText := 'Suspended';
      csDeleted: StatusText := 'Deleted';
    else
      StatusText := 'Unknown';
    end;
    
    GridCustomers.Cells[COL_ID, I + 1] := Customer.Id;
    GridCustomers.Cells[COL_NAME, I + 1] := Customer.DisplayName;
    GridCustomers.Cells[COL_EMAIL, I + 1] := Customer.Email;
    GridCustomers.Cells[COL_PHONE, I + 1] := Customer.Phone;
    GridCustomers.Cells[COL_CITY, I + 1] := Customer.City;
    GridCustomers.Cells[COL_STATUS, I + 1] := StatusText;
  end;
  
  // Select first row if available
  if FCustomers.Count > 0 then
  begin
    GridCustomers.Row := 1;
    FSelectedRow := 1;
  end;
end;

procedure TMainForm.UpdateStatusBar;
var
  TotalCount, ActiveCount: Integer;
begin
  TotalCount := DataMod.GetCustomerCount;
  ActiveCount := DataMod.GetCustomerCountByStatus(csActive);
  
  StatusBar.Panels[0].Text := Format('Total: %d', [TotalCount]);
  StatusBar.Panels[1].Text := Format('Active: %d', [ActiveCount]);
  StatusBar.Panels[2].Text := Format('Showing: %d', [FCustomers.Count]);
end;

procedure TMainForm.UpdateButtonStates;
var
  HasSelection: Boolean;
begin
  HasSelection := (FSelectedRow > 0) and (FSelectedRow <= FCustomers.Count);
  
  BtnEdit.Enabled := HasSelection;
  BtnDelete.Enabled := HasSelection;
  ActEdit.Enabled := HasSelection;
  ActDelete.Enabled := HasSelection;
  MnuEditEdit.Enabled := HasSelection;
  MnuEditDelete.Enabled := HasSelection;
end;

function TMainForm.GetSelectedCustomer: TCustomer;
begin
  Result := nil;
  if (FSelectedRow > 0) and (FSelectedRow <= FCustomers.Count) then
    Result := FCustomers[FSelectedRow - 1];
end;

procedure TMainForm.GridCustomersSelectCell(Sender: TObject; ACol, ARow: Integer;
  var CanSelect: Boolean);
begin
  FSelectedRow := ARow;
  UpdateButtonStates;
end;

procedure TMainForm.GridCustomersDblClick(Sender: TObject);
begin
  if SelectedCustomer <> nil then
    ActEditExecute(nil);
end;

procedure TMainForm.EdtSearchChange(Sender: TObject);
begin
  // Reset and start timer for delayed search
  FSearchTimer.Enabled := False;
  FSearchTimer.Enabled := True;
end;

procedure TMainForm.OnSearchTimer(Sender: TObject);
begin
  FSearchTimer.Enabled := False;
  LoadCustomers;
end;

procedure TMainForm.CmbStatusChange(Sender: TObject);
begin
  LoadCustomers;
end;

procedure TMainForm.ActAddExecute(Sender: TObject);
var
  Customer: TCustomer;
  EditForm: TCustomerEditForm;
begin
  Customer := TCustomer.Create;
  try
    EditForm := TCustomerEditForm.Create(Self);
    try
      EditForm.Customer := Customer;
      EditForm.IsNewCustomer := True;
      
      if EditForm.ShowModal = mrOK then
      begin
        DataMod.SaveCustomer(Customer);
        LoadCustomers;
        Log.Info('Customer added: %s', [Customer.DisplayName]);
      end;
    finally
      EditForm.Free;
    end;
  finally
    if EditForm.ModalResult <> mrOK then
      Customer.Free;
  end;
end;

procedure TMainForm.ActEditExecute(Sender: TObject);
var
  Customer: TCustomer;
  EditForm: TCustomerEditForm;
begin
  if SelectedCustomer = nil then
    Exit;
    
  // Load fresh copy from database
  Customer := DataMod.GetCustomerById(SelectedCustomer.Id);
  if Customer = nil then
  begin
    MessageDlg('Customer not found. It may have been deleted.', mtWarning, [mbOK], 0);
    LoadCustomers;
    Exit;
  end;
  
  try
    EditForm := TCustomerEditForm.Create(Self);
    try
      EditForm.Customer := Customer;
      EditForm.IsNewCustomer := False;
      
      if EditForm.ShowModal = mrOK then
      begin
        DataMod.SaveCustomer(Customer);
        LoadCustomers;
        Log.Info('Customer edited: %s', [Customer.DisplayName]);
      end;
    finally
      EditForm.Free;
    end;
  finally
    Customer.Free;
  end;
end;

procedure TMainForm.ActDeleteExecute(Sender: TObject);
var
  Customer: TCustomer;
begin
  Customer := SelectedCustomer;
  if Customer = nil then
    Exit;
    
  if MessageDlg(
    Format('Are you sure you want to delete customer "%s"?', [Customer.DisplayName]),
    mtConfirmation, [mbYes, mbNo], 0) = mrYes then
  begin
    try
      DataMod.DeleteCustomer(Customer.Id);
      Log.Info('Customer deleted: %s', [Customer.DisplayName]);
      LoadCustomers;
    except
      on E: Exception do
      begin
        Log.Error('Failed to delete customer: %s', [E.Message]);
        MessageDlg('Failed to delete customer: ' + E.Message, mtError, [mbOK], 0);
      end;
    end;
  end;
end;

procedure TMainForm.ActRefreshExecute(Sender: TObject);
begin
  LoadCustomers;
end;

procedure TMainForm.ActExitExecute(Sender: TObject);
begin
  Close;
end;

procedure TMainForm.MnuHelpAboutClick(Sender: TObject);
begin
  MessageDlg(
    'CRUD Application Template' + sLineBreak +
    'Version 1.0' + sLineBreak +
    sLineBreak +
    'Built with DeepBase Framework' + sLineBreak +
    sLineBreak +
    'This template demonstrates:' + sLineBreak +
    '- Entity definition with ORM' + sLineBreak +
    '- CRUD operations' + sLineBreak +
    '- Search and filtering' + sLineBreak +
    '- Form state persistence' + sLineBreak +
    '- Logging and configuration',
    mtInformation, [mbOK], 0);
end;

procedure TMainForm.SaveFormState;
begin
  try
    DeepBase.Config.SetConfigInt('MainForm.Left', Left);
    DeepBase.Config.SetConfigInt('MainForm.Top', Top);
    DeepBase.Config.SetConfigInt('MainForm.Width', Width);
    DeepBase.Config.SetConfigInt('MainForm.Height', Height);
    DeepBase.Config.SetConfigInt('MainForm.WindowState', Ord(WindowState));
    DeepBase.Config.SetConfigInt('MainForm.StatusFilter', CmbStatus.ItemIndex);
  except
    // Ignore errors during form state save
  end;
end;

procedure TMainForm.LoadFormState;
var
  SavedState: Integer;
begin
  try
    Left := DeepBase.Config.GetConfigInt('MainForm.Left', Left);
    Top := DeepBase.Config.GetConfigInt('MainForm.Top', Top);
    Width := DeepBase.Config.GetConfigInt('MainForm.Width', Width);
    Height := DeepBase.Config.GetConfigInt('MainForm.Height', Height);
    SavedState := DeepBase.Config.GetConfigInt('MainForm.WindowState', Ord(wsNormal));
    if SavedState = Ord(wsMaximized) then
      WindowState := wsMaximized;
    CmbStatus.ItemIndex := DeepBase.Config.GetConfigInt('MainForm.StatusFilter', STATUS_ALL);
  except
    // Ignore errors during form state load
  end;
end;

end.
