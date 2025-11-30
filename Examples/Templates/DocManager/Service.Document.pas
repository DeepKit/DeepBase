unit Service.Document;

{*******************************************************************************
  Document Service - 文档服务

  UniBase 框架文档管理模板 - 文档业务逻辑层
  提供 CRUD、版本控制、标签、附件管理功能
*******************************************************************************}

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections, System.IOUtils,
  FireDAC.Comp.Client,
  Entity.Document, Entity.Category, Entity.Tag;

type
  /// <summary>
  /// 文档服务 - 核心业务逻辑
  /// </summary>
  TDocumentService = class
  private
    FConnection: TFDConnection;
    FStoragePath: string;

    function GenerateAttachmentPath(const FileName: string): string;
    procedure SaveDocumentTags(const DocId: string; const Tags: TArray<string>);
    procedure LoadDocumentTags(Doc: TDocument);
    procedure LoadDocumentAttachments(Doc: TDocument);
  public
    constructor Create(AConnection: TFDConnection; const AStoragePath: string);

    // ============= 基本 CRUD =============

    /// <summary>创建文档</summary>
    function CreateDocument(const Title, Content: string; 
      const CategoryId: string = ''): TDocument;

    /// <summary>获取单个文档</summary>
    function GetDocument(const Id: string): TDocument;

    /// <summary>获取文档列表</summary>
    function GetDocuments(const CategoryId: string = ''; 
      Status: TDocumentStatus = dsActive): TObjectList<TDocument>;

    /// <summary>获取指定分类及其子分类下的文档</summary>
    function GetDocumentsInCategory(const CategoryId: string; 
      IncludeSubCategories: Boolean = True): TObjectList<TDocument>;

    /// <summary>更新文档</summary>
    procedure UpdateDocument(Doc: TDocument; SaveVersion: Boolean = True);

    /// <summary>删除文档（软删除）</summary>
    procedure DeleteDocument(const Id: string; HardDelete: Boolean = False);

    /// <summary>恢复已删除的文档</summary>
    procedure RestoreDocument(const Id: string);

    /// <summary>归档文档</summary>
    procedure ArchiveDocument(const Id: string);

    /// <summary>克隆文档</summary>
    function CloneDocument(const Id: string): TDocument;

    // ============= 版本控制 =============

    /// <summary>保存当前版本</summary>
    function SaveVersion(const DocId: string; const Note: string = ''): Integer;

    /// <summary>获取版本历史</summary>
    function GetVersions(const DocId: string): TObjectList<TDocumentVersion>;

    /// <summary>获取指定版本</summary>
    function GetVersion(const DocId: string; Version: Integer): TDocumentVersion;

    /// <summary>恢复到指定版本</summary>
    procedure RestoreVersion(const DocId: string; Version: Integer);

    /// <summary>比较两个版本</summary>
    function CompareVersions(const DocId: string; Version1, Version2: Integer): string;

    // ============= 标签管理 =============

    /// <summary>添加标签</summary>
    procedure AddTag(const DocId, TagName: string);

    /// <summary>移除标签</summary>
    procedure RemoveTag(const DocId, TagId: string);

    /// <summary>设置标签（替换所有）</summary>
    procedure SetTags(const DocId: string; const TagNames: TArray<string>);

    /// <summary>根据标签获取文档</summary>
    function GetDocumentsByTag(const TagName: string): TObjectList<TDocument>;

    /// <summary>获取文档的标签</summary>
    function GetDocumentTags(const DocId: string): TArray<string>;

    // ============= 附件管理 =============

    /// <summary>添加附件</summary>
    function AttachFile(const DocId, FilePath: string): TAttachment;

    /// <summary>移除附件</summary>
    procedure DetachFile(const AttachmentId: string);

    /// <summary>获取附件列表</summary>
    function GetAttachments(const DocId: string): TObjectList<TAttachment>;

    /// <summary>打开附件</summary>
    procedure OpenAttachment(const AttachmentId: string);

    /// <summary>导出附件</summary>
    procedure ExportAttachment(const AttachmentId, DestPath: string);

    // ============= 导入导出 =============

    /// <summary>导出文档</summary>
    procedure ExportDocument(const DocId, FilePath: string; Format: TExportFormat);

    /// <summary>批量导出</summary>
    procedure ExportDocuments(const DocIds: TArray<string>; 
      const FolderPath: string; Format: TExportFormat);

    /// <summary>导入文档</summary>
    function ImportDocument(const FilePath: string; 
      const CategoryId: string = ''): TDocument;

    /// <summary>批量导入</summary>
    function ImportDocuments(const FilePaths: TArray<string>; 
      const CategoryId: string = ''): TArray<TDocument>;

    // ============= 统计 =============

    /// <summary>获取文档总数</summary>
    function GetDocumentCount(Status: TDocumentStatus = dsActive): Integer;

    /// <summary>获取分类下的文档数</summary>
    function GetCategoryDocumentCount(const CategoryId: string): Integer;

    /// <summary>获取最近修改的文档</summary>
    function GetRecentDocuments(Count: Integer = 10): TObjectList<TDocument>;

    property Connection: TFDConnection read FConnection;
    property StoragePath: string read FStoragePath write FStoragePath;
  end;

