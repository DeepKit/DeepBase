
---

## 工单点名 39 单元补审（乙 · 本单产物，不改 20260918 分包正文，H5）

口径：单元全文/关键路径实读 + 机检旗标（`乙-B2-uncovered-probe.txt`：LOC、类、线程/锁/finalization/DB/HTTP 旗标、create-vs-WaitFor 配对）。结论三值：`已审无发现` / `有发现(登记)` / `编码残留(B1已登记)`。

| 单元 | 补审结论 | 依据 |
|---|---|---|
| DeepBase.HB.NavTree.Types | 已审无发现 | 48L 纯类型/record 定义，零资源旗标；HB 域按 H2 只审不改 |
| DeepBase.HB.PageControl.Types | 已审无发现 | 54L 同上 |
| DeepBase.HB.Tray.Types | 已审无发现 | 70L 同上 |
| DeepBase.Manager.Operational | 已审无发现 | 229L 状态门面，0 线程/锁旗标，1×except 有兜底 |
| DeepBase.SchemaAdapter.Types | 已审无发现 | 88L 接口+映射 record（TMapResult:TInterfacedObject） |
| DeepBase.Browser.AutomationAdapter | 已审无发现 | 154L 适配器薄层，转接到 IBrowserAutomationSession |
| DeepBase.Browser.Events | 已审无发现 | 103L 事件定义单元 |
| DeepBase.Browser.Recorder | 有发现(登记) | 470L；`finalization` 段释放全局 recorder 锁（466 行起）且 manager 用 Interlocked×5——与 T3-③"锁/单例在 finalization 释放而无 DCLP 屏障"同族，登记，不属本单 B4 改造点清单 |
| DeepBase.Browser.Registry | 已审无发现 | 342L；TMonitor 9 对 Enter/Leave 配平，class destructor 释放 |
| DeepBase.Browser.ScriptStore | 已审无发现 | 569L；FLock/GScriptStoreLock Enter/Leave 全配对（抽查 462-555 逐对成文），SQLite 路径有 except 兜底 |
| DeepBase.DataPlatform.Bootstrap | 已审无发现 | 105L 装配薄层 |
| DeepBase.Desktop.Perception.ColorMatch | 已审无发现 | 433L 纯像素计算，无共享状态 |
| DeepBase.Desktop.Perception.LLMProvider | 已审无发现 | 264L；FLock 223/237 配对 |
| DeepBase.Desktop.Perception.Types | 已审无发现 | 247L 类型+TPerceptionCache（CritSec 2 配对） |
| DeepBase.Inference.Types | 已审无发现 | 271L 异常/类型层级定义 |
| DeepBase.IntentClarification.Anticipation | 已审无发现 | 273L；CritSec 2 配对 |
| DeepBase.IntentClarification.Budget | 已审无发现 | 94L 纯计数逻辑 |
| DeepBase.IntentClarification.Degradation | 已审无发现 | 85L 策略函数 |
| DeepBase.IntentClarification.Exit | 已审无发现 | 104L 退出处理，无线程旗标 |
| DeepBase.IntentClarification.Logging | 已审无发现 | 27L 日志别名层 |
| DeepBase.IntentClarification.Moments | 已审无发现 | 107L 生成器 |
| DeepBase.IntentClarification.OptionFrame | 已审无发现 | 220L 构造器，无共享状态 |
| DeepBase.IntentClarification.Provider.L0 | 已审无发现 | 93L |
| DeepBase.IntentClarification.Provider.L1 | 已审无发现 | 170L |
| DeepBase.IntentClarification.Provider.L2 | 已审无发现 | 348L；CritSec 2 配对 |
| DeepBase.IntentClarification.Provider.L3 | 已审无发现 | 340L；CritSec 2 配对 |
| DeepBase.IntentClarification.Provider.L4 | 已审无发现 | 393L |
| DeepBase.IntentClarification.Rapport | 已审无发现 | 191L；CritSec 2 配对，create-vs-WaitFor 全 0（无自研线程） |
| DeepBase.IntentClarification.Registration | 已审无发现 | 108L 注册表 |
| DeepBase.IntentClarification.Router | 已审无发现 | 282L 路由决策，无资源旗标 |
| DeepBase.LLM.Client | 编码残留(B1已登记) | 104L 门面；3 处 U+FFFD 在损坏后被编辑的注释行（B1 档C/H6 保留，已入 CI 基线），逻辑无发现 |
| DeepBase.LLM.Config | 已审无发现 | 790L TLLMConfigStore，DB 访问有 except 兜底，无自研线程 |
| DeepBase.LLM.ConfigBridge | 已审无发现 | 58L 桥接薄层 |
| DeepBase.LLM.HTTP | 编码残留(B1已登记)+已审无发现 | 763L TLLMHttpClient；2 处 U+FFFD 在头注释（B1 登记），HTTP 生命周期无发现 |
| DeepBase.LLM.Providers | 已审无发现 | 263L 工厂注册 |
| DeepBase.LLM.Proxy | 有发现(登记) | 668L；`TThread.CreateAnonymousThread` 1 + `TThread.ForceQueue(nil, AOnResult/AOnError…)` 3（616-622 行）：闭包捕获调用方回调，宿主销毁后排队回调可触达已释放 owner；无 create-vs-WaitFor 配对（waitFor:0）——与 T3-②同族，列为 B4 `TManagedWorker` 模式的后续迁移候选（不在本单 B4 点名清单内，不擅自扩界） |
| DeepBase.LLM.Service | 有发现(登记) | 916L；`GLLMLock` 全局 TMonitor 且 `finalization`（905 行）释放，DCLP 无屏障 = T3-③原型；ForceQueue×3 同 Proxy 问题。登记；本单 B4 点名清单不含该文件，列为后续迁移候选 |
| DeepBase.LLM.Types | 已审无发现 | 575L 类型/异常定义 |
| DeepBase.Speech.Types | 已审无发现 | 373L 类型定义 |

