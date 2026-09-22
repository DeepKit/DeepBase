# WO-20260922-AUDIT-甲-A2 —— 建钥 DACL 收敛与迁移建钥可观测

- **工单号**：WO-20260922-AUDIT-甲-A2
- **角色**：开发 AI 甲（`Core/` 密钥栈 + `Tools/CLI/` 域）
- **来源**：甲 A-1 回执 §六/6 + §六/9 登记项，主控裁定「并成一纸」（见 `CodeReview/20260921-AUDIT-主控-甲-A1-验收结论.md` §三.6）
- **前置**：WO-20260921-AUDIT-M1-A1（已交付·已验收）⇒ **前置已解除，可开工**
- **定性**：真缺陷（密钥 = 唯一熵源的风险面另一半）；非阻断既有交付，但**优先于** R8-P2

---

## 一、背景

A-1 把「**导出面**」的密钥副本收敛到了 owner-only（`03` 步 [12]：`FY3700\fuyi.it:(F)` 单条目）。但同一份密钥的**两条旁路**未收敛，二者都会让用户在「备份对不上」时拿不到原因。

---

## 二、缺陷面（主控实测，非转录）

### A2-1 首启建钥未施加 owner-only DACL

证据 `03` 步 [13] 实测（**源**密钥文件，`icacls` 原样输出）：

```
master.key  S-1-5-21-17452405-757048079-2430367978-4111302023:(I)(M,DC)
            S-1-5-21-806911548-2288407920-2332577828-2694129860:(I)(M)
            ... (共 9 条) ...
            FY3700\fuyi.it:(I)(M,DC)
            FY3700\CodexSandboxUsers:(I)(M)
```

- **全部条目带 `(I)` = 继承自父目录**；无任何显式 owner-only 条目 ⇒ 访问权由父目录决定，密钥文件本身不设防;
- 对比：**导出面已收敛**（步 [12] 单条目无 `(I)`）。同一文件族的两个面**不对称**;
- 根因：`Core/DeepBase.Security.MasterKey.pas` 的 owner-only DACL 实施（`:154`–`:210`，含 `PROTECTED_DACL_SECURITY_INFORMATION`）**只在导出路径被调用**；建钥路径不调用。`:253` 注释载明这是**刻意选择**（`DEEPBASE_MASTER_KEY_FILE` 可指向共享路径，权限由外部管）。

### A2-2 迁移路径静默建钥

```
Core/DeepBase.Security.pas:205  function BuildUBS2Key  ->  :207  Result.MasterSecret := TUserMasterKey.LoadOrCreate;
Core/DeepBase.Security.pas:251  Key := BuildUBS2Key;   (常规路径)
Core/DeepBase.Security.pas:292  Key := BuildUBS2Key;   (常规路径)
Core/DeepBase.Security.pas:478  TDeepBaseSecurity.MigrateLegacyUBS2Secrets
Core/DeepBase.Security.pas:495    Key := BuildUBS2Key;   <-- 迁移路径经此取钥
```

`BuildUBS2Key` 是**非测试代码中 `LoadOrCreate` 的唯一调用点**，而 `MigrateLegacyUBS2Secrets` 正经过它 ⇒ **密钥文件缺失时，迁移会静默新建一把钥**，用户按 A-1 的告诫「迁移前先备份」后反而会拿到「备份对不上」的结果，且不知为何。

---

## 三、交付面（三件）

### A2-1 建钥 DACL 收敛（默认收紧 + 显式豁免才放开）

- 默认：`LoadOrCreate` 创建密钥文件后，**与导出面同源地**施加 owner-only DACL（复用既有实施，不再写第二份）;
- 仅当**显式声明**「该路径权限由外部管理」（如 `DEEPBASE_MASTER_KEY_FILE` 指向共享路径时的既定语义）才跳过，且**跳过必须可观测**（打印一行告警 + 记入 `security status` 输出）;
- **不得**新增「明文开关绕过」类旁路（H8）；若确需豁免，须为「声明式 + 可观测 + 默认关」。

### A2-2 迁移建钥可观测（防静默）