implementation

uses
  System.DateUtils, System.StrUtils,
  Winapi.Windows, Winapi.ShellAPI,
  UniBase.Manager, UniBase.Logger;

{ TDocumentService }

constructor TDocumentService.Create(AConnection: TFDConnection; const AStoragePath: string);
begin
  inherited Create;
  FConnection := AConnection;
  FStoragePath := AStoragePath;
  
  // 确保存储目录存在
  if not TDirectory.Exists(FStoragePath) then
    TDirectory.CreateDirectory(FStoragePath);
end;

// ============= 基本 CRUD =============

function TDocumentService.CreateDocument(const Title, Content: string;
  const CategoryId: string): TDocument;
var
  Query: TFDQuery;
begin
  Result := TDocument.Create;
  Result.Title := Title;
  Result.Content := Content;
  Result.CategoryId := CategoryId;
  Result.CreatedBy := UniBase.Config.GetConfig('user.name', 'System');
  
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 
      'INSERT INTO Documents (Id, Title, Content, CategoryId, Status, Version, ' +
      'CreatedAt, UpdatedAt, CreatedBy) VALUES (:Id, :Title, :Content, :CategoryId, ' +
      ':Status, :Version, :CreatedAt, :UpdatedAt, :CreatedBy)';
    Query.ParamByName('Id').AsString := Result.Id;
    Query.ParamByName('Title').AsString := Result.Title;
    Query.ParamByName('Content').AsString := Result.Content;
    Query.ParamByName('CategoryId').AsString := Result.CategoryId;
    Query.ParamByName('Status').AsInteger := Result.StatusValue;
    Query.ParamByName('Version').AsInteger := Result.Version;
    Query.ParamByName('CreatedAt').AsDateTime := Result.CreatedAt;
    Query.ParamByName('UpdatedAt').AsDateTime := Result.UpdatedAt;
    Query.ParamByName('CreatedBy').AsString := Result.CreatedBy;
    Query.ExecSQL;
    
    Log.Info('Document created: %s - %s', [Result.Id, Result.Title]);
  finally
    Query.Free;
  end;
end;

function TDocumentService.GetDocument(const Id: string): TDocument;
var
  Query: TFDQuery;
begin
  Result := nil;
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'SELECT * FROM Documents WHERE Id = :Id';
    Query.ParamByName('Id').AsString := Id;
    Query.Open;
    
    if not Query.Eof then
    begin
      Result := TDocument.Create;
      Result.Id := Query.FieldByName('Id').AsString;
      Result.Title := Query.FieldByName('Title').AsString;
      Result.Content := Query.FieldByName('Content').AsString;
      Result.CategoryId := Query.FieldByName('CategoryId').AsString;
      Result.StatusValue := Query.FieldByName('Status').AsInteger;
      Result.Version := Query.FieldByName('Version').AsInteger;
      Result.CreatedAt := Query.FieldByName('CreatedAt').AsDateTime;
      Result.UpdatedAt := Query.FieldByName('UpdatedAt').AsDateTime;
      Result.CreatedBy := Query.FieldByName('CreatedBy').AsString;
      
      // 加载关联数据
      LoadDocumentTags(Result);
      LoadDocumentAttachments(Result);
    end;
  finally
    Query.Free;
  end;
end;

function TDocumentService.GetDocuments(const CategoryId: string;
  Status: TDocumentStatus): TObjectList<TDocument>;
var
  Query: TFDQuery;
  Doc: TDocument;
begin
  Result := TObjectList<TDocument>.Create(True);
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    
    if CategoryId.IsEmpty then
      Query.SQL.Text := 'SELECT * FROM Documents WHERE Status = :Status ORDER BY UpdatedAt DESC'
    else
    begin
      Query.SQL.Text := 'SELECT * FROM Documents WHERE CategoryId = :CategoryId AND ' +
        'Status = :Status ORDER BY UpdatedAt DESC';
      Query.ParamByName('CategoryId').AsString := CategoryId;
    end;
    Query.ParamByName('Status').AsInteger := Ord(Status);
    Query.Open;
    
    while not Query.Eof do
    begin
      Doc := TDocument.Create;
      Doc.Id := Query.FieldByName('Id').AsString;
      Doc.Title := Query.FieldByName('Title').AsString;
      Doc.Content := Query.FieldByName('Content').AsString;
      Doc.CategoryId := Query.FieldByName('CategoryId').AsString;
      Doc.StatusValue := Query.FieldByName('Status').AsInteger;
      Doc.Version := Query.FieldByName('Version').AsInteger;
      Doc.CreatedAt := Query.FieldByName('CreatedAt').AsDateTime;
      Doc.UpdatedAt := Query.FieldByName('UpdatedAt').AsDateTime;
      Doc.CreatedBy := Query.FieldByName('CreatedBy').AsString;
      Result.Add(Doc);
      Query.Next;
    end;
  finally
    Query.Free;
  end;
