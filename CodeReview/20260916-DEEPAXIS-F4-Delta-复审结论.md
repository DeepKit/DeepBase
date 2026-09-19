# WO-20260916-DEEPAXIS-F4 独立整改｜F4 Delta Review 复审结论

- **报告性质**：主控独立复审结论（F4 Independent Delta Review），非开发方自证
- **被审工单**：`D:\_Progs\02Business\DeepBase\docs\ui\work-orders\WO-20260916-DEEPAXIS-F4-机器语义失真独立整改工单.md`（v1.1）
- **被审交付报告**：`D:\_Progs\02Business\DeepAxis\docs\WO-20260916-DEEPAXIS-F4-机器语义失真独立整改交付报告.md`
- **被审 Git 对象**：
  - 代码实现 Commit = `12dd4da9eb8ef8b1c165e8e35e6d3d26079f0a21`（2026-09-16 16:56:12 +0800，13 文件 / +1020−249）
  - 交付报告首提 Commit = `58eff55440c027a780da761e363e4f84b691c909`（16:57:28）
  - 报告校准 Commit = **`82e57eae1343fcd995adfb67134254390280ab51`**（16:59:02，= 实际 HEAD）
  - 审计基线锚点 = `67034a5f30bf05b22a7252129fc42a87b404ef7a`（tag `audit/ehai-downstream-001-closed`，未移动）
- **复审人**：主控 / Amy（沈予安）
- **取证时间**：2026-09-16 17:13:21 +0800（**结论绑定上述 Git 对象，不随后续 HEAD 变化失效**）
- **取证方法**：主控亲跑测试二进制 + 亲读源码/回执/schema + `git cat-file`/`ls-files` 逐字比对

---

## 一、总结论（结论先行）

**判定：`PASS WITH NON-BLOCKING FINDINGS`**

F4-A ~ F4-F **全部满足**；F4-G **在结构化门达标**（Delphi 4.5.x + Python 1.x/2.x/3.x/5.x 断言均为结构化字段），但参考消费者存在**一项非阻断残留**（详见发现 C-1）。

- **F4 = CLOSED**（阻断项全满足）
- **放行 Phase 2**（AsWish + AXIS Observation Gap Assessment）：**YES**
- 本判定**未**发现任何销毁性 git 操作、跨仓污染或公共层改动。

---

## 二、主控亲跑证据（不采信报告转述）

| 测试 | 报告声明 | 主控亲跑结果 | 副作用 |
| :--- | :--- | :--- | :--- |
| `tests/PhaseBTests.exe` | 52/52 | **52/52，ExitCode=0**（含 §4.1 F4-A / §4.2 F4-B / §4.3 F4-E / §4.4 F4-D / §4.5 F4-G） | `git status` 计数 624→624，**无副作用** |
| `tests/test_da131_machine_consumer.py` | 24/24 | **24/24，ExitCode=0** | 同上，**无副作用** |

- `PhaseBTests.exe` mtime = 2026-09-16 16:55:46；提交日志 mtime = 16:55:49 → 与 F4 开发窗口自洽。
- 已提交 `ci-logs/da131-f4-machine-consumer.log` 与主控亲跑输出**逐行一致**。
- **未运行** `scripts/run_da131_phase_b_delivery.py`：其会重写受跟踪的 `ci-logs/*.log`（写脏工作树），依只读纪律改为逐项等价核验（编译/测试各单独跑）。

---

## 三、F4 验收标准逐项核验（F4-1 ~ F4-6 / F4-A ~ F4-G）

