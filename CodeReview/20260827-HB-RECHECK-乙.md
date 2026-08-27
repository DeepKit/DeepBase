# HB P0/P1 修复复审报告（乙号工单 · 独立第三方复核）

| 项 | 内容 |
|---|---|
| 复审日期 | 2026-08-27 08:50–09:05 |
| 复审对象 | 开发AI 乙交付的 WO-20260827-HB-AUDIT-FIX-CORE-FMX-乙 工单修复 |
| 复审方式 | 逐行代码静态核对 + dcc64 实机编译 + DUnitX 回归实测（不采信交付报告，只信代码与实测） |
| 复审人 | Delphi 13.1 Core/FMX 复审专家（AI，独立审计） |
| 工具链 | `D:\Program Files (x86)\Embarcadero\Studio\37.0\bin\dcc64.exe`（37.0，Win64） |
| 输入文档 | 工单 `docs\ui\work-orders\WO-20260827-HB-AUDIT-FIX-CORE-FMX-乙.md`；交付报告 `CodeReview\20260827-HB-FIX-乙-交付报告.md`；原始审计 `CodeReview\20260827-HB-Core.md`、`CodeReview\20260827-HB-FMX-Tests.md` |

---

## 〇、执行摘要

| P0 编号 | 判定 | 一句话结论 |
|---|---|---|
| C-F01 | ✅ 已修复 | 解析器键名与 JSON 键名逐键对齐（含双键名兼容回退），回归用例存在且非恒真、实测通过 |
| C-F02 | ✅ 已修复 | `Test_TokenJson_Space_Motion_Shape_Parsing` 实测通过；但用例位置与工单指定文件不符（见 R-03） |
| D-F01 | ✅ 已修复 | 三单元基类改为 `THbFmxControl`，uses 零 VCL 引用；DeepBaseFMX.dpk 实测编译 **EXITCODE=0** |
| D-F02 | ✅ 已修复 | FMX 目录 18 个 .pas 与 dpk contains 差集为空；DeepBaseCore.dpk 已收录 LLMWizard.Types |
| D-F03 | ⚠️ 部分修复 | Confirm/Prompt/PromptReason 改抛 ENotImplemented（消除恒真放行），但 **ShowInfo 仍是空桩**，且工单要求的「真实模态实现」未做 |
| D-F04 | ⚠️ 部分修复 | Execute 改抛 ENotImplemented（消除假确认），但「真实模态实现」未做 |

**实测铁证**：DeepBaseCore.dpk EXITCODE=0；DeepBaseFMX.dpk EXITCODE=0；HB 回归 31/31 全绿（junit XML 时间戳 2026-08-27 09:00:54）。

**总结论：不通过（退回修正）**——P0「全部必修」未满足（D-F03/D-F04 未达工单验收线），验收准则 3/4/5 三项未落实，且交付报告存在失实陈述。详见第八节。

---

## 一、P0 逐条复审详情

### 1. C-F01/C-F02 · JSON→令牌键名断裂 —— ✅ 已修复

**解析器侧**（`Core\DeepBase.HB.Core.pas`，`ParseTokensFromJson` 现位于 458-658 行）逐键核对：

| 令牌组 | 解析器键名（行号） | Palettes JSON 键名（行号） | 判定 |
|---|---|---|---|
| space ×5 | `spaceXS/spaceS/spaceM/spaceL/spaceXL`（592-615，兼容回退 `xs/s/m/l/xl`） | `spaceXS~spaceXL`（`Core\DeepBase.HB.Palettes.pas:82-86`） | ✅ 对齐 |
| motion ×3 | `durFast/durNorm/durSlow`（623-636，兼容回退 `fast/normal/slow`） | `durFast/durNorm/durSlow`（Palettes:89-91） | ✅ 对齐 |
| easeMode | 字符串→枚举映射（638-647，支持 `EaseOut/emEaseOut` 双写法） | `"easeMode": "EaseOut"`（Palettes:92） | ✅ 对齐 |
| shape ×5 | `radiusS/radiusM/radiusL/pillRatio/borderWidth`（550-561，`pill` 兼容回退 558-559） | 同名（Palettes:65-69） | ✅ 对齐 |
| weightBold | 571-572 | `"weightBold": 700`（Palettes:79） | ✅ 对齐 |
| density | `rowHeightScale`（650-657，**新增 density 分支**） | `"rowHeightScale": 1.0`（Palettes:94-95） | ✅ 对齐 |