end;

function TDocumentService.GetDocumentsInCategory(const CategoryId: string;
  IncludeSubCategories: Boolean): TObjectList<TDocument>;
begin
  // 简化实现，实际应从 CategoryTree 获取所有子分类 ID
  Result := GetDocuments(CategoryId);
end;

procedure TDocumentService.UpdateDocument(Doc: TDocument; SaveVersion: Boolean);
var
  Query: TFDQuery;
begin
  if SaveVersion then
    Self.SaveVersion(Doc.Id, '自动保存');
  
  Doc.UpdatedAt := Now;
  Doc.Version := Doc.Version + 1;
  
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 
      'UPDATE Documents SET Title = :Title, Content = :Content, CategoryId = :CategoryId, ' +
      'Status = :Status, Version = :Version, UpdatedAt = :UpdatedAt WHERE Id = :Id';
    Query.ParamByName('Title').AsString := Doc.Title;
    Query.ParamByName('Content').AsString := Doc.Content;
    Query.ParamByName('CategoryId').AsString := Doc.CategoryId;
    Query.ParamByName('Status').AsInteger := Doc.StatusValue;
    Query.ParamByName('Version').AsInteger := Doc.Version;
    Query.ParamByName('UpdatedAt').AsDateTime := Doc.UpdatedAt;
    Query.ParamByName('Id').AsString := Doc.Id;
    Query.ExecSQL;
    
    // 保存标签
    SaveDocumentTags(Doc.Id, Doc.Tags);
    
    Doc.ClearDirty;
    Log.Info('Document updated: %s - %s (v%d)', [Doc.Id, Doc.Title, Doc.Version]);
  finally
    Query.Free;
  end;
end;

procedure TDocumentService.DeleteDocument(const Id: string; HardDelete: Boolean);
var
  Query: TFDQuery;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    
    if HardDelete then
    begin
      // 删除关联数据
      Query.SQL.Text := 'DELETE FROM DocumentTags WHERE DocumentId = :DocId';
      Query.ParamByName('DocId').AsString := Id;
      Query.ExecSQL;
      
      Query.SQL.Text := 'DELETE FROM Attachments WHERE DocumentId = :DocId';
      Query.ParamByName('DocId').AsString := Id;
      Query.ExecSQL;
      
      Query.SQL.Text := 'DELETE FROM DocumentVersions WHERE DocumentId = :DocId';
      Query.ParamByName('DocId').AsString := Id;
      Query.ExecSQL;
      
      Query.SQL.Text := 'DELETE FROM Documents WHERE Id = :Id';
      Query.ParamByName('Id').AsString := Id;
      Query.ExecSQL;
      
      Log.Info('Document hard deleted: %s', [Id]);
    end
    else
    begin
      Query.SQL.Text := 'UPDATE Documents SET Status = :Status, UpdatedAt = :UpdatedAt WHERE Id = :Id';
      Query.ParamByName('Status').AsInteger := Ord(dsDeleted);
      Query.ParamByName('UpdatedAt').AsDateTime := Now;
      Query.ParamByName('Id').AsString := Id;
      Query.ExecSQL;
      
      Log.Info('Document soft deleted: %s', [Id]);
    end;
  finally
    Query.Free;
  end;
end;

procedure TDocumentService.RestoreDocument(const Id: string);
var
  Query: TFDQuery;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'UPDATE Documents SET Status = :Status, UpdatedAt = :UpdatedAt WHERE Id = :Id';
    Query.ParamByName('Status').AsInteger := Ord(dsActive);
    Query.ParamByName('UpdatedAt').AsDateTime := Now;
    Query.ParamByName('Id').AsString := Id;
    Query.ExecSQL;
    
    Log.Info('Document restored: %s', [Id]);
  finally
    Query.Free;
  end;
end;

procedure TDocumentService.ArchiveDocument(const Id: string);
var
  Query: TFDQuery;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'UPDATE Documents SET Status = :Status, UpdatedAt = :UpdatedAt WHERE Id = :Id';
    Query.ParamByName('Status').AsInteger := Ord(dsArchived);
    Query.ParamByName('UpdatedAt').AsDateTime := Now;
    Query.ParamByName('Id').AsString := Id;
    Query.ExecSQL;
    
    Log.Info('Document archived: %s', [Id]);
  finally
    Query.Free;
  end;
end;

