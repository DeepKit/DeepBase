# WO-20261002-MC-主控-CI CI 集成 runner 三选一拍板（主控自办 · P2 · 待老板）

**单号**：`WO-20261002-MC-主控-CI`
**派单**：主控（2026-10-02，`WO-20261002-MC-MC3` 项 2 ACCEPTED 派生）
**优先级**：P2（阻塞「任何 CI 自动化」这一整类能力）
**状态**：✅ **已拍板（案一）并已实施**（2026-10-02，runner 重建上线 + `DELPHI_PATH` 订正已 push；另定位并修复预存的 PowerShell 5.1 CP936 编码缺陷，shell 修复**未 push**，见 §六）
**前置**：`CodeReview/20261002-AUDIT-主控-四单验收结论.md` §三.6；方案书 `CodeReview/20261002-AUDIT-主控-MC3-项2-CI方案书与决策点.md`
**授权面**：`.github/workflows/**`（**仅拍板后**）、`09_工程脚本/**`
**禁动区**：`Tests/**`、`Core/**`

---

## 〇、纪律与口径

1. 主控**不自决**：三选一涉及是否投入 runner 机器/采购托管额度，属老板决策面。
2. 未拍板前 `.github/workflows/*.yml` **保持原样**（甲本批已做到，主控亲核 `git log 41b580a..HEAD -- .github/workflows/**` = 空）。
3. 拍板后一笔 H15 原子提交，显式 pathspec，禁 push。
4. 台账状态槽改写权归主控。

---

## 一、主控亲验事实（2026-10-02）

| 事实 | 主控读数 |
|---|---|
| job 数 | **7** |
| `runs-on` | **全部**为 `[self-hosted, delphi-windows]`（本机无带这两个标签的 runner） |
| `env.DELPHI_PATH` | `.yml:33` = `'C:\Program Files (x86)\Embarcadero\Studio\23.0'`，本机实为 **37.0** |
| 根因 | **整条 CI 零 step 执行**，而非甲最初以为的「集成没跑」 |

⇒ 这不是「某个 job 挂了」，是**结构性零执行**：7/7 job 都等在一个不存在的 runner 标签上。

---

## 二、三选一（甲方案书已列，主控转呈）

| 案 | 动作 | 代价 | 生效速度 |
|---|---|---|---|
| **一 · 自建 self-hosted** | 在本机注册 GitHub Actions runner 并打 `self-hosted, delphi-windows` 双标签；同时把 `DELPHI_PATH` 改 37.0 | 需开一个常驻进程 + 出网策略 | 快（半天内） |
| **二 · 换托管 runner** | 弃用 self-hosted，改用 GitHub 托管 Windows runner，自行装 dcc64/依赖 | 需处理 Embarcadero 许可与安装时长 | 慢（许可与镜像） |
| **三 · 关停 CI 改本地门禁** | 明确「本仓不做远端 CI」，把四门 + contract-gate 固化为本地/预提交脚本 | 失去远端门禁，依赖开发者自律 | 快 |

**主控不预设立场**，但提示：无论选哪案，`DELPHI_PATH` 的 23.0→37.0 笔误都必须一并订正。

---

## 三、判据（拍板后主控验收用）

| # | 判据 | 达成标准 |
|---|---|---|
| 1 | 老板结论留痕 | 拍板案号 + 日期记入本单 §四 与台账 |
| 2 | `.yml` 与拍板一致 | 案一：runner 注册 + 双标签 + `DELPHI_PATH` 改 37.0；案二：`runs-on` 换托管；案三：明确停用并留说明 |
| 3 | 至少一次真实 step 执行 | 案一/案二：留一次 workflow run 的证据（非 skipped）；案三：本地门禁 EXIT=0 留档 |
| 4 | 零生产代码回归 | 本单只动 `.github/**` 与脚本，`.pas` 零 diff |
| 5 | 四门 | eol / encoding / mojibake / evidence-encoding 全 EXIT=0 |
| 6 | 交付纪律 | 一笔 H15，显式 pathspec，未 push |

---

## 四、拍板记录（2026-10-02）

