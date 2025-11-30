unit Form.CategoryTree;

{*******************************************************************************
  Category Tree Form - 分类管理窗体

  UniBase 框架文档管理模板 - 分类树管理
*******************************************************************************}

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, System.Generics.Collections,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls,
  Vcl.ExtCtrls, Vcl.ComCtrls,
  Entity.Category;

type
  TCategoryTreeForm = class(TForm)
    pnlLeft: TPanel;
    tvCategories: TTreeView;
    pnlRight: TPanel;
    lblName: TLabel;
    edtName: TEdit;
    lblDescription: TLabel;
    mmoDescription: TMemo;
    lblParent: TLabel;
    cmbParent: TComboBox;
    pnlButtons: TPanel;
    btnAdd: TButton;
    btnSave: TButton;
    btnDelete: TButton;
    btnClose: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure tvCategoriesChange(Sender: TObject; Node: TTreeNode);
    procedure btnAddClick(Sender: TObject);
    procedure btnSaveClick(Sender: TObject);
    procedure btnDeleteClick(Sender: TObject);
    procedure btnCloseClick(Sender: TObject);
  private
    FCategories: TObjectList<TCategory>;
    FCurrentCategory: TCategory;
    FIsNew: Boolean;

    procedure LoadCategories;
    procedure LoadParentCombo;
    procedure ShowCategory(Cat: TCategory);
    procedure ClearFields;
  public
    property Categories: TObjectList<TCategory> read FCategories;
  end;

var
  CategoryTreeForm: TCategoryTreeForm;

implementation

{$R *.dfm}

uses
  Data.Module,
  UniBase.Logger;

{ TCategoryTreeForm }

procedure TCategoryTreeForm.FormCreate(Sender: TObject);
begin
  FCategories := TObjectList<TCategory>.Create(True);
  FCurrentCategory := nil;
  FIsNew := False;
  LoadCategories;
end;

procedure TCategoryTreeForm.FormDestroy(Sender: TObject);
begin
  FCategories.Free;
end;

procedure TCategoryTreeForm.LoadCategories;
var
  Q: TFDQuery;
  Cat: TCategory;
  Node: TTreeNode;
  NodeMap: TDictionary<string, TTreeNode>;
begin
  tvCategories.Items.Clear;
  FCategories.Clear;
  NodeMap := TDictionary<string, TTreeNode>.Create;
  try
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
        FCategories.Add(Cat);
        Q.Next;
      end;
    finally
      Q.Free;
    end;

    // 构建树
    for Cat in FCategories do
    begin
      if Cat.ParentId.IsEmpty then
      begin
        Node := tvCategories.Items.Add(nil, Cat.Name);
        Node.Data := Cat;
        NodeMap.Add(Cat.Id, Node);
      end;
    end;

    // 添加子节点
    for Cat in FCategories do
    begin
      if not Cat.ParentId.IsEmpty and NodeMap.ContainsKey(Cat.ParentId) then
      begin
        Node := tvCategories.Items.AddChild(NodeMap[Cat.ParentId], Cat.Name);
        Node.Data := Cat;
        NodeMap.Add(Cat.Id, Node);
      end;
    end;

    LoadParentCombo;

    if tvCategories.Items.Count > 0 then
      tvCategories.Selected := tvCategories.Items[0];
  finally
    NodeMap.Free;
  end;
end;

procedure TCategoryTreeForm.LoadParentCombo;
var
  Cat: TCategory;
begin
  cmbParent.Items.Clear;
  cmbParent.Items.Add('(无 - 根分类)');

  for Cat in FCategories do
    cmbParent.Items.Add(Cat.Name);

  cmbParent.ItemIndex := 0;
end;

procedure TCategoryTreeForm.ShowCategory(Cat: TCategory);
var
  I: Integer;
begin
  FCurrentCategory := Cat;
  FIsNew := False;

  if Cat = nil then
  begin
    ClearFields;
    Exit;
  end;

  edtName.Text := Cat.Name;
  mmoDescription.Text := Cat.Description;

  // 父分类
  cmbParent.ItemIndex := 0;
  for I := 0 to FCategories.Count - 1 do
  begin
    if FCategories[I].Id = Cat.ParentId then
    begin
      cmbParent.ItemIndex := I + 1;
      Break;
    end;
  end;