function TDocumentService.CloneDocument(const Id: string): TDocument;
var
  Original: TDocument;
begin
  Original := GetDocument(Id);
  try
    if Original <> nil then
    begin
      Result := Original.Clone;
      
      // 保存克隆的文档
      var Query := TFDQuery.Create(nil);
      try
        Query.Connection := FConnection;
        Query.SQL.Text := 
          'INSERT INTO Documents (Id, Title, Content, CategoryId, Status, Version, ' +
          'CreatedAt, UpdatedAt, CreatedBy) VALUES (:Id, :Title, :Content, :CategoryId, ' +
          ':Status, :Version, :CreatedAt, :UpdatedAt, :CreatedBy)';
        Query.ParamByName('Id').AsString := Result.Id;
        Query.ParamByName('Title').AsString := Result.Title;
        Query.ParamByName('Content').AsString := Result.Content;
        Query.ParamByName('CategoryId').AsString := Result.CategoryId;
        Query.ParamByName('Status').AsInteger := Result.StatusValue;
        Query.ParamByName('Version').AsInteger := Result.Version;
        Query.ParamByName('CreatedAt').AsDateTime := Result.CreatedAt;
        Query.ParamByName('UpdatedAt').AsDateTime := Result.UpdatedAt;
        Query.ParamByName('CreatedBy').AsString := UniBase.Config.GetConfig('user.name', 'System');
        Query.ExecSQL;
        
        // 复制标签
        SaveDocumentTags(Result.Id, Original.Tags);
        
        Log.Info('Document cloned: %s -> %s', [Id, Result.Id]);
      finally
        Query.Free;
      end;
    end
    else
      Result := nil;
  finally
    Original.Free;
  end;
end;

// ============= 版本控制 =============

function TDocumentService.SaveVersion(const DocId: string; const Note: string): Integer;
var
  Doc: TDocument;
  Version: TDocumentVersion;
  Query: TFDQuery;
begin
  Doc := GetDocument(DocId);
  try
    if Doc = nil then
      Exit(-1);
    
    Version := TDocumentVersion.CreateFromDocument(Doc, Note);
    try
      Query := TFDQuery.Create(nil);
      try
        Query.Connection := FConnection;
        Query.SQL.Text := 
          'INSERT INTO DocumentVersions (Id, DocumentId, Version, Title, Content, ' +
          'CreatedAt, CreatedBy, ChangeNote) VALUES (:Id, :DocumentId, :Version, ' +
          ':Title, :Content, :CreatedAt, :CreatedBy, :ChangeNote)';
        Query.ParamByName('Id').AsString := Version.Id;
        Query.ParamByName('DocumentId').AsString := Version.DocumentId;
        Query.ParamByName('Version').AsInteger := Version.Version;
        Query.ParamByName('Title').AsString := Version.Title;
        Query.ParamByName('Content').AsString := Version.Content;
        Query.ParamByName('CreatedAt').AsDateTime := Version.CreatedAt;
        Query.ParamByName('CreatedBy').AsString := Version.CreatedBy;
        Query.ParamByName('ChangeNote').AsString := Version.ChangeNote;
        Query.ExecSQL;
        
        Result := Version.Version;
        Log.Debug('Version saved: %s v%d', [DocId, Result]);
      finally
        Query.Free;
      end;
    finally
      Version.Free;
    end;
  finally
    Doc.Free;
  end;
end;

function TDocumentService.GetVersions(const DocId: string): TObjectList<TDocumentVersion>;
var
  Query: TFDQuery;
  Version: TDocumentVersion;
begin
  Result := TObjectList<TDocumentVersion>.Create(True);
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'SELECT * FROM DocumentVersions WHERE DocumentId = :DocId ORDER BY Version DESC';
    Query.ParamByName('DocId').AsString := DocId;
    Query.Open;
    
    while not Query.Eof do
    begin
      Version := TDocumentVersion.Create;
      Version.Id := Query.FieldByName('Id').AsString;
      Version.DocumentId := Query.FieldByName('DocumentId').AsString;
      Version.Version := Query.FieldByName('Version').AsInteger;
      Version.Title := Query.FieldByName('Title').AsString;
      Version.Content := Query.FieldByName('Content').AsString;
      Version.CreatedAt := Query.FieldByName('CreatedAt').AsDateTime;
      Version.CreatedBy := Query.FieldByName('CreatedBy').AsString;
      Version.ChangeNote := Query.FieldByName('ChangeNote').AsString;
      Result.Add(Version);
      Query.Next;
    end;
  finally
    Query.Free;
  end;
end;

function TDocumentService.GetVersion(const DocId: string; Version: Integer): TDocumentVersion;
var
  Query: TFDQuery;
