# EHAI 规范母稿历史版本与对比台账

本目录专门用于妥善封存各层规范在理论收敛、微校准与正式封版过程中的**校准前原稿**与**正式封版稿**，供随时进行跨版本对比、溯源核验与演进审查。

---

## 一、L4《通用 AI 交互协议》对比清单

| 版本属性 | 文件名称 | 状态 | 规模 | 说明 |
| :--- | :--- | :--- | :--- | :--- |
| **校准前原稿** | `EHAI.04.L4-通用交互协议.原稿-20260908-FreezeCandidate.md` | Freeze Candidate (旧) | 666 行 / 46.5 KB | 包含旧版 22 节草案、旧六种判断语义、早期 0–9 及部分未下沉的 UI/呈现与记忆讨论 |
| **正式封版稿** | `EHAI.04.L4-通用交互协议.封版-20260910-Frozen_v1.0.md` | **FROZEN v1.0** (正式) | 390 行 / 22.0 KB | 确立 PI-1～3 三大协议不变量、五类平权 Profile、两场分离、0–9 标准选择语法、Decision Context 绑定及 L5/L6 严格边界 |

### 核心演化与校准点对比：
1. **职责定界与根问题**：
   - *原稿*：试图解决“AI 怎样提问、何时提问、如何判断”等跨越 L3 和 L4 的复合问题；
   - *封版稿*：明确 L3 负责“何时叫人”，L4 只回答“既然已经必须让人进来，怎样以最小充分、语义明确、上下文绑定的交互完成介入，而不把交互完成误当成 Reality 完成”。
2. **根原则收敛**：
   - *原稿*：分散为 22 个长章节与大量局部原则（如题面诚实性三准则、认知状态四分法等）；
   - *封版稿*：严谨收敛为 **Three Protocol Invariants（PI-1 语义承诺完整性、PI-2 最小充分交互、PI-3 上下文绑定的类型化完成）**，严禁私自扩充不可约根原则。
3. **人类介入类型（Human Involvement Profiles）**：
   - *原稿*：使用“六种核心语义”（J-F, J-P, J-T, J-G, J-A 等带有旧 ASTO 编号且等级化色彩的分类）；
   - *封版稿*：全面统一为 L3 冻结的 **Inform / Provide / Judge / Authorize / Act** 五大平权语义角色，非等级化，支持正交复合。
4. **两场分离与核心法理**：
   - *原稿*：零散讨论会话与按钮；
   - *封版稿*：正式确立 **Conversation Surface（会话场）与 Decision Surface（决策场）** 的严格隔离，守护核心法理 **`Exploration ≠ Commitment`（聊天归聊天，拍板归拍板）**。
5. **0–9 协议定性**：
   - *原稿*：作为核心协议层级；
   - *封版稿*：降位为 **Standard Choice Grammar（标准选择语法）**，明确底层 Meta Actions（1–7 Choose, 8 Regenerate, 9 Reframe, 0 Exit without Commitment），单选多选定义为 Cardinality 参数。
6. **边界彻底下沉**：
   - 交互呈现场域、控件、样式、弹窗与键鼠等价映射彻底下沉 **L5 HB 基础设施**；
   - 现实重新观察、真实回闭与对账校验彻底下沉 **L6 机器语义基础设施**，确立 **`Human Interaction Complete ≠ Reality Complete`** 铁律。

---

## 二、L2《AI 交付原则》对比清单

| 版本属性 | 文件名称 | 状态 | 说明 |
| :--- | :--- | :--- | :--- |
| **校准前原稿** | `EHAI.02.L2-AI交付原则.原稿-20260908.md` | Draft (旧) | 包含“七层认知交付结构”、“四自”框架及 13 项勾选清单 |
| **正式封版稿** | `EHAI.02.L2-AI交付原则.封版-20260910-Frozen_v1.0.md` | **FROZEN v1.0** (正式) | 确立三大交付不变量 (DI-1/DI-2/DI-3)、最小充分交付 (MSD)、七类交付要素 (D1～D7) 与三大派生铁律；“四自”降级移出 |

---

## 三、L1《AI 人机认知哲学》对比清单

