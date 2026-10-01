# 请求审核报告 — P0: HEAD 编译断裂修复与全量回归验证

- **报告类型**：请求审核报告（开发 AI 乙交付留痕）
- **承接工单**：`WO-20260920-AUDIT-乙-R6-归档卫生与门禁口径收口.md` §P0（任务 #28 / #29）
- **结束时间**：**2026-09-21 17:46:17 +0800**
- **提交区间**：`d95b522` → `2e97d11`（3 个 commit，含甲 R8-P3 后续 3 个文档 commit 未由本窗产生）
- **本窗提交**：`a6ca329`、`1c1c862`、`2e97d11`
- **取证基线**：`d95b522`（甲 R8-P1 POSIX 符号收口）

---

## 一、结论

**P0 完成。** 施工方 HEAD 编译断裂（Top20#05 签名不兼容，阻塞 `DeepBaseTests.dpr` 链接）已由 3 个精准 commit 修复；pristine HEAD 复验 **编译 EXIT=0**，全量回归 **4617/4625 通过**。

剩余 3 failed + 1 errored 经逐一定位于**存量缺陷**，与本窗 3 个 commit 的改动文件零重叠（详见 §五）。

---

## 二、缺陷根因（E2035/E2034 共 3 组）

Top20#05 安全链改造后，`TDataKey` 的 AEAD API 与 `TKeyManager.Initialize` 签名变更，两处测试 fixture 未同步，导致 `DeepBaseTests.dpr` 无法链接。

| # | 根因 | 触发点 |
|---|---|---|
| 1 | `TDataKey.EncryptWith/DecryptWith/Rotate` 新增 AAD 形参，fixture 仍按旧签名调用 | `Test.Regression.BUG327_KeyManagerAEAD.pas` 共 9 处调用点 |
| 2 | `TKeyManager.Initialize` 移除机器绑定实参，CR20260824_P0Batch2 fixture 仍传 2 参 | `Test.Regression.CR20260824_P0Batch2.pas` 4 处 |
| 3 | `EBackupInvalidIdException` 在 `CloudBackup` 单测中 `raise` 但未在 `Core/DeepBase.Exceptions.pas` 声明 | `Test.DeepBase.CloudBackup.pas` + `Features/DeepBase.CloudBackup.pas` |

---

## 三、修复内容（3 commits）

### `a6ca329` fix(build): declare EBackupInvalidIdException
- `Core/DeepBase.Exceptions.pas` +5 行：补 `EBackupInvalidIdException` 声明，归入备份域异常族
- `Features/DeepBase.CloudBackup.pas` +18/-：按新异常类型收口无效 ID 抛出路径
- `Tests/Test.DeepBase.CloudBackup.pas` +153：补覆盖

### `1c1c862` fix(test): align TKeyManager.Initialize call-sites
- `Test.Regression.CR20260824_P0Batch2.pas` 4 处调用点去实参（4 insertions / 4 deletions）

### `2e97d11` fix(test): supply AAD and drop stale 2-arg Initialize
- `Test.Regression.BUG327_KeyManagerAEAD.pas` +20/-10
- 新增固定 `TestAAD: TBytes` 辅助函数（返回 `'bug327-fixed-aad'`）—— 该 fixture 直接操作 `TDataKey` 层、不经 KeyStore，用固定 AAD 验证 AEAD roundtrip 与版本字节，**不依赖真实机器身份**
- 9 处调用点补 AAD 实参

---

## 四、验证证据

### 4.1 pristine HEAD 编译（git archive 干净工作树）
```
git archive HEAD | tar -x -C .tmp/head-archive
dcc64 -B -N0 ... Tests/DeepBaseTests.dpr
EXIT=0
```
完整日志：`TestResults/head-verify.log`

### 4.2 全量回归（自 pristine HEAD 构建的 exe，自仓库根 cwd 运行）

