// AI-GENERATED
// DeepBase.Governance.EvidenceStore.SQLite.pas
// 第五层：Evidence 表 CRUD（SQLite）
// 依赖 Persistence + EvidenceRecorder
// DATA2-005 修复：
//   - 添加 prev_hash / this_hash 列，构成线性 HMAC-SHA256 链
//   - Save 时自动计算并写入哈希
//   - VerifyChain 方法遍历全表验证链完整性
//   - 迁移：ALTER TABLE 添加列，首次验证时重建已有行的链

unit DeepBase.Governance.EvidenceStore.SQLite;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  System.Classes,
  Data.DB,
  FireDAC.Comp.Client,
  FireDAC.Stan.Param,
  DeepBase.Governance.Types,
  DeepBase.Governance.EvidenceRecorder;

type
  /// <summary>
  /// SQLite 持久化的证据存储。
  /// DATA2-005: 每行包含 prev_hash + this_hash，构成线性 HMAC-SHA256 链，
  /// 防止有 DB 写权限的攻击者静默篡改/删除证据行。
  /// 所有写入方法内部持有 FLock，VerifyChain 同样在 FLock 下执行。
  /// </summary>
  TEvidenceStoreSQLite = class(TInterfacedObject, IEvidenceStore)
  private
    FConnection: TFDConnection;
    FOwnsConnection: Boolean;
    FHmacKey: TBytes;           // HMAC-SHA256 密钥（可为空 → 回退到 SHA-256）
    FLastChainHash: string;     // 缓存的链尾哈希（避免每次 Save 都 SELECT）
    FChainInitialized: Boolean; // 是否已从 DB 加载过链尾哈希
    FLock: TObject;             // 序列化所有 DB 访问 + 链状态

    procedure EnsureTable;
    procedure MigrateHashColumns;
    procedure MigrateExistingChain;
    procedure InitializeChainState;
    function GetLastHash: string;
    function ComputePayload(const AEntry: TEvidenceEntry): string;
    function ComputeHash(const ATimestamp, APayload, APrevHash: string): string;
    function RiskLevelToStr(ALevel: TRiskLevel): string;
    function StrToRiskLevel(const AStr: string): TRiskLevel;
    function EvidenceResultToStr(AResult: TEvidenceResult): string;
    function StrToEvidenceResult(const AStr: string): TEvidenceResult;
  public
    /// <summary>
    /// 创建 EvidenceStore。
    /// </summary>
    /// <param name="AConnection">SQLite 连接（调用方管理生命周期，除非 AOwnsConnection=True）</param>
    /// <param name="AHmacKey">HMAC-SHA256 密钥。为空时回退到普通 SHA-256（仍可检测篡改，
    /// 但攻击者知道算法即可伪造）。建议从 KeyManager.GetActiveKeyForPurpose(kpSigning) 获取。</param>
    constructor Create(AConnection: TFDConnection;
      const AHmacKey: TBytes; AOwnsConnection: Boolean = False);
    destructor Destroy; override;

    // IEvidenceStore
    procedure Save(const AEntry: TEvidenceEntry);
    function Query(const AActionKey: string; ALimit: Integer): TArray<TEvidenceEntry>;

    // 扩展查询
    function QueryByUser(const AUserId: string; ALimit: Integer): TArray<TEvidenceEntry>;
    function Count: Integer;

    /// <summary>
    /// DATA2-005: 遍历全表，验证 HMAC 链完整性。
    /// </summary>
    /// <param name="ABrokenCount">链断裂的行数</param>
    /// <param name="ATotalRows">验证的总行数</param>
    /// <returns>True 表示链完整（或表为空）</returns>
    function VerifyChain(out ABrokenCount, ATotalRows: Integer): Boolean;
  end;

  /// DATA2-005: 链验证时发现单行断裂的信息
  TEvidenceChainLink = record
    RowId: string;
    ExpectedHash: string;
    StoredHash: string;
    LinkIndex: Integer;
  end;

implementation

uses
  System.DateUtils,
  System.Hash,
  System.SyncObjs,
  System.NetEncoding,
  DeepBase.Crypto, DeepBase.Crypto.Hash, DeepBase.Crypto.Encoding;

