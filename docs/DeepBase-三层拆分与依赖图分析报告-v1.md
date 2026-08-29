# DeepBase 三层架构拆分与依赖图分析报告 (v1.0)

> 日期: 2026-08-29  
> 执笔: 架构治理组 (甲/乙)  
> 目标仓库: DeepBase (D:\_Progs\02Business\DeepBase)  
> 对应工单: WO-20260828-0222-甲

---

## 1. 架构三层拆分定义与职责边界

为了彻底解决闭源护城河技术保护与开源生态推广之间的结构性矛盾，DeepBase 实行清晰的三层架构物理隔离与双轨许可治理：

`
+-------------------------------------------------------------------------------+
| Layer 3: 护城河核心资产 (BSL 1.1 - 源码可用 / 商业转售受限)                     |
|  - AutoFix 智能自愈引擎 (Core/DeepBase.AutoFix*.pas, FMX/DeepBase.AutoFix*.pas)|
|  - Browser 自动化与爬虫内核 (Features/DeepBase.Browser.*.pas)                  |
|  - Governance 治理内核 (Governance/DeepBase.Governance.*.pas)                 |
+-------------------------------------------------------------------------------+
                                      |
                                      | 插件注册 / 接口契约
                                      v
+-------------------------------------------------------------------------------+
| Layer 2: 现代桌面 & HB UI 框架 (Apache-2.0 - 自由开源)                          |
|  - HB Design Token 系统 (DeepBase.HB.Core.pas, DeepBase.HB.*.Types.pas)       |
|  - VCL HB 现代组件库 (DeepBase.VCL.HB.Controls / Cards / Dialogs / Voice / Tray)|
|  - FMX HB 跨平台组件库 (DeepBase.FMX.HB.*)                                    |
|  - 终端模拟器 (DeepBase.VCL.HB.Terminal.pas)                                   |
|  - 社交与第三方开放平台集成 (DeepBase.Social.*)                                 |
+-------------------------------------------------------------------------------+
                                      |
                                      | 单向底层依赖
                                      v
+-------------------------------------------------------------------------------+
| Layer 1: 核心基础底座 (Apache-2.0 - 自由开源)                                   |
|  - 配置中心 (DeepBase.Config.*), 结构化日志 (DeepBase.Logger.*)               |
|  - 基础类型体系、高性能 Hash、JSON / YAML 编解码、国际化 i18n                   |
|  - doQry 客户端协议桩 (Persistence/DeepBase.Persistence.DoQry.Client.pas)     |
|  - 跨平台加密安全套件 (DeepBase.RSA, DeepBase.Crypto.*)                       |
+-------------------------------------------------------------------------------+
`

---

## 2. 模块拓扑与依赖流向审计

### 2.1 依赖单向性规则
1. **L1 无外部上层依赖**：Core/ 与 Persistence/ 仅依赖 Delphi RTL 与 OS 底层 API，**0 项**对 L2 或 L3 的引用。
2. **L2 仅依赖 L1**：VCL/ 与 FMX/ 仅依赖 Core/、Persistence/ 和 VCL/FMX 框架，**0 项**对 L3 护城河源码的硬引用。
3. **L3 面向接口注入**：L3 的 AutoFix、Browser、Governance 均作为可插拔插件或独立包存在，对宿主系统提供透明无缝加速，且不污染开源下游项目。

### 2.2 模块物理清单与许可证映射

| 层次 | 路径与包名 | 主要单元 / 职能 | 许可证 | 依赖范围 |
| :--- | :--- | :--- | :--- | :--- |
| **L1** | Core/DeepBase.Core.*.pas<br>Persistence/DeepBase.Persistence.*.pas | Config, Logger, Hash, Json, Yaml, DoQryClient | **Apache-2.0** | Delphi RTL |
| **L2** | VCL/DeepBase.VCL.HB.*.pas<br>FMX/DeepBase.FMX.HB.*.pas<br>Features/DeepBase.Speech.*.pas | HB Controls, Cards, Dialogs, Voice, Tray, Grid, VirtualList | **Apache-2.0** | L1 + VCL/FMX |
| **L3** | Core/DeepBase.AutoFix*.pas<br>Features/DeepBase.Browser.*.pas<br>Governance/DeepBase.Governance.*.pas | AutoFix Engine, Web Scraping Kernel, Governance Engine | **BSL 1.1** | L1 + L2 |

---

## 3. 插件注入与 Fail-Open (开箱兜底) 机制验证

### 3.1 接口抽象与解耦设计
系统在 L1/L2 定义了轻量级护城河接口：
* IAutoFixEngine / IAutoFixProvider
* IBrowserAutomationEngine
* IGovernancePolicyEngine

### 3.2 运行时 Fail-Open 行为
当未引入或未加载 L3 BSL 插件时：
1. **编译期**：下游开源项目（如 DeepSpec、第三方桌面客户端）在没有任何 L3 文件的情况下，dcc64.exe 编译 **0 Error / 0 Warning**。
2. **运行期**：框架检测到未注册 L3 实现时，自动激活 TDefaultNullAutoFixEngine / TFailOpenPolicyHandler：
   * 不阻断任何正常业务操作；
   * 对自愈或高级审查输出友好的轻量提示；
   * 彻底避免了“无商业包即崩溃”的设计缺陷。

---

## 4. 结论与交付合规性

DeepBase 经过三层拆分与 BSL 1.1 许可落地后：
1. **开源纯净度**：L1 与 L2 成为标准的 Apache-2.0 工业级 Delphi 开源基础设施，消除了下游开源使用者的合规顾虑；
2. **护城河安全性**：核心算法与自愈引擎通过 BSL 1.1 实现合法保护，阻断竞品抄袭与转售；
3. **架构稳健性**：分层依赖清晰，物理单向流转，具备完备的 Fail-Open 韧性。