| 版本属性 | 文件名称 | 状态 | 说明 |
| :--- | :--- | :--- | :--- |
| **校准前原稿** | `EHAI.01.L1-人机认知哲学.原稿-20260908.md` | Draft (旧) | 包含旧版 DeepBase 体系命名与部分未收敛的哲学讨论 |
| **正式封版稿** | `EHAI.01.L1-人机认知哲学.封版-20260909-Frozen_v1.0.md` | **FROZEN v1.0** (正式) | 确立三大哲学根原则 (Root Principles)、P1～P12 派生原则与 EHAI 体系身份 |

---


## 四、L5《极简人类交互适配》对比清单

| 版本属性 | 文件名称 | 状态 | 规模 | 说明 |
| :--- | :--- | :--- | :--- | :--- |
| **校准前原稿** | `EHAI.05.L5-人机行为适配.原稿-20260908-FreezeCandidate.md` | Freeze Candidate (旧) | 682 行 / 43.8 KB | 早期以“HB 人机行为适配基础设施”命名，深度混杂了 Delphi/HB 控件实现、状态机、多端通道与理论原则 |
| **正式封版稿** | `EHAI.05.L5-极简人类交互适配.封版-20260911-Frozen_v1.0.md` | **FROZEN v1.0** (正式) | 610 行 / 41.5 KB | 确立中文正式层名《极简人类交互适配》（英文保持 OPEN）；确立唯一核心约束（人的责任不能偷，人的麻烦尽量省）；确立三项最低有效条件（可达/可辨/可响应）；彻底剥离 UI 控件实现污染，明确 HB 为下游工程实现 |

### 核心演化与校准点对比：
1. **层名与理论纯洁化**：
   - *原稿*：命名为“HB 人机行为适配基础设施”，将理论层级与 Delphi/HB 具体软件工程基础设施紧密捆绑；
   - *封版稿*：正式命名为 **《极简人类交互适配》**（英文名称保持 OPEN / Not Frozen）；明确规范为理论母稿，HB 为 DeepBase 中面向 Human 的统一人机交互承载与呈现基础设施，属于独立的下游工程实现关切。
2. **根问题与唯一核心约束**：
   - *原稿*：分散设立八大根原则、A0～A3 介入时机等，与 L3、L4 发生多处交叉；
   - *封版稿*：唯一根问题聚焦于“Human 必要介入确定后，如何将现实交互负担压到最小充分”；确立唯一核心约束：**“必要 Human semantic contribution 不得因极简适配而被削减、替代或静默改变；同时非必要交互负担应尽可能由 AI 消解（人的责任不能偷，人的麻烦尽量省）”**。
3. **合格性检验收敛（Validity Checks）**：
   - *原稿*：提出十余项平行要求（反馈、一致性、无障碍、渐进式暴露等）；
   - *封版稿*：收敛为三项最低有效条件——**可达（Reachability）、可辨（Distinguishability）、可响应（Response Availability）**；明确其它概念均为派生，当前不另立第四项平行 Check。
4. **去具象 UI 污染**：
   - *原稿*：充斥“桌面弹窗/手机推送/系统托盘/语音确认/按钮高亮/圆角阴影”等平台控件细节；
   - *封版稿*：彻底抽象为“不同 Human-facing interaction forms / channels”，平台控件与界面代码一律下沉工程实现。
5. **机器真值与 L6 边界**：
   - *原稿*：由 L5 承担机器状态判定与执行回闭；
   - *封版稿*：确立 **`L6 owns machine state truth; L5 owns human-facing realization of Human-material state`**，机器执行真值与现实对账坚决留归 L6。
6. **重开条件严苛化**：
   - 裁定确立：仅在出现体系级矛盾（system-level contradiction）或真正不可约新残余（genuinely irreducible new residual）时方可重新审议。

---


## 五、L5.D1《表述适配》封版清单

| 版本属性 | 文件名称 | 状态 | 说明 |
| :--- | :--- | :--- | :--- |
| **正式封版稿** | `EHAI.05.D1-表述适配.封版-20260911-Frozen_v1.0.md` | **FROZEN v1.0** (正式) | 确立双维正交模型 (Language Level x Detail Depth)、三项即时理解动作 (举例/类比/讲故事)、即时生效三准则 (Immediate/Context-preserving/Reversible) 与重述/重裁定严格分离 (Re-expression ≠ Task-level Re-reasoning) |