const
  /// DATA2-005: 创世哈希（用于第一行的 prev_hash）
  GENESIS_HASH =
    '0000000000000000000000000000000000000000000000000000000000000000';

  SQL_CREATE_TABLE =
    'CREATE TABLE IF NOT EXISTS governance_evidence (' +
    '  id TEXT PRIMARY KEY,' +
    '  schema_version INTEGER NOT NULL DEFAULT 1,' +
    '  correlation_id TEXT,' +
    '  timestamp TEXT NOT NULL,' +
    '  user_id TEXT,' +
    '  action_key TEXT NOT NULL,' +
    '  risk_level TEXT NOT NULL,' +
    '  gate_path TEXT,' +
    '  input_summary TEXT,' +
    '  output_summary TEXT,' +
    '  result TEXT NOT NULL,' +
    '  blocked_reason TEXT,' +
    '  snapshot_data TEXT,' +
    '  created_at TEXT NOT NULL' +
    ')';

  SQL_CREATE_INDEX_ACTION =
    'CREATE INDEX IF NOT EXISTS idx_evidence_action ON governance_evidence(action_key, timestamp)';

  SQL_CREATE_INDEX_USER =
    'CREATE INDEX IF NOT EXISTS idx_evidence_user ON governance_evidence(user_id, timestamp)';

  SQL_CREATE_INDEX_CORRELATION =
    'CREATE INDEX IF NOT EXISTS idx_evidence_correlation ON governance_evidence(correlation_id)';

  // DATA2-005: 哈希列迁移（ALTER TABLE）
  SQL_ALTER_PREV_HASH =
    'ALTER TABLE governance_evidence ADD COLUMN prev_hash TEXT NOT NULL DEFAULT '''';';
  SQL_ALTER_THIS_HASH =
    'ALTER TABLE governance_evidence ADD COLUMN this_hash TEXT NOT NULL DEFAULT '''';';

  // DATA2-005: 插入时包含 prev_hash + this_hash
  SQL_INSERT =
    'INSERT INTO governance_evidence (id, schema_version, correlation_id, timestamp, user_id, action_key, ' +
    'risk_level, gate_path, input_summary, output_summary, result, ' +
    'blocked_reason, snapshot_data, created_at, prev_hash, this_hash) VALUES ' +
    '(:id, :schema_version, :correlation_id, :timestamp, :user_id, :action_key, :risk_level, :gate_path, ' +
    ':input_summary, :output_summary, :result, :blocked_reason, ' +
    ':snapshot_data, :created_at, :prev_hash, :this_hash)';

  SQL_QUERY_BY_ACTION =
    'SELECT * FROM governance_evidence WHERE action_key = :action_key ' +
    'ORDER BY timestamp DESC LIMIT :limit';

  SQL_QUERY_BY_USER =
    'SELECT * FROM governance_evidence WHERE user_id = :user_id ' +
    'ORDER BY timestamp DESC LIMIT :limit';

  SQL_COUNT =
    'SELECT COUNT(*) FROM governance_evidence';

  // DATA2-005: 查询链尾哈希
  SQL_LAST_HASH =
    'SELECT this_hash FROM governance_evidence ' +
    'ORDER BY created_at DESC, id DESC LIMIT 1';

  // DATA2-005: 链验证用查询（按创建时间正序）
  SQL_VERIFY_CHAIN =
    'SELECT id, timestamp, user_id, action_key, risk_level, ' +
    'input_summary, output_summary, result, prev_hash, this_hash ' +
    'FROM governance_evidence ORDER BY created_at ASC, id ASC';

  // DATA2-005: 更新单行哈希
  SQL_UPDATE_HASH =
    'UPDATE governance_evidence SET prev_hash = :prev_hash, this_hash = :this_hash ' +
    'WHERE id = :id';

{ TEvidenceStoreSQLite }

constructor TEvidenceStoreSQLite.Create(AConnection: TFDConnection;
  const AHmacKey: TBytes; AOwnsConnection: Boolean);
begin
  inherited Create;
  FConnection := AConnection;
  FOwnsConnection := AOwnsConnection;
  FHmacKey := Copy(AHmacKey);  // 防御性拷贝
  FLock := TObject.Create;
  FChainInitialized := False;
  FLastChainHash := '';
  EnsureTable;
  MigrateHashColumns;
  // GOV-R3-002 (D-002): 旧库行 this_hash 为空, 若不回填, VerifyChain 对旧库行必然误报篡改。
  // 必须在 InitializeChainState 之前迁移, 否则链尾缓存读到的是空哈希。
  MigrateExistingChain;
  InitializeChainState;
end;

destructor TEvidenceStoreSQLite.Destroy;
begin
  if FOwnsConnection then
    FConnection.Free;
  FLock.Free;
  inherited;
end;

