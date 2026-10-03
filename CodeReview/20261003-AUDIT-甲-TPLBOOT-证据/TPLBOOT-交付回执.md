# WO-20261003-MC-甲-TPLBOOT 交付回执（开发甲 · 2026-10-03）

**单号**：WO-20261003-MC-甲-TPLBOOT
**结论**：处置选 **(B) 删除** `Examples/Templates/Common/Template.AutoUpdateBootstrap.pas`。四门 after-state 全 EXIT=0；`09_工程脚本/**` 零改动；单笔 H15 提交；未 push。
**核心更正**：F10「还原清单与 HEAD 已漂移」**不成立**——还原已落盘、行号无漂移（详见 §二）；同时实测 encoding-gate G6 对本文件当前命中 **0 行**，而 baseline 记 2，门禁现状恒绿是因为存量高估，不是因为没人看。

---

## 一、F1–F10 复算（亲读/亲跑）

| # | 复算结论 | 证据 |
|---|---|---|
| F1 | **成立** | `VCL/DeepBase.VCL.AutoUpdater.pas:22` `TAutoUpdater = class(TComponent)`；模板 `:29` `GAutoUpdater: TAutoUpdater` |
| F2 | **成立** | 同文件 `:41-48` published 仅 3 属性：UpdateUrl(:43)/CurrentVersion(:45)/AutoCheck(:47) |
| F3 | **成立** | 模板 `:45-50` 六条赋值在 `TAutoUpdater` 上均不存在 |
| F4 | **部分不成立（须订正）** | 6 个名字中 **2 个在 FMX 类有属性定义**：`Channel`、`ShowDialogOnUpdate` 定义于 `FMX/DeepBase.FMX.AutoUpdater.pas:108,117` 的 `TDeepBaseFMXAutoUpdater`（另一个类）；另 4 个（EnablePolicyDrivenSilentUpdate / SilentInstallPollIntervalMs / AutoTriggerExitInstall / SilentInstallMainExePath）全仓零定义。`Features/DeepBase.AutoUpdate.pas:30` 确为 JSON 样例 `"channel": "stable"`（小写、文档注释），非属性——假阳性确认。结论修正表述：**「6 个引用对 VCL 的 TAutoUpdater 全部无效；其中 2 个名字在 FMX 类上存在、4 个全仓不存在」** |
| F5 | **成立且被超出** | 真实编译错误 **8 处非 6 处**（见 §三）：6 属性 E2003 + `ucStable` E2003(:45) + `E2029`(:63)。任何 uses 本单元的工程必红 |
| F6 | **基本成立，漏 1 处** | `git grep -rln "Template.AutoUpdateBootstrap"`：2 处 gate 基线 + 若干 CodeReview 审计件 + 工单文档 + **`Examples/Templates/README.md:4,7-11`（主控清单未列）**。零代码消费：`StartTemplateAutoUpdate`/`StopTemplateAutoUpdate` 全仓零调用；三个模板 dpr 均不 uses 本单元——README「已默认接入」声称**本身不成立** |
| F7 | **部分不成立（须订正）** | ca3364e（`refactor: rename UniBase -> DeepBase`，确为 HEAD 祖先）内容确为可读中文（「为模板工程提供统一的自动更新初始化入口」「默认启用 DeepBase 2026-05 的策略化静默更新编排」），但**不是干净祖先**：该版本自带 7 处不可恢复损伤（按 ASCII `?` 收尾）：入口后、编排后、安装窗口后、约定/下游可、Settings 中配、App.Version 后、一次检查后——与 HEAD 现存 `?` 占位一一对应。即损坏早于 ca3364e |
| F8 | **成立** | HEAD 肉眼乱码行：L5（部分：行首约 39 字符为 GBK 误读串，同行后半已是有效中文）、L7（整行）、L52（乱码与有效中文混排）；L58 已还原、仅缺 2 字符占位 |
| F9 | **成立** | `pas_encoding_baseline.json` mojibake 记本文件 2 行；`还原清单.md:27-29` 记 L6[G1] 现＝`- 后台轮询安装窗口`、L58[G2a] 现＝`- 运行时创建的组件不会触发 Loaded；手动异步触发一次检查?…`（自注缺 2 字符） |
| F10 | **不成立（本单核心，见 §二）** | 还原已落盘，行号无漂移 |

## 二、F10 漂移核定（零「待定」）