### 核心规范要点：
1. **理论归属**：隶属 L5《极简人类交互适配》，坚守唯一核心约束与最低有效三条件；
2. **正交双维**：语言门槛（专业 / 有术语·默认 / 大白话）与内容深度（简要 / 标准·默认 / 深入）严格正交组合；
3. **即时动作解耦**：举例/类比/讲故事属于即时展开技法，非语言门槛且非长期会话状态；
4. **生效准则**：显式触发直接进入流程，保持上下文与位置，低成本可逆；
5. **重述非重裁定**：`Re-expression ≠ Task-level Re-reasoning`，坚守 `Content Correction ≠ Silent Re-expression`；
6. **叙事真实性**：`Narrative Adaptation ≠ Fact Transformation`，严守真实性五不准。

---

## 六、永久保存纪律

1. **绝对禁止删除原稿**：本目录下的所有 `*.原稿-*.md` 均为原始理论推导与工程演进的历史见证，任何后续维护严禁删除、覆盖或重命名；
2. **规范文件指针**：对外公开与工程实现的统一规范指针，始终指向父目录下的标准命名文件（如 `EHAI.04.L4-通用交互协议.md`）。

---

## 七、乙R6-N6 归档层实测台账（2026-09-20）

> 本节数字由只读哈希脚本实测生成（逐件字节数 / mtime / sha256 前 12 位 + 跨 `docs/` 同字节自动判定），非手工誊写。
> 内容零改写自证：`.tmp/r6/n6-move.txt` 记录 15 件位移逐件移动前后 sha256 比对，结果 `TOTAL=15 BAD=0`。