procedure TEvidenceStoreSQLite.EnsureTable;
begin
  FConnection.ExecSQL(SQL_CREATE_TABLE);
  FConnection.ExecSQL(SQL_CREATE_INDEX_ACTION);
  FConnection.ExecSQL(SQL_CREATE_INDEX_USER);
  FConnection.ExecSQL(SQL_CREATE_INDEX_CORRELATION);
end;

{ DATA2-005: 迁移 —— 为旧表添加 prev_hash / this_hash 列 }
procedure TEvidenceStoreSQLite.MigrateHashColumns;
begin
  // ALTER TABLE ADD COLUMN 无 IF NOT EXISTS（SQLite 不支持），
  // 所以通过捕获异常来兼容重复迁移。
  try
    FConnection.ExecSQL(SQL_ALTER_PREV_HASH);
  except
    on E: EDatabaseError do
      ; // 列已存在，忽略
  end;
  try
    FConnection.ExecSQL(SQL_ALTER_THIS_HASH);
  except
    on E: EDatabaseError do
      ; // 列已存在，忽略
  end;
end;

{ DATA2-005: 从 DB 加载链尾哈希，作为下一次 Save 的 prev_hash }
procedure TEvidenceStoreSQLite.InitializeChainState;
begin
  // 注意：构造函数内调用，此时还没有并发问题；
  // 但仍然通过 Monitor 保护 FLastChainHash 的写入。
  System.TMonitor.Enter(FLock);
  try
    FLastChainHash := GetLastHash;
    FChainInitialized := True;
  finally
    System.TMonitor.Exit(FLock);
  end;
end;

{ DATA2-005: 查询当前链尾哈希（必须在 FLock 内调用） }
function TEvidenceStoreSQLite.GetLastHash: string;
var
  LQuery: TFDQuery;
begin
  Result := '';
  LQuery := TFDQuery.Create(nil);
  try
    LQuery.Connection := FConnection;
    LQuery.SQL.Text := SQL_LAST_HASH;
    LQuery.Open;
    if not LQuery.Eof then
      Result := LQuery.Fields[0].AsString;
  finally
    LQuery.Free;
  end;
  // 表为空或哈希列为空 → 返回创世哈希作为首行的 prev_hash
  if Result = '' then
    Result := GENESIS_HASH;
end;

{ DATA2-005: 将证据行的业务字段序列化為 HMAC 输入（不含 prev_hash/this_hash 本身） }
function TEvidenceStoreSQLite.ComputePayload(const AEntry: TEvidenceEntry): string;
begin
  // 使用 | 分隔各字段；任何字段内容被篡改都会改变哈希。
  // 顺序：id, ts, user, action, risk, gate, input, output, result, blocked
  Result := AEntry.Id + '|' +
    DateToISO8601(AEntry.Timestamp) + '|' +
    AEntry.UserId + '|' +
    AEntry.ActionKey + '|' +
    RiskLevelToStr(AEntry.RiskLevel) + '|' +
    AEntry.GatePath + '|' +
    AEntry.InputSummary + '|' +
    AEntry.OutputSummary + '|' +
    EvidenceResultToStr(AEntry.Result) + '|' +
    AEntry.BlockedReason;
end;

{ DATA2-005: 计算 this_hash = HMAC-SHA256(key, timestamp || payload || prev_hash)
  若 FHmacKey 为空则回退到 SHA-256 }
function TEvidenceStoreSQLite.ComputeHash(const ATimestamp, APayload,
  APrevHash: string): string;
var
  LInput: string;
begin
  LInput := ATimestamp + APayload + APrevHash;
  if Length(FHmacKey) > 0 then
    // FHmacKey 是二进制 TBytes 密钥，用 TBytes/TBytes 重载保持二进制语义；
    // 返回 TBytes，再 HexEncode 转十六进制（与 else 分支 HashToHex 输出格式一致）。
    Result := TEncodingUtils.HexEncode(
      THashUtils.HMAC(FHmacKey, TEncoding.UTF8.GetBytes(LInput), haSHA256))
  else
    Result := THashUtils.HashToHex(LInput, haSHA256);
end;

function TEvidenceStoreSQLite.RiskLevelToStr(ALevel: TRiskLevel): string;
begin
  case ALevel of
    rlL0: Result := 'L0';
    rlL1: Result := 'L1';
    rlL2: Result := 'L2';
    rlL3: Result := 'L3';
  else
    Result := 'L0';
  end;
end;