| 指标 | 值 |
|---|---|
| Tests Found | 4625 |
| Tests Passed | **4617** |
| Tests Ignored | 4 |
| Tests Failed | 3 |
| Tests Errored | 1 |

日志：`TestResults/head-tests-repo.log`

### 4.3 cwd 裂缝的排除取证（关键）

同一 exe 在 `.tmp/head-archive/Tests/`（错误 cwd）下运行得 **6 failed + 12 errored**；改自仓库根运行得 **3 failed + 1 errored**。

15 项差异全部源于测试用 `GetCurrentDirectory` / `TPath.GetFullPath` 解析仓库内相对路径（`Examples\HbColdStartProbe\`、`VCL\DeepBase.VCL.Controls.pas` 等），仅在 exe 位于仓库根时成立。**非代码回归，是既有 cwd 依赖缺陷**，已在下节登记。

### 4.4 构建副产物清理
本窗 `-N0` 编译在 `Core/` 等目录产生 14 个 `.dcu`（均 gitignored），已全数删除，`Core/Features/Persistence/Governance/VCL` 现存 `.dcu` = 0。提交前 `git diff --cached --name-only` = 0（未混入他方暂存）。

---

## 五、存量缺陷登记（非本窗引入，未修复）

| # | 测试 | 性质 | 判定依据 |
|---|---|---|---|
| 1 | `Test.Arch.PackageBoundaries.TPackageBoundaryTests.SourceDirectories_DoNotContainDcuArtifacts` | 环境 | 报错列出的 5 个 `.dcu` 系本窗编译副产物，已清理；gitignored，非 tracked |
| 2 | `TBitmapSourceTests.StaticPair_InjectedReplay_Unchanged` | 存量 | 源码 `Tests/` 下 BitmapSource fixture 与本窗 3 commit 改动文件零重叠 |
| 3 | `TBitmapSourceTests.InjectedBitmap_FlowsThroughFrameDifferGate` | 存量 | 同上 |
| 4 | `TTimeoutPolicyPropertyTests.Property6_TimeoutCancelsBackgroundTask`（AV @ nil read） | 存量 | `git diff d95b522 HEAD` 证实该 fixture 及其 resilience 单元未被本窗触碰 |

**零重叠证明**：本窗 3 commit 的代码改动仅涉及
`Core/DeepBase.Exceptions.pas`、`Features/DeepBase.CloudBackup.pas`、
`Tests/Regression/Test.Regression.BUG327_KeyManagerAEAD.pas`、
`Tests/Regression/Test.Regression.CR20260824_P0Batch2.pas`、
`Tests/Test.DeepBase.CloudBackup.pas` 五文件，
与 §五 4 项失败所属模块无交集。

---

## 六、建议后续（移交主控裁定）

1. **P1（任务 #30）**：`Tests/` 下 3 个 fixture 共 14 处 `GetCurrentDirectory`/`TPath.GetFullPath` 仓库内相对路径解析，应改为基于可执行文件位置或仓库根探测，消除 cwd 裂缝。此项独立于 P0，建议另单。
2. **P2（任务 #31）**：BitmapSource 2 项 frame-differ 短路失败与 `TTimeoutPolicyPropertyTests.Property6` 空指针 AV，属存量功能缺陷，建议另单诊断。
3. `Tests/Examples/HbColdStartProbe/` 在仓库中实为根级 `Examples/`，而 fixture 解析 `Tests\Examples\...`，路径映射需一并对齐。

---

## 七、EHAI / 安全自证

- 未对任何非本单改动使用 `checkout --` / `restore` / `reset --hard`
- 删除动作仅限本窗自产的 `.dcu` 构建副产物（gitignored、可再生）
- EHAI 契约件（`EHAI.00`–`EHAI.08`）零写入
- 未触碰甲域在途文件（`.workbuddy/*` 等）

---

**报告完毕。结束时间 2026-09-21 17:46:17 +0800。**