### 7.1 本层存件清单（实测 32 件）
| 文件（本层） | 字节 | mtime(UTC) | sha256 | 同字节存件（跨 docs/ 自动判定） |
| :--- | ---: | :--- | :--- | :--- |
| `DeepBase-AI-Delivery-Principles.原稿-20260908.md` ·原稿 | 33249 | 2026-09-09 | `4ab183b1c9a9`… | 重复于: docs/规范历史版本与对比库/EHAI.02.L2-AI交付原则.原稿-20260908.md |
| `DeepBase-AI-Delivery-Principles.封版-20260910-Frozen_v1.0.md` ·封版 | 38722 | 2026-09-10 | `441ed9963ce7`… | 重复于: docs/EHAI.02.L2-AI交付原则.md , docs/规范历史版本与对比库/EHAI.02.L2-AI交付原则.封版-20260910-Frozen_v1.0.md |
| `DeepBase-AI-Delivery-Principles.快照-20260909.md` ·快照 | 33260 | 2026-09-09 | `0f0c871f2ef1`… | 唯一存件 |
| `DeepBase-AI-Human-Cognition-Philosophy.原稿-20260908.md` ·原稿 | 16808 | 2026-09-09 | `981ce381dbb6`… | 重复于: docs/规范历史版本与对比库/EHAI.01.L1-人机认知哲学.原稿-20260908.md |
| `DeepBase-AI-Human-Cognition-Philosophy.封版-20260909-Frozen_v1.0.md` ·封版 | 26458 | 2026-09-09 | `dad297651e2a`… | 重复于: docs/EHAI.01.L1-人机认知哲学.md , docs/规范历史版本与对比库/EHAI.01.L1-人机认知哲学.封版-20260909-Frozen_v1.0.md |
| `DeepBase-AI-Human-Cognition-Philosophy.快照-20260909.md` ·快照 | 16807 | 2026-09-09 | `d36f1b7b1124`… | 唯一存件 |
| `DeepBase-AI-Human-Intervention-Principles-v1.md` ·旧名母本 | 47674 | 2026-09-09 | `f7f9fcc37aaa`… | 重复于: docs/backup_20260909_l1_l7/DeepBase-AI-Human-Intervention-Principles-v1.md |
| `DeepBase-General-AI-Interaction-Protocol-v1.md` ·旧名母本 | 36330 | 2026-09-10 | `f0c056f433c0`… | 重复于: docs/DeepBase-General-AI-Interaction-Protocol-v1(2).md |
| `DeepBase-General-AI-Interaction-Protocol.原稿-20260908.md` ·原稿 | 46570 | 2026-09-09 | `d67b20cfa26e`… | 重复于: docs/规范历史版本与对比库/EHAI.04.L4-通用交互协议.原稿-20260908-FreezeCandidate.md |
| `DeepBase-General-AI-Interaction-Protocol.封版-20260910-Frozen_v1.0.md` ·封版 | 32041 | 2026-09-10 | `06009c2618a4`… | 重复于: docs/规范历史版本与对比库/EHAI.04.L4-通用交互协议.封版-20260910-Frozen_v1.0.md |
| `DeepBase-General-AI-Interaction-Protocol.快照-20260909.md` ·快照 | 46605 | 2026-09-09 | `f2c22db068eb`… | 唯一存件 |
| `DeepBase-HB-Human-Behavior-Adaptation-Infrastructure-v1.md` ·旧名母本 | 41565 | 2026-09-10 | `bac975e98b42`… | 重复于: docs/EHAI.05.L5-极简人类交互适配.md , docs/规范历史版本与对比库/EHAI.05.L5-极简人类交互适配.封版-20260911-Frozen_v1.0.md |
| `DeepBase-HB-Human-Behavior-Adaptation-Infrastructure.原稿-20260908.md` ·原稿 | 63167 | 2026-09-09 | `c5c9eb2a72a3`… | 重复于: docs/backup_20260909_l1_l7/DeepBase-HB-Human-Behavior-Adaptation-Infrastructure-v1.md |
| `DeepBase-Machine-Semantics-and-Intervention-Infrastructure-v1.md` ·旧名母本 | 56656 | 2026-09-11 | `72e40b959eef`… | 唯一存件 |
| `DeepBase-Machine-Semantics-and-Intervention-Infrastructure.快照-20260909.md` ·快照 | 53721 | 2026-09-09 | `4c94fa5efe9b`… | 唯一存件 |
| `DeepBase-Product-Realization-Boundary-v1-r2.md` ·旧名母本 | 50601 | 2026-09-09 | `18bd30bec847`… | 重复于: docs/backup_20260909_l1_l7/DeepBase-Product-Realization-Boundary-v1-r2.md , docs/backup_20260909_l1_l7/DeepBase-Product-Realization-Boundary-v1.md , docs/规范历史版本与对比库/DeepBase-Product-Realization-Boundary-v1.md |
| `DeepBase-Product-Realization-Boundary-v1.md` ·旧名母本 | 50601 | 2026-09-09 | `18bd30bec847`… | 重复于: docs/backup_20260909_l1_l7/DeepBase-Product-Realization-Boundary-v1-r2.md , docs/backup_20260909_l1_l7/DeepBase-Product-Realization-Boundary-v1.md , docs/规范历史版本与对比库/DeepBase-Product-Realization-Boundary-v1-r2.md |
| `EHAI-Language-Common-Layer-Overview.md` ·旧名母本 | 17238 | 2026-09-13 | `07b165aed146`… | 唯一存件 |
| `EHAI-Language-Neutral-Realization-Contract-v0.md` ·旧名母本 | 28205 | 2026-09-13 | `e7b2101d59cc`… | 唯一存件 |
| `EHAI.00-总览与推导总纲.md` ·旧名母本 | 21348 | 2026-09-12 | `5cbc7daa664b`… | 唯一存件 |
| `EHAI.01.L1-人机认知哲学.原稿-20260908.md` ·原稿 | 16808 | 2026-09-09 | `981ce381dbb6`… | 重复于: docs/规范历史版本与对比库/DeepBase-AI-Human-Cognition-Philosophy.原稿-20260908.md |
| `EHAI.01.L1-人机认知哲学.封版-20260909-Frozen_v1.0.md` ·封版 | 26458 | 2026-09-09 | `dad297651e2a`… | 重复于: docs/EHAI.01.L1-人机认知哲学.md , docs/规范历史版本与对比库/DeepBase-AI-Human-Cognition-Philosophy.封版-20260909-Frozen_v1.0.md |
| `EHAI.02.L2-AI交付原则.原稿-20260908.md` ·原稿 | 33249 | 2026-09-09 | `4ab183b1c9a9`… | 重复于: docs/规范历史版本与对比库/DeepBase-AI-Delivery-Principles.原稿-20260908.md |
| `EHAI.02.L2-AI交付原则.封版-20260910-Frozen_v1.0.md` ·封版 | 38722 | 2026-09-10 | `441ed9963ce7`… | 重复于: docs/EHAI.02.L2-AI交付原则.md , docs/规范历史版本与对比库/DeepBase-AI-Delivery-Principles.封版-20260910-Frozen_v1.0.md |
| `EHAI.03.L3-人类介入原则.原稿-20260909-FreezeCandidate.md` ·原稿 | 47654 | 2026-09-12 | `6ce7af4a9057`… | 唯一存件 |
| `EHAI.04.L4-通用交互协议.原稿-20260908-FreezeCandidate.md` ·原稿 | 46570 | 2026-09-09 | `d67b20cfa26e`… | 重复于: docs/规范历史版本与对比库/DeepBase-General-AI-Interaction-Protocol.原稿-20260908.md |
| `EHAI.04.L4-通用交互协议.封版-20260910-Frozen_v1.0.md` ·封版 | 32041 | 2026-09-10 | `06009c2618a4`… | 重复于: docs/规范历史版本与对比库/DeepBase-General-AI-Interaction-Protocol.封版-20260910-Frozen_v1.0.md |
| `EHAI.05.D1-表述适配.封版-20260911-Frozen_v1.0.md` ·封版 | 49452 | 2026-09-11 | `a489f49fca12`… | 重复于: docs/EHAI.05.D1-表述适配.md |
| `EHAI.05.L5-人机行为适配.原稿-20260908-FreezeCandidate.md` ·原稿 | 63028 | 2026-09-09 | `4e394f5f62fc`… | 唯一存件 |
| `EHAI.05.L5-极简人类交互适配.封版-20260911-Frozen_v1.0.md` ·封版 | 41565 | 2026-09-10 | `bac975e98b42`… | 重复于: docs/EHAI.05.L5-极简人类交互适配.md , docs/规范历史版本与对比库/DeepBase-HB-Human-Behavior-Adaptation-Infrastructure-v1.md |
| `EHAI.06.L6-机器语义与介入.原稿-20260909-Frozen_v1.0.md` ·原稿 | 53646 | 2026-09-09 | `397438dcc2b6`… | 唯一存件 |
| `README-版本对比台账.md` ·台账 | 8856 | 2026-09-11 | `a6cae72df3dc`… | 唯一存件 |
### 7.2 同字节存件、删除预算与预算外登记

