# WO-20260920-AUDIT-甲-R8 — POSIX 构建缺口收口与安全测试网并网

- **工单号**：WO-20260920-AUDIT-甲-R8
- **发出时间**：2026-09-20 23:02 +0800
- **发出人**：主控 AI（**主控自决**：依据甲 R5 回执「已知缺口 B/D」登记 + 主控独立实测，按质量优先排序派发）
- **承接方**：开发 AI 甲
- **取证基线**：DeepBase HEAD = `87caa5c`
- **工单性质**：**安全链收尾单**（承接甲 R5-M2 回执登记的两项待派单项）
- **⚠️ 前置依赖**：**本单为排队单 —— 必须在 `WO-20260920-AUDIT-甲-R7`（安全质量立即优化 P1–P5）全部交付且主控验收通过后开工**。R7 未交付即开工 = 双单并行争共享 index，违反 H16（`ed50cfd` 事故模式）。

---

## 〇、主控裁定（2026-09-20 23:38）—— 维持阻塞，走正 path，不启用老板 override

甲于**领单时核验前置并停等**（提出两条路径请求裁定）。主控复核其核验结论**全部成立**（`CodeReview/` 无任何 R7 文件；`Core/DeepBase.Crypto.AES.pas` 工作树与 HEAD **零差异**；`staged` 空）。裁定如下：

| 项 | 裁定 |
| :--- | :--- |
| **开工时机** | **① 等 R7 交付 + 主控验收**（正 path）。**不启用 ② 老板书面 override** —— 该 override 属**主控职权内的调度事项**，按老板 2026-09-20 20:42「保护老板注意力」裁定（「这些小事要么你定，要么开会定，少来麻烦我」）**不上推** |
| **开工资格（三门齐备）** | ① R7 `P1–P5` **全部交付**（`CodeReview\20260920-AUDIT-甲-R7-交付回执.md` 落盘）；② 主控**验收结论落盘**；③ 主控发 **R8 开工令** |
| **是否因 index 空闲而解锁** | **否**。本单门禁是**状态门**（R7 交付 + 验收），**不是仅争用门** —— 甲此判**正确**（共享 index 当前为空不构成开工资格） |
| **冲突面（主控确认成立）** | R7-P1 改 `Core/DeepBase.Crypto.AES.pas`（删三段 legacy 解密分支）⇄ R8-P1 需**编译验证该单元及同一依赖链**；R7-P5 重写 14 件 M2 文件行尾 ⇄ R8-P1 编译面重叠 ⇒ **必须严格串行**，否则 R8 证据做完即被 R7 失效 |
| **甲的行为评价** | **正确**：领单即核验前置 + 停等 + 请求裁定，符合本单明文前置与 H16；**未见抢跑、未见夹带** |

**在收到 R8 开工令之前，甲保持停等（R7 优先）**。R7 交付并经主控验收后，主控**主动发出本单开工令**，甲无需再次请示。

---

## 一、派发依据（主控实测，非转述）

甲 R5 回执 §「已知缺口与不可测项登记」登记两条**待主控派单**项；主控已独立复核实证：

| 缺口 | 主控实测 | 判定 |
| :--- | :--- | :--- |
| **B（阻断性）POSIX 构建** | `Core/DeepBase.Crypto.OpenSSL.pas:606-607` 硬编码 `external 'libdl.dylib' name 'dlopen'`；`:223/226` 使用 `dlopen`/`RTLD_NOW` 但无 POSIX 条件声明 ⇒ Linux 目标 `E2003 Undeclared identifier` | **真缺陷** |
| **D 测试网覆盖** | `Tests/TestSecurityM2.dpr` 存在；`grep -c "SecurityM2\|UBS2\|MachineIdentity" Tests/DeepBaseTests.dpr` = **0** ⇒ M2 四个安全测试单元未进全库套件 | **真缺口** |

---

## 二、任务清单

### P1【POSIX 动态库加载缺口 —— Linux/macOS 加密后端不可构建】

**现状（主控实测）**：
- `Core/DeepBase.Crypto.OpenSSL.pas:606-607`：`function dlopen(filename: MarshaledAString; flag: Integer): Pointer; cdecl; external 'libdl.dylib' name 'dlopen';` —— **硬编码 macOS 库名**
- `:223/226`：按平台分别 `dlopen(MarshaledAString(UTF8String(APath)), RTLD_NOW)` / `dlopen(PAnsiChar(AnsiString(APath)), RTLD_NOW)`
- 后果：Linux（`dcclinux64`）与 macOS arm64（`dccosxarm64`）目标报 `E2003 Undeclared identifier: 'dlopen'/'RTLD_NOW'`，**凡依赖它的单元**（`Crypto.AES` → `UBS2*` / `MasterKey` / `Security*` / `KeyManager`）在两种 POSIX 目标**均不可编译**