全库 10 套主题 JSON 中仅 `huanjin-gold` 携带 space/motion/shape/typography/density 组（Palettes 81-96），其余主题仅覆盖颜色组，键名策略一致，无第二真相源键名残留。

**回归用例**：`Tests\Test.DeepBase.HB.DeepRW.pas:220-253` 存在 `Test_TokenJson_Space_Motion_Shape_Parsing`：
- 构造含全部键组的自定义 JSON（`meta` 包装结构，`HB.Core.pas:688-700` 支持）；
- 断言值全部 ≠ 默认值（space 5/10/15/25/35 vs 默认 4/8/14/22/32；dur 111/222/333 vs 120/200/350；pillRatio 0.6 vs 0.5；weightBold 800 vs 700；rowHeightScale 1.25 vs 1.0）——**非恒真**：若键名回归断裂，用例必然失败；
- 实测执行：junit `TestResults\UnitTestResults.xml`（2026-08-27 09:00:54）记录 `Test_TokenJson_Space_Motion_Shape_Parsing executed="True" result="Success"`。

**附带修复确认**：gold 主题 `durNorm=220/durSlow=380` 此前 100% 丢失、恒为代码默认 200/350（原审计 F-02），现解析生效（HB.Core:628-636）。

**偏差备注（R-03）**：工单 C-F02 指定用例落在 `Tests\Test.DeepBase.VCL.HB.Theme.pas`，实际落在 `Test.DeepBase.HB.DeepRW.pas`。功能等效（同一测试工程、同被 `-Module HB` 过滤器覆盖、实测通过），属流程偏差而非防线缺失。

### 2. D-F01 · FMX 基类误引 —— ✅ 已修复（编译实测 EXITCODE=0）

**基类核对**：

| 文件 | class 声明（行号） | 判定 |
|---|---|---|
| `FMX\DeepBase.FMX.HB.Gate.pas:35` | `THbGatePanel = class(THbFmxControl)` | ✅ |
| `FMX\DeepBase.FMX.HB.CommandPalette.pas:36` | `THbCommandPalette = class(THbFmxControl)` | ✅ |
| `FMX\DeepBase.FMX.HB.VirtualList.pas:35` | `THbVirtualList = class(THbFmxControl)` | ✅ |

`THbFmxControl` 确系 `FMX\DeepBase.FMX.HB.Controls.pas:44`（`class(TControl)`，:57 `DrawHbControl` virtual abstract 渲染管线）。

**uses 核对**：三单元 uses（Gate:15-29 / CommandPalette:15-30 / VirtualList:15-29）全部为 `System.*` + `FMX.*` + `DeepBase.HB.*` + `DeepBase.FMX.HB.*`；对 FMX 全目录 18 个 HB 单元 grep `Vcl\.|Winapi\.|THbCustomControl` **零命中**——原 E2003 缺陷根因彻底消除。

**dcc64 实测（2026-08-27 08:57 本机）**：
```
DeepBaseFMX.dpk -Q -B -U<FMX;Core;Features;VCL;Persistence;ThirdParty;...>
→ 112589 lines, 12.17 seconds, 830748 bytes code, 68012 bytes data
→ EXITCODE=0（0 Error）
```
说明：因 dpk `{$IMPLICITBUILD ON}`（DeepBaseFMX.dpk:30），本次编译隐式拉起 Services/Features 全源码链一并编译通过，其中包含原审计对照组三单元 Voice/Grid/ShareCard（仅 W1057 警告，无 Error）——**对照基线要求被包内全量覆盖，证据力强于单文件编译**。HB 单元相关警告仅：Voice(211/342/361/367，原审计 F-12 既有)、CommandPalette(251)、Gate(209)、ShareCard(109/177) 各 W1057（见新增发现 N-03）。

**超额修复（原审计 🟡 F-05/F-06/F-07 一并处理）**：三单元均实现 `DrawHbControl` 真实矢量渲染（Gate:187-262 严重度徽标/折叠详情/过滤；CommandPalette:228-290 搜索框/选中行/快捷键列 + `MatchFuzzy` 模糊搜索 98-120 + `SetSearchText` setter 触发过滤重绘 141-149 + `FilteredCount` :65；VirtualList:211-258 行卡片渲染 + `SetSearchFilter` 116-124 + `FilteredCount` :65 + `OnSelectionChange` 触发 169-170/178-179）。

### 3. D-F02 · 编译盲区 —— ✅ 已修复

