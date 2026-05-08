unit Main.Form;

{*******************************************************************************
  Main Form - 主窗�?

  DeepBase 框架文档管理模板 - 主界�?
  左侧分类�?+ 中间文档列表 + 右侧预览/编辑
*******************************************************************************}

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, System.Generics.Collections, System.IOUtils,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ComCtrls,
  Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Menus, Vcl.ActnList, Vcl.ToolWin,
  Vcl.ImgList, System.Actions, System.ImageList,
  Entity.Document, Entity.Category;

type
  TMainForm = class(TForm)
    pnlLeft: TPanel;
    pnlCenter: TPanel;
    pnlRight: TPanel;
    splLeft: TSplitter;
    splRight: TSplitter;
    tvCategories: TTreeView;
    lvDocuments: TListView;
    pnlSearch: TPanel;
    edtSearch: TEdit;
    btnSearch: TButton;
    pnlPreview: TPanel;
    lblTitle: TLabel;
    mmoPreview: TMemo;
    pnlPreviewTop: TPanel;
    MainMenu1: TMainMenu;
    mnuFile: TMenuItem;
    mnuNew: TMenuItem;
    mnuOpen: TMenuItem;
    mnuSave: TMenuItem;
    mnuSep1: TMenuItem;
    mnuImport: TMenuItem;
    mnuExport: TMenuItem;
    mnuSep2: TMenuItem;
    mnuExit: TMenuItem;
    mnuEdit: TMenuItem;
    mnuCut: TMenuItem;
    mnuCopy: TMenuItem;
    mnuPaste: TMenuItem;
    mnuDelete: TMenuItem;
    mnuView: TMenuItem;
    mnuRefresh: TMenuItem;
    mnuHelp: TMenuItem;
    mnuAbout: TMenuItem;
    StatusBar1: TStatusBar;
    ActionList1: TActionList;
    actNew: TAction;
    actOpen: TAction;
    actSave: TAction;
    actDelete: TAction;
    actRefresh: TAction;
    actSearch: TAction;
    ToolBar1: TToolBar;
    tbNew: TToolButton;
    tbOpen: TToolButton;
    tbSave: TToolButton;
    tbSep1: TToolButton;
    tbDelete: TToolButton;
    tbRefresh: TToolButton;
    PopupMenu1: TPopupMenu;
    pmnuOpen: TMenuItem;
    pmnuDelete: TMenuItem;
    pmnuSep1: TMenuItem;
    pmnuRefresh: TMenuItem;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure tvCategoriesChange(Sender: TObject; Node: TTreeNode);
    procedure lvDocumentsSelectItem(Sender: TObject; Item: TListItem;
      Selected: Boolean);
    procedure lvDocumentsDblClick(Sender: TObject);
    procedure actNewExecute(Sender: TObject);
    procedure actOpenExecute(Sender: TObject);
    procedure actSaveExecute(Sender: TObject);
    procedure actDeleteExecute(Sender: TObject);
    procedure actRefreshExecute(Sender: TObject);
    procedure actSearchExecute(Sender: TObject);
    procedure edtSearchKeyPress(Sender: TObject; var Key: Char);
    procedure mnuExitClick(Sender: TObject);
    procedure mnuAboutClick(Sender: TObject);
  private
    FCurrentCategoryId: string;
    FCurrentDocument: TDocument;
    FDocuments: TObjectList<TDocument>;
    FCategoryTree: TCategoryTree;

    procedure LoadCategories;
    procedure LoadDocuments(const CategoryId: string = '');
    procedure ShowDocumentPreview(Doc: TDocument);
    procedure ClearPreview;
    procedure UpdateStatusBar;
    procedure OpenDocument(const DocId: string);
  public
    property CurrentDocument: TDocument read FCurrentDocument;
  end;

var
  MainForm: TMainForm;

implementation

{$R *.dfm}

uses
  Data.Module, Form.DocumentEdit,
  DeepBase.Manager, DeepBase.Logger;

{ TMainForm }

procedure TMainForm.FormCreate(Sender: TObject);
begin
  FDocuments := TObjectList<TDocument>.Create(True);
  FCategoryTree := TCategoryTree.Create;
  FCurrentDocument := nil;

  // 配置列表视图
  lvDocuments.ViewStyle := vsReport;
  lvDocuments.RowSelect := True;
  lvDocuments.ReadOnly := True;
  lvDocuments.Columns.Clear;
  with lvDocuments.Columns.Add do begin Caption := '标题'; Width := 200; end;
  with lvDocuments.Columns.Add do begin Caption := '更新时间'; Width := 150; end;
  with lvDocuments.Columns.Add do begin Caption := '状�?; Width := 80; end;
  with lvDocuments.Columns.Add do begin Caption := '版本'; Width := 60; end;

  // 配置搜索�?
  edtSearch.TextHint := '搜索文档...';

  Log.Info('MainForm created');
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  FCategoryTree.Free;
  FDocuments.Free;
  Log.Info('MainForm destroyed');