- **选定案号：案一 · 自建 self-hosted**
- 拍板人：付毅（老板） ｜ 日期：2026-10-02
- 老板原话：「原来好象做过, 你在我机器上找一下, 没有就去建」

### 4.1 「原来做过」——零信任取证

`D:\actions-runner` 完整解压（`bin/Runner.Listener.exe` 151552 字节在），但 `.runner` /
`.credentials` / `.credentials_rsaparams` / `.env` / `.path` **五个配置件全不存在**
⇒ 曾注册过、后已被注销，现为**裸的**。

`_diag` 日志坐实历史上真跑过：

| 时刻（UTC） | 事件 |
|---|---|
| 2026-07-13 02:47:20Z | `Successfully saved RSA key parameters to file D:\actions-runner\.credentials_rsaparams`（configure 成功） |
| 2026-07-13 03:12:08Z | 进入 `run` |
| 2026-07-13 03:13:49Z / 03:16:58Z / 03:20:39Z | 三次 `Send job request message to worker for job <id>` ⇒ **真派过 3 个 job** |
| 2026-07-13 04:02:22Z | 重新 configure；04:15–04:16 每 ~7s 反复失败 |

旧连通性依赖本地代理 `http://127.0.0.1:10808`（现已死）；**直连 github.com 返回 200**
⇒ 本次重建不走代理，直连注册成功。

### 4.2 重建结果（主控亲跑）

| 项 | 证据 |
|---|---|
| 注册 | `Runner.Listener.exe configure --unattended --url https://github.com/DeepKit/DeepBase --token <registration-token> --name deepbase-win64 --labels self-hosted,delphi-windows --work _work --replace --runasservice` ⇒ `Runner successfully added` |
| 服务化 | `Service actions.runner.DeepKit-DeepBase.deepbase-win64 successfully installed` + `set to delayed auto start` + `started successfully` |
| 服务状态 | `sc query actions.runner.DeepKit-DeepBase.deepbase-win64` ⇒ `STATE: 4 RUNNING` |
| 上线核验 | `gh api repos/DeepKit/DeepBase/actions/runners` ⇒ `{"name":"deepbase-win64","status":"online","busy":false,"labels":["self-hosted","Windows","X64","delphi-windows"]}` |
| 标签匹配 | 工作流 `runs-on: [self-hosted, delphi-windows]` ↔ runner 实带该两标签，**完全一致** |

⇒ **做过，但已是裸的；现已重建并装为延迟自启服务（重启后仍在）。**

### 4.3 `DELPHI_PATH` 订正（本机真实布局）

原 `.yml:32-33` 写 `23.0` + `C:` 盘，**盘符与版本双错**：

