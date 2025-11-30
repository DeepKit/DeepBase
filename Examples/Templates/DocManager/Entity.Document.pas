unit Entity.Document;

{*******************************************************************************
  Document Entity - 文档实体

  UniBase 框架文档管理模板 - 核心文档实体定义
  支持 ORM 映射、版本控制、附件管理
*******************************************************************************}

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  UniBase.ORM.Attributes, UniBase.ORM.Entity;

type
  /// <summary>文档状态</summary>
  TDocumentStatus = (
    dsActive = 0,     // 活动
    dsArchived = 1,   // 已归档
    dsDeleted = 2     // 已删除（软删除）
  );

  /// <summary>导出格式</summary>
  TExportFormat = (
    efText,           // 纯文本
    efHTML,           // HTML
    efMarkdown,       // Markdown
    efPDF,            // PDF
    efWord            // Word 文档
  );

  // 前向声明
  TDocument = class;
  TDocumentVersion = class;
  TAttachment = class;

  /// <summary>
  /// 文档实体
  /// </summary>
  [Table('Documents')]
  TDocument = class(TEntityBase)
  private
    [PrimaryKey]
    [Column('Id')]
    FId: string;

    [Column('Title')]
    FTitle: string;

    [Column('Content')]
    FContent: string;

    [Column('CategoryId')]
    FCategoryId: string;

    [Column('Status')]
    FStatusValue: Integer;

    [Column('Version')]
    FVersion: Integer;

    [Column('CreatedAt')]
    FCreatedAt: TDateTime;

    [Column('UpdatedAt')]
    FUpdatedAt: TDateTime;

    [Column('CreatedBy')]
    FCreatedBy: string;

    // 非持久化字段
    FTags: TList<string>;
    FAttachments: TObjectList<TAttachment>;
    FVersions: TObjectList<TDocumentVersion>;
    FIsDirty: Boolean;

    function GetStatus: TDocumentStatus;
    procedure SetStatus(const Value: TDocumentStatus);
    function GetTags: TArray<string>;
    function GetAttachments: TArray<TAttachment>;
    function GetDisplayStatus: string;
    function GetContentPreview: string;
  public
    constructor Create; override;
    destructor Destroy; override;

    /// <summary>生成新的文档 ID</summary>
    class function NewId: string;

    /// <summary>验证文档</summary>
    function Validate: Boolean; override;

    /// <summary>获取验证错误</summary>
    function GetValidationErrors: TArray<string>;

    /// <summary>克隆文档（不包含 ID）</summary>
    function Clone: TDocument;

    /// <summary>标记为已修改</summary>
    procedure MarkDirty;

    /// <summary>清除已修改标记</summary>
    procedure ClearDirty;

    // 标签操作
    procedure AddTag(const TagName: string);
    procedure RemoveTag(const TagName: string);
    function HasTag(const TagName: string): Boolean;

    // 附件操作
    procedure AddAttachment(Attachment: TAttachment);
    procedure RemoveAttachment(const AttachmentId: string);

    // 属性
    property Id: string read FId write FId;
    property Title: string read FTitle write FTitle;
    property Content: string read FContent write FContent;
    property CategoryId: string read FCategoryId write FCategoryId;
    property Status: TDocumentStatus read GetStatus write SetStatus;
    property StatusValue: Integer read FStatusValue write FStatusValue;
    property Version: Integer read FVersion write FVersion;
    property CreatedAt: TDateTime read FCreatedAt write FCreatedAt;
    property UpdatedAt: TDateTime read FUpdatedAt write FUpdatedAt;
    property CreatedBy: string read FCreatedBy write FCreatedBy;

    // 计算属性
    property Tags: TArray<string> read GetTags;
    property Attachments: TArray<TAttachment> read GetAttachments;
    property DisplayStatus: string read GetDisplayStatus;
    property ContentPreview: string read GetContentPreview;
    property IsDirty: Boolean read FIsDirty;

    // 内部列表访问
    property TagList: TList<string> read FTags;
    property AttachmentList: TObjectList<TAttachment> read FAttachments;
    property VersionList: TObjectList<TDocumentVersion> read FVersions;
  end;

  /// <summary>
  /// 文档版本实体
  /// </summary>
  [Table('DocumentVersions')]
  TDocumentVersion = class(TEntityBase)
  private
    [PrimaryKey]
    [Column('Id')]
    FId: string;

    [Column('DocumentId')]
    FDocumentId: string;

    [Column('Version')]
    FVersion: Integer;

    [Column('Title')]
    FTitle: string;

    [Column('Content')]
    FContent: string;

    [Column('CreatedAt')]
    FCreatedAt: TDateTime;

    [Column('CreatedBy')]
    FCreatedBy: string;

    [Column('ChangeNote')]
    FChangeNote: string;
  public
    constructor Create; override;

    class function NewId: string;

    /// <summary>从文档创建版本快照</summary>
    class function CreateFromDocument(Doc: TDocument; const Note: string = ''): TDocumentVersion;

    property Id: string read FId write FId;
    property DocumentId: string read FDocumentId write FDocumentId;
    property Version: Integer read FVersion write FVersion;
    property Title: string read FTitle write FTitle;
    property Content: string read FContent write FContent;
    property CreatedAt: TDateTime read FCreatedAt write FCreatedAt;
    property CreatedBy: string read FCreatedBy write FCreatedBy;
    property ChangeNote: string read FChangeNote write FChangeNote;
  end;

  /// <summary>
  /// 附件实体
  /// </summary>
  [Table('Attachments')]
  TAttachment = class(TEntityBase)
  private
    [PrimaryKey]
    [Column('Id')]
    FId: string;

    [Column('DocumentId')]
    FDocumentId: string;

    [Column('FileName')]
    FFileName: string;

    [Column('FileType')]
    FFileType: string;

    [Column('FileSize')]
    FFileSize: Int64;

    [Column('FilePath')]
    FFilePath: string;

    [Column('CreatedAt')]
    FCreatedAt: TDateTime;

    function GetDisplaySize: string;
    function GetFileExtension: string;
  public
    constructor Create; override;

    class function NewId: string;

    /// <summary>从文件路径创建附件</summary>
    class function CreateFromFile(const FilePath: string): TAttachment;

    /// <summary>检查文件是否存在</summary>
    function FileExists: Boolean;

    property Id: string read FId write FId;
    property DocumentId: string read FDocumentId write FDocumentId;
    property FileName: string read FFileName write FFileName;
    property FileType: string read FFileType write FFileType;
    property FileSize: Int64 read FFileSize write FFileSize;
    property FilePath: string read FFilePath write FFilePath;
    property CreatedAt: TDateTime read FCreatedAt write FCreatedAt;

    // 计算属性
    property DisplaySize: string read GetDisplaySize;
    property FileExtension: string read GetFileExtension;
  end;

  /// <summary>
  /// 搜索结果
  /// </summary>
  TSearchResult = class
  private
    FDocumentId: string;
    FTitle: string;
    FSnippet: string;
    FScore: Double;
    FCategoryName: string;
    FUpdatedAt: TDateTime;
  public
    property DocumentId: string read FDocumentId write FDocumentId;
    property Title: string read FTitle write FTitle;
    property Snippet: string read FSnippet write FSnippet;
    property Score: Double read FScore write FScore;
    property CategoryName: string read FCategoryName write FCategoryName;
    property UpdatedAt: TDateTime read FUpdatedAt write FUpdatedAt;
  end;