end;

procedure TMainForm.FormShow(Sender: TObject);
begin
  LoadCategories;
  LoadDocuments;
  UpdateStatusBar;
end;

procedure TMainForm.LoadCategories;
var
  Q: TFDQuery;
  Categories: TObjectList<TCategory>;
  Cat: TCategory;
  Node: TTreeNode;
  NodeMap: TDictionary<string, TTreeNode>;

  procedure AddChildNodes(ParentNode: TTreeNode; ParentCat: TCategory);
  var
    Child: TCategory;
    ChildNode: TTreeNode;
  begin
    for Child in ParentCat.Children do
    begin
      ChildNode := tvCategories.Items.AddChild(ParentNode, Child.Name);
      ChildNode.Data := Pointer(NativeInt(Categories.IndexOf(Child)));
      NodeMap.Add(Child.Id, ChildNode);
      AddChildNodes(ChildNode, Child);
    end;
  end;

begin
  tvCategories.Items.Clear;
  Categories := TObjectList<TCategory>.Create(True);
  NodeMap := TDictionary<string, TTreeNode>.Create;
  try
    // 加载分类数据
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := DataModule1.FDConnection1;
      Q.SQL.Text := 'SELECT * FROM Categories ORDER BY SortOrder, Name';
      Q.Open;

      while not Q.Eof do
      begin
        Cat := TCategory.Create;
        Cat.Id := Q.FieldByName('Id').AsString;
        Cat.Name := Q.FieldByName('Name').AsString;
        Cat.ParentId := Q.FieldByName('ParentId').AsString;
        Cat.SortOrder := Q.FieldByName('SortOrder').AsInteger;
        Cat.Description := Q.FieldByName('Description').AsString;
        Categories.Add(Cat);
        Q.Next;
      end;
    finally
      Q.Free;
    end;

    FCategoryTree.LoadFromList(Categories);

    // 添加"全部文档"根节�?
    Node := tvCategories.Items.Add(nil, '全部文档');
    Node.Data := nil;

    // 构建树节�?
    for Cat in FCategoryTree.RootCategories do
    begin
      Node := tvCategories.Items.Add(nil, Cat.Name);
      Node.Data := Pointer(NativeInt(Categories.IndexOf(Cat)));
      NodeMap.Add(Cat.Id, Node);
      AddChildNodes(Node, Cat);
    end;

    // 展开根节�?
    if tvCategories.Items.Count > 0 then
    begin
      tvCategories.Items[0].Expand(False);
      tvCategories.Selected := tvCategories.Items[0];
    end;

    // 保留分类列表供后续使�?
    Categories.OwnsObjects := False;
  finally
    NodeMap.Free;
    Categories.Free;
  end;
end;

procedure TMainForm.LoadDocuments(const CategoryId: string);
var
  Docs: TObjectList<TDocument>;
  Doc: TDocument;
  Item: TListItem;
begin
  lvDocuments.Items.Clear;
  FDocuments.Clear;
  FCurrentCategoryId := CategoryId;

  Docs := DataModule1.DocumentService.GetDocuments(CategoryId);
  try
    for Doc in Docs do
    begin
      Item := lvDocuments.Items.Add;
      Item.Caption := Doc.Title;
      Item.SubItems.Add(FormatDateTime('yyyy-mm-dd hh:nn', Doc.UpdatedAt));
      Item.SubItems.Add(Doc.DisplayStatus);
      Item.SubItems.Add('v' + IntToStr(Doc.Version));
      Item.Data := Pointer(FDocuments.Count);
      FDocuments.Add(Doc);
    end;
    Docs.OwnsObjects := False;
  finally
    Docs.Free;
  end;

  UpdateStatusBar;
end;

procedure TMainForm.tvCategoriesChange(Sender: TObject; Node: TTreeNode);
var
  CatIndex: Integer;
  Cat: TCategory;
begin
  if Node = nil then Exit;

  if Node.Data = nil then
  begin
    // "全部文档"
    LoadDocuments('');
  end
  else
  begin
    CatIndex := NativeInt(Node.Data);
    Cat := FCategoryTree.Flatten[CatIndex];
    LoadDocuments(Cat.Id);
  end;

  ClearPreview;
end;

procedure TMainForm.lvDocumentsSelectItem(Sender: TObject; Item: TListItem;
  Selected: Boolean);
var
  DocIndex: Integer;
begin
  if Selected and (Item <> nil) then
  begin
    DocIndex := NativeInt(Item.Data);
    if (DocIndex >= 0) and (DocIndex < FDocuments.Count) then
      ShowDocumentPreview(FDocuments[DocIndex]);
  end
  else
    ClearPreview;