| 条目 | 验收要求 | 主控核验 | 证据（主控亲验） |
| :--- | :--- | :---: | :--- |
| F4-1 | 快照 4 组 SHA256 复核一致 | ✅ | 历史样件 sha256 = `c5a13f52…3095`，与主控快照逐字节一致 |
| F4-2 | 旧回执登记失效、历史未销毁 | ✅ | `docs/DA-131-Delivery/flight-receipt.json:2` = `INVALID AS REAL-FLIGHT EVIDENCE`；原件保留 |
| F4-3 | 机器字段不再输出 `mode="real"`/无条件 `DELIVERY_CONFIRMED` | ✅ | 现回执 `mode="engine-verification"`、`terminal_state="ENGINE_VERIFIED"` |
| F4-4 | 注入时钟无法产出 real 语义 | ✅ | `tools/FirstFlightPhaseB.dpr:118`（dmReal 分支**不注入**时钟）/`:123-130`（仅 `--engine-verify` 注入） |
| F4-5 | 机器级断言正反两向到位 | ✅ | 主控亲跑 §4.1~§4.4 正反 Counterfactual 全 PASS |
| F4-6 | 隔离、未越界重跑 | ✅ | 上游 DeepBase=`b518c3f`、AsWish=`0b22a52`、锚点 tag 未移动 |
| **F4-A** | mock/engine-verification 不产出 `mode=real` | ✅ | 强类型 `dmEngineVerification`→`"engine-verification"`；4.1.1–4.1.3 |
| **F4-B** | 不产出 `DELIVERY_CONFIRMED` | ✅ | 独立终态 `dsEngineVerified`→`"ENGINE_VERIFIED"`；4.2.1–4.2.3 |
| **F4-C** | audit_trail 清除 real 语义措辞 | ✅ | 现回执 9 节点全为 engine-verification 语义；禁用措辞**仅存于隔离样本** |
| **F4-D** | `dispatch_success` 语义拆分，三权分立 | ✅ | schema `allOf` 条件约束 + 4.4.1–4.4.4（残留见 r-1） |
| **F4-E** | 注入时钟不得入 real 路径（fail-closed） | ✅ | `Engine.pas:623-625` 与 `:824-826` 双点拦截 `F2B_ERR_MOCK_CLOCK_IN_REAL_MODE`（引用错位见 D-1） |
| **F4-F** | 历史原件不得覆盖/静默销毁 | ✅ | 历史样本 sha256 与主控快照**逐字节相同** |
| **F4-G** | 四断言 + Machine Consumer 通过 | ⚠️ 达标（附残留） | Delphi 52/52 + Python 24/24；**残留见 C-1** |

**F4-C 关键取证**：`grep -rn "real dispatch armed\|first flight confirmed\|real delivery confirmed" docs/DA-131-Delivery/` 仅命中 `flight-receipt.historical-f4-defect-sample.json:15`（隔离样本，应保留），**现回执零命中**。

**F4-F 关键取证**：历史样本保留原缺陷全貌（`mode:"real"` + `terminal_state:"DELIVERY_CONFIRMED"` + `environment_note` 免责声明 + `f2b_mode_real_declared:"[F2B][MODE=REAL] real dispatch armed"`）——即 09-04 判定的「掩耳盗铃」样本，**正确隔离，未静默销毁**。

---

## 四、非阻断发现（5 项）

### D-1（引用锚点错位）— file:line 指向非拦截代码

- 报告 §六 F4-E 记：`DeepAxis.F2B.Engine.pas:602-606`。
- **实测 `:602-606` 为该过程局部变量声明区**（`St`/`H`/`Verified,TimedOut`/`Count,SuccessLevel,ChunkIdx`/`Chunks`）。
- 真实 fail-closed 拦截位于 **`:623-625`**（`:injected_clock_cannot_enter_real_delivery`）与 **`:824-826`**（`:injected_clock_cannot_produce_real_delivery`）。
- 报告 §三 记 `IsRealDeviceDelivery`/`IsEngineDispatchSuccess` 在 `:120-121`；实测声明在 `:123-124`、实现在 `:307-313`。
- **定性**：区间对≠符号对（D 类）；代码确实存在且正确，仅引用行号漂移。**不阻断**，须勘误。

### C-1（措辞夸大）— F4-G「零依赖人工文本」不成立

- 报告 §六 F4-G 记「零依赖人工文本」。
- **实测 `tests/test_da131_machine_consumer.py:40-51`**：参考消费者对 `audit_trail[].detail`（自然语言值）做**子串匹配**（`"simulation" in d.lower()` / `"noop_engine" in d` / `d == "delivery_confirmed"`）以判定 `has_sim_event` / `has_real_receipt_event`。
- 后果：TestCase 4「伪造 real 回执」被判为 distortion，**部分依赖 detail 文案**而非纯字段——JSON Schema 单独并不能拦下该伪造（其 `mode:"real"` 分支不触发 `real_device_delivery=false` 约束）。
- **定性**：文档字符串「NEVER reads … disclaimer text」在**字面**上成立（未读 `environment_note`/README 等外部免责文本）；但「零依赖人工文本」的断言**过强**。属非阻断残留，建议后续将 `has_sim_event` 改由结构化 `kind` 枚举承载（如 `f2b_engine_verification_confirmed`），彻底摆脱 prose 子串。