implementation

uses
  System.IOUtils, System.DateUtils;

{ TDocument }

constructor TDocument.Create;
begin
  inherited;
  FId := NewId;
  FVersion := 1;
  FStatusValue := Ord(dsActive);
  FCreatedAt := Now;
  FUpdatedAt := Now;
  FTags := TList<string>.Create;
  FAttachments := TObjectList<TAttachment>.Create(True);
  FVersions := TObjectList<TDocumentVersion>.Create(True);
  FIsDirty := False;
end;

destructor TDocument.Destroy;
begin
  FTags.Free;
  FAttachments.Free;
  FVersions.Free;
  inherited;
end;

class function TDocument.NewId: string;
begin
  Result := TGUID.NewGuid.ToString.Replace('{', '').Replace('}', '').Replace('-', '');
end;

function TDocument.GetStatus: TDocumentStatus;
begin
  Result := TDocumentStatus(FStatusValue);
end;

procedure TDocument.SetStatus(const Value: TDocumentStatus);
begin
  FStatusValue := Ord(Value);
end;

function TDocument.GetTags: TArray<string>;
begin
  Result := FTags.ToArray;
end;

function TDocument.GetAttachments: TArray<TAttachment>;
begin
  Result := FAttachments.ToArray;
end;

function TDocument.GetDisplayStatus: string;
const
  StatusNames: array[TDocumentStatus] of string = ('活动', '已归档', '已删除');
begin
  Result := StatusNames[Status];
end;

function TDocument.GetContentPreview: string;
const
  MaxLength = 200;
