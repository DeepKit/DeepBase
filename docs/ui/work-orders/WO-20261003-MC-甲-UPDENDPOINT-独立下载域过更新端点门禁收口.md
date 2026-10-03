# WO-20261003-MC-甲-UPDENDPOINT 独立下载域过更新端点门禁收口（主控派生 · P1 · 待派工）

**单号**：`WO-20261003-MC-甲-UPDENDPOINT`
**派单**：主控（2026-10-03）
**优先级**：**P1**（不处理 ⇒ COS 桶配好、王维把 `package_url` 填成 `download.deepkit.top` 之后，客户端**下载必被拒**，整条自动升级链路断在最后一步）
**状态**：⏸ **待派工**（本单只留证与判据，不代写生产代码）
**触发**：老板 2026-10-03 两项原话裁决——**「download.deepkit.top」**+**「备案是通过的」**
**上游材料**：`docs/DB4-20261002-COS未配置决策材料-草稿.md` F8 / `docs/DB4-20261002-COS配置具体步骤.md` §〇 G1–G5
**老板待办对应项**：`docs/老板待办-需拍板事项清单.md` T1（备案）与 T2（域名二选一）

---

## 〇、纪律与口径

1. **不重开老板已拍的板**。域名已定 `download.deepkit.top`，本单只解决"让它过得了门禁"，任何"改回复用 host"的提案一律不受理。
2. **禁止为绕开门禁而删弱化校验**。`EffectiveAllowedHosts` / `ValidateUpdateEndpointUrl` 是安全边界；把「空名单=放行」语义加回来等于撤保镖，属**明令禁止**。
3. **先零代码案，后代码案**（见 §四）。只有当零代码案在客户端宿主侧确实不可行时，才动 `Features/**` 与 `VCL/**`。
4. 一笔 H15 原子提交，显式 pathspec，**禁 push**。台账状态槽改写权归主控。
5. `Tests/**` 属禁动区，本单显式授权且**仅限** `Tests/Test.DeepBase.Updater.pas` 的新增 fixture 段（理由见 §六）。

---

## 一、目标

让客户端在 **`UpdateUrl` 的 host ≠ `download.deepkit.top`** 的现实配置下，仍能**通过**更新端点门禁下载 COS 上的升级包——且**不**通过弱校验实现，而是通过**显式、可审计的信任锚**实现。

## 二、事实链（主控实测 2026-10-03，逐环可复算）

> 这一节是本单的地基。甲线开工前请自行复算每一环；任何一环与我写的不一致，**先回报再动手**。

### 2.1 `package_url` 确实走「带白名单」的那条通道

| # | 事实 | 出处 |
|---|---|---|
| F1 | manifest 的 `package_url` 被解析进 `TUpdateInfo.DownloadUrl` | `Features/DeepBase.Updater.pas:588` `LDownloadUrl := JSON.GetValue<string>('package_url', '');` |
| F2 | 下载入口 `DownloadAndInstall` → `StageAndVerifyPackage`（实例版，`:984-1032`） | `Features/DeepBase.Updater.pas:1532` |
| F3 | `StageAndVerifyPackage` → `StageUpdatePackage` → `DownloadFile(Info.DownloadUrl, ...)` | `Features/DeepBase.Updater.pas:1018` → `:966-982`，URL 取自 `:971` |
| F4 | `DownloadFile` → `SendHttpRequest(dbhmGet, Url)` | `Features/DeepBase.Updater.pas:1191` |
| F5 | **咽喉点**：`SendHttpRequest` 统一过 `ValidateUpdateEndpointUrl(AUrl, EffectiveAllowedHosts)`，不批准即 `raise` | `Features/DeepBase.Updater.pas:801-811` |

### 2.2 该通道的白名单在生产里从未被设置

