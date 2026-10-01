# WO-20261001-MC-主控-CONTRACTGATE 签名抽取假阳性与未登记破坏修复（主控派单 · P1）

**单号**：`WO-20261001-MC-主控-CONTRACTGATE`
**派单**：主控（2026-10-01，甲 `WO-20261001-MC-甲-A16` 收尾派生）
**优先级**：P1
**授权面**：`09_工程脚本/contract-gate/check_contract.js`、`./CHANGELOG.md`
**禁动区**：`Features/DeepBase.Licensing.pas`、`contracts/**`、`Core/**`、`Tests/**`、`noise-baseline.json`
**基线重建留待发版**：`09_工程脚本/contract-gate/signature-baseline.json --emit-baseline` 本单**不执行**（见 §三-4）

---

## 〇、纪律与口径

1. 零信任：判据全部主控亲跑留档，隔离 `--detach` 树优先。
2. 本单两件事：**修门禁假阳性** + **补 CHANGELOG 登记**。两件都必须做，只做一件不验收。
3. 一笔 H15 原子提交，message 带单号，显式 pathspec，选项在 `--` 前，禁 push。
4. 台账状态槽改写权归主控。

---

## 一、现象与归因（主控 2026-10-01 亲跑，证据 `CodeReview/20261001-AUDIT-主控-A16-证据/A16-收尾-contract-gate既存红-eb93e23归因.txt`）

`node 09_工程脚本/contract-gate/check_contract.js --root .` 在 HEAD（`248283b`）EXIT=1：

```
契约门禁失败：扫描 18 单元，stable 破坏性变更 1 项:
  DeepBase.Licensing: 公开签名消失/改写 2 处（须记 CHANGELOG 并重新生成基线）:
      interface uses System.SysUtils, System.JSON, System.Generics.Collections,
        DeepBase.Commerce.Types, DeepBase.Commerce.SafeClient, DeepBase.Commerce.Permissions,
        DeepBase.Commerce.UpgradeFlow, DeepBase.Commerce.JsonUtil, DeepBase.Unlock, DeepBase.TimeGuard
      type TLicensingTier = (ltFree, ltPro)
```

**归因三步（已亲证）**：

| 步 | 树 | 读数 |
|---|---|---|
| 1 | `604d05a`（`eb93e23` 父）干净隔离树 | **EXIT=0**（18 单元 stable 一致；`DeepBase.Manager` 新增 2 / `DeepBase.AutoFix` 新增 1，均只报不拦） |
| 2 | `248283b`（HEAD）干净隔离树 | EXIT=1，同上两条 removal |
| 3 | 主树 `git status --porcelain -- Features/ contracts/ Core/` | 空 ⇒ 非主控改动，红在提交本体内 |

`Features/DeepBase.Licensing.pas` 在 `604d05a..248283b` 区间唯一改动提交 = `eb93e23`
fix(licensing): B7-R09（`WO-20260925-AUDIT-乙-B7`，2026-09-29）。

**为何当时未暴露**：`eb93e23` 提交说明自证「四门（B7-7/B7-11）encoding/eol/mojibake/evidence-encoding
全 EXIT=0」——该集合**不含 contract-gate**。

---

## 二、机制：两条 removal 一真一假

签名差集（`--emit-baseline` 到 `.tmp` 后与已提交基线比对，未动基线）：

- 基线 `generated 2026-09-24T04:15:10Z`（提交 `3127203`，甲 D9 段2），sigs 81 条；当前 83 条。
- **removed 2**：`type TLicensingTier = (ltFree, ltPro)`；旧 interface uses 整行（10 个单元）。
- **added 4**：`function VerifyTimeGuard: TTimeGuardResult`；
  `TLicensingTier = (ltFree, ltPro)`（**无 `type ` 前缀**）；
  新 interface uses 整行（末尾多 `DeepBase.TimeSource`）；
  `type EDeepBaseLicensingTimeUntrusted = class(EDeepBaseCommerceError)`。

### removal 第 1 条 = 假阳性（抽取器分块缺陷）

`check_contract.js`：

```js
132 function stripComments(text) {            // {…} (*…*) //… 全部替换为单个空格
138 function extractInterface(text) {         // stripComments 后取 interface..implementation
146 function signatures(text) {
149   for (let chunk of iface.split(';')) {    // ← 按分号切块
150     const norm = chunk.replace(/\s+/g, ' ').trim();
151     if (norm) set.add(norm);               // ← 每块整体作为一条签名
```