- `MigrateLegacyUBS2Secrets` 取钥前先判定密钥文件是否存在：
  - 存在 ⇒ 正常迁移;
  - **不存在 ⇒ 默认 fail-closed 拒绝**（报错说明「密钥文件缺失，迁移会新建密钥，将使既有备份失效」，并给出显式放行选项）;
- `security status` 增一行「密钥来源：既有文件 / 本次新建」（区分 `LoadOrCreate` 的两个分支）;
- 说明文字须与 A-1 §P2 的三段告诫口径一致，不得新增第四套说法。

### A2-3 CLI 手册清障（先清障后加章节）

- `docs/80.ops.CLI用户手册-cli-manual.md` 现存 **206 处 U+FFFD** ⇒ **先清障**;
- 清障完成后**再加** `security` 章节（`export` / `status` / `verify` 三命令，含 ACL 与指纹对账语义）;
- 两笔分开提交，清障笔**不含**新增内容（保证「新增 vs 存量」可辨）。

---

## 四、验收判据

1. **A2-1**：在**全新用户路径**（无既有密钥文件）首启建钥后 `icacls` 回读 ⇒ **owner-only 单条目**（无 `(I)` 继承条目），与导出面步 [12] 同形；
2. **A2-1 豁免**：`DEEPBASE_MASTER_KEY_FILE` 指向共享路径时，若跳过 DACL 施加，`security status` 必须**打印豁免事实**（可观测），且门禁旁路扫描 `skip/bypass/insecure/plaintext/DISABLE` **仍 0 命中**;
3. **A2-2**：删除密钥文件后跑 `MigrateLegacyUBS2Secrets` ⇒ **默认拒绝且 EXIT≠0**，错误文案明确「不新建密钥」；显式放行后才建钥且**打印已新建**;
4. **A2-3**：`docs/80.ops.CLI用户手册-cli-manual.md` 清障后 U+FFFD = **0** 且编码门禁 EXIT=0；新增章节另笔提交;
5. **TDD**：三条行为各配负向用例（旧代码下必红）;
6. **证据**：`icacls` 原始输出 / 迁移拒绝实跑 / 手册清障前后计数，全部合规 UTF-8（NUL=0 / U+FFFD=0），**按 H15 原子提交**（`--only` / 显式 pathspec，前后各跑 `git diff --cached --name-only`），并在提交前跑 `--repo` 指主树的 `git -c core.quotePath=false` 证据集复核。

---

## 五、不动的边界

- **不动**导出面既有收敛（步 [12] 已达标）;
- **不动** `Tools/CLI` 的输出语种（A-1 §三.2 已裁定：CLI 全量英文，本单不改语种）;
- **不动**其他 owner 在制品（现场 `Tests/**` 的乙 P1 未提交改动、`docs/规范历史版本与对比库/` 删除态，均**非甲所有**）;
- `Tests/DeepBaseTests.dpr` 写入槽位：**本单不开 R8-P2 窗口**（R8-P2 为独立顺延项，另按主控授予的串行化窗口执行）。

### 五.1 交叉引用：R5-M1 遗留的 build-ownership O1 孤儿（归甲，随本单处理）

`build-ownership` 门禁 O1 报 `Features/DeepBase.Update.Contracts.pas` 为**新增孤儿单元**。

- **主控实测归属**：该文件由 **`1a6807b`（甲 R5-M1 Top20#01 更新验签链加固，2026-09-20）引入，+381 行**；全仓 `*.json/*.yml/*.yaml/*.ps1/*.js` 未搜到任何 build 清单对其的引用；
- **不是乙的问题**（乙 P2 只动 `09_工程脚本/encoding-gate/`，已核 `git status`）；
- **要求**：把该单元登记进对应的 build-ownership / 编译清单（或说明其豁免理由），使 O1 归零。若判定该文件本就不该存在，走删除路径并说明。

> 之所以挂在本单而不另开单：同一 owner（甲）、同一交付批次，且它是 R5-M1 的收尾欠账 —— 避免为一件小事增加单量。

---

## 六、队列

甲：**A2 → R8-P2**（`DeepBaseTests.dpr` 3 个 `uses` + `git rm Tests/TestSecurityM2.dpr`）。A2 交付并验收后开 R8-P2。

---

*主控（沈予安） · 受控锚点 HEAD `f6b7212`*