| # | 事实 | 出处 |
|---|---|---|
| F6 | 白名单字段注释自述「空=拒绝」 | `Features/DeepBase.Updater.pas:141` `FAllowedHosts: TArray<string>; // 更新端点主机白名单（改法项 (4)），空=拒绝` |
| F7 | 属性可写，带 doc 说明回退语义 | `Features/DeepBase.Updater.pas:326-328` |
| F8 | `EffectiveAllowedHosts`：`FAllowedHosts` 非空则用之，否则回退 `[UrlHost(FUpdateUrl)]`，两者皆无 ⇒ **空数组** | `Features/DeepBase.Updater.pas:905-915` |
| F9 | 空数组 ⇒ `ValidateUpdateEndpointUrl` 直接 Rejected，且实现里**没有**"空=放行"分支 | `Features/DeepBase.Update.Contracts.pas:369-371`（原文：`No allowed update hosts configured; endpoint host is not trusted (fail-closed)`） |
| **F10** | **生产入口只设 `UpdateUrl` / `Channel` / 路由模式，从不设白名单** | `Features/DeepBase.Desktop.Lifecycle.pas:190-202`（`ConfigureUpdater`）；该文件 `git grep UpdateHostWhitelist` = **0 命中** |
| F11 | `UpdateUrl` 完全由宿主 App 传入（record 字段，无仓内默认值） | `Features/DeepBase.Desktop.Lifecycle.pas:20` / `:89-99` |

### 2.3 与 F5 合成 ⇒ 拒绝的具体形态（**不是静默**）

`UpdateUrl` host = `api.deepkit.top`、`package_url` host = `download.deepkit.top` 时：

```
SendHttpRequest → Exception('Update endpoint rejected: Update endpoint host
  "download.deepkit.top" is not in the allowed host list')
  └→ DownloadFile except（:1204-1208）FLastError := 'Download failed: ' + E.Message
      └→ StageUpdatePackage Result := False
          └→ StageAndVerifyPackage Reject(FLastError)（:1019）
              └→ SetStatus(usFailed, ...)（:1030-1031）
```

⇒ 用户层只看到 `usFailed`；**完整原因在 `FLastError` / `LastError` 里**，不丢。这一点与上游材料 F8 的「极难排查」表述**不同**，主控已在同批订正（见 §八.1）。

### 2.4 另一条通道**没有**白名单（上游材料在此处泛化了）

| # | 事实 | 出处 |
|---|---|---|
| F12 | `VCL/DeepBase.VCL.AutoUpdater.pas` 包的内部对象是 **`TDeepBaseAutoUpdate`**，不是 `TUpdateManager` | `VCL/DeepBase.VCL.AutoUpdater.pas:26`（`FAutoUpdate: TDeepBaseAutoUpdate`） |
| F13 | 该通道下载前**只校验 https scheme**，源码注释自述「静态 CDN 通道无主机白名单可配置」 | `Features/DeepBase.AutoUpdate.pas:778-785`（调 `ValidateUpdateEndpointScheme`，实现见 `Features/DeepBase.Update.Contracts.pas:340-357`） |
| F14 | 契约层把两种门禁的分工写在 doc 里：「需要主机白名单的通道必须用 `ValidateUpdateEndpointUrl`」 | `Features/DeepBase.Update.Contracts.pas:132-136` |

⇒ **结论订正**：主机白名单 fail-closed 是**通道特定**规则（`TUpdateManager` 通道有，`TDeepBaseAutoUpdate` 静态通道没有）。上游两件文档把它写成了"客户端对下载 URL 的通用校验"，属**过度泛化**——已由主控同批订正，不构成本单范围，但甲线不得再据此扩散。

---

## 三、缺口定位

COS 升级流（交接说明 §16.5 `GET /dk/updates/manifest` 返回 `package_url`）落在 **F1–F5 的 `TUpdateManager` 通道**（佐证：`Features/DeepBase.Desktop.Lifecycle.pas:202` `UpdateCheckRouteMode := ucrmManifest`）。

该通道的信任锚**只有两个来源**：

1. `FAllowedHosts`（显式白名单）——**生产零设置**（F10）；
2. `UrlHost(FUpdateUrl)`（回退锚）——受宿主 App 配置控制（F11）。

⇒ 老板选了独立下载域后，**两案必居其一**：要么宿主把 `UpdateUrl` 换到 `download.deepkit.top`，要么客户端显式把 `download.deepkit.top` 写进白名单。**没有第三案。**

## 四、解法二选一（按代价从小到大，甲线先评估再定）