begin
  Result := nil;
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'SELECT * FROM DocumentVersions WHERE DocumentId = :DocId AND Version = :Ver';
    Query.ParamByName('DocId').AsString := DocId;
    Query.ParamByName('Ver').AsInteger := Version;
    Query.Open;
    
    if not Query.Eof then
    begin
      Result := TDocumentVersion.Create;
      Result.Id := Query.FieldByName('Id').AsString;
      Result.DocumentId := Query.FieldByName('DocumentId').AsString;
      Result.Version := Query.FieldByName('Version').AsInteger;
      Result.Title := Query.FieldByName('Title').AsString;
      Result.Content := Query.FieldByName('Content').AsString;
      Result.CreatedAt := Query.FieldByName('CreatedAt').AsDateTime;
      Result.CreatedBy := Query.FieldByName('CreatedBy').AsString;
      Result.ChangeNote := Query.FieldByName('ChangeNote').AsString;
    end;
  finally
    Query.Free;
  end;
end;

procedure TDocumentService.RestoreVersion(const DocId: string; Version: Integer);
var
  Ver: TDocumentVersion;
  Doc: TDocument;
begin
  Ver := GetVersion(DocId, Version);
  try
    if Ver = nil then
      Exit;
    
    Doc := GetDocument(DocId);
    try
      if Doc = nil then
        Exit;
      
      // 先保存当前版本
      SaveVersion(DocId, Format('恢复到版本 %d 前的自动保存', [Version]));
      
      // 恢复内容
      Doc.Title := Ver.Title;
      Doc.Content := Ver.Content;
      UpdateDocument(Doc, False);
      
      Log.Info('Document restored to version %d: %s', [Version, DocId]);
    finally
      Doc.Free;
    end;
  finally
    Ver.Free;
  end;
end;

function TDocumentService.CompareVersions(const DocId: string; Version1, Version2: Integer): string;
var
  V1, V2: TDocumentVersion;
begin
  // 简化实现，返回差异描述
  V1 := GetVersion(DocId, Version1);
  V2 := GetVersion(DocId, Version2);
  try
    if (V1 = nil) or (V2 = nil) then
      Exit('版本不存在');
    
    Result := Format('版本 %d (%s) vs 版本 %d (%s)'#13#10 +
      '标题: %s -> %s'#13#10 +
      '内容长度: %d -> %d', [
      V1.Version, DateTimeToStr(V1.CreatedAt),
      V2.Version, DateTimeToStr(V2.CreatedAt),
      V1.Title, V2.Title,
      Length(V1.Content), Length(V2.Content)
    ]);
  finally
    V1.Free;
    V2.Free;
  end;
end;

// ============= 标签管理 =============

procedure TDocumentService.AddTag(const DocId, TagName: string);
var
  Query: TFDQuery;
  TagId: string;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    
    // 查找或创建标签
    Query.SQL.Text := 'SELECT Id FROM Tags WHERE LOWER(Name) = LOWER(:Name)';
    Query.ParamByName('Name').AsString := TagName;
    Query.Open;
    
    if Query.Eof then
    begin
      // 创建新标签
      TagId := TTag.NewId;
      Query.SQL.Text := 'INSERT INTO Tags (Id, Name, Color, UsageCount, CreatedAt) ' +
        'VALUES (:Id, :Name, :Color, 0, :CreatedAt)';
      Query.ParamByName('Id').AsString := TagId;
      Query.ParamByName('Name').AsString := TagName;
      Query.ParamByName('Color').AsString := '#3498db';
      Query.ParamByName('CreatedAt').AsDateTime := Now;
      Query.ExecSQL;
    end
    else
      TagId := Query.FieldByName('Id').AsString;
    
    // 添加关联
    Query.SQL.Text := 'INSERT OR IGNORE INTO DocumentTags (DocumentId, TagId, CreatedAt) ' +
      'VALUES (:DocId, :TagId, :CreatedAt)';
    Query.ParamByName('DocId').AsString := DocId;
    Query.ParamByName('TagId').AsString := TagId;
    Query.ParamByName('CreatedAt').AsDateTime := Now;
    Query.ExecSQL;
    
    // 更新使用计数
    Query.SQL.Text := 'UPDATE Tags SET UsageCount = UsageCount + 1 WHERE Id = :Id';
    Query.ParamByName('Id').AsString := TagId;
    Query.ExecSQL;
  finally
    Query.Free;
  end;
end;

procedure TDocumentService.RemoveTag(const DocId, TagId: string);
var
  Query: TFDQuery;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'DELETE FROM DocumentTags WHERE DocumentId = :DocId AND TagId = :TagId';
    Query.ParamByName('DocId').AsString := DocId;
    Query.ParamByName('TagId').AsString := TagId;
    Query.ExecSQL;
    
    // 更新使用计数
    Query.SQL.Text := 'UPDATE Tags SET UsageCount = MAX(0, UsageCount - 1) WHERE Id = :Id';
    Query.ParamByName('Id').AsString := TagId;
    Query.ExecSQL;
  finally
    Query.Free;
  end;
