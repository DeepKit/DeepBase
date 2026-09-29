# WO-20260929-AUDIT-甲-A11 TimeGuard 密钥库接线（P0 安全 · 1 项）

> 签发：主控 · 2026-09-29 · 冲期：**甲线当前零在途单**（A10 可先行，两单文件零重叠）
> 基线锚点：HEAD `c8adedb`
> 派工对象：**开发 AI 甲**
> 缺陷来源：《20260929-AUDIT-主控-乙-B7-验收结论》§四派生表第 1 行（乙 B7 §六.1 登记项）——**主控已复算坐实**：`Features/DeepBase.Licensing.pas:864` 构造守卫时传了存储键（`AppID + '.timeguard'`），但全仓**从未**给任何 `TTimeGuard` 实例 `SetSecretStore`，而 `ITimeGuardSecretStore` 的实现类数 = **0** ⇒ `LoadLastKnownGoodTime` 恒 0 ⇒ `Verify` 的两条回拨分支（`:420` 离线 / `:438` 在线）都以 `LLastGood > 0` 为前提 ⇒ **`tgClockRewound` 在生产永不可达，时钟回拨防护形同虚设**。
> 佐证：`Features/DeepBase.TimeGuard.pas:82` 注释自称「Minimal interface — `DeepBase.Security.SecretStore` implements this.」——**该注释失实**，底座并未实现本接口（这正是缺陷长期潜伏的原因之一）。

## 〇、开工纪律（违者整单打回）

1. **H15 原子提交**：本单 1 项，可拆「新单元 + dpk 登记」与「TimeGuard 惰性默认」两笔，message 带 `A11`；显式 pathspec；前后 `git diff --cached --name-only` == 申报清单；**禁 push**。
2. **禁动区维持**：`v1.1.0` 标签 / EHAI 冻结面 / `TestResults/**` / 旧轨 `Core/DeepBase.PluginManager.pas` / 新轨 `DeepBase.Plugins.*` / `contracts/**` / `noise-baseline.json` / **`Core/**` 零改动**（底座只读复用）/ **`Features/DeepBase.Licensing.pas` 零改动**（乙 B7 域，本单不得越域）/ `Tests/DeepBaseTests.dpr|.dproj`（新测试单元的 dpr 并网归主控）。
3. **`Features/DeepBase.TimeGuard.pas` 的改动范围收敛为 `GetSecretStore` 惰性默认一处**（见 §一-2），不得借机重构该文件其他部分。
4. **fail-closed 总原则**：时间不可信 ⇒ 拒绝/显式失败。本单的 fail-closed 落点是 §一-1/§二判据③④（回拨可检测 ⇒ 拒绝），**不是**把「无凭据后端」升级成「时间不可信」（理由见 §一-2 的裁定说明）。
5. **测试**：新建 `Tests/Test.DeepBase.TimeGuardSecretStore.pas`（不改 `Tests/DeepBaseTests.dpr`/.dproj，并网归主控）；全限定 fixture 子集跑判据，**禁全量**（必崩 216 既存）。
6. **编译判据**：隔离 `--detach` 工作树 @ 目标 commit 跑 T0 manifest 须 EXIT=0（含新增 dpk 单元后的噪声不超基线）；主树红项逐件点名归属。
7. 编码/行尾：`.pas` UTF-8 BOM + CRLF；四门复跑全 EXIT=0。

## 一、修法（主控已定型，甲执行）

### 1. 新增适配单元 `Features/DeepBase.TimeGuard.SecretStore.pas`

实现 `ITimeGuardSecretStore`（`SaveSecret`/`LoadSecret`，见 `DeepBase.TimeGuard.pas:84-88`）于 `Core/DeepBase.Security.SecretStore.pas` 的 `ISecretStore`（`TryGet`/`Put`/`Delete`/`IsAvailable`）之上：

- `SaveSecret(AKey, AValue)` ⇒ `ISecretStore.Put`；`LoadSecret(AKey)` ⇒ `TryGet`（取不到返 ''）。
- 导出 `function CreateTimeGuardSecretStore: ITimeGuardSecretStore;`——内部调 `TSecretStoreFactory.CreatePlatformStore`，**用 `try/except` 包住**（该工厂在无后端且非 dev 态时抛 `ESecretStoreUnavailable`），异常 ⇒ 返 `nil`。
- 单元头注释须写明「适配 `ITimeGuardSecretStore` → `ISecretStore`；回拨水位是纵深防御，不是唯一边界（主边界是 Core 单调水位）」。
- **把 `Features/DeepBase.TimeGuard.pas:82` 的失实注释改实**（「SecretStore provides a compatible façade; TimeGuard 侧默认经 `DeepBase.TimeGuard.SecretStore` 接线」之类），这是本单附带必须做的一处文档更正。