1. **HEAD 实际 mojibake 行数（肉眼）＝ 3 行**：L5（部分）、L7（整行）、L52（混排）；L58 已还原。全文件 71 个物理行（`\n` 切分，无 CR、无 NEL/LS/PS、无其他控制符，BOM 在行首）。
2. **encoding-gate 行计数规则**（`check_pas_encoding.js:199-209`）：`buf.toString('utf8').split(/\r\n|\r|\n/)` 按物理行；G6 命中需同时满足：① 行含 CJK 表意文字 ② 整行逐字符可查 GBK 反表 ③ **重组字节整体**是合法 UTF-8 ④ 还原文本含 CJK。四条件缺一不可。
3. **与 baseline `2` 的关系**：隔离根 + 真门禁 + 归零基线实测（`_probe_baseline_zero.json`），HEAD 本文件 **G6 命中 0 行，EXIT=0**。原因：L5/L7/L52 三条乱码行都因「部分还原把有效中文插回乱码行」，整行 GBK 重组字节不再合法（判据③断），连已还原的 L58 同样不可逆——**乱码肉眼可见、G6 检测不到**。baseline 的 `2` 来自更早的全量扫描，相对现状是高估；现状 0 ≤ 2 恒绿。
4. **漂移结论**：按 `\n` 行号，HEAD L6 就是 `- 后台轮询安装窗口`、L58 就是清单所记「现」文本（含 `?`）——**还原清单 L6/L58 与 HEAD 逐字对得上，还原已落盘，行号未漂移**。主控 F10 的 off-by-one 来自 L5：它是一条物理长行（乱码前缀 + `默认启用 DeepBase 2026-05 的策略化静默更新编排` + `- onExit/whenIdle staged 下载` 同行结尾），把同行尾部的 `- onExit/whenIdle staged 下载` 记成「第 6 行」即整体错位一行。工具链无第二套行号（Read 与字节级切分一致，无嵌入行分隔符）。
5. 附带实证（`f10-g6-debug-output.sanitized.txt`）：阳性对照（纯乱码行，程序构造）四判据全过、还原为正常中文；阴性对照（正常中文行、L6 已还原行）判据③断、不误报。

## 三、F5 坐实（隔离树真实编译，非推断）

隔离 `git worktree`（`D:/_ProgData/DeepBase-TPLBOOT-wt`，干净 HEAD 检出，规避主树 46679 陈旧 .dcu）。最小工程 `TPLBOOTProbe.dpr` 仅 `uses Template.AutoUpdateBootstrap;`，dcc64 37.0，-U 含 Core/Features/VCL/FMX/Persistence/Governance/doQry/ThirdParty/DeepFlow.Source + BDS Win64 release。

**F5-head（HEAD 原件）BUILD_EXIT=1**，真实错误全文见 `_probe_out/F5-head/compile.log`：

```
Template.AutoUpdateBootstrap.pas(45) Error: E2003 Undeclared identifier: 'Channel'
Template.AutoUpdateBootstrap.pas(45) Error: E2003 Undeclared identifier: 'ucStable'
Template.AutoUpdateBootstrap.pas(46) Error: E2003 Undeclared identifier: 'ShowDialogOnUpdate'
Template.AutoUpdateBootstrap.pas(47) Error: E2003 Undeclared identifier: 'EnablePolicyDrivenSilentUpdate'
Template.AutoUpdateBootstrap.pas(48) Error: E2003 Undeclared identifier: 'SilentInstallPollIntervalMs'
Template.AutoUpdateBootstrap.pas(49) Error: E2003 Undeclared identifier: 'AutoTriggerExitInstall'
Template.AutoUpdateBootstrap.pas(50) Error: E2003 Undeclared identifier: 'SilentInstallMainExePath'
Template.AutoUpdateBootstrap.pas(63) Error: E2029 'END' expected but ')' found
TPLBOOTProbe.dpr(7) Fatal: F2063 Could not compile used unit 'Template.AutoUpdateBootstrap.pas'
```

E2029 根因（F3/F5 均未数到的第八处）：L58 是一行注释 `// 运行时创建的组件不会触发 Loaded；手动异步触发一次检查?  TThread.ForceQueue(nil,`——`//` 把 `TThread.ForceQueue(nil,` 调用本身吞进注释，导致 L59-63 的 `procedure…begin…end);` 成为无宿主调用的裸匿名方法。该结构在 ca3364e 已存在（非本次还原引入）。

**F5-fixed（仅替换 L44-50 六行为合法赋值 + 原位拆开 L58 注释）BUILD_EXIT=0、exe 生成**——证明上述 8 处即全部编译阻断面，单元其余部分（DeepBase.Manager / DeepBase.Updater / DeepBase.VCL.AutoUpdater 依赖链）可正常编译。

## 四、处置：选 (B) 删除

理由（独立取证后与主控倾向一致，非照抄）：

1. **零消费方**（F6 复算 + 零过程调用 + README「已默认接入」本身虚假）。
2. **HEAD 不可编译且伤及语法层**（8 处硬错，含 E2029），「无人 uses」只是掩盖。
3. **(A) 的代价不可接受**：6 个名字里 4 个在全仓**没有任何实现**（无字段、无引擎、无编排逻辑），给生产组件 `TAutoUpdater` 补 4 个空壳 published 属性 = 为客户端口面扩张假 API；另 2 个（Channel/ShowDialogOnUpdate）属于另一个类（FMX 的 `TDeepBaseFMXAutoUpdater`），本样例把 VCL/FMX 两套 Updater 混为一谈，本就无修复意图可依。为一个没人用的样例扩张 `VCL/**` 公开 API 面，违反「最简实现」。
4. **无干净祖先可恢复**（F7）：ca3364e 自带 7 处不可恢复损伤；README 文档自身亦带乱码且声称虚假。恢复＝凭想象重写一个虚构样例。
5. 按「过时的直接删」，删除后 gate 基线条目自然休眠（已实证：四门 after-state 全绿）。