### A-1（自指锚点失效）— 报告自述 HEAD 过时

- 报告头部记「当前 HEAD Commit：`58eff55…`」。
- **实测 HEAD = `82e57ea…`** —— 该提交正是「calibrate commit tracking」，**修改了报告自身**（1 文件 / +8−5）。
- 属 F3 类**自指不可能性**（提交无法命名其后继）：非笔误。**不阻断**；`58eff55` 作为「报告初版归档」引用有效，但作为「当前 HEAD」已失效。

### W-1（工作区未冻结）— DeepAxis 工作树 624 项脏

- `git status --porcelain` = **624 项**（401 `D` / 205 `??` / 18 `M`）；被删文件经抽查**确在磁盘不存在**（如 `docs/00.DeepAxis 序列的由来.md`）。
- 分布：删除 397 项集中于 `docs/`，疑为 docs 命名/目录重构（旧 `NN.名称.md` → 新 `NN-名称.md` 及子目录），**与 F4 无关**；F4 证据文件（`docs/DA-131-Delivery/`、`schemas/`、`src/f2b/`、`tests/`、`tools/`）全部在位。
- **定性**：本判定绑定**提交对象**（已满足 `Audit Verdict is bound to Audited Git Objects`），故不阻断；但工作树非冻结态，**建议在 Case 001 开始前明确归置**（提交或 `git stash`，不得销毁性处置）。

### r-1（遗留字段别名）— `dispatch_success` 非独立字段

- schema 明示 `dispatch_success` = "Legacy field equivalent to engine_dispatch_success"。
- 生成器中二者**同源**（`FirstFlightPhaseB.dpr:149 与 :151` 均为 `TJSONBool.Create(LOk)`），独立字段实为 `real_device_delivery`（`:150`）。
- 故报告 F4-D「`dispatch_success` 语义**独立**检查」措辞不准——三权分立成立于 `engine_dispatch_success` 与 `real_device_delivery` 之间，`dispatch_success` 属遗留镜像。**不阻断**，建议后续废弃该字段。

---

## 五、报告声明 × 主控核验差异汇总

| 报告声明 | 主控核验 | 差异 |
| :--- | :--- | :--- |
| 代码 Commit `12dd4da` / 13 文件 | ✅ 精确吻合 | 无 |
| 52/52 + 24/24 | ✅ 亲跑复现 | 无 |
| 历史样件未销毁 | ✅ 逐字节一致 | 无 |
| F4-E 位置 `:602-606` | ❌ 实为 `:623-625`/`:824-826` | D-1 引用错位 |
| F4-G「零依赖人工文本」 | ⚠️ 仍子串匹配 `detail` | C-1 措辞夸大 |
| 当前 HEAD `58eff55` | ⚠️ 实为 `82e57ea` | A-1 自指失效 |
| 隔离/未越界 | ✅ 上游零改动 | 无 |

---

## 六、放行与后续

1. **F4 Delta Review = PASS WITH NON-BLOCKING FINDINGS**；**F4 = CLOSED**；**Phase 2（AsWish + AXIS Observation Gap Assessment）放行**。
2. 五项发现**不阻断**，但须登记：D-1（勘误引用行号）、C-1（结构化 `kind` 重构）、A-1（锚点纪律重申）、W-1（Case 001 前归置工作树）、r-1（字段废弃）。
3. **未受本次核验影响的既有裁定继续有效**：DOWNSTREAM-001 三仓锚点 tag 未移动，L8 Protocol 冻结不变。
4. 本结论**绑定** `12dd4da` / `58eff55` / `82e57ea` 与锚点 `67034a5`；后续新提交不使本结论失效，但也不被本结论覆盖。

---

- 落盘人：Amy（沈予安）／主控
- 取证时间：2026-09-16 17:13:21 +0800
