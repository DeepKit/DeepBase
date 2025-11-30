unit Data.Module;

{*******************************************************************************
  Data Module - 数据模块

  UniBase 框架文档管理模板 - 数据访问层
*******************************************************************************}

interface

uses
  System.SysUtils, System.Classes, System.IOUtils,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Error, FireDAC.UI.Intf,
  FireDAC.Phys.Intf, FireDAC.Stan.Def, FireDAC.Stan.Pool, FireDAC.Stan.Async,
  FireDAC.Phys, FireDAC.Phys.SQLite, FireDAC.Phys.SQLiteDef,
  FireDAC.Stan.ExprFuncs, FireDAC.VCLUI.Wait, FireDAC.Comp.Client,
  FireDAC.Stan.Param, FireDAC.DatS, FireDAC.DApt.Intf, FireDAC.DApt,
  FireDAC.Comp.DataSet, Data.DB,
  Service.Document, Service.Search;

type
  TDataModule1 = class(TDataModule)
    FDConnection1: TFDConnection;
    FDPhysSQLiteDriverLink1: TFDPhysSQLiteDriverLink;
    qryDocuments: TFDQuery;
    qryCategories: TFDQuery;
    qryTags: TFDQuery;
    procedure DataModuleCreate(Sender: TObject);
    procedure DataModuleDestroy(Sender: TObject);
  private
    FDocumentService: TDocumentService;
    FSearchService: TSearchService;
    FStoragePath: string;
    FDatabasePath: string;

    procedure InitializeDatabase;
    procedure CreateTables;
    procedure CreateDefaultCategories;
  public
    property DocumentService: TDocumentService read FDocumentService;
    property SearchService: TSearchService read FSearchService;
    property StoragePath: string read FStoragePath;
    property DatabasePath: string read FDatabasePath;
  end;

var
  DataModule1: TDataModule1;

implementation

{%CLASSGROUP 'Vcl.Controls.TControl'}

{$R *.dfm}

uses
  UniBase.Manager, UniBase.Logger;

procedure TDataModule1.DataModuleCreate(Sender: TObject);
begin
  // 初始化路径
  FStoragePath := TPath.Combine(UniBase.GetAppPath, 'Documents');
  FDatabasePath := TPath.Combine(UniBase.GetAppPath, 'docmanager.db');

  if not TDirectory.Exists(FStoragePath) then
    TDirectory.CreateDirectory(FStoragePath);

  // 初始化数据库
  InitializeDatabase;

  // 创建服务
  FDocumentService := TDocumentService.Create(FDConnection1, FStoragePath);
  FSearchService := TSearchService.Create(FDConnection1);

  Log.Info('DataModule initialized');
end;

procedure TDataModule1.DataModuleDestroy(Sender: TObject);
begin
  FSearchService.Free;
  FDocumentService.Free;
  FDConnection1.Close;
  Log.Info('DataModule destroyed');
end;

procedure TDataModule1.InitializeDatabase;
begin
  FDConnection1.Params.Clear;
  FDConnection1.Params.Add('DriverID=SQLite');
  FDConnection1.Params.Add('Database=' + FDatabasePath);
  FDConnection1.Params.Add('LockingMode=Normal');
  FDConnection1.Params.Add('JournalMode=WAL');
  FDConnection1.Connected := True;

  CreateTables;
  CreateDefaultCategories;

  Log.Info('Database initialized: %s', [FDatabasePath]);
end;

procedure TDataModule1.CreateTables;
var
  Q: TFDQuery;