end;

procedure TDocumentService.SetTags(const DocId: string; const TagNames: TArray<string>);
var
  Query: TFDQuery;
  TagName: string;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    
    // 清除现有标签
    Query.SQL.Text := 'DELETE FROM DocumentTags WHERE DocumentId = :DocId';
    Query.ParamByName('DocId').AsString := DocId;
    Query.ExecSQL;
    
    // 添加新标签
    for TagName in TagNames do
      AddTag(DocId, TagName);
  finally
    Query.Free;
  end;
end;

function TDocumentService.GetDocumentsByTag(const TagName: string): TObjectList<TDocument>;
var
  Query: TFDQuery;
  Doc: TDocument;
begin
  Result := TObjectList<TDocument>.Create(True);
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 
      'SELECT d.* FROM Documents d ' +
      'INNER JOIN DocumentTags dt ON d.Id = dt.DocumentId ' +
      'INNER JOIN Tags t ON dt.TagId = t.Id ' +
      'WHERE LOWER(t.Name) = LOWER(:TagName) AND d.Status = :Status ' +
      'ORDER BY d.UpdatedAt DESC';
    Query.ParamByName('TagName').AsString := TagName;
    Query.ParamByName('Status').AsInteger := Ord(dsActive);
    Query.Open;
    
    while not Query.Eof do
    begin
      Doc := TDocument.Create;
      Doc.Id := Query.FieldByName('Id').AsString;
      Doc.Title := Query.FieldByName('Title').AsString;
      Doc.Content := Query.FieldByName('Content').AsString;
      Doc.CategoryId := Query.FieldByName('CategoryId').AsString;
      Doc.StatusValue := Query.FieldByName('Status').AsInteger;
      Doc.Version := Query.FieldByName('Version').AsInteger;
      Doc.CreatedAt := Query.FieldByName('CreatedAt').AsDateTime;
      Doc.UpdatedAt := Query.FieldByName('UpdatedAt').AsDateTime;
      Result.Add(Doc);
      Query.Next;
    end;
  finally
    Query.Free;
  end;
end;

function TDocumentService.GetDocumentTags(const DocId: string): TArray<string>;
var
  Query: TFDQuery;
  Tags: TList<string>;
begin
  Tags := TList<string>.Create;
  try
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := FConnection;
      Query.SQL.Text := 
        'SELECT t.Name FROM Tags t ' +
        'INNER JOIN DocumentTags dt ON t.Id = dt.TagId ' +
        'WHERE dt.DocumentId = :DocId ORDER BY t.Name';
      Query.ParamByName('DocId').AsString := DocId;
      Query.Open;
      
      while not Query.Eof do
      begin
        Tags.Add(Query.FieldByName('Name').AsString);
        Query.Next;
      end;
    finally
      Query.Free;
    end;
    Result := Tags.ToArray;
  finally
    Tags.Free;
  end;
end;

procedure TDocumentService.SaveDocumentTags(const DocId: string; const Tags: TArray<string>);
begin
  SetTags(DocId, Tags);
end;

procedure TDocumentService.LoadDocumentTags(Doc: TDocument);
var
  Tags: TArray<string>;
  Tag: string;
begin
  Tags := GetDocumentTags(Doc.Id);
  Doc.TagList.Clear;
  for Tag in Tags do
    Doc.TagList.Add(Tag);
end;

procedure TDocumentService.LoadDocumentAttachments(Doc: TDocument);
var
  Attachments: TObjectList<TAttachment>;
  Att: TAttachment;
begin
  Attachments := GetAttachments(Doc.Id);
  try
    Doc.AttachmentList.Clear;
    for Att in Attachments do
    begin
      Doc.AttachmentList.Add(Att);
    end;
    Attachments.OwnsObjects := False;
  finally
    Attachments.Free;
  end;
end;

// ============= 附件管理 =============

function TDocumentService.GenerateAttachmentPath(const FileName: string): string;
var
  SubDir: string;
begin
  // 按年月组织目录
  SubDir := FormatDateTime('yyyy-mm', Now);
  Result := TPath.Combine(FStoragePath, SubDir);
  
  if not TDirectory.Exists(Result) then
    TDirectory.CreateDirectory(Result);
  
  // 生成唯一文件名
  Result := TPath.Combine(Result, Format('%s_%s', [
    FormatDateTime('yyyymmdd_hhnnss', Now),
    FileName
  ]));
end;

function TDocumentService.AttachFile(const DocId, FilePath: string): TAttachment;
var
  Query: TFDQuery;
  DestPath: string;
