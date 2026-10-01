# WO-20261001-MC-主控-LICFIX 跨夹具 License 隐式传递依赖未声明与假绿修复（主控派单 · P1）

**单号**：`WO-20261001-MC-主控-LICFIX`
**派单**：主控（2026-10-01，甲 `WO-20261001-MC-甲-A16` 收尾派生四项之一）
**优先级**：P1
**授权面**：`Tests/Test.DeepBase.License.pas`、`Tests/Test.DeepBase.LicensingTimeSource.pas`（若判据需要）、一次性 harness 脚本
**禁动区**：`Core/**`、`Features/DeepBase.Licensing.pas`、`contracts/**`、`Scripts/**`、`Tests/Integration/**`、`TestResults/**`、`noise-baseline.json`、`Tests/DeepBaseTests.dpr`（除经主控书面同意）

---

## 〇、纪律与口径

1. 零信任：不采信自报，判据全部主控亲跑留档（隔离 `--detach` 树优先）。
2. 本单只修**测试夹具的依赖声明与断言**，不修生产侧注册机制——机制本身无缺陷（见 §二）。
3. 一笔 H15 原子提交，message 带单号，显式 pathspec，选项在 `--` 前，前后 `git diff --cached --name-only` 核对，`git show --name-only` 复核，**禁 push**。
4. 台账状态槽改写权归主控；本单执行方只写回执。

---

## 一、现象与历史登记

甲 A16 回执 §四 末段记载：八件同进程跑时 `Test.DeepBase.License` 16 例报
`No license storage factory registered for connection-backed constructor`，
并定性为「跨夹具全局注册顺序缺陷」。

主控零信任复跑（证据 `CodeReview/20261001-AUDIT-主控-A16-证据/A16-跨夹具License-主控根因亲验.txt`）：

| 亲验 | 同进程夹具组合 | 读数 | 结论 |
|---|---|---|---|
| A | `Test.DeepBase.License` 独跑 | 16 found / 16 pass / 0 err，EXIT=0 | 全绿 |
| B | License + Commerce 两件 | 84 found / 84 pass / 0 err，EXIT=0 | 全绿 |
| C | License + Commerce + LicensingTimeSource + TimeGuardSecretStore 四件 | **97 found / 81 pass / 16 err**，EXIT=1 | 复现甲读数，逐字一致 |
| D | 同四件 + `Persistence/DeepBase.Persistence.License.FireDAC.pas` | **97 found / 97 pass / 0 err**，EXIT=0 | 决定性 |

主套件面**不受影响**：`Tests/DeepBaseTests.dpr:381` 生产 uses 区显式含
`DeepBase.Persistence.License.FireDAC`，全量跑 `Passed 4866 / Errored 1` 即证。

**「全局注册顺序」定性被推翻**：亲验 A/B 单跑与两件组合都全绿，若是注册顺序缺陷不可能如此；
亲验 D 加一个单元即全绿，说明缺的是**声明**而不是**时序**。

---

## 二、机制（主控 2026-10-01 亲读 @ `a8ffef4`，六步链，每步可复算）

1. `Persistence/DeepBase.Persistence.License.FireDAC.pas:286-288` 的 `initialization` 段调用
   `RegisterLicenseStorageFactory` —— connection-backed License 存储工厂的**唯一**注册点。
   全仓 `TDeepBaseLicense.SetStorageFactory` 调用点仅此一处（rg 亲证；其余同名类方法属
   Config/Logging/LLM/Manager 等其他存储面）。
2. `Tests/Test.DeepBase.License.pas:15-19` 的 uses 面（`DUnitX.TestFramework, Winapi.Windows,
   System.SysUtils, System.Classes, System.DateUtils, DeepBase.Types, DeepBase.Manager,
   DeepBase.License, DeepBase.Storage.Interfaces`）**不含** `DeepBase.Persistence.License.FireDAC`
   ⇒ 夹具从未声明这条传递依赖。
3. `Tests/DeepBaseTests.dpr:381` 显式含该单元 ⇒ 主套件里工厂已注册，16 例真绿。
4. `Tests/Test.DeepBase.LicensingTimeSource.pas:80` uses `DeepBase.Persistence.Manager.FireDAC`
   ⇒ 四件组合里由它把**连接**工厂带进进程（亲验 C 的触发条件）。
5. `Core/DeepBase.Manager.pas:1309-1320` `ConnectToDatabase`：`FConnectionFactory` 未注册即
   `ecConfigDBNotFound` 退出发 ⇒ 该进程里 `InitializeWithDB` 必失败。
