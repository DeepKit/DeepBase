# WO-20261002-MC-主控-GOVCONTRACT 裁定件 —— `DeepBase.DataBinding` 消费者契约登记

> 执行：开发 AI（甲线代主控自办轨）· 2026-10-02
> 工单：docs/ui/work-orders/WO-20261002-MC-主控-GOVCONTRACT-DataBinding显式登记消费者契约.md
> 开工 HEAD：`41b580a` · **零 `.pas`**（亲核见 §六）· 授权面：`contract/consumer-contract.json`、`CodeReview/**`、台账
> **裁定一句话：登记，定级 `stability=stable` + `critical=true`，本单不建签名基线。代价是 contract-gate 从 EXIT=1 两项变三项，新增的那一项是「不在基线内」的记账性红——这是有信息量的红（指出发版动作待执行），优于登记为 `internal` 造成的静默失明。同时亲验出 contract-gate 一处通用结构盲区，须归 CONTRACTGATE 单。**

---

## 一、判据 1 · 契约格式亲读（现有集合逐条 + 字段语义有出处）

### 1.1 文件实况

- 路径实为 `contract/consumer-contract.json`（**单数 `contract/`，18 个单元**）。工单 §二-4 写的 `contracts/consumer-contract.json`（复数）是**笔误**——`contracts/` 目录是另一套东西（T0/T1 契约清单），不要混。本单按实况的 `contract/` 落笔。
- 18 个单元**全部是 `stability: "stable"`**；`check_contract.js:48` 允许的枚举是 `stable | internal | deprecated`，**仓内当前 `internal` / `deprecated` 各 0 条** ⇒ 定级先例只有 `stable` 一种。

### 1.2 字段语义（逐字段给出处，不是复述 JSON）

| 字段 | 语义 | 出处 |
|---|---|---|
| `unit` | 单元名（含点分形式）。门禁用它做 `git ls-files -- '**/<unit>.pas'` 定位，并要求**仓内仅一份** | `check_contract.js:82`（必填）、`:118`、`:165-174` |
| `subdir` | 该单元**唯一**应存在的子目录；门禁断言 `<subdir>/<unit>.pas` 在索引内且是唯一拷贝 | `check_contract.js:83`（必填）、`:166-173` |
| `stability` | 只有 `stable` 单元进签名漂移检测面 | `check_contract.js:84`（必填）、`:223` |
| `consumers` | **仅文档性**：门禁只校验字段存在且非空（`:82-84`），**不参与任何判定**。仓内现有值 1–54，与 DeepSync 等兄弟项目的引用面相关 | `check_contract.js:83` |
| `critical` | **仅文档性**（不在必填表内）：表达「出了事不能悄悄改」的重点单元。仓内 6 条为 `true`：i18n / Config / Manager / DB.DoQry / Licensing / Persistence.Manager.FireDAC | `check_contract.json:13/14/15/23/28` |
| `why` | **仅文档性**：一句话说明为何入约 | 同上 |
| `breaking_change_policy` | **仅文档性**，但 18 条逐字相同 = 契约级默认策略的显式化（`breaking_change_policy_default` 在 `:8`） | `check_contract.js:84`（必填） |

### 1.3 `stability=stable` 的实际效力（读 `check_contract.js:221-232` 得到的两条硬事实）

```
for u of contract.units.filter(stability === 'stable'):
    base = baseline.units[u.unit]
    if (!base) { breaking.push(`stable 单元 ${u.unit} 不在基线内（新纳入稳定的单元须发版时写入基线）`); continue; }
    …removed / added 比对…
```

1. **只有同时出现在「契约 stable 集合」与「基线 units」里的单元才真正被比对**。
2. **新纳入 stable 但不在基线的单元 ⇒ 门禁红，且 `continue` 跳过比对** ⇒ **在发版重建基线之前，它既不在检测面内、又制造一条红**。

⇒ 这条机制**不是 `DeepBase.DataBinding` 专属**，是 contract-gate 的**通用结构盲区**（详见 §五）。

---

## 二、判据 2 · 消费者面亲核（仓内 + 外部承接面，禁凭回执转述）

### 2.1 仓内引用面（`git grep -l "DeepBase\.DataBinding" -- "*.pas" "*.dpk" "*.dpr" "*.dproj"` @ `41b580a`）

