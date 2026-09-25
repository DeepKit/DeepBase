# B1 §1 基线写入守卫（只减不增）— 证据

工单：`WO-20260925-AUDIT-总控-封版后余量总单-甲A1+乙B1+Top20-08.md` §1
基线：封版 `v1.1.0` = `92c14d1`（从 `2bc502e` 起步）

## 交付

- 新模块 `09_工程脚本/gate-emit-guard.js`（门禁唯一写口）：
  - 窄根自证：`root` 非空、不得为裸 `.`，违例拒绝写（`--allow-narrow-root` 逃生阀，仅测试用）；
  - minScan≥10：扫描目标 <10 拒绝写；
  - 只减不增：解析旧基线，「新增 key / key 数上升 / 计数项上升」任一即拒绝写并退出码 **1**；entry 数下降（key 删除）**允许**（按总单 §1 口径）；旧基线不可解析 → 退出码 2（`git checkout -- <file>` 恢复）；
  - 写前整文件 `.bak` 备份（旧 WO 守卫三兑现）；
  - 未改写 → exit 0（维持"新增无害"语义，不制造噪音）。
- 旧 WO `WO-20260922-AUDIT-乙-基线写入守卫` 的「默认拒缩 + `--force-shrink`」被总单更新口径**取代**（总单为准，见总单 §1）；其守卫一（窄根自证）、守卫三（写前备份）已并入本模块兑现。
- 只读门禁 `gate-baseline.js` 保持只读（加指针注释），只增不减判据不变。

## 受保护写点（全部改经 guardedEmitBaseline）

| 写点 | 文件 | 说明 |
|---|---|---|
| eol | `eol-gate/check_eol.js` | eol-decl/eol-build/eol-doc/eol-evidence 四基线 |
| managed-copy | `managed-copy-gate/check_managed_copy.js` | 待评审哨兵基线；同时删除"emit 自动加新孤儿"（孤儿不再静默转待标注） |
| mojibake | `mojibake-gate/check_mojibake.js` | 摩尔可哈基线；删除 `Math.min` 截断（增长必须被看见） |
| build-ownership | `build-ownership/check_build_ownership.js` | 孤儿基线；不再自动 append 新孤儿 |
| build-noise | `build-gate/check_build.js` | 噪音基线；**跨面**（minFileHash/protectedHash/managedHash 全面命中）与新增指纹一律拒绝写，防止 compare 阶段 `incomparable` 静默放行 |

排除项（申报）：`contract-gate` 读的是 release-snapshot 自身基线（范围隔离哈希），发布期由人判定，按 WO-20260915-XL 语义不变；受基线写入守卫统一约束会误伤，故不接入（`contract-gate.js` 含注释说明）。

## 负样本证据（§1 要求 ≥2 反例/行为）

共享负样本库 `09_工程脚本/test_negative_sample.js` 新增 C 段，最终运行结果：

```
SHARED-GUARD-TEST: PASS (EXIT=0)
```

| 反例 | 行为 | 覆盖写点 |
|---|---|---|
| C0 | 噪音单测：跨面/新指纹/条目数上升 → `checkOnlyDecrease` 返回 reject | build-noise |
| C1 | 窄根 root='.' 写 → 拒绝（不落盘） | eol / managed-copy |
| C2 | 新增 key → 拒绝，exit 1，旧文件字节不变 | eol / managed-copy / build-ownership |
| C3 | 计数项上升（2→3）→ 拒绝，exit 1，旧文件字节不变 | managed-copy / mojibake（git fixture） |
| C4 | 条目下降 → 允许写 + `.bak` 存在且为旧内容（2 条目） | eol / managed-copy |

mojibake 负样本库 `mojibake-gate/test_negative_sample.js`：PASS（emit 防扩用 `--allow-narrow-root`，因测试环境 cwd=仓根）。

## 门禁矩阵（交付树，本节改动后）

| 门禁 | EXIT | 说明 |
|---|---|---|
| encoding | 0 | |
| eol | 0 | |
| mojibake | 0 | |
| evidence | 0 | |
| contract | 0 | |
| managed-copy | 1 | 6× M2 = **既存违规**：违规文件（SecureMemory/MasterKey/UBS2 及其测试）`git status` 干净 = 封版后已入库（`9387222`），非本节引入 |
| build-ownership | 1 | 4× O1 孤儿 = **既存违规**：4 个 .pas `git diff HEAD` 为空 = 已入库既存，非本节引入 |
| build | 3 | 无编译范围 fail-closed（行为符合设计）；其 `test_negative_sample.js` 在 HEAD 已 FAIL（stash 回归验证：与本节改动无关，既存） |

## 已知债（申报，不在本节范围）

- managed-copy 6× M2 与 build-ownership 4× O1 既存红：需单独工单补评审/补归属。
- build-gate 自带 11 例负样本在 HEAD 即 FAIL（readdir 注入等）：既存，需单独修。
