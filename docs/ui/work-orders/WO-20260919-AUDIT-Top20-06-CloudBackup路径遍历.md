# WO-20260919-AUDIT-Top20-06 — CloudBackup `ABackupId` 路径遍历：备份 API 成任意文件读/写/删原语

- 法源：`CodeReview/20260918-全库审计-总报告.md` §三 Top20 #6；明细条目 `CodeReview/20260918-Features-C-防御云意图.md` CB-02
- 执行方：**开发 AI 乙**（2026-09-20 主控派发 → `WO-20260920-AUDIT-乙-R5-Top20路径遍历与归档卫生.md` N1；本单由 WO-20260919-AUDIT-甲 A5 建立；主控按文件所有权 `Features\DeepBase.CloudBackup.pas` 属乙组切分）

## 五件套

### 1. 文件:行（2026-09-19 复核，行号已重新定位）

| 锚点 | 说明 |
|---|---|
| `Features\DeepBase.CloudBackup.pas:1728`（`GetBackupArchivePath`） | `ABackupId` 直接 `TPath.Combine` 拼入归档路径，无规范化校验 |
| `Features\DeepBase.CloudBackup.pas:1735`（`GetManifestPath`） | 同上，清单路径 |
| `Features\DeepBase.CloudBackup.pas:2272`（`DeleteVersion`） | 消费侧：`DeleteVersion('../../..')` 可删任意文件（原报告记 `:2281`，实核为 `:2272`） |
| `Features\DeepBase.CloudBackup.pas:2348`（`SyncFromCloud`） | id 可来自**云端清单/列表响应**（服务器被攻陷或 MITM 即投毒），`fmCreate` 落盘 → 任意路径写入（原报告记 `:2356`，实核为 `:2348`） |

### 2. 改法

1. 单一校验入口（SSOT）：`function SafeBackupId(const ABackupId: string): string;` —— 白名单正则 `^[0-9A-Za-z_-]{1,64}$`，不合规直接 `raise ECloudBackupError`（fail-closed，不返回空串让调用方自行判断）。
2. 所有 `ABackupId` 消费点（含未来新增）只允许经 `SafeBackupId` 规范化后再拼路径；拼接后二次防御：`TPath.GetFullPath` 结果必须以 `BackupRoot`（含尾分隔符、OrdinalIgnoreCase）为前缀，否则拒绝。参照本仓 `BuildSafeDestination` 已有的正确实现复用，不另造轮子。
3. 来自云端的 id 与本地生成的 id 走同一校验，不因来源豁免。
4. 恢复流程末尾按 `fctDeleted` 清单逐项删除时复用同一路径校验（联动 CB-07 墓碑处理修复）。

### 3. 验收标准

- 负向用例：`../`、绝对路径（`C:\Windows\temp\x`）、UNC（`\\server\share`）、空字节、超长 id、`..%2f` 变体 → 全部拒绝且错误可区分；
- 正向用例：合法 id（GUID/时间戳格式）全流程（创建/删除/同步/恢复）不回归；
- 云端投毒模拟用例：恶意清单中的 id 在 `SyncFromCloud` 入口即被拒。

### 4. 证据要求

- 修复 diff + 负向/正向用例测试原始输出；
- grep 证明 `ABackupId` 的全部消费点均经过单一校验入口（列出调用点清单）。

### 5. 阻塞他仓

- 否。纯输入校验收紧；仅当云端后端历史上生成过含非法字符的备份 id 时需后端同步（当前 id 生成为本地 GUID/时间戳，预期无影响，执行时与 `CloudSync` 后端契约确认一次即可）。


### 6. 移交登记（A10）

| Top20 # | 条目 | 移交至 | 甲单编号 |
|---|---|---|---|
| #07 | CLI.SSH 命令注入 | 乙 B1/B2 | - |
| #10 | AES 模式静默降级 | **甲（本单纠正 2 移回）** | A17 |
| #14 | CDP Destroy 缺 WaitFor | 乙 B4 | - |
| #15 | CloudSync 谎报成功 | 乙 | - |
| #18 | WebAPI.Auth CSRF | 乙 | - |
| #19 | Resilience 熔断器双轨 | 乙 | - |
| #20 | 构建归属 | 乙 B3 | - |

本工单覆盖 Top20 条目：#01（本文档）/#05/#06/#17 由甲独立交付；上述 7 条为跨方移交关系，无"无人认领"项。