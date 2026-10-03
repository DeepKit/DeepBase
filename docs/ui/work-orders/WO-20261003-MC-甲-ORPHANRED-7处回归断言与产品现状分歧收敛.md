# WO-20261003-MC-甲-ORPHANRED 7 处回归断言与产品现状分歧收敛（主控派单 · P1）

**单号**：`WO-20261003-MC-甲-ORPHANRED`
**派单**：主控（2026-10-03，`WO-20261003-MC-甲-ORPHANREG` 验收当场所派）
**优先级**：**P1** —— 这 7 处就是主套件现在的 4 道新红 + 3 道未并入红
**前置**：`CodeReview/20261003-AUDIT-甲-ORPHANREG-证据/00-交付总表.md` §五/§七
**主控裁定**：batch3 的 4 道新红**保留不回滚**（已在 master）。理由：这 4 处是「测试断言的产品机制在产品里根本不存在」，回滚等于恢复「子集真相」。

---

## 〇、纪律与口径

1. **先裁定方向，再动手**：每一项都要先回答「改产品还是改用例」，**不许先改代码再补理由**。
2. 每项**单独一笔 H15 提交**（7 项最多 7 笔），message 带本单号 + 子项号，显式 pathspec，选项在 `--` 前，**禁 push**。
3. 台账状态槽改写权归主控，本单只写回执。
4. **禁止用改断言/加 SKIP/删用例把读数弄绿**，除非该子项明确裁定为「测试侧错」并给出可验证依据。
5. `Core/**` 是禁动区，本单按子项**显式逐项解禁**（见 §三），未列明的 `Core/**` 文件一律不许动。

---

## 一、7 个子项（读数均已由开发甲实测，非推断）

| 子项 | 单 | 主套件现状 | 断言要求 | HEAD 实测 |
|---|---|---|---|---|
| **R1** | `BUG009_LoggingRace` | 🔴 1 红 | `Core/DeepBase.Logging.pas` 含 `CompareExchange`（双检锁） | `grep -c` = **0**；同单另两条（`TMonitor`/`Lock`）过 ⇒ 有锁、非双检锁形态 |
| **R2** | `BUG054_SemaphoreLeak` | 🔴 1 红 | `Core/DeepBase.Resilience.pas` 含 `NeedReleaseSemaphore`/`SemaphoreAcquired`/`ReleaseSemaphore` | **0**；同单异常/正常路径两条行为用例过 ⇒ 行为对、命名结构对不上 |
| **R3** | `BUG059_JsonDeserializationType` | 🔴 1 红 | `Core/DeepBase.Serialization.pas` 含 `whitelist`/`AllowedTypes`/`IsTypeAllowed`/`ValidateType` | **0**；同单 `Test_UnauthorizedType_IsRejected` 过（走真实反序列化）⇒ 白名单这道防线不存在，但当前其他防线挡住了该攻击 |
| **R4** | `BUG060_SerializationDepth` | 🔴 1 红 | 产品**不应**含 `MaxDepth := 32` | `Core/DeepBase.Serialization.pas:577 Result.MaxDepth := 32;` —— 纯值分歧 |
| **R5** | `BUG007_WhenReadyDeadlock` | ⚪ 未并入（并入即 4 红） | `WhenReady` 回调在 `DeepBase` 已初始化时应执行 | 4 例跑真身后 5 秒超时；4 个用例开头都是 `if not IsInitialized then Assert.Pass(...)` ⇒ **条件绿/条件红** |
| **R6** | `BUG020_KeyNameValidation` | ⚪ 未并入（2 红） | ① `Test_ValidKeyName_IsAccepted`：`SaveSecret/LoadSecret` 往返 ② 产品含 `ValidateKeyName`/`IsValidKeyName`/`ValidateSecretName` | ① `TDeepBaseSecurity` 存储件 nil 时 `SaveSecret/LoadSecret/DeleteSecret` **静默 `Exit`**（不抛不记）⇒ 断言比 `'test_value'` vs `''` ② `Core/DeepBase.Security.pas` `grep -c` = **0** |
| **R7** | `BUG034_HardcodedKeys` | ⚪ 未并入（1 红） | `Test_MissingKey_ThrowsClearError`：未配置密钥时应抛清晰异常 | `Core/DeepBase.Crypto.AES.pas:199` `Create` 里就是 `GenerateKey; GenerateIV;` ⇒ **「未配置密钥」状态不存在**，断言必然假。该测试 2026-05-06 入库时 `69d3f66:Core/UniBase.Crypto.pas:1127-1134` 就已在调 `GenerateKey` ⇒ **从写下那天起就与实现不符** |

---

## 二、每项的裁定表（回执必须逐项填写后动代码）

