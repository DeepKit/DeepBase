{ ============================================================================
  Studio.PromptDebugForm - LLM Prompt Debugging Window
  
  Version: 1.0
  Description: Provides visual interface for prompt management and testing
  Features:
    - 4-level category tree
    - Prompt list and editor
    - Variable grid with 7 types
    - Meta-prompt binding
    - Send to LLM and view response
    - Version comparison (opens separate window)
  UI Design: docs/ui/svg/components/LLM_PromptDebugWindow.svg
  ============================================================================ }

unit Studio.PromptDebugForm;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Variants,
  System.Classes,
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
  DeepBase.LLM,
  DeepBase.LLM.Manager;

type
  TPromptDebugForm = class(TForm)
  private
    // === Left Panel ===
    FLeftPanel: TPanel;
    FSplitterLeft: TSplitter;
    
    // Category Tree (top of left panel)
    FCategoryPanel: TPanel;
    FCategoryTree: TTreeView;
    FBtnAddCategory: TButton;
    FBtnDelCategory: TButton;
    
    // Prompt List (bottom of left panel)
    FPromptListPanel: TPanel;
    FPromptListLabel: TLabel;
    FPromptListBox: TListBox;
    FBtnAddPrompt: TButton;
    FBtnDelPrompt: TButton;
    FSplitterLeftVert: TSplitter;
    
    // === Right Panel ===
    FRightPanel: TPanel;
    
    // Prompt Header
    FHeaderPanel: TPanel;
    FLblInternalCode: TLabel;
    FEdtInternalCode: TEdit;
    FLblName: TLabel;
    FEdtName: TEdit;
    FLblBoundQuery: TLabel;
    FEdtBoundQuery: TEdit;
    FChkActive: TCheckBox;
    
    // Description
    FDescPanel: TPanel;
    FLblDescription: TLabel;
    FMmoDescription: TMemo;
    
    // Variable Grid
    FVarPanel: TPanel;
    FLblVariables: TLabel;
    FVarGrid: TStringGrid;
    FBtnAddVar: TButton;
    FBtnDelVar: TButton;
    FCboVarType: TComboBox;
    
    // Meta-Prompts Binding
    FMetaPanel: TPanel;
    FLblMeta: TLabel;
    FMetaListBox: TCheckListBox;
    
    // Version Tabs
    FVersionPanel: TPanel;
    FVersionTabs: TTabControl;
    FMmoPromptContent: TMemo;
    FChkIsProduction: TCheckBox;
    FLblVersionStats: TLabel;
    
    // Action Panel
    FActionPanel: TPanel;
    FCboLLMConfig: TComboBox;
    FLblLLMConfig: TLabel;
    FBtnSend: TButton;
    FBtnCompareVersions: TButton;
    FBtnSavePrompt: TButton;
    FBtnPreview: TButton;
    
    // Response Panel
    FResponsePanel: TPanel;
    FLblResponse: TLabel;
    FMmoResponse: TMemo;
    FLblResponseStats: TLabel;
    
    // Status Bar
    FStatusBar: TStatusBar;
    
    // Internal State
    FConnection: TFDConnection;
    FLLMManager: TLLMManager;
    FOwnsManager: Boolean;
    FCurrentPrompt: TPrompt;
    FCurrentVersionNum: Integer;
    FModified: Boolean;
    FCategoryMap: TDictionary<Integer, TTreeNode>;  // CategoryId -> TreeNode
    
    procedure CreateControls;
    procedure CreateLeftPanel;
    procedure CreateRightPanel;
    procedure SetupVariableGrid;
    procedure SetupVersionTabs;
    
    // Data Loading
    procedure LoadCategories;
    procedure LoadCategoryNode(ParentNode: TTreeNode; ParentId: Integer);
    procedure LoadPromptList(CategoryId: Integer);
    procedure LoadPrompt(const InternalCode: string);
    procedure LoadVersionContent(VersionNum: Integer);
    procedure LoadMetaPromptBindings;
    procedure LoadLLMConfigs;
    
    // Data Saving
    procedure SaveCurrentPrompt;
    procedure SaveCurrentVersion;
    
    // Events
    procedure CategoryTreeChange(Sender: TObject; Node: TTreeNode);
    procedure PromptListClick(Sender: TObject);
    procedure VersionTabsChange(Sender: TObject);
    procedure VarGridSelectCell(Sender: TObject; ACol, ARow: Integer; var CanSelect: Boolean);
    procedure VarGridSetEditText(Sender: TObject; ACol, ARow: Integer; const Value: string);
    procedure VarGridDrawCell(Sender: TObject; ACol, ARow: Integer; Rect: TRect; State: TGridDrawState);
    
    procedure BtnAddCategoryClick(Sender: TObject);
    procedure BtnDelCategoryClick(Sender: TObject);
    procedure BtnAddPromptClick(Sender: TObject);
    procedure BtnDelPromptClick(Sender: TObject);
    procedure BtnAddVarClick(Sender: TObject);
    procedure BtnDelVarClick(Sender: TObject);
    procedure BtnSavePromptClick(Sender: TObject);
    procedure BtnSendClick(Sender: TObject);
    procedure BtnCompareVersionsClick(Sender: TObject);
    procedure BtnPreviewClick(Sender: TObject);
    procedure ChkIsProductionClick(Sender: TObject);
    procedure MetaListBoxClickCheck(Sender: TObject);
    procedure ContentChanged(Sender: TObject);
    
    procedure SetStatus(const Text: string; IsError: Boolean = False);
    procedure UpdateVersionStats;
    function GetSelectedCategoryId: Integer;
    function BuildVariablesFromGrid: TPromptVariableArray;
    procedure PopulateGridFromVariables(const Variables: TPromptVariableArray);
    function CollectVariableValues: TDictionary<string, Variant>;
    
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    
    procedure Initialize(AConnection: TFDConnection; ALLMManager: TLLMManager = nil);
    procedure RefreshData;
    
    property LLMManager: TLLMManager read FLLMManager;
    property Modified: Boolean read FModified;
  end;

var
  PromptDebugForm: TPromptDebugForm;

implementation

uses
  System.StrUtils,
  System.DateUtils;

const
  VAR_COL_NAME = 0;
  VAR_COL_TYPE = 1;
  VAR_COL_DEFAULT = 2;
  VAR_COL_VALUE = 3;
  VAR_COL_DESC = 4;
  VAR_COL_REQUIRED = 5;
  
  VAR_TYPES: array[0..6] of string = (
    'string', 'number', 'boolean', 'date', 'datetime', 'list', 'json'
  );