begin
  if Length(FContent) <= MaxLength then
    Result := FContent
  else
    Result := Copy(FContent, 1, MaxLength) + '...';

  // 移除换行符
  Result := Result.Replace(#13#10, ' ').Replace(#10, ' ').Replace(#13, ' ');
end;

function TDocument.Validate: Boolean;
var
  Errors: TArray<string>;
begin
  Errors := GetValidationErrors;
  Result := Length(Errors) = 0;
end;

function TDocument.GetValidationErrors: TArray<string>;
var
  Errors: TList<string>;
begin
  Errors := TList<string>.Create;
  try
    if FTitle.Trim.IsEmpty then
      Errors.Add('标题不能为空');

    if Length(FTitle) > 500 then
      Errors.Add('标题长度不能超过 500 字符');

    Result := Errors.ToArray;
  finally
    Errors.Free;
  end;
end;

function TDocument.Clone: TDocument;
var
  Tag: string;
begin
  Result := TDocument.Create;
  Result.FId := NewId;  // 新 ID
  Result.FTitle := FTitle + ' (副本)';
  Result.FContent := FContent;
  Result.FCategoryId := FCategoryId;
  Result.FStatusValue := Ord(dsActive);
  Result.FVersion := 1;
  Result.FCreatedAt := Now;
  Result.FUpdatedAt := Now;

  // 复制标签
  for Tag in FTags do
    Result.FTags.Add(Tag);
end;

procedure TDocument.MarkDirty;
begin
  FIsDirty := True;
  FUpdatedAt := Now;
end;

procedure TDocument.ClearDirty;
begin
  FIsDirty := False;
end;

procedure TDocument.AddTag(const TagName: string);
var
  NormalizedTag: string;
begin
  NormalizedTag := TagName.Trim.ToLower;
  if not NormalizedTag.IsEmpty and not FTags.Contains(NormalizedTag) then
  begin
    FTags.Add(NormalizedTag);
    MarkDirty;
  end;
end;

procedure TDocument.RemoveTag(const TagName: string);
var
  Idx: Integer;
begin
  Idx := FTags.IndexOf(TagName.Trim.ToLower);
  if Idx >= 0 then
  begin
    FTags.Delete(Idx);
    MarkDirty;
  end;
end;

function TDocument.HasTag(const TagName: string): Boolean;
begin
  Result := FTags.Contains(TagName.Trim.ToLower);
end;

procedure TDocument.AddAttachment(Attachment: TAttachment);
begin
  if Attachment <> nil then
  begin
    Attachment.FDocumentId := FId;
    FAttachments.Add(Attachment);
    MarkDirty;
  end;
end;

procedure TDocument.RemoveAttachment(const AttachmentId: string);
var
  I: Integer;
begin
  for I := FAttachments.Count - 1 downto 0 do
  begin
    if FAttachments[I].Id = AttachmentId then
    begin
      FAttachments.Delete(I);
      MarkDirty;
      Break;
    end;
  end;
end;

{ TDocumentVersion }

constructor TDocumentVersion.Create;
begin
  inherited;
  FId := NewId;
  FCreatedAt := Now;
end;

class function TDocumentVersion.NewId: string;
begin
  Result := TGUID.NewGuid.ToString.Replace('{', '').Replace('}', '').Replace('-', '');
end;

class function TDocumentVersion.CreateFromDocument(Doc: TDocument; const Note: string): TDocumentVersion;
begin
  Result := TDocumentVersion.Create;
  Result.FDocumentId := Doc.Id;
  Result.FVersion := Doc.Version;
  Result.FTitle := Doc.Title;
  Result.FContent := Doc.Content;
  Result.FCreatedAt := Now;
  Result.FCreatedBy := Doc.CreatedBy;
  Result.FChangeNote := Note;
end;

{ TAttachment }

constructor TAttachment.Create;
begin
  inherited;
  FId := NewId;
  FCreatedAt := Now;
end;

class function TAttachment.NewId: string;
begin
  Result := TGUID.NewGuid.ToString.Replace('{', '').Replace('}', '').Replace('-', '');
end;

class function TAttachment.CreateFromFile(const FilePath: string): TAttachment;
begin
  Result := TAttachment.Create;
  Result.FFileName := TPath.GetFileName(FilePath);
  Result.FFileType := TPath.GetExtension(FilePath).ToLower;
  Result.FFilePath := FilePath;

  if TFile.Exists(FilePath) then
    Result.FFileSize := TFile.GetSize(FilePath)
  else
    Result.FFileSize := 0;
end;

function TAttachment.FileExists: Boolean;
begin
  Result := TFile.Exists(FFilePath);
end;

function TAttachment.GetDisplaySize: string;
const
  KB = 1024;
  MB = KB * 1024;
  GB = MB * 1024;
begin
  if FFileSize < KB then
    Result := Format('%d B', [FFileSize])
  else if FFileSize < MB then
    Result := Format('%.1f KB', [FFileSize / KB])
  else if FFileSize < GB then
    Result := Format('%.1f MB', [FFileSize / MB])
  else
    Result := Format('%.2f GB', [FFileSize / GB]);
end;

function TAttachment.GetFileExtension: string;
begin
  Result := FFileType;
  if Result.StartsWith('.') then
    Result := Copy(Result, 2, Length(Result));
end;

end.