- 上表「同字节存件」列为跨 `docs/` 逐字节相同者；原稿/封版与母本并存属版本对比库既有冗余，非本轮新增。
- 工单授权删除预算 **7 件**（D4 1 + D5 4 + D7 2）。逐件「路径 + sha256 + 字节数」清单与仓库外备份路径见
  `CodeReview/_audit_recheck/乙-R6-N6-删除清单待复核.txt`；**未经主控复核不得删，本轮零删除**。
- `docs/backup_20260909_l1_l7/` 原 8 件中 4 件已于本轮以 `.快照-20260909.md` 名移入本层（改名避免与本层既有旧名母本重名，
  移动前后 sha256 一致）；目录剩余 4 件即 D5 删除候选，待复核。
- 预算外同字节候选（仅登记，本轮不删）：
  1. `docs/EHAI.05.D1-表述适配.md` 49452B `a489f49fca12` ≡ 本层 `EHAI.05.D1-表述适配.封版-20260911-Frozen_v1.0.md`；
  2. `DeepBase-Product-Realization-Boundary-v1.md` ≡ `-v1-r2.md`（本层与 `docs/backup_20260909_l1_l7/` 各两份，均 50601B `18bd30bec847`）；
  3. L5 三件同字节 41565B `bac975e98b42`：本层 `DeepBase-HB-Human-Behavior-Adaptation-Infrastructure-v1.md`（本轮移入的旧名母本）≡
     `docs/EHAI.05.L5-极简人类交互适配.md` ≡ 本层 `EHAI.05.L5-极简人类交互适配.封版-20260911-Frozen_v1.0.md`。
- 现行规范指针见 `docs/EHAI.00-总纲与规范索引.md` 与 `docs/ui/00-Index.md` 的 L1～L8 分层块；本层只承载历史版本与对比。