6. `Tests/Test.DeepBase.License.pas:130-131`
   ```pascal
   if not Manager.IsInitialized then
     Manager.InitializeWithDB(':memory:');   // ← 返回值被忽略
   ```

### 两个面孔

- **面孔 (i)**：连接工厂在（LicensingTimeSource 带入）、License 存储工厂不在
  ⇒ 16 例运行期抛错。**看得见的红。**
- **面孔 (ii)**：连接工厂也不在 ⇒ `InitializeWithDB` 失败但返回值被忽略、`ConfigDB` 留 `nil`，
  `TDeepBaseLicense.Create(nil)` 因 `Assigned(AConnection)=False` 不抛
  ⇒ **16 例假绿**（亲验 A/B 即此：全绿，但那些用例实际未触达任何存储）。
  **看不见的绿，比红更危险。**

---

## 三、已排除方向（登记免再审）

- ~~跨夹具全局注册顺序缺陷~~：被亲验 A/B/D 三读推翻，见 §一。
- 生产侧 `Core/DeepBase.Manager.pas` / `Core/DeepBase.License.pas` 改动：机制无缺陷，不在本单。
- 主套件 dpr uses 面再补登记：`:381` 已在册，无需动。

---

## 四、修法方向（三选一或组合，执行方裁后落；判据同适用）

1. **补 uses 声明（治面孔 i）**：`Tests/Test.DeepBase.License.pas` interface uses 增
   `DeepBase.Persistence.License.FireDAC`。注意 `Persistence/**` 单元进测试夹具 uses 属既有惯例
   （`Test.DeepBase.LicensingTimeSource.pas:80` 即如此），不构成新依赖面。
2. **断言 `InitializeWithDB` 返回值（治面孔 ii，主裁定优先级最高）**：
   `:130-131` 改为对返回值 fail-closed 断言，且断言 `Manager.ConfigDB <> nil` 后仍
   `TDeepBaseLicense.Create(...)`。不得保留「失败也继续」的路径。
3. **harness 口径**：`a16_run_multi_fixture.sh` 一类脚本若对子集组合有「存储类夹具须自带
   注册单元」的约定，写进脚本注释或附带说明，避免下一线重踩。

**反事实必须做**：修法落地后摘除新增 uses / 摘除新断言，须分别转红，证明用例真的依赖它。

---

## 五、判据（fail-closed，全部主控亲跑留档）

| # | 判据 | 期望 |
|---|---|---|
| 1 | 修后 `Test.DeepBase.License` 独跑 | 16/16 pass，且**真的触达存储**（面孔 i 不复发） |
| 2 | 修后 四件组合（License + Commerce + LicensingTimeSource + TimeGuardSecretStore） | 97/97 pass，0 err（对照亲验 C 的 16 err） |
| 3 | 反事实：摘除新增的 `DeepBase.Persistence.License.FireDAC` uses | 须转红（证明非空登记） |
| 4 | 反事实：摘除/破坏新增的 `InitializeWithDB` 断言 | 须转红（证明假绿被真的拦住） |
| 5 | 主套件不回归 | 全量或约定子集跑，失败集合不新增 |
| 6 | 编译门 | 干净树 HEAD 原样与 HEAD+本单，噪声按码守恒 |
| 7 | 四门 | eol / encoding / mojibake / evidence-encoding EXIT=0（**另见 §六**） |
| 8 | 提交纪律 | 单笔 H15，显式 pathspec，`git show --name-only` 核对，未 push |

---

## 六、与本单并行的既存门禁红（主控已另行派单，勿混修）

`contract-gate` 在 HEAD 即红（`DeepBase.Licensing` 两项签名 removal），由 `eb93e23`（乙 B7，2026-09-29）
引入，与本单无关，主控已派 `WO-20261001-MC-主控-CONTRACTGATE`。
**本单判据 7 的「四门」口径 = eol / encoding / mojibake / evidence-encoding**（与乙 B7 同口径），
不含 contract-gate；若执行方改跑含 contract-gate 的五门，须把既存红登记为已知、不得据以判本单失败。

---

## 七、不在本单（已登记）

- 主套件 dpr 面 (`:381`) 无需改动。
- `Core/**` 任何改动。
- 一次性 harness 的其他缺陷。
- contract-gate 抽取器与基线（另单）。

---

## 八、执行结论（执行方回填）

（待执行方回执填写：判据 1–8 逐条读数、反事实读数、提交哈希、未 push 声明。）