begin
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FDConnection1;

    // Documents 表
    Q.SQL.Text :=
      'CREATE TABLE IF NOT EXISTS Documents (' +
      '  Id TEXT PRIMARY KEY,' +
      '  Title TEXT NOT NULL,' +
      '  Content TEXT,' +
      '  CategoryId TEXT,' +
      '  Status INTEGER DEFAULT 0,' +
      '  Version INTEGER DEFAULT 1,' +
      '  CreatedAt TEXT,' +
      '  UpdatedAt TEXT,' +
      '  CreatedBy TEXT,' +
      '  FOREIGN KEY (CategoryId) REFERENCES Categories(Id)' +
      ')';
    Q.ExecSQL;

    // Categories 表
    Q.SQL.Text :=
      'CREATE TABLE IF NOT EXISTS Categories (' +
      '  Id TEXT PRIMARY KEY,' +
      '  Name TEXT NOT NULL,' +
      '  ParentId TEXT,' +
      '  SortOrder INTEGER DEFAULT 0,' +
      '  Description TEXT,' +
      '  IconIndex INTEGER DEFAULT 0,' +
      '  CreatedAt TEXT,' +
      '  FOREIGN KEY (ParentId) REFERENCES Categories(Id)' +
      ')';
    Q.ExecSQL;

    // Tags 表
    Q.SQL.Text :=
      'CREATE TABLE IF NOT EXISTS Tags (' +
      '  Id TEXT PRIMARY KEY,' +
      '  Name TEXT NOT NULL UNIQUE,' +
      '  Color TEXT,' +
      '  UsageCount INTEGER DEFAULT 0,' +
      '  CreatedAt TEXT' +
      ')';
    Q.ExecSQL;

    // DocumentTags 表
    Q.SQL.Text :=
      'CREATE TABLE IF NOT EXISTS DocumentTags (' +
      '  DocumentId TEXT,' +
      '  TagId TEXT,' +
      '  CreatedAt TEXT,' +
      '  PRIMARY KEY (DocumentId, TagId),' +
      '  FOREIGN KEY (DocumentId) REFERENCES Documents(Id),' +
      '  FOREIGN KEY (TagId) REFERENCES Tags(Id)' +
      ')';
    Q.ExecSQL;

    // Attachments 表
    Q.SQL.Text :=
      'CREATE TABLE IF NOT EXISTS Attachments (' +
      '  Id TEXT PRIMARY KEY,' +
      '  DocumentId TEXT,' +
      '  FileName TEXT NOT NULL,' +
      '  FileType TEXT,' +
      '  FileSize INTEGER,' +
      '  FilePath TEXT,' +
      '  CreatedAt TEXT,' +
      '  FOREIGN KEY (DocumentId) REFERENCES Documents(Id)' +
      ')';
    Q.ExecSQL;

    // DocumentVersions 表
    Q.SQL.Text :=
      'CREATE TABLE IF NOT EXISTS DocumentVersions (' +
      '  Id TEXT PRIMARY KEY,' +
      '  DocumentId TEXT,' +
      '  Version INTEGER,' +
      '  Title TEXT,' +
      '  Content TEXT,' +
      '  CreatedAt TEXT,' +
      '  CreatedBy TEXT,' +
      '  ChangeNote TEXT,' +
      '  FOREIGN KEY (DocumentId) REFERENCES Documents(Id)' +
      ')';
    Q.ExecSQL;

    // 索引
    Q.SQL.Text := 'CREATE INDEX IF NOT EXISTS idx_docs_category ON Documents(CategoryId)';
    Q.ExecSQL;
    Q.SQL.Text := 'CREATE INDEX IF NOT EXISTS idx_docs_status ON Documents(Status)';
    Q.ExecSQL;
    Q.SQL.Text := 'CREATE INDEX IF NOT EXISTS idx_docs_updated ON Documents(UpdatedAt)';
    Q.ExecSQL;
    Q.SQL.Text := 'CREATE INDEX IF NOT EXISTS idx_cat_parent ON Categories(ParentId)';
    Q.ExecSQL;
    Q.SQL.Text := 'CREATE INDEX IF NOT EXISTS idx_versions_doc ON DocumentVersions(DocumentId)';
    Q.ExecSQL;
  finally
    Q.Free;
  end;
end;

procedure TDataModule1.CreateDefaultCategories;
var
  Q: TFDQuery;
begin
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FDConnection1;

    // 检查是否已有分类
    Q.SQL.Text := 'SELECT COUNT(*) AS Cnt FROM Categories';
    Q.Open;
    if Q.FieldByName('Cnt').AsInteger > 0 then
      Exit;

    // 创建默认分类
    Q.SQL.Text :=
      'INSERT INTO Categories (Id, Name, ParentId, SortOrder, Description, CreatedAt) VALUES ' +
      '(:Id, :Name, :Parent, :Sort, :Desc, :Created)';

    // 工作
    Q.ParamByName('Id').AsString := 'cat-work';
    Q.ParamByName('Name').AsString := '工作';
    Q.ParamByName('Parent').Clear;
    Q.ParamByName('Sort').AsInteger := 1;
    Q.ParamByName('Desc').AsString := '工作相关文档';
    Q.ParamByName('Created').AsDateTime := Now;
    Q.ExecSQL;

    // 学习
    Q.ParamByName('Id').AsString := 'cat-study';
    Q.ParamByName('Name').AsString := '学习';
    Q.ParamByName('Parent').Clear;
    Q.ParamByName('Sort').AsInteger := 2;
    Q.ParamByName('Desc').AsString := '学习笔记';
    Q.ParamByName('Created').AsDateTime := Now;
    Q.ExecSQL;

    // 个人
    Q.ParamByName('Id').AsString := 'cat-personal';
    Q.ParamByName('Name').AsString := '个人';
    Q.ParamByName('Parent').Clear;
    Q.ParamByName('Sort').AsInteger := 3;
    Q.ParamByName('Desc').AsString := '个人文档';
    Q.ParamByName('Created').AsDateTime := Now;
    Q.ExecSQL;

    // 归档
    Q.ParamByName('Id').AsString := 'cat-archive';
    Q.ParamByName('Name').AsString := '归档';
    Q.ParamByName('Parent').Clear;
    Q.ParamByName('Sort').AsInteger := 99;
    Q.ParamByName('Desc').AsString := '已归档文档';
    Q.ParamByName('Created').AsDateTime := Now;
    Q.ExecSQL;

    Log.Info('Default categories created');
  finally
    Q.Free;
  end;
end;

end.
