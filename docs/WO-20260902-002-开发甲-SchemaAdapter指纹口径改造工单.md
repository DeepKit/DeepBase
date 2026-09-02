# WO-20260902-002 · 开发甲 · SchemaAdapter 指纹口径改造 + WeChat4x 真实指纹落位（解锁 BLOCKED-DATA-P0-001）

- 下发时间：2026-09-02 (GMT+8)
- 下发人：主控AI（审核侧，受老板指示）
- 承接方：**开发甲（DeepBase / Core + DeepAxis）**
- 工作仓库：`D:\_Progs\02Business\DeepBase`（主工作区，勿动 `.claude\worktrees\*`）
- 前置工单：WO-20260902-001（BUG332 交付的 hex 校验 / virtual Create / Registry 跳过逻辑全部复用，勿重做）
- 优先级：P1（解锁 WO-20260902-001 的 CLOSE）
- 数据来源：`D:\_Progs\02Business\DeepAxis\DeCrypt\fingerprint\deepbase_dump\`（微信 4.1.13.12 生产账号 dump，主控已独立复算三个全量指纹全部 MATCH，32 张 Msg_* 表列签名跨 3 文件完全一致）
- 门禁：《非睿智轻量门禁规范-v1》G1–G5；dcc64 0 Error / 0 Warning；全量测试通过且 XML 存档

---

## 一、背景与主控核实结论（勿重复审计）

微信 4.x schema dump 已交付并通过复算互验。**关键结论改变了方案**：

1. **全量指纹（含表名）不可用作适配器判据**：`Msg_<md5(对方username)>` 分片表名随账号/联系人变化——同一账号的 message_0/1/2 三个文件全量指纹就互不相同（4868…/6d23…/9029…）。固定前缀匹配全量指纹**永不可能跨账号命中**。
2. **深层根因（新发现）**：`TExternalSQLiteReader.TryResolveAdapter`（[DeepBase.External.SQLiteReader.pas:126](file:///d:/_Progs/02Business/DeepBase/DeepAxis/DeepBase.External.SQLiteReader.pas#L126)）把 `GetSchemaFingerprint` 的**全量指纹**传给 Registry，而适配器前缀声称的是**列签名**——口径错位。这意味着 **39x 的 `e4a7b3c9f1` 在生产上也从未命中过**，BUG-332 上轮只修了表层（hex 校验），本工单补根因。
3. **稳定判据（实测数据）**：
   - 三个 message 文件、32 张 `Msg_*` 表，列签名**完全一致**（17 列，`local_id..WCDB_CT_source`）
   - 静态表 `Name2Id` / `TimeStamp` / `wcdb_builtin_compression_record` 三文件全有、列签名一致
   - `message_1.db` 无任何 `Msg_*` 表（仅 3 张静态表）

**主控已计算并冻结的权威值**（口径：`(` + 每列 `名:类型,`（每列后带逗号，含最后一列）+ `)`，UTF-8 SHA256 小写 hex，与 `GetSchemaFingerprint` 表级格式一致、去掉表名）：

| 项 | 值 |
|---|---|
| Msg 17 列签名完整串 | `(local_id:INTEGER,server_id:INTEGER,local_type:INTEGER,sort_seq:INTEGER,real_sender_id:INTEGER,create_time:INTEGER,status:INTEGER,upload_status:INTEGER,download_status:INTEGER,server_seq:INTEGER,origin_source:INTEGER,source:TEXT,message_content:TEXT,compress_content:TEXT,packed_info_data:BLOB,WCDB_CT_message_content:INTEGER,WCDB_CT_source:INTEGER,)` |
| **Msg 列签名 SHA256** | `26d53fe31f389e65779419dc30bfdd73df5f1c299215fa4a0dccd525910cda84` |
| **WeChat4x 注册前缀（10 hex）** | **`26d53fe31f`** |
| Name2Id 签名 SHA256 | `b7d037c8a4b31c5dd124c5c4b2eed666b93106cc4e0f42735ca1fa27f14968ea` |
| TimeStamp 签名 SHA256 | `65f4abade9c280214aeca4d6a89234075a3b6a532084b06299d43a4fb128ee0e` |
| WCDB 压缩表签名 SHA256 | `c19bfac2f14b6d49184c837cc43471bfa4bccd5f11d7612c6157ea2d7b43e84a` |

**范围纪律**：只做本工单的指纹口径改造。39x 前缀无 3.9.x 真实数据，保持占位并标注，**禁止虚构 39x 指纹值**。

---

## 二、修复项明细

### FIX-A · SQLiteReader 新增「消息列签名指纹」计算（SSOT，唯一计算点）

- **文件**：`D:\_Progs\02Business\DeepBase\DeepAxis\DeepBase.External.SQLiteReader.pas`
- **要求**：
  1. 新增函数（命名建议 `GetMessageColumnSignatureFingerprint`）：枚举 `sqlite_master` 中所有 `Msg_%` 表；对每张表按 `PRAGMA table_info` 取 `name:type` 序列，拼 `(` + 每列 `名:类型,` + `)`，SHA256 小写 hex。
  2. **一致性校验**：≥1 张 Msg 表且全部列签名串一致才返回该 SHA256；0 张 Msg 表（如 message_1.db）返回空串；列签名不一致返回空串并记 Warn 日志（异常结构，不猜）。
  3. 拼接逻辑与 `GetSchemaFingerprint` 共用列级拼接 helper（一个函数拼「名:类型,」，两处调用），禁止复制两份拼接代码。
  4. `GetSchemaFingerprint`（全量指纹）**保持不动**，仍用于 schema 变化检测（:495-498 的语义正确：表增删应当触发）。

### FIX-B · TryResolveAdapter 改传列签名指纹

- **文件**：同上，[:126-135](file:///d:/_Progs/02Business/DeepBase/DeepAxis/DeepBase.External.SQLiteReader.pas#L126-L135) 及调用点 [:496](file:///d:/_Progs/02Business/DeepBase/DeepAxis/DeepBase.External.SQLiteReader.pas#L496)
- **要求**：
  1. resolve 用指纹改为 `GetMessageColumnSignatureFingerprint` 的结果；:496 的 schema 变化重 resolve 同步改。
  2. 搜索初次打开路径的 resolve 调用（若有），同步切换；若初次打开不 resolve，补上。
  3. 空列签名指纹（无 Msg 表）时行为要明确：不传给 Registry 匹配（跳过 resolve + 日志），不得把空串传给 `TryResolve` 引发误匹配。
  4. `EExternalSchemaChanged` 的错误消息里同时带全量指纹和列签名指纹，便于运维定位。

### FIX-C · WeChat4x 适配器落位真实指纹

- **文件**：`D:\_Progs\02Business\DeepBase\Core\DeepBase.SchemaAdapter.WeChat4x.pas:75-77`
- **要求**：`FSchemaFingerprintPrefixes := ['26d53fe31f']`；注释更新为：来源微信 4.1.13.12 生产账号 dump（2026-09-02，DeepAxis DeCrypt fingerprint 交付），列签名口径，跨账号稳定。删除 BLOCKED-DATA-P0-001 标注。
- Registry 既有占位符跳过逻辑（上轮交付）会自动放行该前缀，无需改 Registry。

### FIX-D · WeChat39x 保持占位并显式标注 BLOCKED

- **文件**：`D:\_Progs\02Business\DeepBase\Core\DeepBase.SchemaAdapter.WeChat39x.pas:40-44`
- **要求**：保留 `e4a7b3c9f1` 契约值，注释改为显式标注 `BLOCKED-39X-DATA`：待 3.9.x 目标机 dump 后以同口径（列签名 SHA256 前 10 hex）替换。说明该值当前在列签名口径下不会命中 3.9 真实库（占位性质）。
- 台账 bugfix.md / tasks.md 登记 BLOCKED-39X-DATA 为新债务项。

### FIX-E · fixture 归档 + BUG332 真实链路测试

- **要求**：
  1. 新建 `D:\_Progs\02Business\DeepBase\Tests\Regression\Fixtures\WeChat4x\`，从 dump 目录拷入：一张 `Msg_*.txt` table_info 样例、`Name2Id.txt`、`TimeStamp.txt`、`wcdb_builtin_compression_record.txt`、`README.md`、`meta.txt`（合规：仅结构信息）。**禁止**拷入任何含账号 wxid 的文件名残留——Msg 表名含 md5 哈希不属敏感，但 README/meta 中的生产 wxid 需先脱敏（替换为 `wxid_<redacted>`）。
  2. 扩展 `Tests\Regression\Test.Regression.BUG332_WeChatSchemaRegistryResolve.pas`：
     - 读 fixture 的 Msg 列签名 → 按冻结口径计算 SHA256 → 断言等于 `26d53fe31f…`（完整 64 位）
     - 用该指纹走 `TSchemaAdapterRegistry.TryResolve` → 断言命中 `TWeChat4xAdapter`（真实前缀匹配链路，非长度校验）
     - 用 Name2Id 列签名构造的指纹 → 断言**不**命中 4x 适配器（防误匹配）
  3. 若 DeepAxis 侧有 SQLiteReader 单测（见 `Tests/Test.DeepBase.Persistence.*` / DataPlatform 测试），补一条：无 Msg 表的库不触发 resolve。

---

## 三、验收标准（主控复审逐项核）

1. FIX-A 产出指纹对三个 dump 的 Msg 列签名全部 = `26d53fe31f389e65779419dc30bfdd73df5f1c299215fa4a0dccd525910cda84`（fixture 内可复算）。
2. BUG332 扩展测试走真实 SHA256 → Registry → 4x 适配器命中链路，全 PASS。
3. `TryResolveAdapter` 调用链无全量指纹残留（grep 验证）。
4. 39x 未虚构值；BLOCKED-39X-DATA 已入台账。
5. fixture 无生产 wxid 泄漏（主控会 grep `wxid_uldtbevfpjlm22` 验证）。
6. dcc64 编译 0 Error / 0 Warning，全量测试 XML 落 `TestResults\WO-20260902-002\`，数字从工件读取。

## 四、交付与门禁

- Brief：`D:\_Progs\02Business\DeepBase\docs\brief-WO-20260902-002-开发甲.md`
- 交付报告：`D:\_Progs\02Business\DeepBase\docs\WO-20260902-002-开发甲-交付报告.md`（含逐项修复说明、证据索引、生产部署状态节、新发现）
- 本工单 CLOSE 条件：FIX-A~E 全过 + WO-20260902-001 的 BLOCKED-DATA-P0-001 解锁（两个工单可一并 CLOSE，台账同步）。
- Commit 可先行（授权范围），主控复审。
