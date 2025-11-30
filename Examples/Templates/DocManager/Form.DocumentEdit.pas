unit Form.DocumentEdit;

{*******************************************************************************
  Document Edit Form - 文档编辑窗体

  UniBase 框架文档管理模板 - 文档编辑对话框
*******************************************************************************}

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, System.Generics.Collections,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls,
  Vcl.ExtCtrls, Vcl.ComCtrls,
  Entity.Document;

type
  TDocumentEditForm = class(TForm)
    pnlTop: TPanel;
    lblTitle: TLabel;
    edtTitle: TEdit;
    lblCategory: TLabel;
    cmbCategory: TComboBox;
    lblTags: TLabel;
    edtTags: TEdit;
    pnlContent: TPanel;
    mmoContent: TMemo;
    pnlBottom: TPanel;
    btnSave: TButton;
    btnCancel: TButton;
    btnAttach: TButton;
    lblAttachments: TLabel;
    lvAttachments: TListView;
    pnlRight: TPanel;
    lblVersions: TLabel;
    lvVersions: TListView;
    splRight: TSplitter;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnSaveClick(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
    procedure btnAttachClick(Sender: TObject);
    procedure lvVersionsDblClick(Sender: TObject);
    procedure mmoContentChange(Sender: TObject);
    procedure edtTitleChange(Sender: TObject);
  private
    FDocument: TDocument;
    FIsNew: Boolean;
    FModified: Boolean;
    FCategoryIds: TList<string>;

    procedure LoadCategories;
    procedure LoadVersions;
    procedure LoadAttachments;
    procedure SaveDocument;
    procedure UpdateTitle;
  public
    procedure NewDocument(const CategoryId: string = '');
    procedure LoadDocument(const DocId: string);

    property Document: TDocument read FDocument;
    property IsNew: Boolean read FIsNew;
  end;

var
  DocumentEditForm: TDocumentEditForm;

implementation

{$R *.dfm}

uses
  Data.Module,
  UniBase.Logger;

{ TDocumentEditForm }

procedure TDocumentEditForm.FormCreate(Sender: TObject);
begin
  FDocument := nil;
  FIsNew := True;
  FModified := False;
  FCategoryIds := TList<string>.Create;

  // 配置版本列表
  lvVersions.ViewStyle := vsReport;
  lvVersions.RowSelect := True;
  lvVersions.ReadOnly := True;
  lvVersions.Columns.Clear;
  with lvVersions.Columns.Add do begin Caption := '版本'; Width := 50; end;
  with lvVersions.Columns.Add do begin Caption := '时间'; Width := 120; end;
  with lvVersions.Columns.Add do begin Caption := '备注'; Width := 100; end;

  // 配置附件列表
  lvAttachments.ViewStyle := vsReport;
  lvAttachments.RowSelect := True;
  lvAttachments.ReadOnly := True;
  lvAttachments.Columns.Clear;
  with lvAttachments.Columns.Add do begin Caption := '文件名'; Width := 150; end;
  with lvAttachments.Columns.Add do begin Caption := '大小'; Width := 80; end;

  LoadCategories;
end;

procedure TDocumentEditForm.FormDestroy(Sender: TObject);
begin
  FCategoryIds.Free;
  // 不释放 FDocument，由调用者管理
end;

procedure TDocumentEditForm.LoadCategories;
var
  Q: TFDQuery;
begin
  cmbCategory.Items.Clear;
  FCategoryIds.Clear;

  cmbCategory.Items.Add('(无分类)');
  FCategoryIds.Add('');

  Q := TFDQuery.Create(nil);
  try
    Q.Connection := DataModule1.FDConnection1;
    Q.SQL.Text := 'SELECT Id, Name FROM Categories ORDER BY SortOrder, Name';
    Q.Open;

    while not Q.Eof do
    begin
      cmbCategory.Items.Add(Q.FieldByName('Name').AsString);
      FCategoryIds.Add(Q.FieldByName('Id').AsString);
      Q.Next;
    end;
  finally
    Q.Free;
  end;

  cmbCategory.ItemIndex := 0;
end;

procedure TDocumentEditForm.NewDocument(const CategoryId: string);
var
  I: Integer;
begin
  FDocument := TDocument.Create;
  FIsNew := True;
  FModified := False;

  edtTitle.Text := '';
  mmoContent.Text := '';
  edtTags.Text := '';

  // 选择分类
  if not CategoryId.IsEmpty then
  begin
    I := FCategoryIds.IndexOf(CategoryId);
    if I >= 0 then
      cmbCategory.ItemIndex := I;
  end;

  lvVersions.Items.Clear;
  lvAttachments.Items.Clear;

  UpdateTitle;
  edtTitle.SetFocus;
end;

procedure TDocumentEditForm.LoadDocument(const DocId: string);
var
  I: Integer;
  Tag: string;
begin
  FDocument := DataModule1.DocumentService.GetDocument(DocId);
  if FDocument = nil then
  begin
    ShowMessage('文档不存在');
    ModalResult := mrCancel;
    Exit;
  end;

  FIsNew := False;
  FModified := False;

  edtTitle.Text := FDocument.Title;
  mmoContent.Text := FDocument.Content;

  // 分类
  I := FCategoryIds.IndexOf(FDocument.CategoryId);
  if I >= 0 then
    cmbCategory.ItemIndex := I
  else
    cmbCategory.ItemIndex := 0;

  // 标签
  edtTags.Text := '';
  for Tag in FDocument.Tags do
  begin
    if edtTags.Text <> '' then
      edtTags.Text := edtTags.Text + ', ';
    edtTags.Text := edtTags.Text + Tag;
  end;

  LoadVersions;
  LoadAttachments;
  UpdateTitle;
end;

procedure TDocumentEditForm.LoadVersions;
var
  Versions: TObjectList<TDocumentVersion>;
  V: TDocumentVersion;
  Item: TListItem;
begin
  lvVersions.Items.Clear;

  if FDocument = nil then Exit;

  Versions := DataModule1.DocumentService.GetVersions(FDocument.Id);
  try
    for V in Versions do
    begin
      Item := lvVersions.Items.Add;
      Item.Caption := 'v' + IntToStr(V.Version);
      Item.SubItems.Add(FormatDateTime('mm-dd hh:nn', V.CreatedAt));
      Item.SubItems.Add(V.ChangeNote);
      Item.Data := Pointer(V.Version);
    end;
  finally
    Versions.Free;
  end;
end;

procedure TDocumentEditForm.LoadAttachments;
var
  Attachments: TObjectList<TAttachment>;
  A: TAttachment;
  Item: TListItem;
begin
  lvAttachments.Items.Clear;

  if FDocument = nil then Exit;

  Attachments := DataModule1.DocumentService.GetAttachments(FDocument.Id);
  try
    for A in Attachments do
    begin
      Item := lvAttachments.Items.Add;
      Item.Caption := A.FileName;
      Item.SubItems.Add(A.DisplaySize);
      Item.Data := Pointer(Attachments.IndexOf(A));
    end;
  finally
    Attachments.Free;
  end;
end;

procedure TDocumentEditForm.SaveDocument;
var
  TagStr: string;
  Tags: TArray<string>;
begin
  if edtTitle.Text.Trim.IsEmpty then
  begin
    ShowMessage('请输入标题');
    edtTitle.SetFocus;
    Exit;
  end;

  FDocument.Title := edtTitle.Text.Trim;
  FDocument.Content := mmoContent.Text;

  if cmbCategory.ItemIndex > 0 then
    FDocument.CategoryId := FCategoryIds[cmbCategory.ItemIndex]
  else
    FDocument.CategoryId := '';

  // 解析标签
  TagStr := edtTags.Text;
  Tags := TagStr.Split([',', ';', ' '], TStringSplitOptions.ExcludeEmpty);
  FDocument.TagList.Clear;
  for var T in Tags do
    FDocument.AddTag(T.Trim);

  if FIsNew then
  begin
    // 创建新文档
    var NewDoc := DataModule1.DocumentService.CreateDocument(
      FDocument.Title, FDocument.Content, FDocument.CategoryId);
    DataModule1.DocumentService.SetTags(NewDoc.Id, FDocument.Tags);
    FDocument.Free;
    FDocument := NewDoc;
    Log.Info('New document created: %s', [FDocument.Id]);
  end
  else
  begin
    // 更新现有文档
    DataModule1.DocumentService.UpdateDocument(FDocument);
    Log.Info('Document updated: %s', [FDocument.Id]);
  end;

  FModified := False;
  ModalResult := mrOk;
end;

procedure TDocumentEditForm.UpdateTitle;
begin
  if FIsNew then
    Caption := '新建文档'
  else
    Caption := '编辑文档 - ' + FDocument.Title;

  if FModified then
    Caption := Caption + ' *';
end;

procedure TDocumentEditForm.btnSaveClick(Sender: TObject);
begin
  SaveDocument;
end;

procedure TDocumentEditForm.btnCancelClick(Sender: TObject);
begin
  if FModified then
  begin
    case MessageDlg('文档已修改，是否保存？', mtConfirmation, [mbYes, mbNo, mbCancel], 0) of
      mrYes: SaveDocument;
      mrNo: ModalResult := mrCancel;
      mrCancel: Exit;
    end;
  end
  else
    ModalResult := mrCancel;
end;

procedure TDocumentEditForm.btnAttachClick(Sender: TObject);
var
  OpenDlg: TOpenDialog;
  Attachment: TAttachment;
begin
  if FIsNew then
  begin
    ShowMessage('请先保存文档后再添加附件');
    Exit;
  end;

  OpenDlg := TOpenDialog.Create(Self);
  try
    OpenDlg.Title := '选择附件';
    OpenDlg.Filter := '所有文件|*.*';
    if OpenDlg.Execute then
    begin
      Attachment := DataModule1.DocumentService.AttachFile(FDocument.Id, OpenDlg.FileName);
      if Attachment <> nil then
      begin
        LoadAttachments;
        ShowMessage('附件已添加');
      end;
    end;
  finally
    OpenDlg.Free;
  end;
end;

procedure TDocumentEditForm.lvVersionsDblClick(Sender: TObject);
var
  Version: Integer;
begin
  if lvVersions.Selected = nil then Exit;

  Version := Integer(lvVersions.Selected.Data);

  if MessageDlg(Format('确定要恢复到版本 %d 吗？', [Version]),
    mtConfirmation, [mbYes, mbNo], 0) = mrYes then
  begin
    DataModule1.DocumentService.RestoreVersion(FDocument.Id, Version);
    LoadDocument(FDocument.Id);
    ShowMessage('已恢复到指定版本');
  end;
end;

procedure TDocumentEditForm.mmoContentChange(Sender: TObject);
begin
  FModified := True;
  UpdateTitle;
end;

procedure TDocumentEditForm.edtTitleChange(Sender: TObject);
begin
  FModified := True;
  UpdateTitle;
end;

end.