- **FMX 侧差集**：`FMX\DeepBase.FMX.HB.*.pas` 目录实际 18 个文件（Glob 实测），`DeepBaseFMX.dpk` contains（63-80 行）逐一对照：Theme/Palettes/Controls/Cards/Terminal/Dialogs/Voice/Tray/Waterfall/Grid/AI/NavTree/PageControl/Dock/CommandPalette/Gate/VirtualList/ShareCard——**差集为空（18/18）**。
- **Core 侧新增单元**：`DeepBaseCore.dpk:70` 已收录 `DeepBase.HB.LLMWizard.Types in 'Core\DeepBase.HB.LLMWizard.Types.pas'`，且 DeepBaseCore.dpk 实测编译 EXITCODE=0，产物含 `DeepBase.HB.LLMWizard.Types.dcu`。
- 编译门禁验证即上述 dpk 实测本身：原「14/18 无工程引用」盲区自 dpk 全量收录后消除（原破损三单元今日以包级编译验证通过）。

### 4. D-F03 · FMX 确认对话框恒真桩 —— ⚠️ 部分修复（裁定：不满足工单验收）

`FMX\DeepBase.FMX.HB.Dialogs.pas` 现状：
- `Confirm`（333-336）、`Prompt`（338-341）、`PromptReason`（343-346）：改抛 `ENotImplemented`——**恒真放行风险已消除**（审计建议的防呆方向）；
- `ShowInfo`（**328-331 仍为空桩**）：只有一行注释 `// FMX ShowInfo implementation`，静默无操作，与同文件其余三方法的 raise 策略自相矛盾；
- 工单修复要求为「**改为真实模态实现**（对照 VCL 版 523 行附近真实模态）」——未实现任何模态窗体。抛异常属「诚实化」，防御了静默放行，但功能上 FMX 确认流仍不可用。

**裁定**：部分修复。可接受为过渡防线，不满足工单验收线；且 `ShowInfo` 连诚实化都未做，属修复内部不一致。

### 5. D-F04 · FMX VoiceDialog 恒真桩 —— ⚠️ 部分修复（裁定：不满足工单验收）

`FMX\DeepBase.FMX.HB.Voice.pas:372-378`：`Execute` 置 `AConfirmedCount := 0` 后抛 `ENotImplemented`——原「返回 True + 全部字段视为已确认」的假成功语义已消除。但工单要求的真实模态实现（对照 VCL 版 679 行）未做。**裁定**：部分修复，同 D-F03。

**配套防线核查（P1#5 / 验收准则 3）**：交付报告宣称「异常拦截测试通过」——经全 `Tests\` 目录 grep `ENotImplemented|FMX\.HB\.Dialogs|FMX\.HB\.Voice`，**不存在任何针对 FMX 对话框抛异常行为的测试**（唯一命中 `Test.DeepBase.Exceptions.pas` 测的是另一异常类 `ENotImplementedException`，与 FMX 对话框无关）。该宣称**无事实依据**（见新增发现 N-01）。

### 6. D-F06（报告 E-06）· FMX ShareCard 矢量渲染 —— ✅ 已修复

`FMX\DeepBase.FMX.HB.ShareCard.pas` `RenderToBitmap`（83-200）为**真实渲染管线，非空壳**：
- `THbTheme.Tokens` 主题令牌驱动（:92）；`BeginScene/EndScene` 配对正确（:111/:193），异常路径 `Bmp.Free; raise`（196-199）无泄漏；
- 绘制内容：外层圆角卡+描边（114-119）、内层容器（122-125）、头部类别（128-135）、标题/副标题含自动脱敏（95-104/137-150）、指标行+分隔线（152-166）、徽标/水印（169-178，BadgeText 空时回退默认文案）、免责脚注（181-183）、时间戳（186-191）；
- 三规格 16:9/1:1/4:5 尺寸正确（39-62）；`SaveToFile`（202-214）渲染后落盘、try-finally 释放；
- 修复了原审计 F-09「`AData` 完全未使用返回空白位图」的核心缺陷——`AData` 九个字段实际参与绘制。

**残留（🔵）**：`AData.QRSlot/LogoRef` 两契约字段仍未渲染（交付报告亦未声称）；无像素级内容断言测试（FMX 侧零测试，P1#5 未做）。

---

## 二、P1 复核详情

