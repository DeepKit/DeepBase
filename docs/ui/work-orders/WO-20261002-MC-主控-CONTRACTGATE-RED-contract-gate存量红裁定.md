# WO-20261002-MC-主控-CONTRACTGATE-RED contract-gate 存量红裁定（主控派生 · P1 · 待派工）

**单号**：`WO-20261002-MC-主控-CONTRACTGATE-RED`
**派单**：主控（2026-10-02，CI 工单 `WO-20261002-MC-主控-CI` §6.6 当场派生）
**优先级**：**P1**（不处理则 `encoding-gate` job 的第 8 步在 CI 上恒红，整条 Workflow 拿不到绿结论）
**状态**：⏸ **待派工**（本单只留证与判据，不代写生产代码）
**派生自**：`docs/ui/work-orders/WO-20261002-MC-主控-CI-CI集成runner三选一拍板.md` §6.6
**立项依据**：主控修复 CI 的 PowerShell 5.1 CP936 编码缺陷后亲跑五门，contract-gate 实测 `EXIT=1`

---

## 〇、纪律与口径

1. **禁止「跑红就重生成基线」**。基线重建必须走「签名变更评审 + CHANGELOG 登记」流程；未经评审直接重生成等于把破坏性变更洗成绿。
2. 本单要的是**裁定**（有意 / 无意 / 应否纳入 stable），不是「让门禁变绿」。
3. `Features/DeepBase.Licensing.pas` 属主控禁动区，本单由获批的开发侧执行；主控只出判据与零信任验收。
4. 一笔 H15 原子提交，显式 pathspec，禁 push。台账状态槽改写权归主控。

---

## 一、目标

对 contract-gate 当前 3 项命中逐条给出**两态裁定**（有意 / 无意），并据此执行**有据可查**的基线更新或代码回退，使门禁以「正确理由」转绿——而不是把基线刷成现状。

## 二、命中项清单（主控实测原文，2026-10-02 主树）

```
契约门禁失败：扫描 19 单元，stable 破坏性变更 2 项:
  DeepBase.Licensing: 公开签名消失/改写 2 处（须记 CHANGELOG 并重新生成基线）:
      interface uses System.SysUtils, System.JSON, System.Generics.Collections,
        DeepBase.Commerce.Types, DeepBase.Commerce.SafeClient, DeepBase.Commerce.Permissions,
        DeepBase.Commerce.UpgradeFlow, DeepBase.Commerce.JsonUtil, DeepBase.Unlock, DeepBase.TimeGuard
      type TLicensingTier = (ltFree, ltPro)
  stable 单元 DeepBase.DataBinding 不在基线内（新纳入稳定的单元须发版时写入基线）
```

| # | 命中 | 待裁定问题 |
|---|---|---|
| C1 | `DeepBase.Licensing` `interface uses` 全列被判「消失/改写」 | 这是 9/24 之后许可线（B7 / B10 / B11）的真实扩张，还是基线漏登？逐单元给出「应在 / 不应在」的结论 |
| C2 | `DeepBase.Licensing` `type TLicensingTier = (ltFree, ltPro)` | 枚举成员是否被删改？若是，删掉的是哪一档、有无消费方（DB4 侧是否已按旧档位对接）？ |
| C3 | `DeepBase.DataBinding` 不在 stable 基线内 | 该单元是否**已被当作稳定契约消费**？若是，应补入基线；若否，为何被扫描为 stable（是不是 `stable 单元清单` 本身写错了） |

## 三、授权面 / 禁动区

- **授权面**：`Features/DeepBase.Licensing.pas`（仅在裁定为「无意引入且应回退」时）、`09_工程脚本/contract-gate/signature-baseline.json`（仅在裁定完成后、且附 CHANGELOG 条目时）、`CHANGELOG*`、`CodeReview/**`、`docs/**`
- **禁动区**：`Core/**`、`contracts/**`、`Tests/**`（除为验证签名而临时运行）、`.github/workflows/**`（主控已修 shell，本单不再动）
- **禁做**：为让门禁变绿而整体重生成基线；把 `stable 单元清单` 缩窄以避开扫描（那是另一种造假）

## 四、前置依赖

**无**。可立即开工。与 MOE-EV / MOE-JOBS 文件零重叠。

## 五、验收判据（可复算，fail-closed）

| # | 判据 | 期望 |
|---|---|---|
| 1 | C1/C2/C3 逐条两态裁定 | 每条「有意 / 无意」+ 证据指针（提交号 / 消费方文件行号）；无「大概是有意的」这类第三态 |
| 2 | 消费方影响面 | C2 若为删档，给出全仓 grep 消费方清单（含 DB4 函件是否已按旧档位对接——见 `docs/DB4-20261002-试用到期签发协议确认-草稿.md`） |
| 3 | 基线更新有据 | 若更新基线，须同时给出：裁定结论、CHANGELOG 条目、更新前后 diff 三件；diff 必须是**人类可读的逐条差异**，不许「文件整体替换」 |
| 4 | 阴性对照 | 提交一条**故意**的破坏性签名变更（临时改一个 public 方法名），证明门禁仍能拦住 → 复跑 → 回退 |
| 5 | contract-gate 亲跑 | `node .\09_工程脚本\contract-gate\check_contract.js` EXIT=0，原始输出留档 |
| 6 | 四门不回归 | eol / encoding / mojibake / evidence-encoding 复跑仍全 EXIT=0（逐道写门名 + 退出码） |
| 7 | 纪律 | 单笔 H15，显式 pathspec，未 push；`git diff --cached --name-only` 亲核无 `Core/**` |

## 六、产出物

1. `CodeReview/2026xxxx-AUDIT-*-CONTRACTGATE-RED-裁定.md`：三/五 判据的裁定结论
2. `CodeReview/2026xxxx-AUDIT-*-CONTRACTGATE-RED-证据/`：修前/修后亲跑原始输出、基线 diff、阴性对照记录

## 七、不在本单

1. CI 的 shell / runner / DELPHI_PATH —— 归 `WO-20261002-MC-主控-CI`（已修，未 push）。
2. `Features/DeepBase.Licensing.pas:339` / `:710` 的试用到期死路径实现 —— 归乙 B11，另立有单；本单只判**签名**，不判**行为**。
3. 是否把 `DeepBase.DataBinding` 新纳入 stable 的发版流程 —— 若裁定为「应纳入」，执行部分归本单，发版节奏归老板。

---

*主控派生 · 2026-10-02 · 待派工*