end;

procedure TCategoryTreeForm.ClearFields;
begin
  edtName.Text := '';
  mmoDescription.Text := '';
  cmbParent.ItemIndex := 0;
end;

procedure TCategoryTreeForm.tvCategoriesChange(Sender: TObject; Node: TTreeNode);
begin
  if Node <> nil then
    ShowCategory(TCategory(Node.Data))
  else
    ClearFields;
end;

procedure TCategoryTreeForm.btnAddClick(Sender: TObject);
begin
  FCurrentCategory := TCategory.Create;
  FIsNew := True;
  ClearFields;
  edtName.SetFocus;
end;

procedure TCategoryTreeForm.btnSaveClick(Sender: TObject);
var
  Q: TFDQuery;
  ParentId: string;
begin
  if edtName.Text.Trim.IsEmpty then
  begin
    ShowMessage('请输入分类名称');
    edtName.SetFocus;
    Exit;
  end;

  if FCurrentCategory = nil then Exit;

  FCurrentCategory.Name := edtName.Text.Trim;
  FCurrentCategory.Description := mmoDescription.Text;

  // 父分类
  if cmbParent.ItemIndex > 0 then
    ParentId := FCategories[cmbParent.ItemIndex - 1].Id
  else
    ParentId := '';
  FCurrentCategory.ParentId := ParentId;

  Q := TFDQuery.Create(nil);
  try
    Q.Connection := DataModule1.FDConnection1;

    if FIsNew then
    begin
      Q.SQL.Text :=
        'INSERT INTO Categories (Id, Name, ParentId, SortOrder, Description, CreatedAt) ' +
        'VALUES (:Id, :Name, :Parent, :Sort, :Desc, :Created)';
      Q.ParamByName('Id').AsString := FCurrentCategory.Id;
      Q.ParamByName('Created').AsDateTime := Now;
    end
    else
    begin
      Q.SQL.Text :=
        'UPDATE Categories SET Name = :Name, ParentId = :Parent, ' +
        'Description = :Desc WHERE Id = :Id';
      Q.ParamByName('Id').AsString := FCurrentCategory.Id;
    end;

    Q.ParamByName('Name').AsString := FCurrentCategory.Name;
    if ParentId.IsEmpty then
      Q.ParamByName('Parent').Clear
    else
      Q.ParamByName('Parent').AsString := ParentId;
    Q.ParamByName('Desc').AsString := FCurrentCategory.Description;

    if FIsNew then
      Q.ParamByName('Sort').AsInteger := FCategories.Count + 1;

    Q.ExecSQL;

    Log.Info('Category saved: %s', [FCurrentCategory.Name]);
    LoadCategories;
  finally
    Q.Free;
  end;
end;

procedure TCategoryTreeForm.btnDeleteClick(Sender: TObject);
var
  Q: TFDQuery;
begin
  if FCurrentCategory = nil then Exit;

  if MessageDlg(Format('确定要删除分类 "%s" 吗？', [FCurrentCategory.Name]),
    mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    Exit;

  Q := TFDQuery.Create(nil);
  try
    Q.Connection := DataModule1.FDConnection1;

    // 将该分类下的文档移到根
    Q.SQL.Text := 'UPDATE Documents SET CategoryId = NULL WHERE CategoryId = :Id';
    Q.ParamByName('Id').AsString := FCurrentCategory.Id;
    Q.ExecSQL;

    // 将子分类提升为根
    Q.SQL.Text := 'UPDATE Categories SET ParentId = NULL WHERE ParentId = :Id';
    Q.ParamByName('Id').AsString := FCurrentCategory.Id;
    Q.ExecSQL;

    // 删除分类
    Q.SQL.Text := 'DELETE FROM Categories WHERE Id = :Id';
    Q.ParamByName('Id').AsString := FCurrentCategory.Id;
    Q.ExecSQL;

    Log.Info('Category deleted: %s', [FCurrentCategory.Name]);
    LoadCategories;
    ClearFields;
  finally
    Q.Free;
  end;
end;

procedure TCategoryTreeForm.btnCloseClick(Sender: TObject);
begin
  Close;
end;

end.