| # | 工单项 | 判定 | 证据 |
|---|---|---|---|
| 1 | C-F04 density 解析 + 0.85 硬编码 | ✅ 基本修复 | 解析分支 `HB.Core:650-657`；`Tokens()`（826-841）改为 `BaseScale := Def.Tokens.RowHeightScale` 参与乘法（833/838），JSON 令牌不再被覆盖；测试 `Test_Density_Scaling` 实测通过。⚠️ 0.85 魔法数仍在两处硬编码（838、855），const 提取未做（🔵 N-04） |
| 2 | C-F06 WCAG 扩充 | ⚠️ 部分修复 | `ValidateWcagAA`（HB.Core:317-345）新增第 3 对 `InkMuted on Surface ≥ 3.0:1`（338-344），实测 `Test_WCAG_AA_Contrast_All_BuiltInThemes` 通过（gold InkMuted 3.77:1 过线）。**工单明文要求「补 OnPrimary/Primary 按 4.5:1（常规字号正文）」未落实**——该对仍为 3.0:1（330-336，gold 实测 3.19:1，作正文不达标），且无降级声明。覆盖面亦未补 Ink/SurfaceAlt、FocusRing 1.4.11 |
| 3 | C-F09 TMessageManager 线程安全 | ❌ 未修复 | `BroadcastChange`（887-917）仍直接 `SendMessage`（:914）+ 裸 `except end`（915-916），无 Synchronize/Queue、无主线程限定文档，与原审计 F-09/F-10 原样一致 |
| 4 | run_tests.ps1 HB 别名 | ✅ 已修复 | `Scripts\run_tests.ps1:90` 新增 `"HB" = "Test.DeepBase.HB.DeepRW,...,Test.DeepBase.VCL.HB.Theme"`（5 单元齐全）；**实测可用**：本次复审即以 `-Module HB` 触发，过滤器正确解析 5 个 fixture 并全部执行（见第六节） |
| 5 | FMX 冒烟测试 + 恒真桩回归断言 | ❌ 未交付 | `Tests\` 全目录零 FMX HB 测试；无任何「确认流取消返回 False」或「抛 ENotImplemented」断言（验收准则 3 明文要求，落空） |
| 6 | 测试边界补齐（DeepRW） | ⚠️ 少量交付 | 新增 `Test_ShareCard_TruePngExport`（DeepRW:255-296，PNG magic header 校验，部分缓解原 T-02 的 SaveToFile 检查）；空队列/特殊字符/掩码边界/4:5 溢出用例**未补** |
| 附 | DefaultWarmGold FillChar（原 F-15） | ✅ 已修复 | `HB.Core:242` 改为 `Result := Default(THbTokens);`，FillChar 消除 |

---

## 三、新增文件审计：`Core\DeepBase.HB.LLMWizard.Types.pas`（83 行）

按首轮 Core 审计标准（维度 1/2/5/6）：
- **包收录**：DeepBaseCore.dpk:70 ✓，编译通过 ✓；
- **框架中立**：uses 仅 System.SysUtils/Classes/Types（16-19），零 VCL/FMX 引用 ✓；已入 Core.dpk（:70）且编译通过；
- **生命周期**：`CreateDefault` 用 `Default(THbLLMSetupConfig)`（:70）初始化，managed record 处理正确，无 FillChar 风险 ✓；
- **枚举命名**：`lws*` 前缀（25-30），与既有 `ss*` 家族无冲突 ✓；
- 🔵 uses 冗余：System.Classes/System.Types 实际未使用（F-14 同族，轻微）；
- 🔵 契约提示：`ApiKey: string` 明文承载于 UI 载荷 record（:48），无脱敏约定；`ApiFormat` 魔法字符串集合（'OpenAI'…）宜枚举化——均属提示级。

配套 VCL 实现单元 `VCL\DeepBase.VCL.HB.LLMWizard.pas` 存在（DeepRW 测试 :35 引用并实测通过），属工单外新增交付，本次不展开。

---

## 四、dcc64 编译实测记录（全部本机 2026-08-27 实跑）

| # | 目标 | 参数摘要 | 结果 |
|---|---|---|---|
| 1 | `DeepBaseCore.dpk` | `-Q -B -U<Core;BDS lib;out>` 输出至 `TestResults\recheck-20260827` | **EXITCODE=0**，58320 lines / 3.39s；HB.Core 仅 1 条 W1057（:404 中文注释字面量，系 EnsureInitialized 既有代码，非本次修复引入） |
| 2 | `DeepBaseFMX.dpk` | `-Q -B -U<FMX;Core;Features;VCL;Persistence;ThirdParty;dcp64;BDS lib>` | **EXITCODE=0**，112589 lines / 12.17s（隐式构建链含 Services/Features 全量），0 Error；HB 单元警告仅 W1057（Voice×4 既有 + CommandPalette:251/Gate:209/ShareCard:109,177 新增） |
| 3 | 对照组（Voice/Grid/ShareCard） | 包含于 #2 | 同参数同结果 EXITCODE=0——对照基线成立，证明 #2 非环境侥幸 |
| 4 | 回归工程 `DeepBaseTests.dpr` | run_tests.ps1 内部编译 | 编译成功（357516 lines / 25.48s），运行 31/31 通过 |

---

## 五、DUnitX 回归实测（2026-08-27 09:00:54，junit XML 为准）

```
命令：powershell -ExecutionPolicy Bypass -File Scripts\run_tests.ps1 -Type Unit -Module HB
过滤器：Test.DeepBase.HB.DeepRW.TTestHbDeepRWSuite,
        Test.DeepBase.HB.Suite.TTestHbSuite,
        Test.DeepBase.HB.Tray.TTestHbTrayMenu,
        Test.DeepBase.HB.Voice.CF.TTestHbVoiceCounterfactual,
        Test.DeepBase.VCL.HB.Theme.TTestHbTheme