function TEvidenceStoreSQLite.StrToRiskLevel(const AStr: string): TRiskLevel;
begin
  if AStr = 'L1' then Result := rlL1
  else if AStr = 'L2' then Result := rlL2
  else if AStr = 'L3' then Result := rlL3
  else Result := rlL0;
end;

function TEvidenceStoreSQLite.EvidenceResultToStr(AResult: TEvidenceResult): string;
begin
  case AResult of
    erSuccess: Result := 'success';
    erFail:    Result := 'fail';
    erBlocked: Result := 'blocked';
  else
    Result := 'success';
  end;
end;

function TEvidenceStoreSQLite.StrToEvidenceResult(const AStr: string): TEvidenceResult;
begin
  if AStr = 'fail' then Result := erFail
  else if AStr = 'blocked' then Result := erBlocked
  else Result := erSuccess;
end;

{ DATA2-005: 保存证据行，同时计算并写入 prev_hash + this_hash }
procedure TEvidenceStoreSQLite.Save(const AEntry: TEvidenceEntry);
var
  LQuery: TFDQuery;
  LTimestamp, LPayload, LPrevHash, LThisHash: string;
begin
  System.TMonitor.Enter(FLock);
  try
    // 惰性初始化（若构造函数中 InitializeChainState 尚未完成）
    if not FChainInitialized then
    begin
      FLastChainHash := GetLastHash;
      FChainInitialized := True;
    end;

    LTimestamp := DateToISO8601(AEntry.Timestamp);
    LPayload := ComputePayload(AEntry);
    LPrevHash := FLastChainHash;
    LThisHash := ComputeHash(LTimestamp, LPayload, LPrevHash);

    LQuery := TFDQuery.Create(nil);
    try
      LQuery.Connection := FConnection;
      LQuery.SQL.Text := SQL_INSERT;
      LQuery.ParamByName('id').AsString := AEntry.Id;
      LQuery.ParamByName('schema_version').AsInteger := AEntry.SchemaVersion;
      LQuery.ParamByName('correlation_id').AsString := AEntry.CorrelationId;
      LQuery.ParamByName('timestamp').AsString := LTimestamp;
      LQuery.ParamByName('user_id').AsString := AEntry.UserId;
      LQuery.ParamByName('action_key').AsString := AEntry.ActionKey;
      LQuery.ParamByName('risk_level').AsString := RiskLevelToStr(AEntry.RiskLevel);
      LQuery.ParamByName('gate_path').AsString := AEntry.GatePath;
      LQuery.ParamByName('input_summary').AsString := AEntry.InputSummary;
      LQuery.ParamByName('output_summary').AsString := AEntry.OutputSummary;
      LQuery.ParamByName('result').AsString := EvidenceResultToStr(AEntry.Result);
      LQuery.ParamByName('blocked_reason').AsString := AEntry.BlockedReason;
      LQuery.ParamByName('snapshot_data').AsString := AEntry.SnapshotData;
      LQuery.ParamByName('created_at').AsString := DateToISO8601(Now);
      // DATA2-005: 哈希链字段
      LQuery.ParamByName('prev_hash').AsString := LPrevHash;
      LQuery.ParamByName('this_hash').AsString := LThisHash;
      LQuery.ExecSQL;
    finally
      LQuery.Free;
    end;

    // 更新链尾缓存
    FLastChainHash := LThisHash;
  finally
    System.TMonitor.Exit(FLock);
  end;
end;

function TEvidenceStoreSQLite.Query(const AActionKey: string;
  ALimit: Integer): TArray<TEvidenceEntry>;
var
  LQuery: TFDQuery;
  LList: TList<TEvidenceEntry>;
  LEntry: TEvidenceEntry;
