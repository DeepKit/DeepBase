# Document Manager Application Template

基于 DeepBase 框架的文档管理系统应用程序模板�?

## 功能特�?

- 文档分类管理（树状目录结构）
- 全文搜索（基�?SQLite FTS�?
- 版本控制
- 标签系统
- 文件附件支持
- 导入/导出功能

## 项目结构

```
DocManager/
├── DocManager.dpr           # 项目主文�?
├── Main.Form.pas/dfm        # 主窗体（文档列表+预览�?
├── Data.Module.pas/dfm      # 数据访问模块
├── Entity.Document.pas      # 文档实体
├── Entity.Category.pas      # 分类实体
├── Entity.Tag.pas           # 标签实体
├── Service.Document.pas     # 文档服务�?
├── Service.Search.pas       # 搜索服务
├── Form.DocumentEdit.pas    # 文档编辑窗体
├── Form.CategoryTree.pas    # 分类树管�?
└── README.md                # 本文�?
```

## 数据库设�?

### Documents �?
```sql
CREATE TABLE Documents (
  Id TEXT PRIMARY KEY,
  Title TEXT NOT NULL,
  Content TEXT,
  CategoryId TEXT,
  Status INTEGER DEFAULT 0,
  Version INTEGER DEFAULT 1,
  CreatedAt TEXT,
  UpdatedAt TEXT,
  CreatedBy TEXT,
  FOREIGN KEY (CategoryId) REFERENCES Categories(Id)
);
```

### Categories �?
```sql
CREATE TABLE Categories (
  Id TEXT PRIMARY KEY,
  Name TEXT NOT NULL,
  ParentId TEXT,
  SortOrder INTEGER DEFAULT 0,
  FOREIGN KEY (ParentId) REFERENCES Categories(Id)
);
```

### Tags �?
```sql
CREATE TABLE Tags (
  Id TEXT PRIMARY KEY,
  Name TEXT NOT NULL UNIQUE,
  Color TEXT
);

CREATE TABLE DocumentTags (
  DocumentId TEXT,
  TagId TEXT,
  PRIMARY KEY (DocumentId, TagId),
  FOREIGN KEY (DocumentId) REFERENCES Documents(Id),
  FOREIGN KEY (TagId) REFERENCES Tags(Id)
);
```

### Attachments �?
```sql
CREATE TABLE Attachments (
  Id TEXT PRIMARY KEY,
  DocumentId TEXT,
  FileName TEXT NOT NULL,
  FileType TEXT,
  FileSize INTEGER,
  FilePath TEXT,
  CreatedAt TEXT,
  FOREIGN KEY (DocumentId) REFERENCES Documents(Id)
);
```

### DocumentVersions �?
```sql
CREATE TABLE DocumentVersions (
  Id TEXT PRIMARY KEY,
  DocumentId TEXT,
  Version INTEGER,
  Title TEXT,
  Content TEXT,
  CreatedAt TEXT,
  CreatedBy TEXT,
  FOREIGN KEY (DocumentId) REFERENCES Documents(Id)
);
```

## 核心组件

### Document Entity

```pascal
type
  TDocumentStatus = (dsActive, dsArchived, dsDeleted);
  
  [Table('Documents')]
  TDocument = class
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
    FStatus: Integer;
    
    [Column('Version')]
    FVersion: Integer;
  public
    property Id: string read FId write FId;
    property Title: string read FTitle write FTitle;
    property Content: string read FContent write FContent;
    property CategoryId: string read FCategoryId write FCategoryId;
    property Status: TDocumentStatus read GetStatus write SetStatus;
    property Version: Integer read FVersion write FVersion;
    
    // Computed
    property Tags: TArray<TTag> read GetTags;
    property Attachments: TArray<TAttachment> read GetAttachments;
  end;
```

### Document Service