| 类别 | 文件 | 计数 |
|---|---|---|
| 生产 · Core | `Core/DeepBase.MVVM.pas` | 1 |
| 生产 · VCL | `VCL/DeepBase.VCL.BindableControls.pas`、`VCL/DeepBase.VCL.MVVMControls.pas` | 2 |
| Examples | `Examples/DataBindingDemo/MainForm.pas`（+ dpr）、`Examples/MVVMDemo/LoginViewModel.pas`（+ dpr） | 2 |
| 测试 | `Tests/Test.DeepBase.DataBinding.pas`、`Tests/Test.DeepBase.DataBindingLifetime.pas`、`Tests/Test.DeepBase.DataBindingUnbindRefCount.pas`、`Tests/Test.DeepBase.MVVM.pas`（+ `Tests/DeepBaseTests.dpr`） | 4 |
| 包登记 | `DeepBaseCore.dpk`、`DeepBaseCore.dproj` | 2 |

⇒ **`consumers` 取 5 = 生产 3 + Examples 2**（测试面按仓内既有单子的口径不计消费者；`DeepBase.Config` 的 17、`DeepBase.i18n` 的 54 都是同一层含义）。为避免与兄弟项目计数混读，额外加 `consumers_basis` 字段写明这是仓内口径。

### 2.2 `TBindingManager.Bind` 的**实际调用点**（这是 A16 breaking change 的真实影响面）

```
git grep -n -E "TBindingManager|\.Bind\(|BindingManager" -- Core VCL FMX Features Persistence Examples Tools
```

- **生产面（Core / VCL / FMX / Features / Persistence / Tools）命中 0 处调用**——`Core/DeepBase.DataBinding.pas:15-16` 的 `FBindings.Bind(...)` 只出现在**单元头注释的示例代码**里，不是可执行代码。
- 真实调用点全在 `Examples/`（`DataBindingDemo/MainForm.pas:231/276/277/278` 等）。
- `Core/DeepBase.MVVM.pas` 与 `VCL/DeepBase.VCL.*` 引用该**单元**（`uses`），但不直接调 `TBindingManager`。

⇒ **A16 的 `Bind` 契约收窄对仓内生产代码零影响**（与 A16 回执「仓内零影响」自述一致，本单独立复核成立）；影响面是 Examples + 潜在外部消费者。

### 2.3 外部承接面亲核（DeepSync 源码树）

```
git -C D:/_Progs/02Business/DeepSync grep -ln "DataBinding"      → 仅 Tests/DeepSyncTests.rsm
git -C .../DeepSync grep -in "DataBinding" -- Tests/DeepSyncTests.rsm
    → Binary file Tests/DeepSyncTests.rsm matches（本地化 .rsm，非源码引用）
git -C .../DeepSync grep -ln "TBindingManager|MVVM" -- "*.pas" "*.dpk" "*.dpr"  → 0 命中（exit=1）
```

⇒ **外部消费者面 = 0**（唯一字样命中是二进制 `.rsm` 本地化资源内的巧合串，非 Pascal 引用）。这是外单 DB-002/004/006/007 的承接面，**当前无任何兄弟项目引用本单元**。

---

## 三、判据 3 · 裁定件：两问各有结论

### 问 1：是否显式登记？ → **登记**

理由：

1. **它是 Core 单元、在 `DeepBaseCore.dpk` 登记、有 3 个生产消费点 + 2 个 Example**。契约头自己写明 DeepBase 是「30+ 兄弟项目共享的平台库」，判定「稳定 API vs 内部实现」的依据就是 `subdir` + 消费面（`:9` `required_dirs: ["Core","Features","Persistence"]`）。把一个跨 `Core` 边界、有 VCL 生产消费者的单元排除在约外，等于让下一个门禁修订者重新发现它。
2. **不登记的后果已经被本单实测坐实**：一次 breaking change（`Bind` 由任意 `TObject` 收窄为可追踪对象，`a2c4077`/`37cdf3a`）**已经发生**，而门禁当时连「不在检测面内」都不会说 ⇒ 纯静默。工单 §一称之为「检测盲区」，成立。
3. 工单判据 5 要求：若裁「不登记」须写明盲区由何种别的手段覆盖。本单**找不到**能替代的既有手段：仓内唯一的消费者面治理机制就是 `contract-gate`；人工审阅清单不存在（`grep` 全仓无「消费者 API 变更需人工登记」的清单件）。⇒ 裁「不登记」会落到工单明令禁止的「不登记且无覆盖」。

