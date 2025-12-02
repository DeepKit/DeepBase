{ ============================================================================
  Studio.PromptTemplateFrame - Prompt Template Management Frame
  
  Version: 1.0
  Description: Provides UI for managing LLM prompt templates
  Features:
    - Template list with categories (TreeView)
    - Template editor with variable highlighting
    - Variable management
    - Test panel for rendering and execution
    - Import/Export functionality
  ============================================================================ }

unit Studio.PromptTemplateFrame;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Variants,
  System.Classes,
  System.Math,
  System.Generics.Collections,
  System.JSON,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.ComCtrls,
  Vcl.Grids,
  Vcl.Menus,
  FireDAC.Comp.Client,
  UniBase.LLM;

type
  TfraPromptTemplate = class(TFrame)
  private
    FConnection: TFDConnection;
    FLLM: TUniBaseLLM;
    FCurrentTemplate: TLLMPromptTemplate;
    FIsModified: Boolean;
    FCategories: TStringList;
    
    { UI Controls }
    pnlLeft: TPanel;
    pnlRight: TPanel;
    splMain: TSplitter;
    
    { Left Panel - Template List }
    pnlListHeader: TPanel;
    lblTemplates: TLabel;
    btnNew: TButton;
    btnDelete: TButton;
    btnCopy: TButton;
    tvTemplates: TTreeView;
    pnlFilter: TPanel;
    edtFilter: TEdit;
    cboCategory: TComboBox;
    
    { Right Panel - Template Editor }
    pgcEditor: TPageControl;
    tabBasic: TTabSheet;
    tabAdvanced: TTabSheet;
    tabTest: TTabSheet;
    
    { Basic Tab }
    pnlBasicTop: TPanel;
    lblName: TLabel;
    edtName: TEdit;
    lblCategory: TLabel;
    cboCategoryEdit: TComboBox;
    lblDescription: TLabel;
    edtDescription: TEdit;
    lblSystemPrompt: TLabel;
    mmoSystemPrompt: TMemo;
    lblUserPrompt: TLabel;
    mmoUserPrompt: TMemo;
    pnlVariables: TPanel;
    lblVariables: TLabel;
    sgVariables: TStringGrid;
    btnAddVar: TButton;
    btnRemoveVar: TButton;
    pnlBasicBottom: TPanel;
    btnSave: TButton;
    btnCancel: TButton;
    lblStatus: TLabel;
    
    { Advanced Tab }
    lblParent: TLabel;
    cboParent: TComboBox;
    lblOutputFormat: TLabel;
    cboOutputFormat: TComboBox;
    lblTemperature: TLabel;
    edtTemperature: TEdit;
    lblMaxTokens: TLabel;
    edtMaxTokens: TEdit;
    lblValidationRegex: TLabel;
    edtValidationRegex: TEdit;
    lblRecommendedConfig: TLabel;
    cboRecommendedConfig: TComboBox;
    chkIsEnabled: TCheckBox;
    
    { Test Tab }
    pnlTestTop: TPanel;
    lblTestVars: TLabel;
    sgTestVars: TStringGrid;
    btnRender: TButton;
    btnExecute: TButton;
    pnlTestBottom: TPanel;
    lblRenderedPrompt: TLabel;
    mmoRendered: TMemo;
    lblResponse: TLabel;
    mmoResponse: TMemo;
    
    { Import/Export }
    pnlImportExport: TPanel;
    btnImport: TButton;
    btnExport: TButton;
    
    { Popup Menu }
    pmTemplates: TPopupMenu;
    miNew: TMenuItem;
    miCopy: TMenuItem;
    miDelete: TMenuItem;
    miSeparator: TMenuItem;
    miExport: TMenuItem;
    
    { Dialogs }
    dlgOpen: TOpenDialog;
    dlgSave: TSaveDialog;
    
    procedure CreateControls;
    procedure LoadTemplates;
    procedure LoadTemplate(const Name: string);
    procedure SaveTemplate;
    procedure ClearEditor;
    procedure UpdateCategories;
    procedure UpdateVariablesGrid;
    procedure UpdateTestVariables;
    procedure SetStatus(const Text: string; IsError: Boolean = False);
    procedure SetModified(Value: Boolean);
    
    { Event Handlers }
    procedure tvTemplatesChange(Sender: TObject; Node: TTreeNode);
    procedure btnNewClick(Sender: TObject);
    procedure btnDeleteClick(Sender: TObject);
    procedure btnCopyClick(Sender: TObject);
    procedure btnSaveClick(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
    procedure btnAddVarClick(Sender: TObject);
    procedure btnRemoveVarClick(Sender: TObject);
    procedure btnRenderClick(Sender: TObject);
    procedure btnExecuteClick(Sender: TObject);
    procedure btnImportClick(Sender: TObject);
    procedure btnExportClick(Sender: TObject);
    procedure edtFilterChange(Sender: TObject);
    procedure cboCategoryChange(Sender: TObject);
    procedure OnEditorChange(Sender: TObject);
    
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    
    procedure SetConnection(AConnection: TFDConnection);
    procedure RefreshData;
    
    property LLM: TUniBaseLLM read FLLM;
    property IsModified: Boolean read FIsModified;
  end;

implementation

{$R *.dfm}

const
  OUTPUT_FORMATS: array[0..2] of string = ('text', 'json', 'markdown');

{ TfraPromptTemplate }

constructor TfraPromptTemplate.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FCategories := TStringList.Create;
  FCategories.Sorted := True;
  FCategories.Duplicates := dupIgnore;
  FIsModified := False;
  FCurrentTemplate.Init;
  CreateControls;
end;

destructor TfraPromptTemplate.Destroy;
begin
  FCategories.Free;
  if Assigned(FLLM) then
    FLLM.Free;
  inherited;
end;

procedure TfraPromptTemplate.CreateControls;
begin
  // Main splitter layout
  pnlLeft := TPanel.Create(Self);
  pnlLeft.Parent := Self;
  pnlLeft.Align := alLeft;
  pnlLeft.Width := 280;
  pnlLeft.BevelOuter := bvNone;
  
  splMain := TSplitter.Create(Self);
  splMain.Parent := Self;
  splMain.Left := pnlLeft.Width;
  splMain.Width := 4;
  
  pnlRight := TPanel.Create(Self);
  pnlRight.Parent := Self;
  pnlRight.Align := alClient;
  pnlRight.BevelOuter := bvNone;
  
  // === Left Panel: Template List ===
  pnlListHeader := TPanel.Create(Self);
  pnlListHeader.Parent := pnlLeft;
  pnlListHeader.Align := alTop;
  pnlListHeader.Height := 36;
  pnlListHeader.BevelOuter := bvNone;
  
  lblTemplates := TLabel.Create(Self);
  lblTemplates.Parent := pnlListHeader;
  lblTemplates.Caption := 'Templates';
  lblTemplates.Font.Style := [fsBold];
  lblTemplates.Left := 8;
  lblTemplates.Top := 10;
  
  btnNew := TButton.Create(Self);
  btnNew.Parent := pnlListHeader;
  btnNew.Caption := '+';
  btnNew.Width := 28;
  btnNew.Height := 24;
  btnNew.Left := pnlListHeader.Width - 100;
  btnNew.Anchors := [akTop, akRight];
  btnNew.OnClick := btnNewClick;
  btnNew.Hint := 'New Template';
  btnNew.ShowHint := True;
  
  btnCopy := TButton.Create(Self);
  btnCopy.Parent := pnlListHeader;
  btnCopy.Caption := 'C';
  btnCopy.Width := 28;
  btnCopy.Height := 24;
  btnCopy.Left := pnlListHeader.Width - 68;
  btnCopy.Anchors := [akTop, akRight];
  btnCopy.OnClick := btnCopyClick;
  btnCopy.Hint := 'Copy Template';
  btnCopy.ShowHint := True;
  
  btnDelete := TButton.Create(Self);
  btnDelete.Parent := pnlListHeader;
  btnDelete.Caption := 'X';
  btnDelete.Width := 28;
  btnDelete.Height := 24;
  btnDelete.Left := pnlListHeader.Width - 36;
  btnDelete.Anchors := [akTop, akRight];
  btnDelete.OnClick := btnDeleteClick;
  btnDelete.Hint := 'Delete Template';
  btnDelete.ShowHint := True;
  
  pnlFilter := TPanel.Create(Self);
  pnlFilter.Parent := pnlLeft;
  pnlFilter.Align := alTop;
  pnlFilter.Height := 56;
  pnlFilter.BevelOuter := bvNone;
  
  edtFilter := TEdit.Create(Self);
  edtFilter.Parent := pnlFilter;
  edtFilter.Left := 8;
  edtFilter.Top := 4;
  edtFilter.Width := pnlFilter.Width - 16;
  edtFilter.Anchors := [akLeft, akTop, akRight];
  edtFilter.TextHint := 'Filter templates...';
  edtFilter.OnChange := edtFilterChange;
  
  cboCategory := TComboBox.Create(Self);
  cboCategory.Parent := pnlFilter;
  cboCategory.Left := 8;
  cboCategory.Top := 30;
  cboCategory.Width := pnlFilter.Width - 16;
  cboCategory.Anchors := [akLeft, akTop, akRight];
  cboCategory.Style := csDropDownList;
  cboCategory.Items.Add('(All Categories)');
  cboCategory.ItemIndex := 0;
  cboCategory.OnChange := cboCategoryChange;
  
  tvTemplates := TTreeView.Create(Self);
  tvTemplates.Parent := pnlLeft;
  tvTemplates.Align := alClient;
  tvTemplates.ReadOnly := True;
  tvTemplates.HideSelection := False;
  tvTemplates.OnChange := tvTemplatesChange;
  
  pnlImportExport := TPanel.Create(Self);
  pnlImportExport.Parent := pnlLeft;
  pnlImportExport.Align := alBottom;
  pnlImportExport.Height := 36;
  pnlImportExport.BevelOuter := bvNone;
  
  btnImport := TButton.Create(Self);
  btnImport.Parent := pnlImportExport;
  btnImport.Caption := 'Import';
  btnImport.Left := 8;
  btnImport.Top := 6;
  btnImport.Width := 80;
  btnImport.OnClick := btnImportClick;
  
  btnExport := TButton.Create(Self);
  btnExport.Parent := pnlImportExport;
  btnExport.Caption := 'Export';
  btnExport.Left := 96;
  btnExport.Top := 6;
  btnExport.Width := 80;
  btnExport.OnClick := btnExportClick;
  
  // === Right Panel: Editor ===
  pgcEditor := TPageControl.Create(Self);
  pgcEditor.Parent := pnlRight;
  pgcEditor.Align := alClient;
  
  // === Basic Tab ===
  tabBasic := TTabSheet.Create(pgcEditor);
  tabBasic.PageControl := pgcEditor;
  tabBasic.Caption := 'Basic';
  
  pnlBasicTop := TPanel.Create(Self);
  pnlBasicTop.Parent := tabBasic;
  pnlBasicTop.Align := alTop;
  pnlBasicTop.Height := 90;
  pnlBasicTop.BevelOuter := bvNone;
  
  lblName := TLabel.Create(Self);
  lblName.Parent := pnlBasicTop;
  lblName.Caption := 'Name:';
  lblName.Left := 8;
  lblName.Top := 10;
  
  edtName := TEdit.Create(Self);
  edtName.Parent := pnlBasicTop;
  edtName.Left := 80;
  edtName.Top := 8;
  edtName.Width := 200;
  edtName.OnChange := OnEditorChange;
  
  lblCategory := TLabel.Create(Self);
  lblCategory.Parent := pnlBasicTop;
  lblCategory.Caption := 'Category:';
  lblCategory.Left := 300;
  lblCategory.Top := 10;
  
  cboCategoryEdit := TComboBox.Create(Self);
  cboCategoryEdit.Parent := pnlBasicTop;
  cboCategoryEdit.Left := 370;
  cboCategoryEdit.Top := 8;
  cboCategoryEdit.Width := 150;
  cboCategoryEdit.OnChange := OnEditorChange;
  
  lblDescription := TLabel.Create(Self);
  lblDescription.Parent := pnlBasicTop;
  lblDescription.Caption := 'Description:';
  lblDescription.Left := 8;
  lblDescription.Top := 40;
  
  edtDescription := TEdit.Create(Self);
  edtDescription.Parent := pnlBasicTop;
  edtDescription.Left := 80;
  edtDescription.Top := 38;
  edtDescription.Width := 440;
  edtDescription.Anchors := [akLeft, akTop, akRight];
  edtDescription.OnChange := OnEditorChange;
  
  lblSystemPrompt := TLabel.Create(Self);
  lblSystemPrompt.Parent := pnlBasicTop;
  lblSystemPrompt.Caption := 'System Prompt:';
  lblSystemPrompt.Left := 8;
  lblSystemPrompt.Top := 68;
  
  mmoSystemPrompt := TMemo.Create(Self);
  mmoSystemPrompt.Parent := tabBasic;
  mmoSystemPrompt.Align := alTop;
  mmoSystemPrompt.Top := pnlBasicTop.Height;
  mmoSystemPrompt.Height := 80;
  mmoSystemPrompt.ScrollBars := ssVertical;
  mmoSystemPrompt.OnChange := OnEditorChange;
  
  lblUserPrompt := TLabel.Create(Self);
  lblUserPrompt.Parent := tabBasic;
  lblUserPrompt.Caption := 'User Prompt Template (use {{variable}} for variables):';
  lblUserPrompt.Align := alTop;
  lblUserPrompt.Top := mmoSystemPrompt.Top + mmoSystemPrompt.Height;
  
  mmoUserPrompt := TMemo.Create(Self);
  mmoUserPrompt.Parent := tabBasic;
  mmoUserPrompt.Align := alClient;
  mmoUserPrompt.ScrollBars := ssBoth;
  mmoUserPrompt.Font.Name := 'Consolas';
  mmoUserPrompt.Font.Size := 10;
  mmoUserPrompt.OnChange := OnEditorChange;
  
  pnlVariables := TPanel.Create(Self);
  pnlVariables.Parent := tabBasic;
  pnlVariables.Align := alBottom;
  pnlVariables.Height := 120;
  pnlVariables.BevelOuter := bvNone;
  
  lblVariables := TLabel.Create(Self);
  lblVariables.Parent := pnlVariables;
  lblVariables.Caption := 'Variables:';
  lblVariables.Left := 8;
  lblVariables.Top := 4;
  
  sgVariables := TStringGrid.Create(Self);
  sgVariables.Parent := pnlVariables;
  sgVariables.Left := 8;
  sgVariables.Top := 24;
  sgVariables.Width := pnlVariables.Width - 100;
  sgVariables.Height := 90;
  sgVariables.Anchors := [akLeft, akTop, akRight, akBottom];
  sgVariables.ColCount := 2;
  sgVariables.RowCount := 2;
  sgVariables.FixedCols := 0;
  sgVariables.FixedRows := 1;
  sgVariables.Cells[0, 0] := 'Variable';
  sgVariables.Cells[1, 0] := 'Default Value';
  sgVariables.ColWidths[0] := 150;
  sgVariables.ColWidths[1] := 200;
  sgVariables.Options := sgVariables.Options + [goEditing];
  
  btnAddVar := TButton.Create(Self);
  btnAddVar.Parent := pnlVariables;
  btnAddVar.Caption := 'Add';
  btnAddVar.Left := pnlVariables.Width - 80;
  btnAddVar.Top := 24;
  btnAddVar.Width := 70;
  btnAddVar.Anchors := [akTop, akRight];
  btnAddVar.OnClick := btnAddVarClick;
  
  btnRemoveVar := TButton.Create(Self);
  btnRemoveVar.Parent := pnlVariables;
  btnRemoveVar.Caption := 'Remove';
  btnRemoveVar.Left := pnlVariables.Width - 80;
  btnRemoveVar.Top := 54;
  btnRemoveVar.Width := 70;
  btnRemoveVar.Anchors := [akTop, akRight];
  btnRemoveVar.OnClick := btnRemoveVarClick;
  
  pnlBasicBottom := TPanel.Create(Self);
  pnlBasicBottom.Parent := tabBasic;
  pnlBasicBottom.Align := alBottom;
  pnlBasicBottom.Height := 36;
  pnlBasicBottom.BevelOuter := bvNone;
  
  btnSave := TButton.Create(Self);
  btnSave.Parent := pnlBasicBottom;
  btnSave.Caption := 'Save';
  btnSave.Left := 8;
  btnSave.Top := 6;
  btnSave.Width := 80;
  btnSave.OnClick := btnSaveClick;
  
  btnCancel := TButton.Create(Self);
  btnCancel.Parent := pnlBasicBottom;
  btnCancel.Caption := 'Cancel';
  btnCancel.Left := 96;
  btnCancel.Top := 6;
  btnCancel.Width := 80;
  btnCancel.OnClick := btnCancelClick;
  
  lblStatus := TLabel.Create(Self);
  lblStatus.Parent := pnlBasicBottom;
  lblStatus.Left := 200;
  lblStatus.Top := 10;
  lblStatus.AutoSize := True;
  
  // === Advanced Tab ===
  tabAdvanced := TTabSheet.Create(pgcEditor);
  tabAdvanced.PageControl := pgcEditor;
  tabAdvanced.Caption := 'Advanced';
  
  lblParent := TLabel.Create(Self);
  lblParent.Parent := tabAdvanced;
  lblParent.Caption := 'Parent Template:';
  lblParent.Left := 16;
  lblParent.Top := 20;
  
  cboParent := TComboBox.Create(Self);
  cboParent.Parent := tabAdvanced;
  cboParent.Left := 140;
  cboParent.Top := 18;
  cboParent.Width := 200;
  cboParent.Style := csDropDownList;
  cboParent.OnChange := OnEditorChange;
  
  lblOutputFormat := TLabel.Create(Self);
  lblOutputFormat.Parent := tabAdvanced;
  lblOutputFormat.Caption := 'Output Format:';
  lblOutputFormat.Left := 16;
  lblOutputFormat.Top := 52;
  
  cboOutputFormat := TComboBox.Create(Self);
  cboOutputFormat.Parent := tabAdvanced;
  cboOutputFormat.Left := 140;
  cboOutputFormat.Top := 50;
  cboOutputFormat.Width := 100;
  cboOutputFormat.Style := csDropDownList;
  cboOutputFormat.Items.AddStrings(OUTPUT_FORMATS);
  cboOutputFormat.ItemIndex := 0;
  cboOutputFormat.OnChange := OnEditorChange;
  
  lblTemperature := TLabel.Create(Self);
  lblTemperature.Parent := tabAdvanced;
  lblTemperature.Caption := 'Temperature:';
  lblTemperature.Left := 16;
  lblTemperature.Top := 84;
  
  edtTemperature := TEdit.Create(Self);
  edtTemperature.Parent := tabAdvanced;
  edtTemperature.Left := 140;
  edtTemperature.Top := 82;
  edtTemperature.Width := 80;
  edtTemperature.Text := '0.7';
  edtTemperature.OnChange := OnEditorChange;
  
  lblMaxTokens := TLabel.Create(Self);
  lblMaxTokens.Parent := tabAdvanced;
  lblMaxTokens.Caption := 'Max Tokens:';
  lblMaxTokens.Left := 260;
  lblMaxTokens.Top := 84;
  
  edtMaxTokens := TEdit.Create(Self);
  edtMaxTokens.Parent := tabAdvanced;
  edtMaxTokens.Left := 350;
  edtMaxTokens.Top := 82;
  edtMaxTokens.Width := 80;
  edtMaxTokens.Text := '0';
  edtMaxTokens.OnChange := OnEditorChange;
  
  lblValidationRegex := TLabel.Create(Self);
  lblValidationRegex.Parent := tabAdvanced;
  lblValidationRegex.Caption := 'Validation Regex:';
  lblValidationRegex.Left := 16;
  lblValidationRegex.Top := 116;
  
  edtValidationRegex := TEdit.Create(Self);
  edtValidationRegex.Parent := tabAdvanced;
  edtValidationRegex.Left := 140;
  edtValidationRegex.Top := 114;
  edtValidationRegex.Width := 300;
  edtValidationRegex.OnChange := OnEditorChange;
  
  lblRecommendedConfig := TLabel.Create(Self);
  lblRecommendedConfig.Parent := tabAdvanced;
  lblRecommendedConfig.Caption := 'Recommended Config:';
  lblRecommendedConfig.Left := 16;
  lblRecommendedConfig.Top := 148;
  
  cboRecommendedConfig := TComboBox.Create(Self);
  cboRecommendedConfig.Parent := tabAdvanced;
  cboRecommendedConfig.Left := 140;
  cboRecommendedConfig.Top := 146;
  cboRecommendedConfig.Width := 200;
  cboRecommendedConfig.OnChange := OnEditorChange;
  
  chkIsEnabled := TCheckBox.Create(Self);
  chkIsEnabled.Parent := tabAdvanced;
  chkIsEnabled.Caption := 'Enabled';
  chkIsEnabled.Left := 16;
  chkIsEnabled.Top := 180;
  chkIsEnabled.Checked := True;
  chkIsEnabled.OnClick := OnEditorChange;
  
  // === Test Tab ===
  tabTest := TTabSheet.Create(pgcEditor);
  tabTest.PageControl := pgcEditor;
  tabTest.Caption := 'Test';
  
  pnlTestTop := TPanel.Create(Self);
  pnlTestTop.Parent := tabTest;
  pnlTestTop.Align := alTop;
  pnlTestTop.Height := 140;
  pnlTestTop.BevelOuter := bvNone;
  
  lblTestVars := TLabel.Create(Self);
  lblTestVars.Parent := pnlTestTop;
  lblTestVars.Caption := 'Test Variables:';
  lblTestVars.Left := 8;
  lblTestVars.Top := 4;
  
  sgTestVars := TStringGrid.Create(Self);
  sgTestVars.Parent := pnlTestTop;
  sgTestVars.Left := 8;
  sgTestVars.Top := 24;
  sgTestVars.Width := pnlTestTop.Width - 120;
  sgTestVars.Height := 100;
  sgTestVars.Anchors := [akLeft, akTop, akRight, akBottom];
  sgTestVars.ColCount := 2;
  sgTestVars.RowCount := 2;
  sgTestVars.FixedCols := 0;
  sgTestVars.FixedRows := 1;
  sgTestVars.Cells[0, 0] := 'Variable';
  sgTestVars.Cells[1, 0] := 'Test Value';
  sgTestVars.ColWidths[0] := 150;
  sgTestVars.ColWidths[1] := 300;
  sgTestVars.Options := sgTestVars.Options + [goEditing];
  
  btnRender := TButton.Create(Self);
  btnRender.Parent := pnlTestTop;
  btnRender.Caption := 'Render';
  btnRender.Left := pnlTestTop.Width - 100;
  btnRender.Top := 24;
  btnRender.Width := 90;
  btnRender.Anchors := [akTop, akRight];
  btnRender.OnClick := btnRenderClick;
  
  btnExecute := TButton.Create(Self);
  btnExecute.Parent := pnlTestTop;
  btnExecute.Caption := 'Execute';
  btnExecute.Left := pnlTestTop.Width - 100;
  btnExecute.Top := 56;
  btnExecute.Width := 90;
  btnExecute.Anchors := [akTop, akRight];
  btnExecute.OnClick := btnExecuteClick;
  
  pnlTestBottom := TPanel.Create(Self);
  pnlTestBottom.Parent := tabTest;
  pnlTestBottom.Align := alClient;
  pnlTestBottom.BevelOuter := bvNone;
  
  lblRenderedPrompt := TLabel.Create(Self);
  lblRenderedPrompt.Parent := pnlTestBottom;
  lblRenderedPrompt.Caption := 'Rendered Prompt:';
  lblRenderedPrompt.Align := alTop;
  
  mmoRendered := TMemo.Create(Self);
  mmoRendered.Parent := pnlTestBottom;
  mmoRendered.Align := alTop;
  mmoRendered.Height := 120;
  mmoRendered.ReadOnly := True;
  mmoRendered.ScrollBars := ssVertical;
  mmoRendered.Font.Name := 'Consolas';
  
  lblResponse := TLabel.Create(Self);
  lblResponse.Parent := pnlTestBottom;
  lblResponse.Caption := 'LLM Response:';
  lblResponse.Align := alTop;
  
  mmoResponse := TMemo.Create(Self);
  mmoResponse.Parent := pnlTestBottom;
  mmoResponse.Align := alClient;
  mmoResponse.ReadOnly := True;
  mmoResponse.ScrollBars := ssBoth;
  
  // Dialogs
  dlgOpen := TOpenDialog.Create(Self);
  dlgOpen.Filter := 'JSON Files (*.json)|*.json|All Files (*.*)|*.*';
  dlgOpen.DefaultExt := 'json';
  
  dlgSave := TSaveDialog.Create(Self);
  dlgSave.Filter := 'JSON Files (*.json)|*.json|All Files (*.*)|*.*';
  dlgSave.DefaultExt := 'json';
  
  // Popup Menu
  pmTemplates := TPopupMenu.Create(Self);
  tvTemplates.PopupMenu := pmTemplates;
  
  miNew := TMenuItem.Create(pmTemplates);
  miNew.Caption := 'New Template';
  miNew.OnClick := btnNewClick;
  pmTemplates.Items.Add(miNew);
  
  miCopy := TMenuItem.Create(pmTemplates);
  miCopy.Caption := 'Copy Template';
  miCopy.OnClick := btnCopyClick;
  pmTemplates.Items.Add(miCopy);
  
  miDelete := TMenuItem.Create(pmTemplates);
  miDelete.Caption := 'Delete Template';
  miDelete.OnClick := btnDeleteClick;
  pmTemplates.Items.Add(miDelete);
  
  miSeparator := TMenuItem.Create(pmTemplates);
  miSeparator.Caption := '-';
  pmTemplates.Items.Add(miSeparator);
  
  miExport := TMenuItem.Create(pmTemplates);
  miExport.Caption := 'Export All...';
  miExport.OnClick := btnExportClick;
  pmTemplates.Items.Add(miExport);
end;

procedure TfraPromptTemplate.SetConnection(AConnection: TFDConnection);
begin
  FConnection := AConnection;
  
  if Assigned(FLLM) then
    FreeAndNil(FLLM);
    
  if Assigned(FConnection) and FConnection.Connected then
  begin
    FLLM := TUniBaseLLM.Create(FConnection);
    RefreshData;
  end
  else
    ClearEditor;
end;

procedure TfraPromptTemplate.RefreshData;
begin
  if not Assigned(FLLM) then Exit;
  
  LoadTemplates;
  UpdateCategories;
  
  // Load LLM configs for recommended config dropdown
  cboRecommendedConfig.Items.Clear;
  cboRecommendedConfig.Items.Add('');
  var Configs := FLLM.GetAllConfigs;
  for var C in Configs do
    cboRecommendedConfig.Items.Add(C.Name);
    
  // Load parent templates dropdown
  cboParent.Items.Clear;
  cboParent.Items.Add('(None)');
  var Templates := FLLM.GetAllTemplates;
  for var T in Templates do
    cboParent.Items.Add(T.Name);
end;

procedure TfraPromptTemplate.LoadTemplates;
var
  Templates: TLLMPromptTemplateArray;
  T: TLLMPromptTemplate;
  CatNode, TplNode: TTreeNode;
  CatIndex: Integer;
  FilterText, FilterCat: string;
begin
  if not Assigned(FLLM) then Exit;
  
  tvTemplates.Items.BeginUpdate;
  try
    tvTemplates.Items.Clear;
    FCategories.Clear;
    
    Templates := FLLM.GetAllTemplates;
    FilterText := LowerCase(Trim(edtFilter.Text));
    if cboCategory.ItemIndex > 0 then
      FilterCat := cboCategory.Items[cboCategory.ItemIndex]
    else
      FilterCat := '';
    
    // Group by category
    for T in Templates do
    begin
      // Apply filter
      if (FilterText <> '') and (Pos(FilterText, LowerCase(T.Name)) = 0) and
         (Pos(FilterText, LowerCase(T.Description)) = 0) then
        Continue;
      if (FilterCat <> '') and (T.Category <> FilterCat) then
        Continue;
        
      // Find or create category node
      CatIndex := FCategories.IndexOf(T.Category);
      if CatIndex < 0 then
      begin
        CatNode := tvTemplates.Items.Add(nil, T.Category);
        CatNode.ImageIndex := 0;
        FCategories.AddObject(T.Category, CatNode);
      end
      else
        CatNode := TTreeNode(FCategories.Objects[CatIndex]);
      
      // Add template node
      TplNode := tvTemplates.Items.AddChild(CatNode, T.Name);
      TplNode.Data := Pointer(T.Id);
      if T.IsBuiltIn then
        TplNode.ImageIndex := 1
      else
        TplNode.ImageIndex := 2;
    end;
    
    // Expand all
    tvTemplates.FullExpand;
  finally
    tvTemplates.Items.EndUpdate;
  end;
end;

procedure TfraPromptTemplate.LoadTemplate(const Name: string);
var
  I: Integer;
begin
  if not Assigned(FLLM) then Exit;
  
  FCurrentTemplate := FLLM.GetTemplate(Name);
  if FCurrentTemplate.Name = '' then Exit;
  
  // Basic tab
  edtName.Text := FCurrentTemplate.Name;
  cboCategoryEdit.Text := FCurrentTemplate.Category;
  edtDescription.Text := FCurrentTemplate.Description;
  mmoSystemPrompt.Text := FCurrentTemplate.SystemPrompt;
  mmoUserPrompt.Text := FCurrentTemplate.UserPromptTemplate;
  
  // Variables grid
  UpdateVariablesGrid;
  
  // Advanced tab
  if FCurrentTemplate.ParentTemplate <> '' then
    cboParent.ItemIndex := cboParent.Items.IndexOf(FCurrentTemplate.ParentTemplate)
  else
    cboParent.ItemIndex := 0;
    
  I := IndexStr(FCurrentTemplate.OutputFormat, OUTPUT_FORMATS);
  if I >= 0 then
    cboOutputFormat.ItemIndex := I
  else
    cboOutputFormat.ItemIndex := 0;
    
  edtTemperature.Text := FormatFloat('0.0', FCurrentTemplate.Temperature);
  edtMaxTokens.Text := IntToStr(FCurrentTemplate.MaxTokens);
  edtValidationRegex.Text := FCurrentTemplate.ValidationRegex;
  cboRecommendedConfig.Text := FCurrentTemplate.RecommendedConfig;
  chkIsEnabled.Checked := FCurrentTemplate.IsEnabled;
  
  // Test tab
  UpdateTestVariables;
  mmoRendered.Clear;
  mmoResponse.Clear;
  
  // Enable/disable controls based on IsBuiltIn
  edtName.Enabled := not FCurrentTemplate.IsBuiltIn;
  btnDelete.Enabled := not FCurrentTemplate.IsBuiltIn;
  
  SetModified(False);
end;

procedure TfraPromptTemplate.UpdateVariablesGrid;
var
  I: Integer;
  DefVal: string;
begin
  sgVariables.RowCount := Max(2, Length(FCurrentTemplate.Variables) + 1);
  
  for I := 0 to High(FCurrentTemplate.Variables) do
  begin
    sgVariables.Cells[0, I + 1] := FCurrentTemplate.Variables[I];
    DefVal := '';
    if Assigned(FCurrentTemplate.DefaultValues) then
      FCurrentTemplate.DefaultValues.TryGetValue(FCurrentTemplate.Variables[I], DefVal);
    sgVariables.Cells[1, I + 1] := DefVal;
  end;
  
  // Clear remaining rows
  for I := Length(FCurrentTemplate.Variables) + 1 to sgVariables.RowCount - 1 do
  begin
    sgVariables.Cells[0, I] := '';
    sgVariables.Cells[1, I] := '';
  end;
end;

procedure TfraPromptTemplate.UpdateTestVariables;
var
  I: Integer;
  DefVal: string;
begin
  sgTestVars.RowCount := Max(2, Length(FCurrentTemplate.Variables) + 1);
  
  for I := 0 to High(FCurrentTemplate.Variables) do
  begin
    sgTestVars.Cells[0, I + 1] := FCurrentTemplate.Variables[I];
    DefVal := '';
    if Assigned(FCurrentTemplate.DefaultValues) then
      FCurrentTemplate.DefaultValues.TryGetValue(FCurrentTemplate.Variables[I], DefVal);
    sgTestVars.Cells[1, I + 1] := DefVal;
  end;
end;

procedure TfraPromptTemplate.SaveTemplate;
var
  T: TLLMPromptTemplate;
  I, VarCount: Integer;
  VarName, DefVal: string;
begin
  if not Assigned(FLLM) then Exit;
  
  T.Init;
  T.Id := FCurrentTemplate.Id;
  T.Name := Trim(edtName.Text);
  T.Category := Trim(cboCategoryEdit.Text);
  T.Description := Trim(edtDescription.Text);
  T.SystemPrompt := mmoSystemPrompt.Text;
  T.UserPromptTemplate := mmoUserPrompt.Text;
  
  // Collect variables from grid
  VarCount := 0;
  for I := 1 to sgVariables.RowCount - 1 do
  begin
    VarName := Trim(sgVariables.Cells[0, I]);
    if VarName <> '' then
      Inc(VarCount);
  end;
  
  SetLength(T.Variables, VarCount);
  T.DefaultValues := TDictionary<string, string>.Create;
  
  VarCount := 0;
  for I := 1 to sgVariables.RowCount - 1 do
  begin
    VarName := Trim(sgVariables.Cells[0, I]);
    if VarName <> '' then
    begin
      T.Variables[VarCount] := VarName;
      DefVal := sgVariables.Cells[1, I];
      if DefVal <> '' then
        T.DefaultValues.Add(VarName, DefVal);
      Inc(VarCount);
    end;
  end;
  
  // Advanced settings
  if cboParent.ItemIndex > 0 then
    T.ParentTemplate := cboParent.Items[cboParent.ItemIndex]
  else
    T.ParentTemplate := '';
  T.OutputFormat := cboOutputFormat.Text;
  T.Temperature := StrToFloatDef(edtTemperature.Text, 0.7);
  T.MaxTokens := StrToIntDef(edtMaxTokens.Text, 0);
  T.ValidationRegex := edtValidationRegex.Text;
  T.RecommendedConfig := cboRecommendedConfig.Text;
  T.IsEnabled := chkIsEnabled.Checked;
  T.IsBuiltIn := FCurrentTemplate.IsBuiltIn;
  
  // Validate
  var Validation := FLLM.ValidateTemplate(T);
  if not Validation.IsValid then
  begin
    SetStatus('Validation error: ' + String.Join(', ', Validation.Errors), True);
    Exit;
  end;
  
  try
    FLLM.SaveTemplate(T);
    FCurrentTemplate := T;
    SetStatus('Template saved successfully', False);
    SetModified(False);
    LoadTemplates;
  except
    on E: Exception do
      SetStatus('Error: ' + E.Message, True);
  end;
end;

procedure TfraPromptTemplate.ClearEditor;
begin
  edtName.Clear;
  cboCategoryEdit.Text := 'General';
  edtDescription.Clear;
  mmoSystemPrompt.Clear;
  mmoUserPrompt.Clear;
  sgVariables.RowCount := 2;
  sgVariables.Cells[0, 1] := '';
  sgVariables.Cells[1, 1] := '';
  cboParent.ItemIndex := 0;
  cboOutputFormat.ItemIndex := 0;
  edtTemperature.Text := '0.7';
  edtMaxTokens.Text := '0';
  edtValidationRegex.Clear;
  cboRecommendedConfig.ItemIndex := 0;
  chkIsEnabled.Checked := True;
  mmoRendered.Clear;
  mmoResponse.Clear;
  FCurrentTemplate.Init;
  SetModified(False);
end;

procedure TfraPromptTemplate.UpdateCategories;
var
  Templates: TLLMPromptTemplateArray;
  T: TLLMPromptTemplate;
  CurrentCat: string;
begin
  CurrentCat := cboCategory.Text;
  cboCategory.Items.Clear;
  cboCategory.Items.Add('(All Categories)');
  
  cboCategoryEdit.Items.Clear;
  
  if not Assigned(FLLM) then Exit;
  
  Templates := FLLM.GetAllTemplates;
  for T in Templates do
  begin
    if cboCategory.Items.IndexOf(T.Category) < 0 then
      cboCategory.Items.Add(T.Category);
    if cboCategoryEdit.Items.IndexOf(T.Category) < 0 then
      cboCategoryEdit.Items.Add(T.Category);
  end;
  
  // Add common categories
  if cboCategoryEdit.Items.IndexOf('General') < 0 then
    cboCategoryEdit.Items.Add('General');
  if cboCategoryEdit.Items.IndexOf('Translation') < 0 then
    cboCategoryEdit.Items.Add('Translation');
  if cboCategoryEdit.Items.IndexOf('Code') < 0 then
    cboCategoryEdit.Items.Add('Code');
    
  cboCategory.ItemIndex := Max(0, cboCategory.Items.IndexOf(CurrentCat));
end;

procedure TfraPromptTemplate.SetStatus(const Text: string; IsError: Boolean);
begin
  lblStatus.Caption := Text;
  if IsError then
    lblStatus.Font.Color := clRed
  else
    lblStatus.Font.Color := clGreen;
end;

procedure TfraPromptTemplate.SetModified(Value: Boolean);
begin
  FIsModified := Value;
  if Value then
    lblStatus.Caption := '* Modified'
  else
    lblStatus.Caption := '';
end;

{ Event Handlers }

procedure TfraPromptTemplate.tvTemplatesChange(Sender: TObject; Node: TTreeNode);
begin
  if (Node = nil) or (Node.Parent = nil) then
  begin
    // Category node selected
    ClearEditor;
    Exit;
  end;
  
  if FIsModified then
  begin
    if MessageDlg('Save changes to current template?', mtConfirmation, [mbYes, mbNo, mbCancel], 0) = mrYes then
      SaveTemplate
    else if ModalResult = mrCancel then
    begin
      // Restore selection
      Exit;
    end;
  end;
  
  LoadTemplate(Node.Text);
end;

procedure TfraPromptTemplate.btnNewClick(Sender: TObject);
begin
  ClearEditor;
  edtName.SetFocus;
end;

procedure TfraPromptTemplate.btnDeleteClick(Sender: TObject);
begin
  if FCurrentTemplate.Name = '' then Exit;
  if FCurrentTemplate.IsBuiltIn then
  begin
    ShowMessage('Cannot delete built-in templates.');
    Exit;
  end;
  
  if MessageDlg('Delete template "' + FCurrentTemplate.Name + '"?', mtConfirmation, [mbYes, mbNo], 0) = mrYes then
  begin
    FLLM.DeleteTemplate(FCurrentTemplate.Name);
    ClearEditor;
    LoadTemplates;
  end;
end;

procedure TfraPromptTemplate.btnCopyClick(Sender: TObject);
var
  NewName: string;
begin
  if FCurrentTemplate.Name = '' then Exit;
  
  NewName := FCurrentTemplate.Name + '_copy';
  if InputQuery('Copy Template', 'New template name:', NewName) then
  begin
    if FLLM.CopyTemplate(FCurrentTemplate.Name, NewName) then
    begin
      LoadTemplates;
      LoadTemplate(NewName);
    end
    else
      ShowMessage('Failed to copy template. Name may already exist.');
  end;
end;

procedure TfraPromptTemplate.btnSaveClick(Sender: TObject);
begin
  SaveTemplate;
end;

procedure TfraPromptTemplate.btnCancelClick(Sender: TObject);
begin
  if FCurrentTemplate.Name <> '' then
    LoadTemplate(FCurrentTemplate.Name)
  else
    ClearEditor;
end;

procedure TfraPromptTemplate.btnAddVarClick(Sender: TObject);
begin
  sgVariables.RowCount := sgVariables.RowCount + 1;
  sgVariables.Row := sgVariables.RowCount - 1;
  sgVariables.Col := 0;
  SetModified(True);
end;

procedure TfraPromptTemplate.btnRemoveVarClick(Sender: TObject);
var
  I: Integer;
begin
  if sgVariables.Row <= 0 then Exit;
  if sgVariables.RowCount <= 2 then
  begin
    sgVariables.Cells[0, 1] := '';
    sgVariables.Cells[1, 1] := '';
    Exit;
  end;
  
  for I := sgVariables.Row to sgVariables.RowCount - 2 do
  begin
    sgVariables.Cells[0, I] := sgVariables.Cells[0, I + 1];
    sgVariables.Cells[1, I] := sgVariables.Cells[1, I + 1];
  end;
  sgVariables.RowCount := sgVariables.RowCount - 1;
  SetModified(True);
end;

procedure TfraPromptTemplate.btnRenderClick(Sender: TObject);
var
  Vars: TDictionary<string, string>;
  I: Integer;
  VarName, VarVal: string;
begin
  if FCurrentTemplate.Name = '' then Exit;
  
  Vars := TDictionary<string, string>.Create;
  try
    for I := 1 to sgTestVars.RowCount - 1 do
    begin
      VarName := Trim(sgTestVars.Cells[0, I]);
      VarVal := sgTestVars.Cells[1, I];
      if VarName <> '' then
        Vars.AddOrSetValue(VarName, VarVal);
    end;
    
    mmoRendered.Text := FLLM.RenderWithInheritance(FCurrentTemplate.Name, Vars);
  finally
    Vars.Free;
  end;
end;

procedure TfraPromptTemplate.btnExecuteClick(Sender: TObject);
var
  Vars: TDictionary<string, string>;
  I: Integer;
  VarName, VarVal: string;
  Response: string;
begin
  if FCurrentTemplate.Name = '' then Exit;
  
  mmoResponse.Text := 'Executing...';
  Application.ProcessMessages;
  
  Vars := TDictionary<string, string>.Create;
  try
    for I := 1 to sgTestVars.RowCount - 1 do
    begin
      VarName := Trim(sgTestVars.Cells[0, I]);
      VarVal := sgTestVars.Cells[1, I];
      if VarName <> '' then
        Vars.AddOrSetValue(VarName, VarVal);
    end;
    
    // Render first
    mmoRendered.Text := FLLM.RenderWithInheritance(FCurrentTemplate.Name, Vars);
    
    // Execute
    if FLLM.ExecuteTemplate(FCurrentTemplate.Name, Vars, Response) then
      mmoResponse.Text := Response
    else
      mmoResponse.Text := 'Error: ' + Response;
  finally
    Vars.Free;
  end;
end;

procedure TfraPromptTemplate.btnImportClick(Sender: TObject);
var
  Json: string;
  Stream: TStringList;
  Imported: Integer;
begin
  if not Assigned(FLLM) then Exit;
  
  if dlgOpen.Execute then
  begin
    Stream := TStringList.Create;
    try
      Stream.LoadFromFile(dlgOpen.FileName);
      Json := Stream.Text;
      
      Imported := FLLM.ImportTemplates(Json, False);
      ShowMessage(Format('Imported %d templates.', [Imported]));
      
      RefreshData;
    finally
      Stream.Free;
    end;
  end;
end;

procedure TfraPromptTemplate.btnExportClick(Sender: TObject);
var
  Json: string;
  Stream: TStringList;
begin
  if not Assigned(FLLM) then Exit;
  
  if dlgSave.Execute then
  begin
    Json := FLLM.ExportTemplates;
    
    Stream := TStringList.Create;
    try
      Stream.Text := Json;
      Stream.SaveToFile(dlgSave.FileName);
      ShowMessage('Templates exported successfully.');
    finally
      Stream.Free;
    end;
  end;
end;

procedure TfraPromptTemplate.edtFilterChange(Sender: TObject);
begin
  LoadTemplates;
end;

procedure TfraPromptTemplate.cboCategoryChange(Sender: TObject);
begin
  LoadTemplates;
end;

procedure TfraPromptTemplate.OnEditorChange(Sender: TObject);
begin
  SetModified(True);
end;

end.