`type` 只是某分块的前缀词，**谁与它同块就归谁**。`eb93e23` 在 type 段首插入带 `///` 注释的
`EDeepBaseLicensingTimeUntrusted` 后，`stripComments` 把注释打成空格，按 `;` 分块时
`type` 被绑进前一片，`TLicensingTier` 那片不再含 `type` 前缀：

- 声文本体一字未改：`TLicensingTier = (ltFree, ltPro)` 仍在，字号内容同一。
- 同一现实被同时计为 1 条 removal + 1 条 addition（added 里那条无前缀）。

⇒ 与「公开声明消失或改写」无关，纯属门禁 bug。**注释位置一变就幻象红的用例应作为回归样本入
`09_工程脚本/contract-gate/test_negative_sample.js`。**

### removal 第 2 条 = 真但向后兼容

`eb93e23` diff 实证：interface uses 末尾 `- DeepBase.TimeGuard;` / `+ DeepBase.TimeGuard,` / `+ DeepBase.TimeSource;`。

公开增补一个同产品内单元的 uses 依赖：无公开声明被删/被改写，按 `:18` 判定口径（新增公开成员只报不拦）
属向后兼容。门禁把「interface uses 整行」当单条签名做**全等**比对，任何 uses 增删都计 removal，
是同一设计缺陷的另一面（uses 行是结构化事实，不该整串全等）。

---

## 三、修法方向（执行方裁后落；两处都要，判据同适用）

1. **`type` 关键字归属**：让 `type` 绑定其**后**第一个声明所属分块，或把 `type`/`const`/`var`/
   `resourcestring` 等段关键字从签名串中剥离后单独记录。修后 `TLicensingTier` 一条不再计 removal。
2. **uses 行**：把 interface uses 集拆为「单元名集合」单独比对（集合差），不走整串全等；
   集合新增只报不拦，集合**减少**才计破坏。
3. **补 CHANGELOG 登记**：`grep -n "GetCorrectedNow|EDeepBaseLicensingTimeUntrusted|TimeGuard|TimeSource|B7|试用" CHANGELOG.md`
   当前**零命中**。`eb93e23` 自述的 Breaking 三条（`GetCorrectedNow` 由「未验证返回裸 Now」改为抛异常；
   未校钟/回拨/重大偏差下试用天数由「照判」改为 0；离线启动由「必抛」改为可正常初始化）
   须记入 `./CHANGELOG.md` 的 `## [Unreleased]`，并在文内标注来源提交 `eb93e23` 与工单
   `WO-20260925-AUDIT-乙-B7`。**这是替乙线补登记，须在回执注明「主控代登记」。**
4. **不重建基线**：`--emit-baseline` 是发版动作，且会在假阳性未修的情况下把门禁发现的问题一并洗掉
   = 掩盖。基线重建留待下次发版，本单只在结论里登记「待发版重建」。

---

## 四、判据（fail-closed，全部主控亲跑留档）

| # | 判据 | 期望 |
|---|---|---|
| 1 | 修后全仓跑 `check_contract.js --root .` | EXIT=0；`DeepBase.Licensing` 无 removal |
| 2 | 注释位移回归样本（负样本） | 「type 段首插入/移除带 `///` 注释的声明」不得产生幻象 removal，样本入 `test_negative_sample.js` 且跑过 |
| 3 | uses 集合差样本 | uses 新增单元 ⇒ 只报不拦；uses 减少 ⇒ 计破坏转红 |
| 4 | 修后 `eb93e23^`（`604d05a`）复跑 | 仍 EXIT=0（不因修抽取器把已绿的搞红） |
| 5 | 反向红线：人为删一个公开声明 | 必须转红（证明门禁仍有牙） |
| 6 | CHANGELOG | B7 三条 Breaking 已登记且标注来源提交与工单；`eol`/`encoding` 门 EXIT=0 |
| 7 | 基线文件 | `signature-baseline.json` 在 `git show --name-only` 里**不出现** |
| 8 | 提交纪律 | 单笔 H15，显式 pathspec，禁 push |

---

## 五、不在本单（已登记）

- `Features/DeepBase.Licensing.pas` 任何改动（禁动区；行为已由乙 B7 修毕）。
- `signature-baseline.json` 重建（发版动作）。
- `contract/consumer-contract.json` 增删单元（另属治理决定）。
- 其他 17 个契约单元的签名面。

---

## 六、执行结论（执行方回填）

（待执行方回执填写：判据 1–8 逐条读数、负样本与反向红线读数、提交哈希、未 push 声明。）