### 问 2a：定何级？ → **`stability: "stable"` + `critical: true`**

- **不裁 `internal`**：`internal` 只进存在性/唯一性检查（`check_contract.js:165-174`），**不进签名检测面**（`:223` 只 filter `stable`）⇒ 裁 `internal` 等于把这次登记做成「登记了但仍然看不见」，是工单 §一 明确要消灭的那种状态，只是换了个词。
- **`critical: true`**：与仓内 6 条 `critical` 同族判据（单一入口 / 禁区）。`TBindingManager.Bind` 是 MVVM 数据绑定的唯一入口，且 A16 已因它产生过一次公开签名语义变更（虽未改声明本体，但**收窄了可接受参数集合**并新增异常类 `EBindingUnsupportedObject`）⇒ 属「出了事不能悄悄改」的重点单元。
- **`consumers: 5` + `consumers_basis: "in-repo（git grep 亲核 @41b580a）；外部兄弟项目消费者计数未取证，不混入本数"`**：`consumers` 字段是文档性的（§1.2），但若不写明口径，本仓 `1`–`54` 的兄弟项目计数与这个 `5` 会被读成同一把尺子 ⇒ 加 `consumers_basis` 消歧，而不是让下一个人去猜。

### 问 2b：`signatures` 基线如何取？ → **本单不取；发版时按发布 ref 的 HEAD 快照取**

理由链：

1. **`signature-baseline.json` 是发版快照，不是可随手重录的配置**。其自身 `generatedFrom` 字段写明「git show <ref>（stability=stable 单元的 interface 公开签名快照，**随每次发布重新生成并提交**）」，`generated` 时间戳是 `2026-09-24T04:15:10.886Z`（对应 `v1.1.0` 封版）。工单 §〇-2 与主控在 A16 验收中的裁定都明确：**`--emit-baseline` 是发版动作，主控不自行执行**。
2. **取当前 HEAD 快照 = 洗掉既存事实**。A16 的收窄已经发生且已登记入 `./CHANGELOG.md` 的 `## [Unreleased]`（`BREAKING CHANGES` + `Added` 各一条）。若现在按 HEAD 建基线，「`Bind` 收窄」这件事在**基线面**上就从未存在过 ⇒ 基线成为「洗白」的载体，正是工单禁止的行为。
3. **取 A16 前旧签名 = 让门禁永远报一条已处置项**。那条 removal 会一直红到下一次发版重建基线为止 ⇒ 噪声掩盖真发现（工单 §〇-2 的原话逻辑）。
4. **不建基线的代价是可量化且可接受的**：见 §四，登记后门禁新增一条**指向发版动作**的红，不是伪装成通过的沉默。

⇒ 裁定：**基线留待发版**，由主控在发版动作内按发布 ref 重生成本单元条目；本单**一个字都不改** `signature-baseline.json`。

---

## 四、判据 4 · contract-gate 修前 / 修后读数与逐条归因（未用 `--emit-baseline`）

原始输出：
- 修前：`CodeReview/20261002-AUDIT-主控-GOVCONTRACT-证据/contract-gate-修前.txt`
- 修后：`CodeReview/20261002-AUDIT-主控-GOVCONTRACT-证据/contract-gate-修后.txt`

| | 修前（登记前） | 修后（登记后） |
|---|---|---|
| 扫描单元数 | 18 | **19** |
| 破坏性变更项 | **1**（含 2 条签名明细） | **2**（含 2 条签名明细 + 1 条新登记提示） |
| EXIT | 1 | 1 |

逐条归因：