end;

procedure TMainForm.lvDocumentsDblClick(Sender: TObject);
begin
  actOpenExecute(Sender);
end;

procedure TMainForm.ShowDocumentPreview(Doc: TDocument);
begin
  FCurrentDocument := Doc;
  lblTitle.Caption := Doc.Title;
  mmoPreview.Text := Doc.ContentPreview;
  pnlPreview.Visible := True;
end;

procedure TMainForm.ClearPreview;
begin
  FCurrentDocument := nil;
  lblTitle.Caption := '';
  mmoPreview.Clear;
end;

procedure TMainForm.UpdateStatusBar;
begin
  StatusBar1.Panels[0].Text := Format('文档�? %d', [FDocuments.Count]);
  StatusBar1.Panels[1].Text := FormatDateTime('yyyy-mm-dd hh:nn:ss', Now);
end;

procedure TMainForm.OpenDocument(const DocId: string);
var
  EditForm: TDocumentEditForm;
begin
  EditForm := TDocumentEditForm.Create(Self);
  try
    EditForm.LoadDocument(DocId);
    if EditForm.ShowModal = mrOk then
      LoadDocuments(FCurrentCategoryId);
  finally
    EditForm.Free;
  end;
end;

// Actions

procedure TMainForm.actNewExecute(Sender: TObject);
var
  EditForm: TDocumentEditForm;
begin
  EditForm := TDocumentEditForm.Create(Self);
  try
    EditForm.NewDocument(FCurrentCategoryId);
    if EditForm.ShowModal = mrOk then
      LoadDocuments(FCurrentCategoryId);
  finally
    EditForm.Free;
  end;
end;

procedure TMainForm.actOpenExecute(Sender: TObject);
begin
  if FCurrentDocument <> nil then
    OpenDocument(FCurrentDocument.Id);
end;

procedure TMainForm.actSaveExecute(Sender: TObject);
begin
  if (FCurrentDocument <> nil) and FCurrentDocument.IsDirty then
  begin
    DataModule1.DocumentService.UpdateDocument(FCurrentDocument);
    LoadDocuments(FCurrentCategoryId);
  end;
end;

procedure TMainForm.actDeleteExecute(Sender: TObject);
begin
  if FCurrentDocument = nil then Exit;

  if MessageDlg(Format('确定要删除文�?"%s" 吗？', [FCurrentDocument.Title]),
    mtConfirmation, [mbYes, mbNo], 0) = mrYes then
  begin
    DataModule1.DocumentService.DeleteDocument(FCurrentDocument.Id);
    ClearPreview;
    LoadDocuments(FCurrentCategoryId);
  end;
end;

procedure TMainForm.actRefreshExecute(Sender: TObject);
begin
  LoadCategories;
  LoadDocuments(FCurrentCategoryId);
end;

procedure TMainForm.actSearchExecute(Sender: TObject);
var
  Query: string;
  Results: TObjectList<TSearchResult>;
  R: TSearchResult;
  Item: TListItem;
begin
  Query := edtSearch.Text.Trim;
  if Query.IsEmpty then
  begin
    LoadDocuments(FCurrentCategoryId);
    Exit;
  end;

  lvDocuments.Items.Clear;
  FDocuments.Clear;

  Results := DataModule1.SearchService.Search(Query);
  try
    for R in Results do
    begin
      var Doc := DataModule1.DocumentService.GetDocument(R.DocumentId);
      if Doc <> nil then
      begin
        Item := lvDocuments.Items.Add;
        Item.Caption := Doc.Title;
        Item.SubItems.Add(FormatDateTime('yyyy-mm-dd hh:nn', Doc.UpdatedAt));
        Item.SubItems.Add(Doc.DisplayStatus);
        Item.SubItems.Add('v' + IntToStr(Doc.Version));
        Item.Data := Pointer(FDocuments.Count);
        FDocuments.Add(Doc);
      end;
    end;
  finally
    Results.Free;
  end;

  StatusBar1.Panels[0].Text := Format('搜索结果: %d', [FDocuments.Count]);
end;

procedure TMainForm.edtSearchKeyPress(Sender: TObject; var Key: Char);
begin
  if Key = #13 then
  begin
    Key := #0;
    actSearchExecute(Sender);
  end;
end;

procedure TMainForm.mnuExitClick(Sender: TObject);
begin
  Close;
end;

procedure TMainForm.mnuAboutClick(Sender: TObject);
begin
  MessageDlg('Document Manager'#13#10 +
    '基于 DeepBase 框架的文档管理系�?#13#10#13#10 +
    '版本: 1.0.0',
    mtInformation, [mbOK], 0);
end;

end.