begin
  LList := TList<TEvidenceEntry>.Create;
  try
    System.TMonitor.Enter(FLock);
    try
      LQuery := TFDQuery.Create(nil);
      try
        LQuery.Connection := FConnection;
        LQuery.SQL.Text := SQL_QUERY_BY_ACTION;
        LQuery.ParamByName('action_key').AsString := AActionKey;
        LQuery.ParamByName('limit').AsInteger := ALimit;
        LQuery.Open;

        while not LQuery.Eof do
        begin
          LEntry.Id := LQuery.FieldByName('id').AsString;
          LEntry.SchemaVersion := LQuery.FieldByName('schema_version').AsInteger;
          LEntry.CorrelationId := LQuery.FieldByName('correlation_id').AsString;
          LEntry.Timestamp := ISO8601ToDate(LQuery.FieldByName('timestamp').AsString);
          LEntry.UserId := LQuery.FieldByName('user_id').AsString;
          LEntry.ActionKey := LQuery.FieldByName('action_key').AsString;
          LEntry.RiskLevel := StrToRiskLevel(LQuery.FieldByName('risk_level').AsString);
          LEntry.GatePath := LQuery.FieldByName('gate_path').AsString;
          LEntry.InputSummary := LQuery.FieldByName('input_summary').AsString;
          LEntry.OutputSummary := LQuery.FieldByName('output_summary').AsString;
          LEntry.Result := StrToEvidenceResult(LQuery.FieldByName('result').AsString);
          LEntry.BlockedReason := LQuery.FieldByName('blocked_reason').AsString;
          LEntry.SnapshotData := LQuery.FieldByName('snapshot_data').AsString;
          LList.Add(LEntry);
          LQuery.Next;
        end;
      finally
        LQuery.Free;
      end;
    finally
      System.TMonitor.Exit(FLock);
    end;
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

function TEvidenceStoreSQLite.QueryByUser(const AUserId: string;
  ALimit: Integer): TArray<TEvidenceEntry>;
var
  LQuery: TFDQuery;
  LList: TList<TEvidenceEntry>;
  LEntry: TEvidenceEntry;
begin
  LList := TList<TEvidenceEntry>.Create;
  try
    System.TMonitor.Enter(FLock);
    try
      LQuery := TFDQuery.Create(nil);
      try
        LQuery.Connection := FConnection;
        LQuery.SQL.Text := SQL_QUERY_BY_USER;
        LQuery.ParamByName('user_id').AsString := AUserId;
        LQuery.ParamByName('limit').AsInteger := ALimit;
        LQuery.Open;

        while not LQuery.Eof do
        begin
          LEntry.Id := LQuery.FieldByName('id').AsString;
          LEntry.UserId := LQuery.FieldByName('user_id').AsString;
          LEntry.ActionKey := LQuery.FieldByName('action_key').AsString;
          LEntry.Result := StrToEvidenceResult(LQuery.FieldByName('result').AsString);
          LList.Add(LEntry);
          LQuery.Next;
        end;
      finally
        LQuery.Free;
      end;
    finally
      System.TMonitor.Exit(FLock);
    end;
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

function TEvidenceStoreSQLite.Count: Integer;
var
  LQuery: TFDQuery;
begin
  System.TMonitor.Enter(FLock);
  try
    LQuery := TFDQuery.Create(nil);
    try
      LQuery.Connection := FConnection;
      LQuery.SQL.Text := SQL_COUNT;
      LQuery.Open;
      Result := LQuery.Fields[0].AsInteger;
    finally
      LQuery.Free;
    end;
  finally
    System.TMonitor.Exit(FLock);
  end;
end;

{ DATA2-005: 迁移已有行的哈希链 —— 按 created_at 顺序逐行重建 }
procedure TEvidenceStoreSQLite.MigrateExistingChain;
var
  LReadQuery, LUpdateQuery: TFDQuery;
  LPrevHash, LThisHash, LTimestamp, LPayload, LId: string;
  LEntry: TEvidenceEntry;