{ TPromptDebugForm }

constructor TPromptDebugForm.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  
  Caption := 'LLM Prompt Debug';
  Width := 1200;
  Height := 800;
  Position := poScreenCenter;
  
  FOwnsManager := False;
  FModified := False;
  FCurrentVersionNum := 1;
  FCategoryMap := TDictionary<Integer, TTreeNode>.Create;
  
  CreateControls;
end;

destructor TPromptDebugForm.Destroy;
begin
  // Clear event handlers
  if Assigned(FCategoryTree) then FCategoryTree.OnChange := nil;
  if Assigned(FPromptListBox) then FPromptListBox.OnClick := nil;
  if Assigned(FVersionTabs) then FVersionTabs.OnChange := nil;
  if Assigned(FVarGrid) then
  begin
    FVarGrid.OnSelectCell := nil;
    FVarGrid.OnSetEditText := nil;
    FVarGrid.OnDrawCell := nil;
  end;
  
  FCategoryMap.Free;
  
  if FOwnsManager and Assigned(FLLMManager) then
  begin
    FLLMManager.Free;
    FLLMManager := nil;
  end;
  
  inherited;
end;

procedure TPromptDebugForm.CreateControls;
begin
  // Status Bar
  FStatusBar := TStatusBar.Create(Self);
  FStatusBar.Parent := Self;
  FStatusBar.SimplePanel := True;
  FStatusBar.SimpleText := 'Ready';
  
  // Main splitter layout
  CreateLeftPanel;
  CreateRightPanel;
end;

procedure TPromptDebugForm.CreateLeftPanel;
begin
  FLeftPanel := TPanel.Create(Self);
  FLeftPanel.Parent := Self;
  FLeftPanel.Align := alLeft;
  FLeftPanel.Width := 280;
  FLeftPanel.BevelOuter := bvNone;
  
  FSplitterLeft := TSplitter.Create(Self);
  FSplitterLeft.Parent := Self;
  FSplitterLeft.Left := FLeftPanel.Width;
  FSplitterLeft.Width := 5;
  
  // === Category Tree Panel (Top) ===
  FCategoryPanel := TPanel.Create(Self);
  FCategoryPanel.Parent := FLeftPanel;
  FCategoryPanel.Align := alTop;
  FCategoryPanel.Height := 350;
  FCategoryPanel.BevelOuter := bvNone;
  FCategoryPanel.Caption := '';
  
  // Category buttons
  FBtnAddCategory := TButton.Create(Self);
  FBtnAddCategory.Parent := FCategoryPanel;
  FBtnAddCategory.SetBounds(5, 5, 60, 24);
  FBtnAddCategory.Caption := '+ Cat';
  FBtnAddCategory.OnClick := BtnAddCategoryClick;
  
  FBtnDelCategory := TButton.Create(Self);
  FBtnDelCategory.Parent := FCategoryPanel;
  FBtnDelCategory.SetBounds(70, 5, 60, 24);
  FBtnDelCategory.Caption := '- Cat';
  FBtnDelCategory.OnClick := BtnDelCategoryClick;
  
  // Category Tree
  FCategoryTree := TTreeView.Create(Self);
  FCategoryTree.Parent := FCategoryPanel;
  FCategoryTree.SetBounds(5, 34, 270, 310);
  FCategoryTree.Anchors := [akLeft, akTop, akRight, akBottom];
  FCategoryTree.ReadOnly := True;
  FCategoryTree.HideSelection := False;
  FCategoryTree.OnChange := CategoryTreeChange;
  
  // === Splitter ===
  FSplitterLeftVert := TSplitter.Create(Self);
  FSplitterLeftVert.Parent := FLeftPanel;
  FSplitterLeftVert.Align := alTop;
  FSplitterLeftVert.Top := FCategoryPanel.Height;
  FSplitterLeftVert.Height := 5;
  FSplitterLeftVert.Cursor := crVSplit;
  
  // === Prompt List Panel (Bottom) ===
  FPromptListPanel := TPanel.Create(Self);
  FPromptListPanel.Parent := FLeftPanel;
  FPromptListPanel.Align := alClient;
  FPromptListPanel.BevelOuter := bvNone;
  FPromptListPanel.Caption := '';
  
  FPromptListLabel := TLabel.Create(Self);
  FPromptListLabel.Parent := FPromptListPanel;
  FPromptListLabel.SetBounds(5, 5, 200, 16);
  FPromptListLabel.Caption := 'Prompts in Category:';
  
  // Prompt buttons
  FBtnAddPrompt := TButton.Create(Self);
  FBtnAddPrompt.Parent := FPromptListPanel;
  FBtnAddPrompt.SetBounds(5, 24, 60, 24);
  FBtnAddPrompt.Caption := '+ New';
  FBtnAddPrompt.OnClick := BtnAddPromptClick;
  
  FBtnDelPrompt := TButton.Create(Self);
  FBtnDelPrompt.Parent := FPromptListPanel;
  FBtnDelPrompt.SetBounds(70, 24, 60, 24);
  FBtnDelPrompt.Caption := '- Del';
  FBtnDelPrompt.OnClick := BtnDelPromptClick;
  
  // Prompt List
  FPromptListBox := TListBox.Create(Self);
  FPromptListBox.Parent := FPromptListPanel;
  FPromptListBox.SetBounds(5, 52, 270, 200);
  FPromptListBox.Anchors := [akLeft, akTop, akRight, akBottom];
  FPromptListBox.OnClick := PromptListClick;
end;