| # | 修前既有项 | 修后是否仍在 | 归因 |
|---|---|---|---|
| P1 | `DeepBase.Licensing: 公开签名消失/改写 2 处` 明细①`type TLicensingTier = (ltFree, ltPro)` | **仍在，逐字相同** | **假阳性**（A16 验收已归因）：`check_contract.js:146-155` 按 `;` 分块 + `:132` `stripComments` 把注释打成空格 ⇒ `type` 关键字只与同块首个声明绑定，注释位移即幻象 removal，声文本体一字未改。归 `WO-20261001-MC-主控-CONTRACTGATE` 修抽取器 |
| P2 | `DeepBase.Licensing` 明细②`interface uses ... DeepBase.TimeGuard` | **仍在，逐字相同** | **真变更但向后兼容**（`eb93e23` 乙 B7 追加 uses，无公开声明被删/改写，按 `:18` 口径新增只报不拦）。同归 CONTRACTGATE |
| **P3** | — | **新增**：`stable 单元 DeepBase.DataBinding 不在基线内（新纳入稳定的单元须发版时写入基线）` | **本单登记的直接后果，记账性红**。含义精确：三件事同时成立——①该单元已入约；②它的 `interface` 公开签名**尚未**进入比对面；③补齐动作 = 发版时重生成基线（`check_contract.js:185-205` 的 `--emit-baseline` 分支）。这条红**不是缺陷**，是发版待办的显式挂账 |

**关于「假阳性未修前不得重建基线」这条前置的遵守**：本单**未执行** `--emit-baseline`，`signature-baseline.json` 的 `generated` 时间戳与 `generatedFrom` 内容均**未改动**（可 `git diff 09_工程脚本/contract-gate/signature-baseline.json` 亲核为空）。因此 CONTRACTGATE 修好抽取器后，P1 的假阳性消失**不会**连带洗掉任何真发现——因为本单根本没碰基线。

---

## 五、亲验出的结构盲区（须归 CONTRACTGATE 单，本单不修）

**盲区陈述**：由 §1.3 的两条硬事实可得——

> **任何「新纳入 `stability=stable`」的单元，在下一次发版重建基线之前，都不在签名检测面内；而门禁只以一行 `不在基线内` 提示这件事。**
> 若没有人逐行读那行 stderr，**登记 = 宣示检测已覆盖，实际未覆盖**——正是本单要消灭的「检测盲区」以一种更隐蔽的形式回归。

**这不是 `DeepBase.DataBinding` 专属**，本仓现存的 18 个单元里凡是在 `v1.1.0`（2026-09-24）之后新增的，都会踩同一条。当前契约 18 条与基线 18 条**恰好一一对应**（`node -e` 实测两侧 keys 逐条相同）⇒ 该盲区目前**潜伏未爆**，本单是第一次触发。

**结构修法方向（建议，不在本单实施）**：让「纳入 stable」与「进入比对面」解耦，而不是靠发版这个外部事件顺带完成。具体形态待 CONTRACTGATE 单裁定，候选之一是在契约条目上加一个可机读的登记态字段（形如 `signatures_baseline_pending: "<引入提交>"`），门禁据此**只对该提交之后**的比对面生效，且把「不在基线内」从破坏性变更项降级为单独的待办提示（不同 EXIT 通道）。这样：

- 登记不再需要靠一条红来「提醒」；
- 发版重建基线时该字段自然消解，不需要额外清理；
- 门禁的破坏性通道只装真破坏，不被记账项稀释。

**归属**：`WO-20261001-MC-主控-CONTRACTGATE`（P1，修抽取器）——同族、同门、同一份 `check_contract.js`，**不另立单**（避免同一文件被两笔单并改）。

---

## 六、判据 5 · 零 `.pas` 亲核 + 提交面

```
git diff --stat 41b580a -- '*.pas' '*.dpr' '*.dproj' '*.dpk'
  → （空）
```

改动面共 2 件：

| # | 路径 | 性质 |
|---|---|---|
| 1 | `contract/consumer-contract.json` | +1 条 `DeepBase.DataBinding` 登记（`stability` / `critical` / `consumers` / `consumers_basis` / `why` / `breaking_change_policy` 六字段齐） |
| 2 | `CodeReview/20261002-AUDIT-主控-GOVCONTRACT-裁定.md` | 本裁定件 |

证据件 2 件（`CodeReview/20261002-AUDIT-主控-GOVCONTRACT-证据/contract-gate-{修前,修后}.txt`）。
`signature-baseline.json` **零改动**。台账状态槽由主控回填（本单以主控自办轨身份落笔，仍按 §六 给出建议措辞供主控确认）。