### 2. `TTimeGuard.GetSecretStore` 改惰性默认（唯一允许的 TimeGuard 改动）

```
当前：Result := FSecretStore;              // 生产恒 nil ⇒ 存取静默 Exit
改为：Result := FSecretStore;
      if Result = nil then
      begin
        Result := CreateTimeGuardSecretStore;   // 失败返 nil
        FSecretStore := Result;                 // 缓存，避免每次 Verify 重建
      end;
```

**为什么不把「无后端」升级成「时间不可信」（主控裁定，甲照做）**：① 会把环境缺口（Linux dev 机无 libsecret / CI 无凭据后端）变成**许可拒绝**，是判据「无过紧回归」明令禁止的过紧行为；② 本水位的定位是**纵深防御**——主边界是 Core 单调水位（`Core/DeepBase.License.pas` 的 `SeedWatermark`/持久化，甲 A5-R09 已在册）；③ fail-closed 的正确落点是「有后端且检出回拨 ⇒ 拒绝」，而这条路径修前在生产**根本不存在**——本单把它变成可达，即是 fail-closed 的落实。

## 二、判据（可执行）

1. **持久化往返**：新单元内注入 fake `ISecretStore`（内存字典），`SaveSecret('k','2026-01-01T00:00:00Z')` 后 `LoadSecret('k')` 原样取回；键名错误 ⇒ ''（不抛）。
2. **回拨可达（核心判据）**：fake 时钟下先以「服务器确认读数」走一次在线 `Verify`（水位写入 fake store，读数 = 现在 + 1 天）⇒ 新实例（重新从 store 载入水位）把本地时钟回拨 1 天后 `Verify` ⇒ **`tgClockRewound`**、`IsTimeTrusted=False`。修前同场景为 `tgOk/tgOffline`（水位 0，回拨分支不进入）——必须留修前/修后对照原件。
3. **无后端不过紧**：`CreateTimeGuardSecretStore` 返回 nil 的路径（fake 工厂或 dev 关环境）⇒ `GetSecretStore` = nil ⇒ `Verify` 仍返回 `tgOk/tgOffline` 之一，**不得**因无存储而变红。
4. **工厂异常不泄漏**：底座抛 `ESecretStoreUnavailable` ⇒ 适配层吞住返 nil，调用链无异常逃逸。
5. **不回归**：既有 TimeGuard/License 相关 fixture 全限定跑：`Test.DeepBase.LicensingTimeSource`（7/7）、`Test.DeepBase.License`（16/0）、`Test.DeepBase.Commerce`（62/0）——基线比对，零新增红。
6. **dpk 登记**：新单元加入 `DeepBaseCommerce.dpk`（`DeepBase.TimeGuard` 同册，`:50` 附近）。登记前后 T0 manifest 全量 `Hint` 按码不超 `noise-baseline.json`（当前 793/155）——若本单元带入新 Hint，须逐码列出并由主控决定是否走基线流程，**不许自行 emit**。

## 三、破坏面

`Features/DeepBase.TimeGuard.SecretStore.pas`（新）+ `Features/DeepBase.TimeGuard.pas`（仅 `GetSecretStore` + `:82` 注释）+ `DeepBaseCommerce.dpk`（1 行 contains）+ 新测试单元；`Core/**`、`Features/DeepBase.Licensing.pas`、`contracts/**`、dpr/.dproj 零改动。

## 四、输出物与验收

- 回执：`CodeReview/20260929-AUDIT-甲-A11-交付回执.md`（修前/修后对照、四项判据跑录、dpk 登记前后噪声对照、四门复跑）。
- 证据：`CodeReview/20260929-AUDIT-甲-A11-证据/`。
- 验收：主控亲跑新单元 + 判据②的修前/修后双向复现 + 亲读 diff + T0 隔离树复跑 + 基线比对；**甲自报不作为验收依据**。
- 衔接：本单验收后由主控把新测试单元并网进 `Tests/DeepBaseTests.dpr`。

## 五、不在本单（已登记）

- 若联调时发现「某些环境（如 CI 容器）应当**强制**要求凭据后端而不能 best-effort」⇒ 停机上报主控另议，不许本单内自行升级为 fail-closed 拒绝。
- `Licensing.pas:1011/:1017` 超时测量改单调计时源（乙 B12 项）、B7 §六.2 试用到期死路径（乙 B11 项）均不属本单。

*主控 · 2026-09-29 签发 · 选型已定型（适配 + 惰性默认），甲照做；设计变更 ⇒ 停机上报，不许自行换型*