procedure TPromptDebugForm.CreateRightPanel;
begin
  FRightPanel := TPanel.Create(Self);
  FRightPanel.Parent := Self;
  FRightPanel.Align := alClient;
  FRightPanel.BevelOuter := bvNone;
  FRightPanel.Caption := '';
  
  // === Header Panel ===
  FHeaderPanel := TPanel.Create(Self);
  FHeaderPanel.Parent := FRightPanel;
  FHeaderPanel.Align := alTop;
  FHeaderPanel.Height := 70;
  FHeaderPanel.BevelOuter := bvNone;
  
  FLblInternalCode := TLabel.Create(Self);
  FLblInternalCode.Parent := FHeaderPanel;
  FLblInternalCode.SetBounds(10, 10, 80, 16);
  FLblInternalCode.Caption := 'Internal Code:';
  
  FEdtInternalCode := TEdit.Create(Self);
  FEdtInternalCode.Parent := FHeaderPanel;
  FEdtInternalCode.SetBounds(95, 6, 100, 24);
  FEdtInternalCode.OnChange := ContentChanged;
  
  FLblName := TLabel.Create(Self);
  FLblName.Parent := FHeaderPanel;
  FLblName.SetBounds(210, 10, 40, 16);
  FLblName.Caption := 'Name:';
  
  FEdtName := TEdit.Create(Self);
  FEdtName.Parent := FHeaderPanel;
  FEdtName.SetBounds(255, 6, 200, 24);
  FEdtName.OnChange := ContentChanged;
  
  FChkActive := TCheckBox.Create(Self);
  FChkActive.Parent := FHeaderPanel;
  FChkActive.SetBounds(470, 8, 60, 20);
  FChkActive.Caption := 'Active';
  FChkActive.Checked := True;
  FChkActive.OnClick := ContentChanged;
  
  FLblBoundQuery := TLabel.Create(Self);
  FLblBoundQuery.Parent := FHeaderPanel;
  FLblBoundQuery.SetBounds(10, 42, 80, 16);
  FLblBoundQuery.Caption := 'BoundQuery:';
  
  FEdtBoundQuery := TEdit.Create(Self);
  FEdtBoundQuery.Parent := FHeaderPanel;
  FEdtBoundQuery.SetBounds(95, 38, 200, 24);
  FEdtBoundQuery.OnChange := ContentChanged;
  
  // === Description Panel ===
  FDescPanel := TPanel.Create(Self);
  FDescPanel.Parent := FRightPanel;
  FDescPanel.Align := alTop;
  FDescPanel.Top := FHeaderPanel.Height;
  FDescPanel.Height := 70;
  FDescPanel.BevelOuter := bvNone;
  
  FLblDescription := TLabel.Create(Self);
  FLblDescription.Parent := FDescPanel;
  FLblDescription.SetBounds(10, 5, 80, 16);
  FLblDescription.Caption := 'Description:';
  
  FMmoDescription := TMemo.Create(Self);
  FMmoDescription.Parent := FDescPanel;
  FMmoDescription.SetBounds(10, 22, 870, 42);
  FMmoDescription.Anchors := [akLeft, akTop, akRight];
  FMmoDescription.ScrollBars := ssVertical;
  FMmoDescription.OnChange := ContentChanged;
  
  // === Variable Grid Panel ===
  FVarPanel := TPanel.Create(Self);
  FVarPanel.Parent := FRightPanel;
  FVarPanel.Align := alTop;
  FVarPanel.Top := FHeaderPanel.Height + FDescPanel.Height;
  FVarPanel.Height := 130;
  FVarPanel.BevelOuter := bvNone;
  
  FLblVariables := TLabel.Create(Self);
  FLblVariables.Parent := FVarPanel;
  FLblVariables.SetBounds(10, 5, 60, 16);
  FLblVariables.Caption := 'Variables:';
  
  FBtnAddVar := TButton.Create(Self);
  FBtnAddVar.Parent := FVarPanel;
  FBtnAddVar.SetBounds(80, 2, 50, 22);
  FBtnAddVar.Caption := '+';
  FBtnAddVar.OnClick := BtnAddVarClick;
  
  FBtnDelVar := TButton.Create(Self);
  FBtnDelVar.Parent := FVarPanel;
  FBtnDelVar.SetBounds(135, 2, 50, 22);
  FBtnDelVar.Caption := '-';
  FBtnDelVar.OnClick := BtnDelVarClick;
  
  // Hidden combo for type selection
  FCboVarType := TComboBox.Create(Self);
  FCboVarType.Parent := FVarPanel;
  FCboVarType.Visible := False;
  FCboVarType.Style := csDropDownList;
  FCboVarType.Items.AddStrings(VAR_TYPES);
  
  SetupVariableGrid;
  
  // === Meta-Prompt Binding Panel ===
  FMetaPanel := TPanel.Create(Self);
  FMetaPanel.Parent := FRightPanel;
  FMetaPanel.Align := alTop;
  FMetaPanel.Top := FHeaderPanel.Height + FDescPanel.Height + FVarPanel.Height;
  FMetaPanel.Height := 80;
  FMetaPanel.BevelOuter := bvNone;
  
  FLblMeta := TLabel.Create(Self);
  FLblMeta.Parent := FMetaPanel;
  FLblMeta.SetBounds(10, 5, 100, 16);
  FLblMeta.Caption := 'Meta-Prompts:';
  
  FMetaListBox := TCheckListBox.Create(Self);
  FMetaListBox.Parent := FMetaPanel;
  FMetaListBox.SetBounds(10, 22, 870, 52);
  FMetaListBox.Anchors := [akLeft, akTop, akRight];
  FMetaListBox.Columns := 3;
  FMetaListBox.OnClickCheck := MetaListBoxClickCheck;
  
  // === Version Panel ===
  FVersionPanel := TPanel.Create(Self);
  FVersionPanel.Parent := FRightPanel;
  FVersionPanel.Align := alTop;
  FVersionPanel.Top := FHeaderPanel.Height + FDescPanel.Height + FVarPanel.Height + FMetaPanel.Height;
  FVersionPanel.Height := 200;
  FVersionPanel.BevelOuter := bvNone;
  
  SetupVersionTabs;
  
  // === Action Panel ===
  FActionPanel := TPanel.Create(Self);
  FActionPanel.Parent := FRightPanel;
  FActionPanel.Align := alTop;
  FActionPanel.Top := FVersionPanel.Top + FVersionPanel.Height;
  FActionPanel.Height := 40;
  FActionPanel.BevelOuter := bvNone;
  
  FLblLLMConfig := TLabel.Create(Self);
  FLblLLMConfig.Parent := FActionPanel;
  FLblLLMConfig.SetBounds(10, 12, 70, 16);
  FLblLLMConfig.Caption := 'LLM Config:';
  
  FCboLLMConfig := TComboBox.Create(Self);
  FCboLLMConfig.Parent := FActionPanel;
  FCboLLMConfig.SetBounds(85, 8, 150, 24);
  FCboLLMConfig.Style := csDropDownList;
  
  FBtnSend := TButton.Create(Self);
  FBtnSend.Parent := FActionPanel;
  FBtnSend.SetBounds(250, 6, 80, 28);
  FBtnSend.Caption := 'Send';
  FBtnSend.Font.Style := [fsBold];
  FBtnSend.OnClick := BtnSendClick;
  
  FBtnPreview := TButton.Create(Self);
  FBtnPreview.Parent := FActionPanel;
  FBtnPreview.SetBounds(340, 6, 80, 28);
  FBtnPreview.Caption := 'Preview';
  FBtnPreview.OnClick := BtnPreviewClick;
  
  FBtnCompareVersions := TButton.Create(Self);
  FBtnCompareVersions.Parent := FActionPanel;
  FBtnCompareVersions.SetBounds(430, 6, 120, 28);
  FBtnCompareVersions.Caption := 'Compare Versions';
  FBtnCompareVersions.OnClick := BtnCompareVersionsClick;
  
  FBtnSavePrompt := TButton.Create(Self);
  FBtnSavePrompt.Parent := FActionPanel;
  FBtnSavePrompt.SetBounds(560, 6, 80, 28);
  FBtnSavePrompt.Caption := 'Save';
  FBtnSavePrompt.OnClick := BtnSavePromptClick;
  
  // === Response Panel ===
  FResponsePanel := TPanel.Create(Self);
  FResponsePanel.Parent := FRightPanel;
  FResponsePanel.Align := alClient;
  FResponsePanel.BevelOuter := bvNone;
  
  FLblResponse := TLabel.Create(Self);
  FLblResponse.Parent := FResponsePanel;
  FLblResponse.SetBounds(10, 5, 80, 16);
  FLblResponse.Caption := 'LLM Response:';
  
  FLblResponseStats := TLabel.Create(Self);
  FLblResponseStats.Parent := FResponsePanel;
  FLblResponseStats.SetBounds(110, 5, 400, 16);
  FLblResponseStats.Caption := '';
  FLblResponseStats.Font.Color := clGray;
  
  FMmoResponse := TMemo.Create(Self);
  FMmoResponse.Parent := FResponsePanel;
  FMmoResponse.SetBounds(10, 24, 870, 150);
  FMmoResponse.Anchors := [akLeft, akTop, akRight, akBottom];
  FMmoResponse.ScrollBars := ssBoth;
  FMmoResponse.ReadOnly := True;
  FMmoResponse.Font.Name := 'Consolas';
  FMmoResponse.Font.Size := 10;