| 案 | 做法 | 客户端是否发版 | 前置条件 |
|---|---|---|---|
| **Z1 · 零代码（首选评估）** | 宿主 App 把 `UpdateUrl` 配成 `https://download.deepkit.top/dk/updates/manifest` | **否**（纯配置） | 王维侧需在 `download.deepkit.top` 上同时提供 manifest 端点（CDN 回源 / 网关路由），而不仅是 COS 静态包 |
| **Z2 · 显式白名单（兜底）** | `TUpdateManager.UpdateHostWhitelist` 增加**可配置入口**并显式填入 `download.deepkit.top` | **是** | 需要一个配置通道；当前 VCL/FMX 层**未暴露**该属性（见 §三 补证） |

### Z2 的补证：白名单在上层确实无入口

| # | 事实 | 出处 |
|---|---|---|
| G1 | VCL 组件 `published` 区只有 `UpdateUrl` / `CurrentVersion` / `AutoCheck`，**无白名单** | `VCL/DeepBase.VCL.AutoUpdater.pas:41-47` |
| G2 | 且该组件根本不包装 `TUpdateManager`（F12）⇒ 它连透传的对象都不是同一个 | 同上 |
| G3 | 唯一的"配置驱动"样例模板引用了 **6 个不存在的属性**，在 HEAD 不可编译 | `Examples/Templates/Common/Template.AutoUpdateBootstrap.pas:43-56`（`Channel` / `ShowDialogOnUpdate` / `EnablePolicyDrivenSilentUpdate` / `SilentInstallPollIntervalMs` / `AutoTriggerExitInstall` / `SilentInstallMainExePath`；`git grep` 全仓仅本文件出现后四者） |
| G4 | 该模板**零消费方**（`git grep -rn "Template.AutoUpdateBootstrap"` 只命中自身 2 行注释），不阻塞任何构建 | 实测 |

> ⇒ **Z2 不等于"改模板"**。G3/G4 说明那个模板是死代码且坏的，不能当改动载体。Z2 若要做，正确载体是 `Features/DeepBase.Desktop.Lifecycle.pas`（在 `TDeepBaseDesktopLifecycleConfig` 增加白名单字段 + `ConfigureUpdater` 显式下传）与/或 `VCL`/`FMX` `DesktopLifecycle` 的同构补口。

**甲线必须先给出 Z1/Z2 的可行性结论**（Z1 只取决于王维侧能否同域提供 manifest，不取决于本仓代码），把结论写进交付件；**不得跳过 Z1 直接动 `Features/**`**。

---

## 五、授权面 / 禁动区

- **授权面（按案）**
  - **Z1**：本仓**零代码改动**；交付物是一份《Z1 可行性结论 + 需王维配合事项》Markdown（落 `docs/`）。若同时要补 VCL/FMX 侧配置样例，只写文档不写码。
  - **Z2**：`Features/DeepBase.Desktop.Lifecycle.pas`、`VCL/DeepBase.VCL.DesktopLifecycle.pas`、`FMX/DeepBase.FMX.DesktopLifecycle.pas`、`docs/**`、`CodeReview/**`；测试仅 `Tests/Test.DeepBase.Updater.pas`（新增段）。
- **禁动区（硬）**
  - `Features/DeepBase.Updater.pas` 的**校验语义**：`EffectiveAllowedHosts`（`:905-915`）、`SendHttpRequest` 咽喉点（`:801-811`）、`StageAndVerifyPackage` 任一版本（`:213` / `:308` / `:312` / `:984` / `:1986` / `:2042`）。
  - `Features/DeepBase.Update.Contracts.pas` 的两个门禁实现（`:340-357` / `:359-379`）。
  - `Features/DeepBase.AutoUpdate.pas`（通道 A 不在本单范围）。
  - `Core/**`、`contracts/**`、`09_工程脚本/**`、`Scripts/**`、`.github/workflows/**`、`noise-baseline.json`。
  - **不为编译通过而顺手修** `Examples/Templates/Common/Template.AutoUpdateBootstrap.pas`（G3/G4：死代码且坏，属另单登记项，见 §八.2）。
