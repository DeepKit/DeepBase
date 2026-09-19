unit Entity.Document;

{*******************************************************************************
  Document Entity - 鏂囨。瀹炰綋

  DeepBase 妗嗘灦鏂囨。绠＄悊妯℃澘 - 鏍稿績鏂囨。瀹炰綋瀹氫箟
  鏀寔 ORM 鏄犲皠銆佺増鏈帶鍒躲€侀檮浠剁鐞?
*******************************************************************************}

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  DeepBase.ORM.Attributes, DeepBase.ORM.Entity;

type
  /// <summary>鏂囨。鐘舵€?/summary>
  TDocumentStatus = (
    dsActive = 0,     // 娲诲姩
    dsArchived = 1,   // 宸插綊妗?
    dsDeleted = 2     // 宸插垹闄わ紙杞垹闄わ級
  );

  /// <summary>瀵煎嚭鏍煎紡</summary>
  TExportFormat = (
    efText,           // 绾枃鏈?
    efHTML,           // HTML
    efMarkdown,       // Markdown
    efPDF,            // PDF
    efWord            // Word 鏂囨。
  );

  // 鍓嶅悜澹版槑
  TDocument = class;
  TDocumentVersion = class;
  TAttachment = class;

  /// <summary>
  /// 鏂囨。瀹炰綋
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

    // 闈炴寔涔呭寲瀛楁
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

    /// <summary>鐢熸垚鏂扮殑鏂囨。 ID</summary>
    class function NewId: string;

    /// <summary>楠岃瘉鏂囨。</summary>
    function Validate: Boolean; override;

    /// <summary>鑾峰彇楠岃瘉閿欒</summary>
    function GetValidationErrors: TArray<string>;

    /// <summary>鍏嬮殕鏂囨。锛堜笉鍖呭惈 ID锛?/summary>
    function Clone: TDocument;

    /// <summary>鏍囪涓哄凡淇敼</summary>
    procedure MarkDirty;

    /// <summary>娓呴櫎宸蹭慨鏀规爣璁?/summary>
    procedure ClearDirty;

    // 鏍囩鎿嶄綔
    procedure AddTag(const TagName: string);
    procedure RemoveTag(const TagName: string);
    function HasTag(const TagName: string): Boolean;

    // 闄勪欢鎿嶄綔
    procedure AddAttachment(Attachment: TAttachment);
    procedure RemoveAttachment(const AttachmentId: string);

    // 灞炴€?
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

    // 璁＄畻灞炴€?
    property Tags: TArray<string> read GetTags;
    property Attachments: TArray<TAttachment> read GetAttachments;
    property DisplayStatus: string read GetDisplayStatus;
    property ContentPreview: string read GetContentPreview;
    property IsDirty: Boolean read FIsDirty;

    // 鍐呴儴鍒楄〃璁块棶
    property TagList: TList<string> read FTags;
    property AttachmentList: TObjectList<TAttachment> read FAttachments;
    property VersionList: TObjectList<TDocumentVersion> read FVersions;
  end;

  /// <summary>
  /// 鏂囨。鐗堟湰瀹炰綋
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

    /// <summary>浠庢枃妗ｅ垱寤虹増鏈揩鐓?/summary>
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
  /// 闄勪欢瀹炰綋
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

    /// <summary>浠庢枃浠惰矾寰勫垱寤洪檮浠?/summary>
    class function CreateFromFile(const FilePath: string): TAttachment;

    /// <summary>妫€鏌ユ枃浠舵槸鍚﹀瓨鍦?/summary>
    function FileExists: Boolean;

    property Id: string read FId write FId;
    property DocumentId: string read FDocumentId write FDocumentId;
    property FileName: string read FFileName write FFileName;
    property FileType: string read FFileType write FFileType;
    property FileSize: Int64 read FFileSize write FFileSize;
    property FilePath: string read FFilePath write FFilePath;
    property CreatedAt: TDateTime read FCreatedAt write FCreatedAt;

    // 璁＄畻灞炴€?
    property DisplaySize: string read GetDisplaySize;
    property FileExtension: string read GetFileExtension;
  end;

  /// <summary>
  /// 鎼滅储缁撴灉
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
  StatusNames: array[TDocumentStatus] of string = ('娲诲姩', '宸插綊妗?, '宸插垹闄?);
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

  // 绉婚櫎鎹㈣绗?
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
      Errors.Add('鏍囬涓嶈兘涓虹┖');

    if Length(FTitle) > 500 then
      Errors.Add('鏍囬闀垮害涓嶈兘瓒呰繃 500 瀛楃');

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
  Result.FId := NewId;  // 鏂?ID
  Result.FTitle := FTitle + ' (鍓湰)';
  Result.FContent := FContent;
  Result.FCategoryId := FCategoryId;
  Result.FStatusValue := Ord(dsActive);
  Result.FVersion := 1;
  Result.FCreatedAt := Now;
  Result.FUpdatedAt := Now;

  // 澶嶅埗鏍囩
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
