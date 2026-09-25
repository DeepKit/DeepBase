# B1 §2 GB18030 反表三处合一 — 证据

工单：`WO-20260925-AUDIT-总控-封版后余量总单-甲A1+乙B1+Top20-08.md` §2
判据：新旧表对全仓 .pas 扫描结果**逐字节一致**

## 合并前的三处（总单点名）

| 处 | 位置 | 归宿 |
|---|---|---|
| 数据 | `.tmp/gb18030_rev.json` | §3 移 `02-附件/gb18030_rev-旧数据件.json`（固化留证）；权威数据件改 `09_工程脚本/gb18030-reverse-table.json` |
| 生成器 | `.tmp/mb_table.py` | §3 删除（一次性 Python）；再生入口改 `node 09_工程脚本/gb18030-reverse-table.js --write` |
| 检测器内置 | `mojibake-core.js` / `encoding-gate/check_pas_encoding.js` / `evidence-encoding-gate/check_evidence_encoding.js` 三份同构构建循环 | 全部改为 `require` 共享模块 `09_工程脚本/gb18030-reverse-table.js` |

## 交付

- `09_工程脚本/gb18030-reverse-table.js`：唯一构建实现（`buildReverseTable(encoding)` + 权威 `gbkReverseTable()`），`--write` 再生数据件。
- `09_工程脚本/gb18030-reverse-table.json`：数据件（23939 双字节键 + ASCII 128），与重建表逐键一致（防漂移校验）。
- 三个检测器删除本地副本，只留引用 + 各自 fail-closed 语义不变（无 ICU ⇒ `null`/EXIT=3，与合并前同）。
- 永久守卫：共享负样本库新增 **D 段**（D1 引用检查 + 禁止内联构建循环；D2 强制 encoding-gate 传 `'gbk'`；D3 数据件防漂移）→ `SHARED-GUARD-TEST: PASS`。

## 等价校验（总单判据）

校验脚本：`02-表等价校验.js`（从 `git show HEAD:` 提取**旧实现真身**做深比对，非复刻）
运行输出：`02-表等价校验-运行输出.txt`，最终 `EQUIV: PASS (EXIT=0)`。

| 比对 | 结果 |
|---|---|
| mojibake-core 旧表 == 新表(gb18030) | PASS（23939 键，sha256 `980a3123…58d2ff1`） |
| evidence-encoding 旧表 == 新表(gb18030) | PASS（同上，逐键一致） |
| encoding-gate 旧表(gbk) == 新表(`buildReverseTable('gbk')`) | PASS（23940 键，sha256 `a4814bd6…9c3101f`） |
| 数据件 JSON == 算法重建表 | PASS |

表逐键一致 ⇒ 由同表驱动的全仓扫描结果逐字节一致（检测逻辑本次零改动）。

### 口径决策申报（encoding-gate 为什么保留 `encoding='gbk'` 参数）

gb18030 与 gbk 两口径差异实测 100/101 键，且全仓风险行扫描发现 **419 行（.pas 内 77 行）**
含差异键字符——若把 G6 换成 gb18030 默认口径，扫描结果会真的变化。G6 立法判据是 GBK
（WO-20260922 乙-P2 §3.1），故共享模块只暴露两个既有口径（gb18030 权威 / gbk 仅供 G6），
D2 负样本强制该选择不被静默更改。风险行清单见运行输出第 3 节。

## 测试与门禁

- 全部 8 个门禁负样本库 PASS（encoding / evidence / mojibake / eol / managed-copy / build-ownership / contract / shared 含 D 段）。
- 门禁矩阵（与 §1 交付时一致，无新增红）：encoding/eol/mojibake/evidence/contract = 0；managed-copy = 1（6× M2 既存）；build-ownership = 1（4× O1 既存）。