begin
  LReadQuery := TFDQuery.Create(nil);
  LUpdateQuery := TFDQuery.Create(nil);
  try
    LReadQuery.Connection := FConnection;
    LReadQuery.SQL.Text := SQL_VERIFY_CHAIN;
    LReadQuery.Open;

    LUpdateQuery.Connection := FConnection;
    LPrevHash := GENESIS_HASH;

    // GOV-R3-004 (D-004): 多行 UPDATE 在循环中逐行提交, 崩溃/异常致链断裂（部分行已回填, 部分仍空）。
    // 整个迁移作为一个原子事务: 全成或全回退。
    FConnection.StartTransaction;
    try
      while not LReadQuery.Eof do
      begin
        // 只处理尚未迁移的行（this_hash 为空）
        if LReadQuery.FieldByName('this_hash').AsString = '' then
        begin
          LId := LReadQuery.FieldByName('id').AsString;
          LTimestamp := LReadQuery.FieldByName('timestamp').AsString;

          // 重建 Entry 用于 Payload 计算
          LEntry.Id := LId;
          LEntry.Timestamp := ISO8601ToDate(LTimestamp);
          LEntry.UserId := LReadQuery.FieldByName('user_id').AsString;
          LEntry.ActionKey := LReadQuery.FieldByName('action_key').AsString;
          LEntry.RiskLevel := StrToRiskLevel(LReadQuery.FieldByName('risk_level').AsString);
          LEntry.GatePath := LReadQuery.FieldByName('gate_path').AsString;
          LEntry.InputSummary := LReadQuery.FieldByName('input_summary').AsString;
          LEntry.OutputSummary := LReadQuery.FieldByName('output_summary').AsString;
          LEntry.Result := StrToEvidenceResult(LReadQuery.FieldByName('result').AsString);
          LEntry.BlockedReason := LReadQuery.FieldByName('blocked_reason').AsString;

          LPayload := ComputePayload(LEntry);
          LThisHash := ComputeHash(LTimestamp, LPayload, LPrevHash);

          LUpdateQuery.SQL.Text := SQL_UPDATE_HASH;
          LUpdateQuery.ParamByName('prev_hash').AsString := LPrevHash;
          LUpdateQuery.ParamByName('this_hash').AsString := LThisHash;
          LUpdateQuery.ParamByName('id').AsString := LId;
          LUpdateQuery.ExecSQL;

          LPrevHash := LThisHash;
        end
        else
        begin
          // 已迁移的行，推进 prev_hash
          LPrevHash := LReadQuery.FieldByName('this_hash').AsString;
        end;
        LReadQuery.Next;
      end;
      FConnection.Commit;
    except
      // 异常时回退, 保证不会出现"部分行已回填 + 部分仍空"的断裂链
      FConnection.Rollback;
      raise;
    end;

    // 更新链尾缓存（事务已提交, 读到的是已回填的链尾哈希）
    FLastChainHash := GetLastHash;
  finally
    LReadQuery.Free;
    LUpdateQuery.Free;
  end;
end;

{ DATA2-005: 遍历全表验证 HMAC 链完整性 }
function TEvidenceStoreSQLite.VerifyChain(out ABrokenCount,
  ATotalRows: Integer): Boolean;
var
  LQuery: TFDQuery;
  LPrevHash, LExpectedHash, LTimestamp, LPayload, LStoredHash: string;
  LEntry: TEvidenceEntry;
begin
  System.TMonitor.Enter(FLock);
  try
    // 首次验证时迁移旧数据
    if not FChainInitialized then
    begin
      FLastChainHash := GetLastHash;
      FChainInitialized := True;
    end;

    LQuery := TFDQuery.Create(nil);
    try
      LQuery.Connection := FConnection;
      LQuery.SQL.Text := SQL_VERIFY_CHAIN;
      LQuery.Open;

      ABrokenCount := 0;
      ATotalRows := 0;
      LPrevHash := GENESIS_HASH;

      while not LQuery.Eof do
      begin
        Inc(ATotalRows);
        LTimestamp := LQuery.FieldByName('timestamp').AsString;
        LStoredHash := LQuery.FieldByName('this_hash').AsString;

        // 重建 Entry 用于 Payload 计算
        LEntry.Id := LQuery.FieldByName('id').AsString;
        LEntry.Timestamp := ISO8601ToDate(LTimestamp);
        LEntry.UserId := LQuery.FieldByName('user_id').AsString;
        LEntry.ActionKey := LQuery.FieldByName('action_key').AsString;
        LEntry.RiskLevel := StrToRiskLevel(LQuery.FieldByName('risk_level').AsString);
        LEntry.GatePath := LQuery.FieldByName('gate_path').AsString;
        LEntry.InputSummary := LQuery.FieldByName('input_summary').AsString;
        LEntry.OutputSummary := LQuery.FieldByName('output_summary').AsString;
        LEntry.Result := StrToEvidenceResult(LQuery.FieldByName('result').AsString);
        LEntry.BlockedReason := LQuery.FieldByName('blocked_reason').AsString;

        LPayload := ComputePayload(LEntry);
        LExpectedHash := ComputeHash(LTimestamp, LPayload, LPrevHash);

        if not SameText(LStoredHash, LExpectedHash) then
          Inc(ABrokenCount);

        // 下一行的 prev_hash = 本行的 this_hash（即使本行被破坏，也继续用存储值
        // 以保证后续链段的连续性；这样可定位到第一个被篡改的行）
        if LStoredHash <> '' then
          LPrevHash := LStoredHash
        else
          LPrevHash := LExpectedHash;  // 未迁移行：用计算值推进

        LQuery.Next;
      end;
    finally
      LQuery.Free;
    end;

    Result := (ABrokenCount = 0);
  finally
    System.TMonitor.Exit(FLock);
  end;
end;

end.
