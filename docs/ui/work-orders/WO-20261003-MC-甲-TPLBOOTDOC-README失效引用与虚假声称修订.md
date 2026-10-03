# WO-20261003-MC-甲-TPLBOOTDOC README 失效引用与虚假声称修订（主控派单 · P3）

**单号**：`WO-20261003-MC-甲-TPLBOOTDOC`
**派单**：主控（2026-10-03，`WO-20261003-MC-甲-TPLBOOT` 验收遗留项转正）
**优先级**：P3（文档债，但属**对外可见的虚假声称**）
**前置**：`CodeReview/20261003-AUDIT-甲-TPLBOOT-证据/TPLBOOT-交付回执.md` §一 F6、§七 第 2 项

---

## 〇、背景：一次删除留下的文档真空

`WO-20261003-MC-甲-TPLBOOT` 判定**删除**下列文件（理由：零消费方 + 8 处硬编译错 + 无干净祖先可恢复），下文称「已删样例」：

```text
Examples/Templates/Common/Template.AutoUpdateBootstrap.pas
```

该工单授权面不含 README，未动。

现在 `Examples/Templates/README.md` 处于**引用一个已不存在的文件、并声称它已被默认接入**的状态。

---

## 一、主控已核实的事实（待本单复算）

| # | 事实 | 取证 |
|---|---|---|
| F1 | 文件已不在库：`git ls-files --error-unmatch` 对已删样例路径失败 | 主控亲验 |
| F2 | `Examples/Templates/README.md` 第 4、7–11 行引用该文件 | 开发甲 `git grep -rln` 命中（主控原清单漏列） |
| F3 | README 声称「已默认接入」**本身不成立**：`StartTemplateAutoUpdate`/`StopTemplateAutoUpdate` 全仓零调用，三个模板 `.dpr` 均不 `uses` 该单元 | 开发甲复算 |
| F4 | 残留引用还有 2 处 gate 基线条目（`09_工程脚本/encoding-gate/pas_encoding_baseline.json:75`、`09_工程脚本/eol-gate/eol_baseline.json:108`）——**本单不许动**，已登记待主控处理 | 主控亲验 |
| F5 | `CodeReview/20260924-AUDIT-主控-乱码还原/还原清单.md:27-29` 该条随对象删除作废（A3 范围，本单登记不擅动） | TPLBOOT 回执 §四 |

---

## 二、判据（主控验收用）

| # | 判据 | 达成标准 |
|---|---|---|
| 1 | README 引用订正 | 对被删文件的引用全部移除或改为「已移除」说明；**不留断链** |
| 2 | 虚假声称订正 | 「已默认接入」这类与事实不符的表述逐条改掉，改为事实陈述（例如「模板工程需自行接线」） |
| 3 | 接线说明补位 | 删除样例后，README 需说明**现在要接自动更新该怎么做**（指向 `VCL/DeepBase.VCL.AutoUpdater.pas` 真实存在的 3 个属性：`UpdateUrl`/`CurrentVersion`/`AutoCheck`）。**不许把 6 个不存在的属性写进文档** |
| 4 | 全仓清查同类问题 | `git grep` 扫所有 `*.md` 还有没有引用已删文件、或声称「已接入/已默认」而实际零消费的样例，列出清单并逐条处置 |
| 5 | doc-links | `powershell -ExecutionPolicy Bypass -File .\Scripts\check_doc_links.ps1 -Path <改后的文档>` 跑过；**本单新引入断链 0**（注意仓外同步区引用要略去扩展名） |
| 6 | 基线零擅动 | `git diff --stat -- 09_工程脚本/` 为空 |
| 7 | 四门 + 纪律 | eol/encoding/mojibake/evidence-encoding 全 EXIT=0；一笔 H15；禁 push；台账状态槽不改 |

---

## 三、授权面与禁动区

**授权**：`Examples/Templates/README.md`、`Examples/**/*.md`（若判据 4 牵动）、`CodeReview/20261003-AUDIT-甲-TPLBOOTDOC-证据/**`。

**禁动**：`Core/**`、`contracts/**`、`Features/**`、`09_工程脚本/**`、`Scripts/**`、`noise-baseline.json`、`Tests/**`、`VCL/**`、`FMX/**`、`CodeReview/20260924-AUDIT-主控-乱码还原/**`（F5 只登记）。

**明令禁止**：
- 为「补位」而把 `Template.AutoUpdateBootstrap.pas` 恢复回来
- 在文档里写 `Channel` / `ShowDialogOnUpdate` / `EnablePolicyDrivenSilentUpdate` / `SilentInstallPollIntervalMs` / `AutoTriggerExitInstall` / `SilentInstallMainExePath` 中任何一个作为可用属性 —— 它们对 `TAutoUpdater` 都不存在（TPFBOOT 已实测 8 处编译错）
- 「已默认接入」「开箱即用」「零配置」这类未经验证的措辞

---

## 四、不在本单

1. gate 基线两条休眠条目清理 —— 主控自办，已在 TPLBOOT 回执登记。
2. 还原清单该条作废登记 —— A3 范围。
3.  `WO-20260922-AUDIT-甲-A3`（`Examples/` 域乱码还原）其余文件。
4. 7 处断言与产品分歧 —— 归 `WO-20261003-MC-甲-ORPHANRED`。