---

## 七、四门（判据 6：逐道写门名 + EXIT）

门名口径 = **eol / encoding / mojibake / evidence-encoding** 四道静态门禁（**不含 contract-gate**——contract-gate 的既存红归 CONTRACTGATE 单，本单已单独留档修前/修后两版读数）。逐道读数见统一四门跑录件与最终请求审核报告 §五。

---

## 八、给主控的台账建议措辞

> **GOVCONTRACT 行**：✅ **已办（2026-10-02）** —— 裁定**登记** `DeepBase.DataBinding`（`Core`，`stability=stable`、`critical=true`、`consumers=5`（仓内口径，见新增 `consumers_basis` 字段））。**本单不建签名基线**（`signature-baseline.json` 零改动），代价是 contract-gate 由 EXIT=1 两项变三项，新增项为**记账性红**「stable 单元 DeepBase.DataBinding 不在基线内」⇒ 指向发版动作，不是缺陷。消费者面亲核：仓内生产 3（`Core/DeepBase.MVVM.pas`、`VCL/DeepBase.VCL.BindableControls.pas`、`VCL/DeepBase.VCL.MVVMControls.pas`）+ Examples 2；`TBindingManager.Bind` **生产面零调用点**（仅 Examples + 单元头注释示例）；外部 DeepSync 源码树**零引用**（唯一字样在二进制 `.rsm` 内）。
> **同条派生登记（归 CONTRACTGATE，不另立单）**：contract-gate **通用结构盲区** —— 新纳入 stable 的单元在发版重建基线前不在比对面内，门禁只以一行 `不在基线内` 提示 ⇒ 无人逐行读 stderr 时等于「登记了但未覆盖」。现存 18 单元与基线 18 条恰好一一对应，**盲区目前潜伏未爆，本单是第一次触发**。修法方向：把「纳入 stable」与「进入比对面」解耦（契约上加可机读登记态字段 + 门禁分通道），在 CONTRACTGATE 单内与抽取器一并处置。
> **工单文本更正**：工单 §二-4 写的 `contracts/consumer-contract.json`（复数）为笔误，实况是 `contract/consumer-contract.json`（单数，18 单元）；`contracts/` 是另一套（T0/T1 契约清单）。

---

## 九、判据逐条读数（fail-closed）

| # | 判据 | 读数 | 结论 |
|---|---|---|---|
| 1 | 契约格式亲读，现有集合逐条列出，字段语义有出处 | 18 单元全为 `stable`（`internal`/`deprecated` 各 0）；6 字段逐个给出处（必填表 `:82-84` / 判定点 `:223`/`:165-174`）；`consumers`/`critical`/`why`/`breaking_change_policy` 判定为**仅文档性** | **成立** |
| 2 | 消费者面亲核，仓内 + 外部，禁凭回执转述 | 仓内 5 消费点逐件列出 + `Bind` 生产面零调用（独立 grep 复核） + DeepSync 源码树两次 grep 零引用 | **成立** |
| 3 | 裁定件：两问各有结论与理由，定级与基线取法写明 | 问1 登记（三条理由，含「找不到替代覆盖手段」以满足判据 5）；问2a `stable`+`critical`（含「裁 internal 等于换词复现盲区」的论证）；问2b 不建基线（四条理由链） | **成立** |
| 4 | 若登记：修前/修后读数留档，差异逐条归因，**不得** `--emit-baseline` 洗 | 两版读数各留档；18→19 单元、1→2 项；新增项逐条归因为记账性红；`signature-baseline.json` 零改动 | **成立** |
| 5 | 若裁「不登记」须写明盲区覆盖手段 | 本单裁「登记」，且**已执行该判据的反向检查**：逐条搜寻仓内是否存在可替代的人工审阅清单，结论为不存在 ⇒ 「不登记」会落到工单明令禁止的「不登记且无覆盖」 | **成立（反向检查已执行）** |
| 6 | 四门逐道写门名 + EXIT | 见 §七 | **成立** |
| 7 | 纪律：单笔 H15、显式 pathspec、未 push | 单笔；pathspec 见 §六；未 push | **成立** |

---

*开发 AI（甲线代主控自办轨）· 2026-10-02 · 零 `.pas` · 结论与自报读数不作为验收依据*