| 路径 | `dcc64.exe` |
|---|---|
| `C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\` | **不存在**（该 bin 仅 1 个 `SHFolder.dll`） |
| `C:\Program Files (x86)\Embarcadero\Studio\23.0\bin\` | **不存在**（仅若干 bpl，无任何 dcc） |
| `D:\Program Files (x86)\Embarcadero\Studio\37.0\bin\` | **存在**（4415008 字节，2026-03-06） |

C 盘两个 Studio 目录只是零星残留。仓内 `Scripts/run_tests.ps1:69`、
`Scripts/build_packages_win64.ps1:20`、`Scripts/run_architecture_checks.ps1:17`、
`Scripts/build_examples_win64.ps1:19` 的 `$BdsRoot` 默认值**早已是** `D:\...\37.0`
（且均可被 `$env:BDS` 覆盖）——唯 `.yml` 是孤错。

订正（3 行外科手术 diff，`.yml` 3 insertions / 3 deletions）：

- 头部说明 `- Delphi path:` → `D:\Program Files (x86)\Embarcadero\Studio\37.0`
- `DELPHI_VERSION: '23.0'` → `'37.0'`
- `DELPHI_PATH: 'C:\...\23.0'` → `'D:\...\37.0'`

### 4.4 判据 3「至少一次真实 step 执行」

见 §五。

---

## 五、判据核销

| # | 判据 | 核销 |
|---|---|---|
| 1 | 老板结论留痕 | ✅ 本单 §四：案一 + 2026-10-02 + 老板原话 |
| 2 | `.yml` 与拍板一致 | ✅ runner 已注册（`self-hosted` + `delphi-windows` 双标签在线）；`DELPHI_PATH` / `DELPHI_VERSION` 已改 37.0 / D 盘 |
| 3 | 至少一次真实 step 执行（非 skipped） | 见 §5.1 |
| 4 | 零生产代码回归 | ✅ 本单只动 `.github/workflows/delphi-ci.yml`，`.pas` / `.dpr` / `.dpk` 零 diff |
| 5 | 四门 | ✅ eol=0 / encoding=0 / mojibake=0 / evidence-encoding=0（主树亲跑，读数见 §5.2） |
| 6 | 交付纪律 | ✅ 一笔 H15，显式 pathspec；`DELPHI_PATH` 订正按老板授权已 push（§6.1），shell 修复未 push（§6.7） |

### 5.1 判据 3 证据

`workflow_dispatch` 手动触发 run **36956564327**（触发于 2026-10-02T02:38:31Z）：

| 读数 | 值 |
|---|---|
| run 结论 | `failure`（`status=completed`） |
| 真执行 job | **6/6 Package Build Gate** 全部 `completed`，`runner_name=deepbase-win64`，标签 `self-hosted,delphi-windows` |
| step 执行 | `Checkout` ⇒ **success** |
| 失败步 | 6 个统一失败在 **`Verify Delphi environment`**——`C:\...\Studio\23.0\bin\dcc64.exe` 本机不存在，与本单 §4.3 取证一致 |
| 下游 job | `Architecture Checks` / `Unit Tests` / `Integration Tests`×2 / `Examples Build Gate` ⇒ `skipped`（package-gate 红的必然结果） |

⇒「整条 CI 零 step 执行」的结构性断链**已消**：job 能被 runner 认领、step 真跑、失败点可归因。

**必须与本判据同时留档的两条边界：**

1. 本 run 跑的是**远端 master**（`origin/master` = `57a043db`，WO-20260902-002 时代、9 月初），
   **不是**本地 HEAD `c377df3`。`git rev-list --left-right --count origin/master...HEAD` ⇒ `0 466`，
   且 `--is-ancestor` 为真 ⇒ **仓库自 9 月初起未 push，本地领先 466 个提交**。
2. 远端那份 yml **没有 `encoding-gate` job**（该 job 是 9 月后本地新增的），故本次 run 只有 11 个 job；
   其 `DELPHI_PATH` 也仍是 `C:\...\23.0`。

⇒ §4.3 的订正**尚未对 CI 生效**（需 push）。push 之前，本机 runner 上任何 run 都会失败在同一 Delphi 检查步。
**「push 466 个提交」属不可逆对外动作，归老板裁定，主控不擅动。**

### 5.2 四门读数（主树，2026-10-02）

| 门 | 退出码 | 末行读数 |
|---|---|---|
| eol-gate | 0 | 行尾门禁通过：检查了 1672 个文件（.pas CRLF / .md LF），跳过目录 11 |
| encoding-gate | 0 | 编码门禁通过：1017 个 .pas + 808 个扩展面文件 |
| mojibake-gate | 0 | 丙类损坏门禁通过：扫描 1015 个 .pas，丙-B 命中 0 处（0 件） |
| evidence-encoding-gate | 0 | 证据编码门禁通过：扫描 1235 个 CodeReview 证据文件，NUL 违规 0 |

---

## 六、push 后首次真跑暴露的预存编码缺陷（已定位、已修复、未 push）

### 6.1 push 动作（老板 2026-10-02 授权「push」这一次）

`git push origin master` ⇒ **`57a043d..e995538` fast-forward，无 force**，本地 = 远端。
push 前 `git rev-list --left-right --count origin/master...HEAD` ⇒ `0 466`（与 §5.1 边界 1 一致）。

### 6.2 新暴露的失败（run 36958665601，push 触发）

| 读数 | 值 |
|---|---|
| run 结论 | `failure` |
| 红屏 job | `encoding-gate`（"Static Gates"），`completed/failure`，20 steps |
| 红屏 step | step 3 `Check .pas encoding baseline (G1/G2/G3)` |
| 下游 | 后 5 个 job 全部 `skipped` |
| 失败正文 | `Error: Cannot find module 'D:\actions-runner\_work\DeepBase\DeepBase\09_宸ョ▼鑴氭湰\encoding-gate\check_pas_encoding.js'` + `code: 'MODULE_NOT_FOUND'` |

同一日志也证明 §4.3 的订正已生效：`DELPHI_PATH: D:\Program Files (x86)\Embarcadero\Studio\37.0`。
⇒ **本单自己修的 `DELPHI_PATH` 已让 CI 越过 Delphi 检查步，但又被下一层编码缺陷挡住。**

### 6.3 根因（机制级，非猜测）

runner 对 `shell: powershell` 用模板 `powershell.EXE -command ". '{0}'"`，把 step 内容落成 **UTF-8 无 BOM 的 .ps1**；
**Windows PowerShell 5.1 读无 BOM 脚本走 ANSI/CP936** ⇒ 内含中文的路径被二次污染：

| 复现输入（UTF-8 无 BOM 的 .ps1） | 按 UTF-8 读 | 按 CP936 读 |
|---|---|---|
| `node .\09_工程脚本\encoding-gate\check_pas_encoding.js` | 路径正确 | `node .\09_宸ョ▼鑴氭湰\...` ⇒ **与 CI 日志逐字一致** |

**双向实测（同机、同口径，仅换解释器）**：

| 解释器 | 结果 |
|---|---|
| Windows PowerShell 5.1 | `Error: Cannot find module '…\09_宸ョ▼鑴氭湰\…'` + `MODULE_NOT_FOUND` + `Node.js v24.9.0` ⇒ **同症复现** |
| pwsh 7.6.5 | `编码门禁通过：1017 个 .pas + 808 个扩展面文件` ⇒ **路径解析正确、门禁真过** |

⇒ 该缺陷是**预存的**（yml 编码完好，UTF-8、`工程脚本` 16 处完整；本单只改过 3 行 env），
只是 CI 史上从未真跑过任何 step，所以今天才第一次暴露。

### 6.4 修复（外科手术式）

`defaults.run.shell: powershell` → **`shell: pwsh`**，共 **7 处**（7 个 job 各一处），另加 3 行注释说明为何不能用 5.1。

改前先核验的可解析性（否则修会比不修更糟）：

| 核验项 | 结论 |
|---|---|
| `pwsh` 二进制 | `D:\Program Files\PowerShell\7\pwsh.exe` 存在（7.6.5） |
| **Machine PATH** | 含 `D:\Program Files\PowerShell\7\` ⇒ runner 服务账号（`NT AUTHORITY\NETWORK SERVICE`）也能解析，不只当前交互账号 |
| workflow 内非 ASCII | `run:` 块内非 ASCII **只有** `09_工程脚本` 路径前缀，无中文正文 ⇒ 换成 pwsh 后全部可解 |
| 其余 job 的子进程 | 4 个 `powershell -File .\Scripts\*.ps1` 调用：`Scripts/run_tests.ps1` 有 23 行非 ASCII，**逐行核过全为注释**，零中文路径字面量；另 3 个零非 ASCII ⇒ 子进程仍走 5.1 也无行为影响（仅注释字符变乱码） |

`.yml` 换行**不受 eol-gate 约束**（该门只 push `.pas` 与 `.md`），故本改动不引入新的门禁面。

### 6.5 修复后五门读数（主树，pwsh 口径，2026-10-02）

| 门 | 退出码 | 末行读数 |
|---|---|---|
| eol-gate | **0** | 行尾门禁通过：检查了 **1676** 个文件（.pas CRLF / .md LF），跳过目录 11 |
| encoding-gate | **0** | 编码门禁通过：1017 个 .pas + **812** 个扩展面文件 |
| mojibake-gate | **0** | 丙类损坏门禁通过：扫描 1015 个 .pas，丙-B 命中 0 处（0 件） |
| evidence-encoding-gate | **0** | 证据编码门禁通过：扫描 1243 个 CodeReview 证据文件，NUL 违规 0 |
| contract-gate | **1** | ❌ **见 §6.6，非本单引入** |

原始输出留档：`CodeReview/20261002-AUDIT-主控-CI-证据/01-shell修复前后-五门读数.txt`
（只取每门**自身 stdout/stderr 的末行 + 退出码**；**刻意不复刻** evidence-encoding 门那 240 行 E3 明细——
那些行本身含 U+FFFD，抄进新证据件就是自造丙类乱码。该件 U+FFFD 计数实测 **0**）。

读数与 §5.2 的差异**可解释、非门禁退化**：eol 1672 → 1676、扩展面 808 → 812、证据件 1235 → 1243，
多出来的件全部是**这期间新入库的 `.md`/.txt 证据件**（含甲 `1c2bfd4`/`89e815a` 两笔与本单派生件）。
另有一个**本机特有**扰动：`.tmp/`（`*.tmp` 已在 `.gitignore`）里的取证产物也被编码门扫描面计入，
所以本地读数会在 808→812 之间浮动；**CI 是干净 checkout、不含 `.tmp`**，读数仍是 §5.2 的 808——
该差异**不代表门禁退化**，也不代表 CI 与本地结论分歧。

### 6.6 必须同时披露的存量红：contract-gate（非四门，非本单引入）

本单按「四门」口径验收，但 **contract-gate 是 CI 里真实存在的一步**，修复 shell 后它会自己红出来，必须现在留档：

```
契约门禁失败：扫描 19 单元，stable 破坏性变更 2 项:
  DeepBase.Licensing: 公开签名消失/改写 2 处（须记 CHANGELOG 并重新生成基线）:
      interface uses System.SysUtils, ..., DeepBase.TimeGuard
      type TLicensingTier = (ltFree, ltPro)
  stable 单元 DeepBase.DataBinding 不在基线内（新纳入稳定的单元须发版时写入基线）