end;

procedure TPromptDebugForm.SetupVariableGrid;
begin
  FVarGrid := TStringGrid.Create(Self);
  FVarGrid.Parent := FVarPanel;
  FVarGrid.SetBounds(10, 26, 870, 98);
  FVarGrid.Anchors := [akLeft, akTop, akRight, akBottom];
  FVarGrid.ColCount := 6;
  FVarGrid.RowCount := 2;
  FVarGrid.FixedRows := 1;
  FVarGrid.FixedCols := 0;
  FVarGrid.DefaultRowHeight := 22;
  FVarGrid.Options := FVarGrid.Options + [goEditing, goRowSelect, goThumbTracking];
  FVarGrid.OnSelectCell := VarGridSelectCell;
  FVarGrid.OnSetEditText := VarGridSetEditText;
  FVarGrid.OnDrawCell := VarGridDrawCell;
  
  // Column headers
  FVarGrid.Cells[VAR_COL_NAME, 0] := 'Name';
  FVarGrid.Cells[VAR_COL_TYPE, 0] := 'Type';
  FVarGrid.Cells[VAR_COL_DEFAULT, 0] := 'Default';
  FVarGrid.Cells[VAR_COL_VALUE, 0] := 'Test Value';
  FVarGrid.Cells[VAR_COL_DESC, 0] := 'Description';
  FVarGrid.Cells[VAR_COL_REQUIRED, 0] := 'Req';
  
  // Column widths
  FVarGrid.ColWidths[VAR_COL_NAME] := 100;
  FVarGrid.ColWidths[VAR_COL_TYPE] := 80;
  FVarGrid.ColWidths[VAR_COL_DEFAULT] := 100;
  FVarGrid.ColWidths[VAR_COL_VALUE] := 150;
  FVarGrid.ColWidths[VAR_COL_DESC] := 250;
  FVarGrid.ColWidths[VAR_COL_REQUIRED] := 40;
end;

procedure TPromptDebugForm.SetupVersionTabs;
begin
  FVersionTabs := TTabControl.Create(Self);
  FVersionTabs.Parent := FVersionPanel;
  FVersionTabs.SetBounds(10, 5, 870, 190);
  FVersionTabs.Anchors := [akLeft, akTop, akRight, akBottom];
  FVersionTabs.Tabs.Add('V1');
  FVersionTabs.Tabs.Add('V2');
  FVersionTabs.Tabs.Add('V3');
  FVersionTabs.Tabs.Add('V4');
  FVersionTabs.TabIndex := 0;
  FVersionTabs.OnChange := VersionTabsChange;
  
  FChkIsProduction := TCheckBox.Create(Self);
  FChkIsProduction.Parent := FVersionTabs;
  FChkIsProduction.SetBounds(10, 30, 100, 20);
  FChkIsProduction.Caption := 'Production';
  FChkIsProduction.OnClick := ChkIsProductionClick;
  
  FLblVersionStats := TLabel.Create(Self);
  FLblVersionStats.Parent := FVersionTabs;
  FLblVersionStats.SetBounds(120, 32, 400, 16);
  FLblVersionStats.Caption := '';
  FLblVersionStats.Font.Color := clGray;
  
  FMmoPromptContent := TMemo.Create(Self);
  FMmoPromptContent.Parent := FVersionTabs;
  FMmoPromptContent.SetBounds(10, 55, 845, 125);
  FMmoPromptContent.Anchors := [akLeft, akTop, akRight, akBottom];
  FMmoPromptContent.ScrollBars := ssBoth;
  FMmoPromptContent.Font.Name := 'Consolas';
  FMmoPromptContent.Font.Size := 10;
  FMmoPromptContent.OnChange := ContentChanged;
end;

procedure TPromptDebugForm.Initialize(AConnection: TFDConnection; ALLMManager: TLLMManager);
begin
  FConnection := AConnection;
  
  if Assigned(ALLMManager) then
  begin
    FLLMManager := ALLMManager;
    FOwnsManager := False;
  end
  else if Assigned(FConnection) and FConnection.Connected then
  begin
    FLLMManager := TLLMManager.Create(FConnection, False);
    FLLMManager.Initialize;
    FOwnsManager := True;
  end;
  
  RefreshData;
