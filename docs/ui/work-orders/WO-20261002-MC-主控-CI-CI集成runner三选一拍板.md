# WO-20261002-MC-主控-CI CI 集成 runner 三选一拍板（主控自办 · P2 · 待老板）

**单号**：`WO-20261002-MC-主控-CI`
**派单**：主控（2026-10-02，`WO-20261002-MC-MC3` 项 2 ACCEPTED 派生）
**优先级**：P2（阻塞「任何 CI 自动化」这一整类能力）
**状态**：✅ **已拍板（案一）并已实施**（2026-10-02，runner 重建上线 + `DELPHI_PATH` 订正已提交、**未 push**）
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
| 6 | 交付纪律 | ✅ 一笔 H15，显式 pathspec，未 push |

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

## 附、不在本单

1. `tzutil` 固定非 UTC 时区（CI 时区稳定性）—— 归主控自办 task（MC1 项 3），未开工，**不得因本单顺带做掉而混记**。
2. 各 job 内部脚本逻辑改写 —— 拍板后另立单。
3. **「本地领先 origin/master 466 个提交、是否 push」** —— §5.1 边界 1 坐实。属不可逆对外动作，
   归老板裁定；本单只留证、不代决。拍板前 CI 永远只能跑到远端旧 yml。