**改法**：
1. 按平台条件引入符号：**Linux 用 FPC RTL 的 `Posix.Dl`（或 `dl` 单元）**提供 `dlopen`/`dlsym`/`RTLD_NOW`；macOS 保留 `libdl.dylib` external 声明；Windows 分支不得引用 POSIX 单元。
2. **质量优先（H8）**：**禁**以「Windows 已验证」替代 POSIX 结论；**禁**用 `{$IFDEF}` 空实现吞掉 POSIX 路径（那是兼容层掩盖）。
3. 复跑 POSIX 交叉编译门禁（R5 已产 `CodeReview/20260920-AUDIT-甲-证据/M2-Security主口令/06-posix-cross-compile-gate.log`），给出**修复后**双目标 EXIT 与残留项。

**验收**：`dcclinux64` 与 `dccosxarm64` 下 `Crypto.AES` 及其依赖单元 `exit=0`（或逐单元登记「仍不可编译 + 原因 + 平台支持声明」，**不得笼统带过**）；未新增编码违规。

### P2【安全测试网并网 —— M2 四单元未进全库回归】

**现状（主控实测）**：`Tests/TestSecurityM2.dpr` 为 M2 专用 runner；`Tests/DeepBaseTests.dpr` 中 `SecurityM2|UBS2|MachineIdentity` **0 命中** ⇒ 安全链新增用例不进全库套件，「全库回归绿」不含安全链。

**改法**：
1. 将 M2 的 4 个安全测试单元并入 `Tests/DeepBaseTests.dpr`（并入后专用 runner 留/删须说明）。
2. ⚠️ **`Tests/DeepBaseTests.dpr` 属 H2 保护对象** —— **本项由主控授权甲处理**（**仅限新增 `uses` 注册行**，不得改动其他既有单元顺序/编译开关）。
3. 申报「全库套件计数变化」（并入前/后 found/passed/errored），H14 双数字。

**验收**：全库套件含 M2 单元且**真跑通过**（附 NUnit XML）；计数变化申报自洽。

---

## 三、明确不在本单

| 项 | 处置 |
| :--- | :--- |
| 甲 R7 全部 P1–P5 | **先行**；本单不得触碰同一批安全域文件直至 R7 交付 |
| 乙域（`CloudBackup.pas` / 门禁脚本 / `TestResults/**` / `Persistence/**`） | 乙域，甲不碰 |
| `master.key` 丢失恢复路径（R5 缺口 A） | 属**产品决策**，主控另行呈报，不在本单 |
| POSIX **运行时**不可测项（R5 缺口 C） | 环境限制，登记即可，不要求可运行验证 |

---

## 四、验收标准

| 项 | 标准 | 主控判定 |
| :--- | :--- | :--- |
| P1 | 双 POSIX 目标 EXIT 与残留单元申报齐备；符号引入无隐藏空实现 | 主控读源码 + 复跑门禁 |
| P2 | 全库套件含 M2 单元且真跑绿；计数申报自洽 | 主控读 XML + 复跑 |
| — | H14 双数字（raw + `--ignore-cr-at-eol`）；双证据（控制台 + NUnit XML） | 主控复验 |

---

## 五、硬约束（H 系列，违反即 REJECT）

- **H1**：禁 `checkout --`/`restore`/`clean`/`reset --hard` 处置非本单改动。
- **H2**：禁触碰乙组文件；`Tests/DeepBaseTests.dpr` **仅本单 P2 经主控授权可加 `uses` 行**。
- **H3**：逐件精确 pathspec；禁宽泛 `add`。
- **H8 · 质量优先，不是兼容优先**：P1 核心 —— 不得为「本机能编」而加平台开关掩盖不可构建事实。
- **H14/H15/H16/H18**：行尾前置核验双数字 / 原子提交 / 共享 index 并发禁令 / 证据 UTF-8。
- **H7**：禁自报 PASS。**H11**：不授权 pg-tag。**H9**：回执写明结束时间 + commit hash。
- **门禁申报（延续 R7）**：每段提交前必跑 `encoding-gate` + `evidence-encoding-gate` 并申报 EXIT 值。

---

## 六、交付物

1. 精确 pathspec 的 commit（P1 / P2 分次）
2. 回执：`CodeReview\20260920-AUDIT-甲-R8-交付回执.md`
3. 证据：`CodeReview\20260920-AUDIT-甲-证据\R8\`（POSIX 双目标门禁 log + 全库套件 NUnit XML + 计数对账）

---

## 七、是否阻塞他仓

**是（P1）**：POSIX 构建修复直接影响 **AsWish / DeepAxis 若在 Linux/macOS 复用该加密栈** ⇒ 须在回执申报平台支持面，由主控决定是否下发下游工单。