| 子项 | 主控倾向（仅供参照，AI 必须自行取证后独立给结论） | 需回答的问题 |
|---|---|---|
| R1 | **改产品**：双检锁是并发正确性补强 | 换成双检锁会不会影响日志热路径性能？有 benchmark 读数吗？ |
| R2 | **改测试**：行为已对，把「结构存在」断言改成行为断言 | 但「改名/结构对不上」是否意味着维护性缺陷？先答这个 |
| R3 | **改产品**：类型白名单是反序列化安全防线，不是锦上添花 | 补白名单会不会破坏现有合法类型的反序列化？给兼容矩阵 |
| R4 | **需产品侧定值**：32 到底过不过高 | 给出「合理值 + 为什么」，不是拍一个数 |
| R5 | **改产品 + 改用例两侧都动**：先判 `WhenReady` 不执行为真 bug 还是设计如此 | 若是设计如此，用例应改为显式初始化后断言，不是 `Assert.Pass` 短路 |
| R6 | **改产品**：nil 存储时静默 no-op 是危险语义（调用方以为存了） | 显式抛异常会不会破坏既有调用方？给调用方清单 |
| R7 | **改测试**：测试前提与实现相反已 5 个月，属测试债 | 但「缺密钥时应抛清晰异常」这个安全诉求本身要不要保留？若要，另立产品单 |

---

## 三、授权面与禁动区（按子项解禁，未列即禁）

| 子项 | `Tests/**` | `Core/**` 解禁文件 |
|---|---|---|
| R1 | `Tests/Regression/Test.Regression.BUG009_LoggingRace.pas` | `Core/DeepBase.Logging.pas` |
| R2 | `Tests/Regression/Test.Regression.BUG054_SemaphoreLeak.pas` | `Core/DeepBase.Resilience.pas` |
| R3 | `Tests/Regression/Test.Regression.BUG059_JsonDeserializationType.pas` | `Core/DeepBase.Serialization.pas` |
| R4 | `Tests/Regression/Test.Regression.BUG060_SerializationDepth.pas` | `Core/DeepBase.Serialization.pas` |
| R5 | `Tests/Regression/Test.Regression.BUG007_WhenReadyDeadlock.pas` | 待 R5 裁定后由主控补授权；未授权前只读 |
| R6 | `Tests/Regression/Test.Regression.BUG020_KeyNameValidation.pas` | `Core/DeepBase.Security.pas` |
| R7 | `Tests/Regression/Test.Regression.BUG034_HardcodedKeys.pas` | 不改产品（主控倾向为测试侧债） |

**另授权**：`CodeReview/20261003-AUDIT-甲-ORPHANRED-证据/**`（取证留档，目录自建）。

**禁动**：除上表解禁外的全部 `Core/**`、以及 `contracts/**`、`Features/**`、`09_工程脚本/**`、`Scripts/**`、`noise-baseline.json`、`Governance/**`、`VCL/**`、`FMX/**`、`Tests/DeepBaseTests.dpr`（并入已由 ORPHANREG 做完，本单不再动 dpr）。

---

## 四、判据（主控验收用）

| # | 判据 | 达成标准 |
|---|---|---|
| 1 | 7 项裁定表全部填写 | 每项「改产品/改用例」+ 理由 + 对 §二 问题的回答，零「待定」 |
| 2 | 每项独立 H15 提交 | `git show --stat` 可核；禁止把多项塞一笔 |
| 3 | 主套件前后读数 | 每项给出并入后主套件 `Found/Passed/Failed/Errored`，**Failed 只减不增** |
| 4 | 产品侧改动有回归背书 | 改 `Core/**` 的子项，既有 4871+ 用例**零新增红** |
| 5 | 测试侧改动不是「弄绿」 | 若改断言，必须给出「原断言错在哪」的代码级依据；禁止删用例、禁加 SKIP |
| 6 | R7 特别判据 | 若判测试侧错，须说明「缺密钥抛清晰异常」的安全诉求如何处置（保留/另立单/明确放弃） |
| 7 | 阴性对照 | 每项造一例「改错了会怎样」的红对照 |
| 8 | 四门 + 纪律 | eol/encoding/mojibake/evidence-encoding 全 EXIT=0；禁 push；台账状态槽不改 |

**验收前置**：判据 1 未填完不动代码。**R5/R6 的 `Core/**` 未获主控补授权前，允许提交裁定表但不允许动产品代码。**

---

## 五、不在本单

1. 11 处 `Assert.Pass` 假绿反模式 —— 归 `WO-20261003-MC-甲-FAILCLOSED`。
2. `Examples/Templates/README.md` 失效引用 —— 归 `WO-20261003-MC-甲-TPLBOOTDOC`。
3. HB Gate #6 句柄泄漏断言稳定性 —— 归 `WO-20261003-MC-甲-HBGATE6`。
4. `Timeout PBT` AV（`Property6_TimeoutCancelsBackgroundTask`）—— 归 `WO-20261002-MC-甲-F2`。
5. `RegressionTestRegistry.pas` 死注册表 —— 本单不接，另议。
6. 剩余 3 个未并入单（BUG007/BUG020/BUG034）**是否并入 `Tests/DeepBaseTests.dpr`** —— 由各子项收敛后由主控决定。