```pascal
type
  TDocumentService = class
  public
    // CRUD
    function CreateDocument(const Title, Content: string; CategoryId: string = ''): TDocument;
    function GetDocument(const Id: string): TDocument;
    function GetDocuments(CategoryId: string = ''; Status: TDocumentStatus = dsActive): TObjectList<TDocument>;
    procedure UpdateDocument(Doc: TDocument);
    procedure DeleteDocument(const Id: string; HardDelete: Boolean = False);
    
    // Version Control
    function SaveVersion(const DocId: string): Integer;
    function GetVersions(const DocId: string): TObjectList<TDocumentVersion>;
    procedure RestoreVersion(const DocId: string; Version: Integer);
    
    // Tags
    procedure AddTag(const DocId, TagName: string);
    procedure RemoveTag(const DocId, TagId: string);
    function GetDocumentsByTag(const TagName: string): TObjectList<TDocument>;
    
    // Attachments
    function AttachFile(const DocId, FilePath: string): TAttachment;
    procedure DetachFile(const AttachmentId: string);
    procedure OpenAttachment(const AttachmentId: string);
    
    // Import/Export
    procedure ExportDocument(const DocId, FilePath: string; Format: TExportFormat);
    function ImportDocument(const FilePath: string; CategoryId: string = ''): TDocument;
  end;
```

### Search Service

```pascal
type
  TSearchService = class
  public
    // 全文搜索（使�?SQLite FTS5�?
    function Search(const Query: string): TObjectList<TSearchResult>;
    
    // 高级搜索
    function AdvancedSearch(const Title, Content: string;
      CategoryId: string; Tags: TArray<string>;
      DateFrom, DateTo: TDateTime): TObjectList<TSearchResult>;
    
    // 搜索建议
    function GetSuggestions(const Prefix: string): TArray<string>;
    
    // 重建索引
    procedure RebuildIndex;
  end;
```

## DeepBase 功能演示

### 配置管理
```pascal
// 文档存储路径
DocPath := DeepBase.Config.GetConfig('docmanager.storagePath', 
  TPath.Combine(AppPath, 'Documents'));

// 自动保存间隔
AutoSaveInterval := DeepBase.Config.GetConfigInt('docmanager.autoSaveInterval', 60);
```

### 日志记录
```pascal
Log.Info('Document created: %s', [Doc.Title]);
Log.Debug('Search query: %s, Results: %d', [Query, Results.Count]);
```

### 数据绑定
```pascal
// 使用 MVVM 绑定文档编辑
type
  TDocumentViewModel = class(TViewModelBase)
    property Title: string read FTitle write SetTitle;
    property Content: string read FContent write SetContent;
    property SaveCommand: ICommand read FSaveCommand;
  end;
```

## 快速开�?

1. �?RAD Studio 中打开 `DocManager.dproj`
2. 添加 DeepBase 框架到搜索路�?
3. 编译并运�?
4. 首次运行自动创建数据库和默认分类

## 扩展指南

### 添加新的文档类型

1. 扩展 `TDocumentType` 枚举
2. �?`TDocumentService` 中添加类型特定的处理
3. 创建对应的编辑器 UI

### 集成云存�?

```pascal
type
  IStorageProvider = interface
    function Upload(const LocalPath: string): string;  // Returns remote URL
    function Download(const RemoteURL, LocalPath: string): Boolean;
    function Delete(const RemoteURL: string): Boolean;
  end;
  
  // 实现�?
  // - TLocalStorageProvider
  // - TAWSStorageProvider
  // - TAzureStorageProvider
```

### 添加协作功能

```pascal
type
  TCollaborationService = class
    procedure LockDocument(const DocId, UserId: string);
    procedure UnlockDocument(const DocId: string);
    function IsLocked(const DocId: string): Boolean;
    function GetLockOwner(const DocId: string): string;
  end;
```

## 依赖

- DeepBase Framework
- FireDAC (SQLite)
- VCL

## 许可

MIT License