Tests Found: 31 | Passed: 31 | Failed: 0 | Errored: 0 | Leaked: 0 → SUCCESS
```
关键用例逐条见 XML：`Test_TokenJson_Space_Motion_Shape_Parsing` Success、`Test_WCAG_AA_Contrast_All_BuiltInThemes` Success、`Test_ShareCard_TruePngExport` Success、CF-VOICE-01..06 全 Success。**该次运行同时构成 `-Module HB` 别名可用性的直接实证。**

---

## 六、交付报告诚信核对（对照 `20260827-HB-FIX-乙-交付报告.md`）

| 交付声明 | 复核结果 |
|---|---|
| 「全项通过（100% GREEN，0 编译错误，0 内存泄漏）」 | 编译 0 错误属实（本复审独立复现）；「100% GREEN」与 D-F03/D-F04 部分修复矛盾；「0 内存泄漏」无任何测试佐证 |
| E-04/E-05「异常拦截测试通过」 | **失实**：不存在对应测试（见 D-F03 节核查） |
| E-01「通过 Test_TokenJson_Space_Motion_Shape_Parsing 自动化测试断言」 | 属实（用例存在、非恒真、实测通过；唯位置与工单指定文件不符） |
| E-02「FMX 编译完全通过」/E-03「18 单元全部纳管」 | 属实（本复审独立复现 EXITCODE=0 + 差集空），但交付报告本身未附任何编译输出或时间戳 |
| E-06「矢量渲染通过」 | 渲染管线真实（代码实证），但「通过」无测试依据（无像素级断言） |
| 验收准则 4「生产部署状态章节（编译/测试进程时间戳）」 | **缺失**，交付报告无该章节 |
| 验收准则 5「引用审计编号 C-F01~D-F04 逐条标注」 | 未按工单编号体系，自用 E-01~E-06 别名（可映射但不对齐） |

---

## 七、新增发现统计

**🔴 必须处理（1 条）**
- **N-01 交付报告失实陈述**：E-04/E-05「异常拦截测试通过」无对应测试存在；总体「100% GREEN」掩盖 D-F03/D-F04 未达验收；缺「生产部署状态」章节（违反验收准则 4）。需修正报告并补真实证据。

**🟡 建议修（6 条）**
- **N-02** `FMX\DeepBase.FMX.HB.Dialogs.pas:328-331` `ShowInfo` 仍为空桩（静默无操作），与同文件 raise 策略不一致；
- **N-03** 新增代码引入 5 处 W1057 隐式 AnsiString 转换警告：`CommandPalette.pas:251`、`Gate.pas:209`、`ShareCard.pas:109/175/177`（UTF-8 无 BOM 中文字面量，原审计 F-12 家族新增实例，跨平台隐患）；
- **N-04** WCAG 工单要求未落实：OnPrimary/Primary 正文 4.5:1 未实施亦无降级声明（HB.Core:330-336 维持 3.0:1）；Ink on SurfaceAlt、FocusRing 1.4.11 覆盖未补；
- **N-05** P1#5 测试防线未交付：FMX 零冒烟测试、零恒真桩/异常断言（验收准则 3 落空）；
- **N-06** P1#6 边界用例基本未补（仅 TruePngExport 一项），空队列/特殊字符/掩码边界/4:5 溢出缺口维持；
- **N-07** P1#3（C-F09）完全未动：`BroadcastChange` 仍跨线程直发 TMessageManager + 双处吞异常（HB.Core:906-916）。

**🔵 提示（6 条）**
- **N-08** ShareCard `QRSlot/LogoRef` 契约字段仍未渲染（FMX.ShareCard 全文无消费点）；
- **N-09** `LLMWizard.Types` uses 冗余（System.Classes/System.Types 未使用）；
- **N-10** 密度系数 0.85 双处硬编码残留（HB.Core:838/855），const 提取未做（F-04 第三子项）；
- **N-11** VirtualList `SelectItem` 仍为 toggle 语义且从不回写 `Item.IsSelected`（FMX.VirtualList:141/164-167，原 S-05 残留）；
- **N-12** ShareCard `GetDimensions` 未知枚举仍返回 True（FMX.ShareCard:58-61，原 S-03 残留）；
- **N-13** 回归用例落位偏离工单指定文件（DeepRW.pas 而非 Test.DeepBase.VCL.HB.Theme.pas），功能等效但应知会工单签发方。

范围外顺带记录：B 层 6 单元（Waterfall/Grid/AI/NavTree/PageControl/Dock）仍直继承 `class(TControl)`（各自 :26/:27），渲染缺失状态未变——现已随 dpk 全量收录脱离编译盲区，但「双胞胎完整性」仍欠（原 F-11 遗留，非本工单范围）。

---

## 八、复审总结论

### 判定：**不通过（退回修正）**

**退回依据（按工单验收准则逐条）**：
1. **P0 未全修**：工单明文「P0 全部必修」。D-F03/D-F04 交付为抛 `ENotImplemented` 而非工单要求的「真实模态实现」，属部分修复；D-F03 内部尚有 `ShowInfo` 空桩残留（N-02）。
2. **验收准则 3 落空**：要求「新增 D-F03/D-F04 恒真桩断言，结果以 junit XML 为准」——零对应测试存在（N-05），且交付报告就此作出失实声明（N-01）。
3. **验收准则 4 落空**：交付报告无「生产部署状态」章节（编译/测试进程时间戳缺失）。
4. **验收准则 5 不对齐**：未按审计编号 C-F01~D-F04 标注，自用 E-xx 体系。

**同时明确认可（防误伤）**：C-F01/C-F02/D-F01/D-F02/D-F06 五项修复**真实有效**，经代码逐行核对 + dcc64 双包编译 EXITCODE=0 + 31/31 回归全绿三重独立实证；D-F01 修复还超额消化了原审计 🟡 F-05/F-06/F-07 三条。编译状态与 HB 回归防线是本次交付的实打实增量。

**退回修正清单（按优先级）**：
1. D-F03/D-F04 补真实模态实现（或与工单签发方书面约定降级验收线，明示「FMX 对话框暂不可用，接通即抛异常」）；
2. `ShowInfo` 补 raise（一行改动）；
3. 补 FMX 对话框异常断言测试 + FMX 冒烟编译级测试纳入 run_tests.ps1；
4. 修正交付报告失实声明，补生产部署状态章节（编译/测试时间戳与命令输出）；
5. 次批：WCAG 4.5:1 语义裁定、C-F09 线程安全、W1057 编码卫生（UTF-8 BOM）、边界用例补齐。

### 统计

| 级别 | 数量 | 编号 |
|---|---|---|
| 🔴 新增必须处理 | **1** | N-01（交付报告失实） |
| 🟡 新增建议修 | **6** | N-02 ~ N-07 |
| 🔵 新增提示 | **6** | N-08 ~ N-13 |
| P0 判定 | ✅4 / ⚠️2 / ❌0 | C-F01, C-F02, D-F01, D-F02, D-F06 ✅；D-F03, D-F04 ⚠️ |
| P1 判定 | ✅2 / ⚠️2 / ❌2 | C-F04✅、run_tests✅；C-F06⚠️、边界用例⚠️；C-F09❌、FMX测试❌（另 F-15 附带修复✅） |

---

*证据纪律：本报告全部行号取自 2026-08-27 实际读取的文件内容；全部编译/测试结果为本机当日实跑输出（输出目录 `TestResults\recheck-20260827`、junit `TestResults\UnitTestResults.xml` 2026-08-27 09:00:54）。未发现项不臆造。*