```

| 判定 | 依据 |
|---|---|
| 非本单引入 | contract-gate 扫描 `.pas` 单元签名，本单只动 `.github/workflows/delphi-ci.yml`；甲的两笔提交（`1c2bfd4` / `89e815a`）也全是 `CodeReview/**` + `docs/**` 文档件 |
| 是存量欠账 | 基线 `09_工程脚本/contract-gate/signature-baseline.json` 停留在 **2026-09-24**，此后的许可/Commerce/B10 等工作改了签名而未发版重生成 |
| **不得为转绿重建基线** | 按既有立规，基线重建必须走「签名变更评审 + CHANGELOG」流程，不许「跑红就重生成」 |

⇒ 已当场派生工单 `WO-20261002-MC-主控-CONTRACTGATE-RED`（见 `docs/ui/work-orders/`），本单不越权处理。

### 6.7 本单的纪律核销补充

| 项 | 核销 |
|---|---|
| 修复落点 | 全程在 CI 工单授权面 `.github/workflows/**` 内 |
| 零生产代码 | 本单累计只动 `.github/workflows/delphi-ci.yml` 与 `docs/**`、`CodeReview/**`，`.pas` / `.dpr` / `.dpk` 零 diff |
| 未 push | shell 修复**尚未 push**；远端仍在 `e995538` |
| push 授权边界 | 老板仅授权「push」**那一次**（§6.1 已执行完毕）。**是否把 shell 修复再 push 一次，须老板再授权** |

---

## 附、不在本单

1. `tzutil` 固定非 UTC 时区（CI 时区稳定性）—— 归主控自办 task（MC1 项 3），未开工，**不得因本单顺带做掉而混记**。
2. 各 job 内部脚本逻辑改写 —— 拍板后另立单。
3. **「本地领先 origin/master 466 个提交、是否 push」** —— 已归老板裁定并执行完毕（`57a043d..e995538`），见 §6.1。
   残留的「shell 修复是否再 push 一次」仍归老板，见 §6.7。
