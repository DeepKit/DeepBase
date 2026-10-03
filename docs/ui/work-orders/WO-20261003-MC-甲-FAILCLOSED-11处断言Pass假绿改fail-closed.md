# WO-20261003-MC-甲-FAILCLOSED 11 处「断言 Pass 假绿」改 fail-closed（主控派单 · P1）

**单号**：`WO-20261003-MC-甲-FAILCLOSED`
**派单**：主控（2026-10-03，`WO-20261003-MC-甲-ORPHANREG` 验收观察项转正）
**优先级**：**P1** —— 这是 ORPHANREG 首轮读数出现 5 处假绿的**直接机制原因**
**前置**：`CodeReview/20261003-AUDIT-甲-ORPHANREG-证据/00-交付总表.md` §四 判据 4 纠偏节

---

## 〇、纪律与口径

1. 一笔 H15 原子提交（或按两个形态分两笔），message 带单号，显式 pathspec，选项在 `--` 前，**禁 push**。
2. 台账状态槽改写权归主控，本单只写回执。
3. **本单只改测试夹具，不改产品代码**。产品侧的问题归各自工单。
4. 改完后必须证明「同一用例在错误环境下由绿转红」，不能只证明「改完之后还是绿」。

---

## 一、问题：两种形态的「跑不到就自动算过」

### 形态 A —— 源码不存在就跳过（**主控实测 11 件**，非开发甲报的 10 件）

```pascal
SourcePath := 'Core\DeepBase.XXX.pas';
if not TFile.Exists(SourcePath) then
begin
  SourcePath := '..\Core\DeepBase.XXX.pas';
  if not TFile.Exists(SourcePath) then
  begin
    Assert.Pass('源文件不可访问，跳过静态分析测试');   // ← 无条件算「过」
    Exit;
  end;
end;
```

**主控核实的 11 件清单**（`rg -l "源文件不可访问" Tests/Regression/`）：

```
Test.Regression.BUG001_AnimationMemoryLeak.pas
Test.Regression.BUG009_LoggingRace.pas
Test.Regression.BUG010_WorkerQueueRace.pas
Test.Regression.BUG034_HardcodedKeys.pas
Test.Regression.BUG054_SemaphoreLeak.pas
Test.Regression.BUG059_JsonDeserializationType.pas
Test.Regression.BUG060_SerializationDepth.pas
Test.Regression.BUG066_PathTraversal.pas
Test.Regression.BUG070_LogInjection.pas
Test.Regression.BUG073_EventTypeInjection.pas
Test.Regression.BUG320_FileWatcherLifecycle.pas   ← 已在主套件里，主套件自身就埋着一颗
```

> 开发甲回执报「10 个」，因为它把 grep 限定在自己的 22 个单里。**实际 11 件**，第 11 件 `BUG320_FileWatcherLifecycle` 是原本就注册在主套件的那 31 个之一。请以本单 11 件为准，并自行复核是否还有第 12 件（含 `Tests/` 其他子目录）。

### 形态 B —— 全局未初始化就跳过

`Test.Regression.BUG007_WhenReadyDeadlock.pas` 每个用例开头：

```pascal
if not DeepBase.Manager.DeepBase.IsInitialized then
begin
  Assert.Pass('DeepBase not initialized, skipping test');
  Exit;
end;
```

⇒ 单独跑 4/4 假绿；与初始化了单例的 fixture 共住即 4 红。

---

## 二、危害（已被实测证实，不是假想）

`WO-20261003-MC-甲-ORPHANREG` 判据 4 首轮把 4 个单误判为「全绿」并据此并入主套件，**引入 4 道新红**。根因就是形态 A：探针的 CWD 是 scratch 目录，`Core\*.pas` 与 `..\Core\*.pas` 都不存在 ⇒ 静态分析用例全部静默 `Assert.Pass`。

⇒ **这不是理论风险，是本周已经真实发生的事故**，而且会再发生。

---

## 三、判据（主控验收用）

| # | 判据 | 达成标准 |
|---|---|---|
| 1 | 11 件逐件处置 | 每件给出「改动前/改动后」代码片段 + 处置方式（`Assert.Fail` / 显式跳过标记 / 删除该用例） |
| 2 | 形态 B 处置 | `BUG007` 的 4 例给出处置；若保留「需初始化」前提，必须让它**显式依赖**初始化 fixture，而不是静默 Pass |
| 3 | **假绿转红实证** | 对形态 A 至少 3 件：在**不存在的 CWD** 下跑改动后的 exe，必须由 `Pass` 变 `Fail`，贴出 DUnitX 输出行 |
| 4 | 形态 A 在正确环境下不得新增红 | `CWD=Tests` 下跑改动后的全部 11 件，与 ORPHANREG 纠偏读数比对，**不得新增红、不得减少 Found** |
| 5 | 主套件不退步 | 全量 `Found/Passed/Failed/Errored` 与改前一致或更好 |
| 6 | 阴性对照 | 造一例「改动写反了」（把 `Assert.Fail` 写回 `Assert.Pass`），证明判据 3 的检查能抓住它 |
| 7 | 全仓清查 | `rg` 扫 `Tests/**` 全目录（不限 `Regression/`）还有没有第三种「无条件 Pass」形态，有就登记并处置 |
| 8 | 四门 + 纪律 | eol/encoding/mojibake/evidence-encoding 全 EXIT=0；禁 push；台账状态槽不改 |

---

## 四、授权面与禁动区

**授权**：`Tests/**`（含 `Tests/DeepBaseTests.dpr` 之外的全部测试夹具）、`CodeReview/20261003-AUDIT-甲-FAILCLOSED-证据/**`。

**禁动**：`Core/**`、`contracts/**`、`Features/**`、`09_工程脚本/**`、`Scripts/**`、`noise-baseline.json`、`Governance/**`、`VCL/**`、`FMX/**`、`Tests/DeepBaseTests.dpr`。

**明令禁止**：
- 用「删掉这些静态分析用例」来省事 —— 除非逐件说明该用例已无意义
- 把 `Assert.Pass` 换成 `Assert.Ignore` 就宣称完成（要证明它真的会在缺文件时红）
- 顺手修 `Tests/Regression/RegressionTestRegistry.pas` 死注册表（不在本单）

---

## 五、不在本单

1. 7 处断言与产品现状分歧（R1–R7）—— 归 `WO-20261003-MC-甲-ORPHANRED`。
2. `Examples/Templates/README.md` 失效引用 —— 归 `WO-20261003-MC-甲-TPLBOOTDOC`。
3. HB Gate #6 句柄泄漏断言 —— 归 `WO-20261003-MC-甲-HBGATE6`。
4. `RegressionTestRegistry.pas` 死注册表是否接门禁 —— 另议。
