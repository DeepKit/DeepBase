# D6 段2 · Tools/Studio/DeepBaseStudio.dpr 处置论证（交主控裁定）

工单：WO-20260923-AUDIT-甲-D6 · 段2（戊类续修）· 2026-09-23
取证：D6-段2-01（改前基线）/ D6-段2-02（改引用实验件，未入库）/ D6-段2-03（全历史取证）
判定面：`09_工程脚本/build-gate/contracts/T1-观测面.txt` 的 `Tools/Studio/DeepBaseStudio.dpr` 行
（清单行号会随归面变动漂移，故本件一律按工程名指位，不写行号）

## 一、结论（一句话）

**`Tools/Studio/DeepBaseStudio.dpr` 唯一能让它 `BUILD_EXIT=0` 的改法，是把同仓已存在的活工程 `Studio.dpr` 抢注成第二个入口——这不是修好这一件，而是制造架构分叉。因此该件的正确处置不是「移出契约面」，而是「移出库」；删工程属不可逆处置且本单未获授权，故按工单指令停下并交主控裁定。**

## 二、事实基座（全部实测，可复跑）

1. **该件生来即坏，从未编译过。** `git log --all -S"TStudioMainForm" -- Tools/` 全历史仅 1 笔命中 = 引入笔 `7516962d`；同一笔里窗体真实类/变量名自始为 `TfrmStudioMain`/`frmStudioMain`（.pas:55/:112、.dfm 根），而死入口写 `TStudioMainForm`/`StudioMainForm`——这两个名字在仓库任何 revision 都不存在。此后该件只被碰过 2 次（`ca3364ee` 纯更名、`cd20ddc6` 加一条 `uses`），无人碰过报错行。
2. **同一工具的真入口早就在契约面并且是绿的。** D6-段2-01：`Tools/Studio/Studio.dpr` `BUILD_EXIT=0`，已登记于同一清单的 `Tools/Studio/Studio.dpr` 行。⇒ Studio 这个工具的编译健康度**并未失保**，该行红不是功能盲区，而是死文件的红。
3. **D5 补 `.dproj` 是对的，且已把环境假红清零。** D3 基线该件红为 `F2613 Unit 'Studio.ConfigFrame' not found`（无 `.dproj` ⇒ `Frames\` 不在搜索面），甲 D5 补 `.dproj`（`dbd672e`）后暴露真实代码红 `E2003 TStudioMainForm` ⇒ 主控「首错遮蔽」判定成立。
4. **修到绿的唯一路径 = 造第二套入口。** D6-段2-02 实测：把 `{StudioMainForm}`→`{frmStudioMain}`、`(TStudioMainForm, StudioMainForm)`→`(TfrmStudioMain, frmStudioMain)` 两处 2 个标识符后 `BUILD_EXIT=0`、`GATE_EXIT=0`。但两个入口的语义差距如下（D6-段2-02 §三 + 本件复测）：

| 比对项 | `Studio.dpr`（活） | `DeepBaseStudio.dpr`（死） |
|---|---|---|
| uses 单元数 | 22 | 8 |
| 登记的 `Studio.*` 应用单元 | 12（主窗体 + 10 Frame + HelpPanel） | 1（仅主窗体） |
| `DeepBase.Manager` / `DeepBase.Types` | 有 | **无** |
| 生命周期 | `InitializeEx` 1 / `Finalize` 1 / `GetUserDefaultLCID` 1 / `CurrentLanguage` 4 | **全 0** |
| 主窗体依赖 | `Studio.MainForm.pas` interface uses 45 件，含 `DeepBase.Manager`、`DeepBase.i18n`、10 件 Frame、`Studio.i18nInit`、`Studio.Resources` | 同一窗体，但入口不做初始化 |
| `.dproj` 产物 | `Studio.exe`（`MainSource=Studio.dpr`，11 个 `<Form>`） | `MainSource=DeepBaseStudio.dpr`，仅 1 个 `<Form>`（甲 D5 镜像补建） |

⇒ 改引用后该件**能编译、能链接，但运行即未初始化**（管理器与 i18n 均由 `Studio.dpr` 的 body 负责）。这正是工单禁止的「为了编译通过乱补」形态：以 2 个标识符换来一个绿色的假入口。

## 三、三条可选路径与后果

| 选项 | 内容 | 后果 | 甲评 |
|---|---|---|---|
| (a) | 删除 `DeepBaseStudio.dpr` + `DeepBaseStudio.dproj`，同步删 T1 里 `Tools/Studio/DeepBaseStudio.dpr` 该行 | 红项 15→14 且**未放宽任何门禁**；Studio 工具面覆盖由 `Tools/Studio/Studio.dpr` 行独立承担，不降；`DeepStudio.ico` 两 `.dproj` 共用，**必须保留** | **推荐**。单一真相源回归，死代码按 AGENTS.md「及时删除无效代码」清掉 |
| (b) | 若主控认为工具应叫 DeepBase 前缀：把**活入口** `Studio.dpr/.dproj` 更名为 `DeepBaseStudio.*`，并删死件，迁移 T1 里 `DeepBaseStudio.dpr` / `Studio.dpr` 两处引用 | 同名，但真相源只有一个；需同步 IDE 侧产物路径 | 次选，成本高于 (a)，仅在命名统一是明确要求时取 |
| (c) | 把死件提升为完整第二入口（补 12 单元 uses + `InitializeEx`/i18n/`Finalize`） | 一个工具两套生命周期代码，双入口长期漂移 | **否决**：典型架构分叉，AGENTS.md 明禁 |
| （附）| 移入 T2 待定面 | 只是把死文件换个清单挂着，T2 语义是「待补齐的适用面」，不是「死件收容所」 | 否决，且工单已明令「不要自行把它塞进 T2 了事」 |

## 四、本单为何不自行落地 (a)

删工程文件属不可逆处置（连带 `.dproj` 与 T1 清单行），工单段2 的授权是「修到 `BUILD_EXIT=0`，否则停下交裁定」，不含删除授权。按「数量的下降必须是修复的结果，不是视线的转移」，本单不删、不改引用、不动门禁与清单，该件如实留在 T1 红项中。

## 五、对本单判据的影响（如实登记）

- **判据 4**：本件不主张 `BUILD_EXIT=0`，走后半支——以上即为「应移出契约面」的完整论证，并附更强的结论：应移出库。
- **判据 6**：不依赖段2 转绿。段1 清零 4 件、段3 DataAnalyzer/DocManager 补齐 2 件、PageDriverSmoke/DoQryDemo 移出库 2 件 ⇒ 15 − 8 = **7 件 ≤ 10**，达成；段2 若主控另裁，红项再 −1 至 6。
- **判据 7 / 门禁本体**：`check_build.js` 的 `UNIT_DIRS`/`DEFAULT_NS` 与 T1/T2 搜索面在本单未放宽一字（段3 只按主控已裁的三项改 T2 清单内容，不改门禁逻辑）。
- **遗留债务（不在本单修）**：`DeepBaseStudio.dpr:5` 头注释仍有 1 处丙-A 有损特征（尾字节 `86e5b7a5efbfbd3f`，全文件唯一）。待裁定处置若选 (a)，随件消失；若选 (b)/(c)，届时按乙 D6 方法补回。