**对 WO-20260922-AUDIT-甲-A3 的影响（登记不自行处理）**：A3（Examples/ 域乱码还原）文件数 **-1**；本文件移出 A3 范围，其余文件不受影响；`还原清单.md:27-29` 该条目随对象删除作废（其 L6/L58 文字记录本身无误，但指向的文件已不存在）。

**gate 基线条目（登记上报，零擅动）**：
- `09_工程脚本/encoding-gate/pas_encoding_baseline.json` mojibake 本文件 `2` → 变休眠条目（门禁只遍历现存文件；`gate-baseline.js` T1-T4 不校验条目存在性，不会因此不可信）。**不适用「实际好于基线」上报收紧**——它本就是存量豁免高估（实测 0），是否清理由主控定。
- `09_工程脚本/eol-gate/eol_baseline.json` `pas_lf_exceptions` 本文件条目 → 同上，休眠待清。
- `pb_baseline.json` 无本文件条目（已核，17 件均不含）。

## 五、阴性对照（各造一例，全部按预期红）

| 对照 | 造法 | 结果 |
|---|---|---|
| NC1 写错属性名 | F5-fixed 的 `UpdateUrl`→`UpdateUrll` | BUILD_EXIT=1，`(45)/(50) E2003 Undeclared identifier: 'UpdateUrll'` |
| NC2 漏 uses 一行 | F5-fixed 删 implementation uses 的 `DeepBase.VCL.AutoUpdater` | BUILD_EXIT=1，含 `(42) E2003 Undeclared identifier: 'TAutoUpdater'` |
| NC3a 乱码行（纯） | L6 换成程序构造的纯双重编码行（「日志导出」UTF-8 字节 GBK 误读，与 gate 文档样本同源） | encoding-gate EXIT=1：`G6 双重编码乱码 1 行 > 基线 0`，样例行可还原为正常中文 |
| NC3b 补错一个字符 | L6 中一字替换为 U+FFFD | encoding-gate EXIT=1：`G1 U+FFFD 1 > 基线 0` |

（NC3 均跑真门禁 + 隔离 root + 归零基线副本；输出见 `nc3-gate-probes-output.sanitized.txt`）

## 六、四门与交付纪律

| 门禁 | 处置前 EXIT | 处置后 EXIT |
|---|---|---|
| eol-gate | 0 | 0（1687→1686 文件） |
| encoding-gate | 0 | 0（1017→1016 .pas） |
| mojibake-gate | 0 | 0（丙-B 0 命中） |
| evidence-encoding-gate | 0 | 0 |

- `git diff --stat -- 09_工程脚本/`：工作区与暂存区**均为空**（禁动区零改动）。
- 单笔 H15 提交（message 带单号、显式 pathspec、选项在 `--` 前）；未 push。
- 证据件全部 LF/UTF-8；含乱码样本的输出日志已净化为非 ASCII 零残留（`sanitize-log.js`），避免证据件自身触发 evidence-encoding-gate E3。

## 七、需主控决定（4 项）

1. 两条休眠基线条目（`pas_encoding_baseline.json` mojibake `2`、`eol_baseline.json` pas_lf_exceptions）何时清理、由谁清理——本单只登记。
2. `Examples/Templates/README.md:4,7-11` 对本文件的引用与「已默认接入」虚假声称已随删除失效（该文件不在本单授权面，未动）——建议派单修订。
3. `CodeReview/20260924-AUDIT-主控-乱码还原/还原清单.md:27-29` 条目作废登记（A3 范围）。
4. 主控记录三处订正：F4（2/6 在 FMX 类有定义）、F5（8 处错非 6）、F7（ca3364e 非干净祖先）、F10（还原已落盘、无漂移，G6 实测 0 命中）。

## 八、留档索引（本目录）

- `f10-line-drift-probe.py` / `f10-deepdive.py` / `f10-ca3364e-probe.py`：行号与编码取证脚本
- `f10-g6-line-count.js` / `f10-g6-debug.js` / `f10-g6-debug-output.sanitized.txt`：G6 行计数规则同源复算
- `TPLBOOTProbe.dpr.template` / `gen-probes.py` / `run-compile-probes.sh`：编译探针（H15 纪律：可复跑）
- `_probe_out/{F5-head,F5-fixed,NC1-typo,NC2-missing-uses}/{compile.log,TPLBOOTProbe.dpr}`：四用例真实编译日志
- `nc3-gate-probes.js` / `nc3-gate-probes-output.sanitized.txt`：门禁阴性对照
- `_probe_baseline_zero.json`：归零基线副本（**非真基线**，真基线零改动）
- `_probe_out/gates-{before,after}/*.log`：四门处置前后实录
- `sanitize-log.js`：证据日志净化工具