**计数**：39 单元 = 已审无发现 33 + 编码残留已登记 2（LLM.Client / LLM.HTTP，逻辑亦无发现）+ 有发现登记 4（Browser.Recorder、LLM.Proxy、LLM.Service；Recorder 与 Service 为 finalization/锁屏障同族，Proxy/Service 含回调捕获）。发现项均与总报告 T3 既有模式同族，未产生新模式；不在 B4 点名清单内的迁移候选已标注"不擅自扩界"。

## 工单外未审 119 单元（VCL/FMX/Governance/Tools/DeepFlow）——组级补审 + 分包覆盖缺口报告

主控 39 未点名口径只覆盖 Core+Features 两目录；按 565 生产目录全集对账后，VCL/FMX/Tools/Governance/DeepFlow 存在**系统性分包覆盖缺口**（`20260918-VCL.md` 仅 22KB 对 72 单元；`20260918-FMX-DeepFlow.md` 35KB 对 55 单元；`20260918-Governance-Tools.md` 123KB 对 109 单元但 Tools 的 Studio/Tray/UniPublisher/Gallery dpr 附属单元基本未点名）。此缺口本身是本审计的交付发现，归口报告更正线（甲 A2/主控），乙不修改分包正文（H5）。

组级机检结论（create-vs-WaitFor / 旗标全表见 `乙-B2-uncovered-probe.txt`）：

| 组 | 单元数 | 机检结论 |
|---|---|---|
| VCL DeepShell 族（Commands/Context/Intf/Layout/Localization/MainForm/Panels/Recent/Services/Settings/Theme/ToolWindow/Types） | 14 | 实际 `TThread.Create` 为 0（旗标多为接口签名/类型引用）；TMonitor 配对抽查正常；`TThread.Queue` 回调 5 处属 T3-②同族风险面。无新缺陷模式 |
| VCL LLMSettingsFrame | 1 | **create:3 / waitFor:0** —— T3-①原型（宿主销毁不 WaitFor），与 B4 模式一致，列为迁移候选（非本单点名清单） |
| VCL 其余（HB.* 控件族/AboutFrame/AutoUpdater/LogListView/NotificationBar 等） | 33 | UI 控件+Timer 为主，Destroy 均存在；AutoUpdater 仅 ForceQueue 无自建线程。无新缺陷模式 |
| FMX 全部（含 HB.* 族、ListView/Theme/Hotkeys 等） | 26 | 纯 FMX 控件/框架层，无自建线程；FMX.HB.* 与 Core HB.*.Types 同属 H2 域只审不改；LLMConfigPanel 的 10 处 FFFD 为 B1 档C 已登记 |
| Governance 全部 | 21 | 注册表/模型/桥接类，CritSec 配对抽查（ProposalQueue 3 对）正常；RouteStore.SQLite 有 Destroy。无新缺陷模式；该域为甲独占整改线（bomExceptions 47 文件），乙只审不改 |
| Tools Studio/Tray/UniPublisher/Gallery/LogAnalyzer/CLI/WebService | 23 | 独立 dpr 工具的表单/命令层（本单口径列为"非构建资产候选"，见构建归属清单）；Publisher.Config 有 HTTP×1+Except；无自建线程新模式 |
| DeepFlow.Chronicler | 1 | 668L；FLogLock Enter/Leave 6 对配平，Destroy 存在。无新缺陷模式 |

**209 个"已审·宽松匹配"单元说明**：名称在分包正文（多为逐单元清单表/统计表）出现但无独立缺陷条目，状态列已标注；其风险面由分包"逐单元全文精读"声明（如 Core-B §"1. 逐单元全文精读"列出的清单）覆盖，不重复补审；如主控认为需二次抽样，可用本表 `条目编号` 列反查。