- **禁做**：给 `ValidateUpdateEndpointUrl` 加"空名单放行"；把 `EffectiveAllowedHosts` 的回退锚从 `UpdateUrl` host 改成"任意 https 即信任"；在 `FInsecureDevMode` 之外新增任何跳过分支。

## 六、前置依赖

- **Z1 依赖王维**：确认 `download.deepkit.top` 能否承载 manifest 端点。**这条与 `docs/老板待办-需拍板事项清单.md` T3/T4 同链**（三函 + 对端机器上线）——Z1 的对外确认本身就要等 #101/#102/#103 送达。
- **Z2 无外部依赖**，可立即开工；但按 §〇.3，仍须先交付 Z1 评估结论。
- 本单与 `Test.DeepBase.Updater.pas` 既有测试簇**零冲突**：`:1533` 已在设 `UpdateHostWhitelist := ['updates.deepbase.invalid']`，`:1754-1794` 已覆盖正/负/空/大小写四态——甲线是**新增**，不是改旧。

## 七、验收判据（可复算，fail-closed）

| # | 判据 | 期望 |
|---|---|---|
| 1 | Z1 可行性结论成文 | 明确「可行 / 不可行」+ 需王维配合的具体事项清单；不许"待调研" |
| 2 | **四态复算表** | 逐态给出 `UpdateUrl` host / 白名单 / `package_url` host / 门禁判定 四列，覆盖：①同 host ②不同 host+空名单 ③不同 host+名单含新域 ④不同 host+名单不含新域 |
| 3 | Z2 改动后**正样本过、负样本仍拒** | `download.deepkit.top` 在名单 ⇒ Approved；`evil.example.com` 不在 ⇒ Rejected；**空名单 ⇒ 仍 Rejected**（不许因为引入了配置入口而变成放行） |
| 4 | 回退锚语义不变 | 未配置白名单时，`EffectiveAllowedHosts` 仍 = `[UrlHost(FUpdateUrl)]`；既存 `:1754-1794` 四条断言**全绿不变** |
| 5 | 阴性对照 | 临时把白名单写错一个字符 ⇒ 门禁必须拦住 ⇒ 复跑 ⇒ 回退；证明判据 3 不是恒真 |
| 6 | 若走 Z2，须给出**配置样例** | 一个完整的 `UpdateUrl` + 白名单配置写法（含 JSON/ini 键名），让宿主 App 一行能抄；不许只给属性名 |
| 7 | 交付件自证 | 每条结论附「命令 + 原文摘录」；不接受"已验证"这类无证据表述 |

## 八、主控同批处理的周边两件（不并本单，仅登记）

### 8.1 上游两件文档的门禁泛化（主控自办，**本批同改**）

- `docs/DB4-20261002-COS未配置决策材料-草稿.md` F8：把"客户端对下载 URL 有主机白名单 fail-closed 校验"改为**通道限定**表述（§2.4 F12–F14），并把"极难排查"改为"UI 只见 `usFailed`、原因在 `LastError`"。
- `docs/DB4-20261002-COS配置具体步骤.md` G1–G5：同样限定到 `TUpdateManager` 通道，并在 G5 增加 **Z1（`UpdateUrl` 同域）** 这一零代码案——原 G5 只列了"复用 `api.deepkit.top`"与"客户端加白名单"两案，漏了"`UpdateUrl` 直接指向 `download.deepkit.top`"，而那恰是当前唯一可能零代码的一案。

### 8.2 顺带发现的既存缺陷（只登记，不并本单）

| # | 缺陷 | 证据 | 归属 |
|---|---|---|---|
| D1 | `Examples/Templates/Common/Template.AutoUpdateBootstrap.pas` 在 HEAD 不可编译（引用 6 个不存在属性）且零消费方 | §四 G3/G4 | 另单：TESTDEBT 或样例死代码清理 |
| D2 | `update_manifests.package_url` 的 host 与客户端 `UpdateUrl` host 之间的约束，**交接说明 §16.5/§16.9 完全没写** | docs/66 交接说明；F8–F11 才是真相 | 已在 `docs/DB4-20261002-COS配置具体步骤.md` §六 拟补丁说明，待三函送达王维 |

---

*派单 · 主控 2026-10-03 · 触发：老板拍板 COS 域名 download.deepkit.top + 备案通过*