end;

procedure TPromptDebugForm.RefreshData;
begin
  if not Assigned(FLLMManager) then
  begin
    SetStatus('No LLM Manager - open database first', True);
    Exit;
  end;
  
  FLLMManager.RefreshCache;
  LoadCategories;
  LoadLLMConfigs;
  LoadMetaPromptBindings;
  
  SetStatus('Data loaded');
end;

procedure TPromptDebugForm.LoadCategories;
begin
  FCategoryTree.Items.Clear;
  FCategoryMap.Clear;
  
  if not Assigned(FLLMManager) then Exit;
  
  // Load root categories (Level 1)
  LoadCategoryNode(nil, 0);
  
  // Expand first level
  if FCategoryTree.Items.Count > 0 then
  begin
    FCategoryTree.Items[0].Expand(False);
    FCategoryTree.Selected := FCategoryTree.Items[0];
  end;
end;

procedure TPromptDebugForm.LoadCategoryNode(ParentNode: TTreeNode; ParentId: Integer);
var
  Categories: TPromptCategoryArray;
  Cat: TPromptCategory;
  Node: TTreeNode;
begin
  if ParentId = 0 then
    Categories := FLLMManager.GetCategoriesByLevel(1)
  else
    Categories := FLLMManager.GetChildCategories(ParentId);
    
  for Cat in Categories do
  begin
    if ParentNode = nil then
      Node := FCategoryTree.Items.Add(nil, Cat.Name)
    else
      Node := FCategoryTree.Items.AddChild(ParentNode, Cat.Name);
      
    Node.Data := Pointer(Cat.Id);
    FCategoryMap.AddOrSetValue(Cat.Id, Node);
    
    // Recursively load children
    if Cat.Level < 4 then
      LoadCategoryNode(Node, Cat.Id);
  end;
end;

procedure TPromptDebugForm.LoadPromptList(CategoryId: Integer);
var
  Prompts: TPromptArray;
  P: TPrompt;
begin
  FPromptListBox.Items.Clear;
  
  if not Assigned(FLLMManager) or (CategoryId <= 0) then Exit;
  
  Prompts := FLLMManager.GetPromptsByCategory(CategoryId);
  for P in Prompts do
    FPromptListBox.Items.AddObject(P.Name, TObject(NativeInt(PChar(P.InternalCode))));
    
  // Also store internal codes
  FPromptListBox.Items.BeginUpdate;
  try
    FPromptListBox.Items.Clear;
    for P in Prompts do
      FPromptListBox.Items.Add(Format('%s [%s]', [P.Name, P.InternalCode]));
  finally
    FPromptListBox.Items.EndUpdate;
  end;
  
  FPromptListLabel.Caption := Format('Prompts in Category (%d):', [Length(Prompts)]);
end;

procedure TPromptDebugForm.LoadPrompt(const InternalCode: string);
var
  V: TPromptVersion;
begin
  if not Assigned(FLLMManager) then Exit;
  
  FCurrentPrompt := FLLMManager.GetPrompt(InternalCode);
  if FCurrentPrompt.Id = 0 then
  begin
    SetStatus('Prompt not found: ' + InternalCode, True);
    Exit;
  end;
  
  // Header
  FEdtInternalCode.Text := FCurrentPrompt.InternalCode;
  FEdtName.Text := FCurrentPrompt.Name;
  FEdtBoundQuery.Text := FCurrentPrompt.BoundQueryName;
  FChkActive.Checked := FCurrentPrompt.IsActive;
  
  // Description
  FMmoDescription.Text := FCurrentPrompt.Description;
  
  // Variables
  PopulateGridFromVariables(FCurrentPrompt.Variables);
  
  // Meta-prompts
  LoadMetaPromptBindings;
  
  // Version tabs - determine production version
  FCurrentVersionNum := FCurrentPrompt.GetProductionVersion;
  if FCurrentVersionNum = 0 then
    FCurrentVersionNum := 1;
    
  FVersionTabs.TabIndex := FCurrentVersionNum - 1;
  LoadVersionContent(FCurrentVersionNum);
  
  FModified := False;
  SetStatus(Format('Loaded: %s', [FCurrentPrompt.Name]));
end;

procedure TPromptDebugForm.LoadVersionContent(VersionNum: Integer);
var
  V: TPromptVersion;
begin
  FCurrentVersionNum := VersionNum;
  V := FCurrentPrompt.GetVersion(VersionNum);
  
  if V.VersionNumber > 0 then
  begin
    FMmoPromptContent.Text := V.Content;
    FChkIsProduction.Checked := V.IsProduction;
    UpdateVersionStats;
  end
  else
  begin
    FMmoPromptContent.Clear;
    FChkIsProduction.Checked := False;
    FLblVersionStats.Caption := '(No content for this version)';
  end;
end;

procedure TPromptDebugForm.LoadMetaPromptBindings;
var
  MetaPrompts: TMetaPromptArray;
  Meta, BoundMeta: TMetaPrompt;
  I: Integer;
  IsBound: Boolean;
begin
  FMetaListBox.Items.Clear;
  
  if not Assigned(FLLMManager) then Exit;
  
  MetaPrompts := FLLMManager.GetMetaPrompts;
  
  for Meta in MetaPrompts do
  begin
    FMetaListBox.Items.AddObject(
      Format('%s [%s] (%s)', [Meta.Name, Meta.InternalCode, Meta.MergeModeToStr]),
      TObject(Meta.Id)
    );
    
    // Check if bound to current prompt
    IsBound := False;
    if FCurrentPrompt.Id > 0 then
    begin
      for BoundMeta in FCurrentPrompt.MetaPrompts do
        if BoundMeta.Id = Meta.Id then
        begin
          IsBound := True;
          Break;
        end;
    end;
    
    FMetaListBox.Checked[FMetaListBox.Items.Count - 1] := IsBound;
  end;
end;

procedure TPromptDebugForm.LoadLLMConfigs;
var
  Configs: TLLMConfigArray;
  Cfg: TLLMConfig;
begin
  FCboLLMConfig.Items.Clear;
  
  if not Assigned(FLLMManager) then Exit;
  
  Configs := FLLMManager.LLMClient.GetAllConfigs;
  for Cfg in Configs do
    FCboLLMConfig.Items.Add(Cfg.Name);
    
  if FCboLLMConfig.Items.Count = 0 then
    FCboLLMConfig.Items.Add('Default');
    
  FCboLLMConfig.ItemIndex := 0;