begin
  if not TFile.Exists(FilePath) then
    Exit(nil);
  
  Result := TAttachment.CreateFromFile(FilePath);
  Result.DocumentId := DocId;
  
  // 复制文件到存储目录
  DestPath := GenerateAttachmentPath(Result.FileName);
  TFile.Copy(FilePath, DestPath);
  Result.FilePath := DestPath;
  
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 
      'INSERT INTO Attachments (Id, DocumentId, FileName, FileType, FileSize, FilePath, CreatedAt) ' +
      'VALUES (:Id, :DocId, :FileName, :FileType, :FileSize, :FilePath, :CreatedAt)';
    Query.ParamByName('Id').AsString := Result.Id;
    Query.ParamByName('DocId').AsString := Result.DocumentId;
    Query.ParamByName('FileName').AsString := Result.FileName;
    Query.ParamByName('FileType').AsString := Result.FileType;
    Query.ParamByName('FileSize').AsLargeInt := Result.FileSize;
    Query.ParamByName('FilePath').AsString := Result.FilePath;
    Query.ParamByName('CreatedAt').AsDateTime := Result.CreatedAt;
    Query.ExecSQL;
    
    Log.Info('Attachment added: %s -> %s', [Result.FileName, DocId]);
  finally
    Query.Free;
  end;
end;

procedure TDocumentService.DetachFile(const AttachmentId: string);
var
  Query: TFDQuery;
  FilePath: string;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    
    // 获取文件路径
    Query.SQL.Text := 'SELECT FilePath FROM Attachments WHERE Id = :Id';
    Query.ParamByName('Id').AsString := AttachmentId;
    Query.Open;
    
    if not Query.Eof then
    begin
      FilePath := Query.FieldByName('FilePath').AsString;
      
      // 删除文件
      if TFile.Exists(FilePath) then
        TFile.Delete(FilePath);
      
      // 删除记录
      Query.SQL.Text := 'DELETE FROM Attachments WHERE Id = :Id';
      Query.ParamByName('Id').AsString := AttachmentId;
      Query.ExecSQL;
      
      Log.Info('Attachment removed: %s', [AttachmentId]);
    end;
  finally
    Query.Free;
  end;
end;

function TDocumentService.GetAttachments(const DocId: string): TObjectList<TAttachment>;
var
  Query: TFDQuery;
  Att: TAttachment;
begin
  Result := TObjectList<TAttachment>.Create(True);
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'SELECT * FROM Attachments WHERE DocumentId = :DocId ORDER BY CreatedAt';
    Query.ParamByName('DocId').AsString := DocId;
    Query.Open;
    
    while not Query.Eof do
    begin
      Att := TAttachment.Create;
      Att.Id := Query.FieldByName('Id').AsString;
      Att.DocumentId := Query.FieldByName('DocumentId').AsString;
      Att.FileName := Query.FieldByName('FileName').AsString;
      Att.FileType := Query.FieldByName('FileType').AsString;
      Att.FileSize := Query.FieldByName('FileSize').AsLargeInt;
      Att.FilePath := Query.FieldByName('FilePath').AsString;
      Att.CreatedAt := Query.FieldByName('CreatedAt').AsDateTime;
      Result.Add(Att);
      Query.Next;
    end;
  finally
    Query.Free;
  end;
end;

procedure TDocumentService.OpenAttachment(const AttachmentId: string);
var
  Query: TFDQuery;
  FilePath: string;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'SELECT FilePath FROM Attachments WHERE Id = :Id';
    Query.ParamByName('Id').AsString := AttachmentId;
    Query.Open;
    
    if not Query.Eof then
    begin
      FilePath := Query.FieldByName('FilePath').AsString;
      if TFile.Exists(FilePath) then
        ShellExecute(0, 'open', PChar(FilePath), nil, nil, SW_SHOWNORMAL);
    end;
  finally
    Query.Free;
  end;
end;

procedure TDocumentService.ExportAttachment(const AttachmentId, DestPath: string);
var
  Query: TFDQuery;
  FilePath: string;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'SELECT FilePath FROM Attachments WHERE Id = :Id';
    Query.ParamByName('Id').AsString := AttachmentId;
    Query.Open;
    
    if not Query.Eof then
    begin
      FilePath := Query.FieldByName('FilePath').AsString;
      if TFile.Exists(FilePath) then
        TFile.Copy(FilePath, DestPath, True);
    end;
  finally
    Query.Free;
  end;
end;

// ============= 导入导出 =============

procedure TDocumentService.ExportDocument(const DocId, FilePath: string; Format: TExportFormat);
var
  Doc: TDocument;
  Content: TStringList;
