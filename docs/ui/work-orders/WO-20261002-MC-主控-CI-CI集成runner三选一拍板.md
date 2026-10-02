# WO-20261002-MC-主控-CI CI 集成 runner 三选一拍板（主控自办 · P2 · 待老板）

**单号**：`WO-20261002-MC-主控-CI`
**派单**：主控（2026-10-02，`WO-20261002-MC-MC3` 项 2 ACCEPTED 派生）
**优先级**：P2（阻塞「任何 CI 自动化」这一整类能力）
**状态**：⏸ **等老板拍板**，未拍板不得动 `.github/**`
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

## 四、拍板记录（待填）

- 选定案号：☐ 一 ｜ ☐ 二 ｜ ☐ 三
- 拍板人 / 日期：

---

## 附、不在本单

1. `tzutil` 固定非 UTC 时区（CI 时区稳定性）—— 归主控自办 task（MC1 项 3），未开工，**不得因本单顺带做掉而混记**。
2. 各 job 内部脚本逻辑改写 —— 拍板后另立单。