end;

procedure TPromptDebugForm.SaveCurrentPrompt;
var
  V: TPromptVersion;
begin
  if not Assigned(FLLMManager) then Exit;
  
  // Update prompt from UI
  FCurrentPrompt.InternalCode := FEdtInternalCode.Text;
  FCurrentPrompt.Name := FEdtName.Text;
  FCurrentPrompt.Description := FMmoDescription.Text;
  FCurrentPrompt.BoundQueryName := FEdtBoundQuery.Text;
  FCurrentPrompt.IsActive := FChkActive.Checked;
  FCurrentPrompt.Variables := BuildVariablesFromGrid;
  
  // Get category from tree
  FCurrentPrompt.CategoryId := GetSelectedCategoryId;
  
  FLLMManager.SavePrompt(FCurrentPrompt);
  
  // Save current version content
  SaveCurrentVersion;
  
  FModified := False;
  SetStatus('Prompt saved: ' + FCurrentPrompt.Name);
end;

procedure TPromptDebugForm.SaveCurrentVersion;
var
  V: TPromptVersion;
begin
  if (FCurrentPrompt.Id = 0) or (FMmoPromptContent.Text = '') then Exit;
  
  V := FCurrentPrompt.GetVersion(FCurrentVersionNum);
  if V.VersionNumber = 0 then
  begin
    // Create new version
    V.VersionNumber := FCurrentVersionNum;
    V.PromptId := FCurrentPrompt.Id;
  end;
  
  V.Content := FMmoPromptContent.Text;
  V.IsProduction := FChkIsProduction.Checked;
  
  FLLMManager.SaveVersion(FCurrentPrompt.InternalCode, V);
end;

// === Event Handlers ===

procedure TPromptDebugForm.CategoryTreeChange(Sender: TObject; Node: TTreeNode);
var
  CategoryId: Integer;
begin
  if Node = nil then Exit;
  
  CategoryId := Integer(Node.Data);
  LoadPromptList(CategoryId);
end;

procedure TPromptDebugForm.PromptListClick(Sender: TObject);
var
  S, Code: string;
  P1, P2: Integer;
begin
  if FPromptListBox.ItemIndex < 0 then Exit;
  
  // Extract internal code from "Name [CODE]" format
  S := FPromptListBox.Items[FPromptListBox.ItemIndex];
  P1 := Pos('[', S);
  P2 := Pos(']', S);
  if (P1 > 0) and (P2 > P1) then
  begin
    Code := Copy(S, P1 + 1, P2 - P1 - 1);
    LoadPrompt(Code);
  end;
end;

procedure TPromptDebugForm.VersionTabsChange(Sender: TObject);
begin
  // Save current version before switching
  if FModified and (FCurrentPrompt.Id > 0) then
    SaveCurrentVersion;
    
  LoadVersionContent(FVersionTabs.TabIndex + 1);
end;

procedure TPromptDebugForm.VarGridSelectCell(Sender: TObject; ACol, ARow: Integer; var CanSelect: Boolean);
begin
  CanSelect := ARow > 0; // Can edit data rows only
end;

procedure TPromptDebugForm.VarGridSetEditText(Sender: TObject; ACol, ARow: Integer; const Value: string);
begin
  if ARow > 0 then
    FModified := True;
end;

procedure TPromptDebugForm.VarGridDrawCell(Sender: TObject; ACol, ARow: Integer; Rect: TRect; State: TGridDrawState);
var
  Grid: TStringGrid;
  S: string;
  TypeStr: string;