begin
  Doc := GetDocument(DocId);
  try
    if Doc = nil then Exit;
    
    Content := TStringList.Create;
    try
      case Format of
        efText:
          begin
            Content.Add('标题: ' + Doc.Title);
            Content.Add('创建时间: ' + DateTimeToStr(Doc.CreatedAt));
            Content.Add('更新时间: ' + DateTimeToStr(Doc.UpdatedAt));
            Content.Add('');
            Content.Add(Doc.Content);
          end;
        efMarkdown:
          begin
            Content.Add('# ' + Doc.Title);
            Content.Add('');
            Content.Add(Doc.Content);
          end;
        efHTML:
          begin
            Content.Add('<!DOCTYPE html>');
            Content.Add('<html><head><meta charset="utf-8">');
            Content.Add('<title>' + Doc.Title + '</title></head>');
            Content.Add('<body>');
            Content.Add('<h1>' + Doc.Title + '</h1>');
            Content.Add('<pre>' + Doc.Content + '</pre>');
            Content.Add('</body></html>');
          end;
      end;
      
      Content.SaveToFile(FilePath, TEncoding.UTF8);
      Log.Info('Document exported: %s -> %s', [DocId, FilePath]);
    finally
      Content.Free;
    end;
  finally
    Doc.Free;
  end;
end;

procedure TDocumentService.ExportDocuments(const DocIds: TArray<string>;
  const FolderPath: string; Format: TExportFormat);
var
  DocId: string;
  FileName: string;
  Ext: string;
begin
  case Format of
    efText: Ext := '.txt';
    efMarkdown: Ext := '.md';
    efHTML: Ext := '.html';
  else
    Ext := '.txt';
  end;
  
  for DocId in DocIds do
  begin
    FileName := TPath.Combine(FolderPath, DocId + Ext);
    ExportDocument(DocId, FileName, Format);
  end;
end;

function TDocumentService.ImportDocument(const FilePath: string;
  const CategoryId: string): TDocument;
var
  Content: TStringList;
  Title: string;
begin
  if not TFile.Exists(FilePath) then
    Exit(nil);
  
  Content := TStringList.Create;
  try
    Content.LoadFromFile(FilePath, TEncoding.UTF8);
    Title := TPath.GetFileNameWithoutExtension(FilePath);
    Result := CreateDocument(Title, Content.Text, CategoryId);
    Log.Info('Document imported: %s -> %s', [FilePath, Result.Id]);
  finally
    Content.Free;
  end;
end;

function TDocumentService.ImportDocuments(const FilePaths: TArray<string>;
  const CategoryId: string): TArray<TDocument>;
var
  List: TList<TDocument>;
  FilePath: string;
  Doc: TDocument;
begin
  List := TList<TDocument>.Create;
  try
    for FilePath in FilePaths do
    begin
      Doc := ImportDocument(FilePath, CategoryId);
      if Doc <> nil then
        List.Add(Doc);
    end;
    Result := List.ToArray;
  finally
    List.Free;
  end;
end;

// ============= 统计 =============

function TDocumentService.GetDocumentCount(Status: TDocumentStatus): Integer;
var
  Query: TFDQuery;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'SELECT COUNT(*) AS Cnt FROM Documents WHERE Status = :Status';
    Query.ParamByName('Status').AsInteger := Ord(Status);
    Query.Open;
    Result := Query.FieldByName('Cnt').AsInteger;
  finally
    Query.Free;
  end;
end;

function TDocumentService.GetCategoryDocumentCount(const CategoryId: string): Integer;
var
  Query: TFDQuery;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'SELECT COUNT(*) AS Cnt FROM Documents WHERE CategoryId = :CatId AND Status = :Status';
    Query.ParamByName('CatId').AsString := CategoryId;
    Query.ParamByName('Status').AsInteger := Ord(dsActive);
    Query.Open;
    Result := Query.FieldByName('Cnt').AsInteger;
  finally
    Query.Free;
  end;
end;

function TDocumentService.GetRecentDocuments(Count: Integer): TObjectList<TDocument>;
var
  Query: TFDQuery;
  Doc: TDocument;
begin
  Result := TObjectList<TDocument>.Create(True);
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'SELECT * FROM Documents WHERE Status = :Status ORDER BY UpdatedAt DESC LIMIT :Limit';
    Query.ParamByName('Status').AsInteger := Ord(dsActive);
    Query.ParamByName('Limit').AsInteger := Count;
    Query.Open;
    
    while not Query.Eof do
    begin
      Doc := TDocument.Create;
      Doc.Id := Query.FieldByName('Id').AsString;
      Doc.Title := Query.FieldByName('Title').AsString;
      Doc.Content := Query.FieldByName('Content').AsString;
      Doc.CategoryId := Query.FieldByName('CategoryId').AsString;
      Doc.StatusValue := Query.FieldByName('Status').AsInteger;
      Doc.Version := Query.FieldByName('Version').AsInteger;
      Doc.CreatedAt := Query.FieldByName('CreatedAt').AsDateTime;
      Doc.UpdatedAt := Query.FieldByName('UpdatedAt').AsDateTime;
      Result.Add(Doc);
      Query.Next;
    end;
  finally
    Query.Free;
  end;
end;

end.