begin
  Grid := TStringGrid(Sender);
  
  // Custom draw for Type column and Required column
  if (ARow > 0) and (ACol = VAR_COL_TYPE) then
  begin
    // Draw type with color coding
    TypeStr := Grid.Cells[ACol, ARow];
    Grid.Canvas.FillRect(Rect);
    
    if TypeStr = 'string' then Grid.Canvas.Font.Color := clBlue
    else if TypeStr = 'number' then Grid.Canvas.Font.Color := clGreen
    else if TypeStr = 'boolean' then Grid.Canvas.Font.Color := clMaroon
    else if TypeStr = 'json' then Grid.Canvas.Font.Color := clPurple
    else Grid.Canvas.Font.Color := clBlack;
    
    Grid.Canvas.TextRect(Rect, Rect.Left + 2, Rect.Top + 2, TypeStr);
  end
  else if (ARow > 0) and (ACol = VAR_COL_REQUIRED) then
  begin
    // Draw checkbox style
    Grid.Canvas.FillRect(Rect);
    S := Grid.Cells[ACol, ARow];
    if (S = '1') or (S = 'Y') or (S = 'Yes') or (S = 'true') then
      Grid.Canvas.TextRect(Rect, Rect.Left + 10, Rect.Top + 2, 'âœ?)
    else
      Grid.Canvas.TextRect(Rect, Rect.Left + 10, Rect.Top + 2, 'â—?);
  end;
end;

procedure TPromptDebugForm.BtnAddCategoryClick(Sender: TObject);
var
  ParentId: Integer;
  ParentNode: TTreeNode;
  Cat: TPromptCategory;
  NewName: string;
  Level: Integer;
begin
  if not Assigned(FLLMManager) then Exit;
  
  ParentNode := FCategoryTree.Selected;
  if ParentNode = nil then
  begin
    ParentId := 0;
    Level := 1;
  end
  else
  begin
    ParentId := Integer(ParentNode.Data);
    // Get parent level
    Level := 1;
    var TempNode := ParentNode;
    while TempNode.Parent <> nil do
    begin
      Inc(Level);
      TempNode := TempNode.Parent;
    end;
    Inc(Level); // Child level
  end;
  
  if Level > 4 then
  begin
    ShowMessage('Maximum 4 levels of categories allowed.');
    Exit;
  end;
  
  NewName := InputBox('New Category', 'Enter category name:', '');
  if NewName = '' then Exit;
  
  Cat.Id := 0;
  Cat.ParentId := ParentId;
  Cat.Level := Level;
  Cat.Code := Format('%02d', [FCategoryTree.Items.Count + 1]);
  Cat.Name := NewName;
  Cat.Description := '';
  Cat.SortOrder := 0;
  Cat.IsActive := True;
  
  FLLMManager.SaveCategory(Cat);
  LoadCategories;
  SetStatus('Category created: ' + NewName);
end;

procedure TPromptDebugForm.BtnDelCategoryClick(Sender: TObject);
var
  Node: TTreeNode;
  CategoryId: Integer;
begin
  if not Assigned(FLLMManager) then Exit;
  
  Node := FCategoryTree.Selected;
  if Node = nil then Exit;
  
  if MessageDlg('Delete this category and all its children?', mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    Exit;
  
  CategoryId := Integer(Node.Data);
  FLLMManager.DeleteCategory(CategoryId);
  LoadCategories;
  SetStatus('Category deleted');
end;

procedure TPromptDebugForm.BtnAddPromptClick(Sender: TObject);
var
  CategoryId: Integer;
  NewCode, NewName: string;
begin
  if not Assigned(FLLMManager) then Exit;
  
  CategoryId := GetSelectedCategoryId;
  if CategoryId <= 0 then
  begin
    ShowMessage('Please select a category first.');
    Exit;
  end;
  
  NewCode := InputBox('New Prompt', 'Enter internal code (e.g. 01-01-001):', '');
  if NewCode = '' then Exit;
  
  if FLLMManager.PromptExists(NewCode) then
  begin
    ShowMessage('Prompt with this code already exists.');
    Exit;
  end;
  
  NewName := InputBox('New Prompt', 'Enter prompt name:', '');
  if NewName = '' then Exit;
  
  FCurrentPrompt.Id := 0;
  FCurrentPrompt.CategoryId := CategoryId;
  FCurrentPrompt.InternalCode := NewCode;
  FCurrentPrompt.Name := NewName;
  FCurrentPrompt.Description := '';
  FCurrentPrompt.BoundQueryName := '';
  FCurrentPrompt.IsActive := True;
  SetLength(FCurrentPrompt.Variables, 0);
  SetLength(FCurrentPrompt.Versions, 0);
  SetLength(FCurrentPrompt.MetaPrompts, 0);
  
  FLLMManager.SavePrompt(FCurrentPrompt);
  
  LoadPromptList(CategoryId);
  LoadPrompt(NewCode);
  SetStatus('Prompt created: ' + NewName);
end;

procedure TPromptDebugForm.BtnDelPromptClick(Sender: TObject);
begin
  if not Assigned(FLLMManager) then Exit;
  if FCurrentPrompt.Id = 0 then Exit;
  
  if MessageDlg(Format('Delete prompt "%s"?', [FCurrentPrompt.Name]), 
     mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    Exit;
  
  FLLMManager.DeletePrompt(FCurrentPrompt.InternalCode);
  
  FCurrentPrompt.Id := 0;
  FEdtInternalCode.Clear;
  FEdtName.Clear;
  FMmoDescription.Clear;
  FMmoPromptContent.Clear;
  
  LoadPromptList(GetSelectedCategoryId);
  SetStatus('Prompt deleted');
end;

procedure TPromptDebugForm.BtnAddVarClick(Sender: TObject);
begin
  FVarGrid.RowCount := FVarGrid.RowCount + 1;
  FVarGrid.Cells[VAR_COL_TYPE, FVarGrid.RowCount - 1] := 'string';
  FVarGrid.Cells[VAR_COL_REQUIRED, FVarGrid.RowCount - 1] := '0';
  FModified := True;
end;

procedure TPromptDebugForm.BtnDelVarClick(Sender: TObject);
var
  Row, I: Integer;
begin
  Row := FVarGrid.Row;
  if Row <= 0 then Exit;
  
  if FVarGrid.RowCount <= 2 then
  begin
    // Clear the row instead of deleting
    for I := 0 to FVarGrid.ColCount - 1 do
      FVarGrid.Cells[I, 1] := '';
  end
  else
  begin
    // Shift rows up
    for I := Row to FVarGrid.RowCount - 2 do
      FVarGrid.Rows[I].Assign(FVarGrid.Rows[I + 1]);
    FVarGrid.RowCount := FVarGrid.RowCount - 1;
  end;
  
  FModified := True;
end;

procedure TPromptDebugForm.BtnSavePromptClick(Sender: TObject);
begin
  SaveCurrentPrompt;
end;

procedure TPromptDebugForm.BtnSendClick(Sender: TObject);
var
  Response: TLLMResponse;
  Params: TDictionary<string, Variant>;
  ConfigName: string;
begin
  if not Assigned(FLLMManager) then
  begin
    SetStatus('No LLM Manager', True);
    Exit;
  end;
  
  if FCurrentPrompt.Id = 0 then
  begin
    SetStatus('No prompt selected', True);
    Exit;
  end;
  
  // Save first
  SaveCurrentPrompt;
  
  // Collect variable values from grid
  Params := CollectVariableValues;
  try
    ConfigName := FCboLLMConfig.Text;
    if ConfigName = '' then ConfigName := 'Default';
    
    SetStatus('Sending to LLM...');
    FMmoResponse.Clear;
    Application.ProcessMessages;
    
    Response := FLLMManager.Execute(FCurrentPrompt.InternalCode, Params, FCurrentVersionNum, ConfigName);
    
    if Response.Success then
    begin
      FMmoResponse.Text := Response.Content;
      FLblResponseStats.Caption := Format('Tokens: %d in / %d out | Time: %d ms | Cost: $%.4f',
        [Response.InputTokens, Response.OutputTokens, Response.DurationMs, Response.Cost]);
      SetStatus('Response received');
    end
    else
    begin
      FMmoResponse.Text := 'ERROR: ' + Response.ErrorMessage;
      FLblResponseStats.Caption := Format('Failed after %d ms', [Response.DurationMs]);
      SetStatus('LLM call failed', True);
    end;
    
    // Refresh to show updated stats
    FLLMManager.RefreshCache;
    FCurrentPrompt := FLLMManager.GetPrompt(FCurrentPrompt.InternalCode);
    UpdateVersionStats;
  finally
    Params.Free;
  end;
end;

procedure TPromptDebugForm.BtnPreviewClick(Sender: TObject);
var
  Params: TDictionary<string, Variant>;
  FinalPrompt: string;
begin
  if not Assigned(FLLMManager) then Exit;
  if FCurrentPrompt.Id = 0 then Exit;
  
  // Save first
  SaveCurrentPrompt;
  
  Params := CollectVariableValues;
  try
    FinalPrompt := FLLMManager.BuildFinalPrompt(FCurrentPrompt.InternalCode, Params, FCurrentVersionNum);
    
    // Show in response area
    FMmoResponse.Clear;
    FMmoResponse.Lines.Add('=== MERGED PROMPT PREVIEW ===');
    FMmoResponse.Lines.Add('');
    FMmoResponse.Lines.Add(FinalPrompt);
    FLblResponseStats.Caption := Format('Length: %d chars', [Length(FinalPrompt)]);
  finally
    Params.Free;
  end;
end;

procedure TPromptDebugForm.BtnCompareVersionsClick(Sender: TObject);
begin
  // TODO: Open version comparison window
  ShowMessage('Version comparison window will be implemented in P6-004');
end;

procedure TPromptDebugForm.ChkIsProductionClick(Sender: TObject);
begin
  if FCurrentPrompt.Id = 0 then Exit;
  
  if FChkIsProduction.Checked then
  begin
    FLLMManager.SetProductionVersion(FCurrentPrompt.InternalCode, FCurrentVersionNum);
    SetStatus(Format('Version %d set as production', [FCurrentVersionNum]));
  end;
end;

procedure TPromptDebugForm.MetaListBoxClickCheck(Sender: TObject);
var
  I: Integer;
  MetaId: Integer;
  MetaPrompts: TMetaPromptArray;
begin
  if FCurrentPrompt.Id = 0 then Exit;
  
  MetaPrompts := FLLMManager.GetMetaPrompts;
  
  for I := 0 to FMetaListBox.Items.Count - 1 do
  begin
    MetaId := Integer(FMetaListBox.Items.Objects[I]);
    
    // Find meta by ID
    for var Meta in MetaPrompts do
    begin
      if Meta.Id = MetaId then
      begin
        if FMetaListBox.Checked[I] then
          FLLMManager.BindMetaPrompt(FCurrentPrompt.InternalCode, Meta.InternalCode)
        else
          FLLMManager.UnbindMetaPrompt(FCurrentPrompt.InternalCode, Meta.InternalCode);
        Break;
      end;
    end;
  end;
  
  // Refresh prompt to update MetaPrompts array
  FLLMManager.RefreshCache;
  FCurrentPrompt := FLLMManager.GetPrompt(FCurrentPrompt.InternalCode);
  FModified := True;
end;

procedure TPromptDebugForm.ContentChanged(Sender: TObject);
begin
  FModified := True;
end;

procedure TPromptDebugForm.SetStatus(const Text: string; IsError: Boolean);
begin
  FStatusBar.SimpleText := Text;
  if IsError then
    FStatusBar.Font.Color := clRed
  else
    FStatusBar.Font.Color := clWindowText;
end;

procedure TPromptDebugForm.UpdateVersionStats;
var
  V: TPromptVersion;
begin
  V := FCurrentPrompt.GetVersion(FCurrentVersionNum);
  if V.VersionNumber > 0 then
  begin
    FLblVersionStats.Caption := Format('Tests: %d | Success: %.1f%% | Avg: %.0f ms | Cost: $%.4f',
      [V.TestCount, V.SuccessRate, V.AvgDuration, V.TotalCost]);
  end
  else
    FLblVersionStats.Caption := '';
end;

function TPromptDebugForm.GetSelectedCategoryId: Integer;
var
  Node: TTreeNode;
begin
  Result := 0;
  Node := FCategoryTree.Selected;
  if Node <> nil then
    Result := Integer(Node.Data);
end;

function TPromptDebugForm.BuildVariablesFromGrid: TPromptVariableArray;
var
  I: Integer;
  V: TPromptVariable;
  List: TList<TPromptVariable>;
begin
  List := TList<TPromptVariable>.Create;
  try
    for I := 1 to FVarGrid.RowCount - 1 do
    begin
      if FVarGrid.Cells[VAR_COL_NAME, I] = '' then
        Continue;
        
      V.Name := FVarGrid.Cells[VAR_COL_NAME, I];
      V.VarType := TPromptVariable.StrToType(FVarGrid.Cells[VAR_COL_TYPE, I]);
      V.DefaultValue := FVarGrid.Cells[VAR_COL_DEFAULT, I];
      V.Description := FVarGrid.Cells[VAR_COL_DESC, I];
      V.Required := (FVarGrid.Cells[VAR_COL_REQUIRED, I] = '1') or 
                    (FVarGrid.Cells[VAR_COL_REQUIRED, I] = 'Y');
      
      List.Add(V);
    end;
    
    Result := List.ToArray;
  finally
    List.Free;
  end;
end;

procedure TPromptDebugForm.PopulateGridFromVariables(const Variables: TPromptVariableArray);
var
  I: Integer;
begin
  FVarGrid.RowCount := Max(2, Length(Variables) + 1);
  
  // Clear existing data
  for I := 1 to FVarGrid.RowCount - 1 do
    FVarGrid.Rows[I].Clear;
  
  for I := 0 to High(Variables) do
  begin
    FVarGrid.Cells[VAR_COL_NAME, I + 1] := Variables[I].Name;
    FVarGrid.Cells[VAR_COL_TYPE, I + 1] := Variables[I].TypeToStr;
    FVarGrid.Cells[VAR_COL_DEFAULT, I + 1] := VarToStr(Variables[I].DefaultValue);
    FVarGrid.Cells[VAR_COL_VALUE, I + 1] := VarToStr(Variables[I].DefaultValue);  // Test value defaults to default
    FVarGrid.Cells[VAR_COL_DESC, I + 1] := Variables[I].Description;
    FVarGrid.Cells[VAR_COL_REQUIRED, I + 1] := IfThen(Variables[I].Required, '1', '0');
  end;
end;

function TPromptDebugForm.CollectVariableValues: TDictionary<string, Variant>;
var
  I: Integer;
  VarName, VarValue, VarType: string;
begin
  Result := TDictionary<string, Variant>.Create;
  
  for I := 1 to FVarGrid.RowCount - 1 do
  begin
    VarName := FVarGrid.Cells[VAR_COL_NAME, I];
    if VarName = '' then Continue;
    
    VarValue := FVarGrid.Cells[VAR_COL_VALUE, I];
    VarType := FVarGrid.Cells[VAR_COL_TYPE, I];
    
    // Convert based on type
    if VarType = 'number' then
      Result.Add(VarName, StrToFloatDef(VarValue, 0))
    else if VarType = 'boolean' then
      Result.Add(VarName, (VarValue = '1') or (LowerCase(VarValue) = 'true'))
    else
      Result.Add(VarName, VarValue);
  end;
end;

end.
