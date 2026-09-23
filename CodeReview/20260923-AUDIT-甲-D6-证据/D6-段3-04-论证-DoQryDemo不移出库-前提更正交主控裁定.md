# D6 段3 · `doQry/examples/DoQryDemo/DoQryDemo.dpr` 不执行「移出库」的论证（前提更正 + 交主控裁定）

工单：WO-20260923-AUDIT-甲-D6 · 段3 · 2026-09-24
裁定原文：「`DoQryDemo` ⇒ **移出库**，写明「`DBClient` 不在 Win64 lib 面，属平台不适用`」」
取证：D6-段3-01（改前/改后门禁实测）/ D6-段3-03（三层原因与 61 处损坏面）/ D6-段3-05（prjDoQry 与 demo 同批对照）
判定面：`09_工程脚本/build-gate/contracts/T1-观测面.txt` 的 `doQry/examples/DoQryDemo/DoQryDemo.dpr` 行
（该件在 T1 观测面，不在 T2；清单行号随归面漂移，本件按工程名指位）

## 一、结论（一句话）

**「`DBClient` 不在 Win64 lib 面，属平台不适用」这个前提是错的：DataSnap 客户端数据集在 Win64 完整存在（`Datasnap.DBClient.dcu`），首错 F2613 只是这个 `.dpr` 没有 `.dproj`、回落到门禁 `DEFAULT_NS`（不含 `Datasnap`）所致；把它按「平台不适用」删掉，会连带抹掉它身后两层真实缺陷——`doQry/src/uDoQry.pas:10/:18` 因编码损坏丢掉的两个公开例程声明，和 demo 自身自诞生笔起就写的跨行字符串字面量。因此本单不删、不改清单，按工单逃生门停下交主控裁定。**

## 二、前提逐层证伪（详见 D6-段3-03）

| 层 | 裁定/直觉给出的说法 | 实测 |
|---|---|---|
| 单元是否存在 | DBClient 不在 Win64 lib 面 | `Datasnap.DBClient.dcu` 存在（706,523 字节）；`MidasLib.dcu` 也存在且是顶层裸名。缺的只是「顶层裸名 DBClient」，不是能力 |
| 为什么找不到 | 平台不适用 | `doQry/prjDoQry.dproj:69` 的 Base `DCC_Namespace` 含 `Datasnap`，同批实测 `prjDoQry.dpr BUILD_EXIT=0`；demo 目录只有 `.dpr`（无 `.dproj`）⇒ 回落到 `check_build.js:39` 的 `DEFAULT_NS`，该串没有 `Datasnap` ⇒ F2613。差异在「有没有工程配置」，不在平台 |
| 补上命名空间后是否就绿 | 是（隐含） | 否。`-NS+Datasnap` 后暴露：`E2003 'DoQryInit'`、`E2003 'DoQryExecSelect'`、`E2052 Unterminated string`（.dpr:58/60/61 等），共 15 条 |
| E2003 从哪来 | demo 写错 | 库自身坏了。`doQry/src/uDoQry.pas:10/:18` 的注释尾字节被换成 0x3F 且**换行一并丢失**，`procedure DoQryInit` / `function DoQryExecSelect` 被并进注释行 ⇒ interface 少两个导出例程（implementation :30/:74 实现仍在）。干净祖先 `7516962d` 里这两条各自成行 |
| 谁弄坏的 | — | 引入笔 `ca3364e`（UniBase→DeepBase 更名）；`7ddfbed` 只把非法字节改成 U+FFFD 而未补回换行；乙 B1-B5 编码修复笔 `649b1e0` 反而把注释文字再转成双重编码乱码，声明依旧被吞。**HEAD 上缺陷仍在，且历次编码修复都没命中它**（换行缺失不在逐字节替换的修复模型里） |
| E2052 从哪来 | 编码损坏 | 不是。58/60 行内 0x3F 命中 0 处、无 U+FFFD；SQL 是被人直接折行写，Delphi 字符串字面量不允许跨行 ⇒ 该 `.dpr` 与段2 的 `DeepBaseStudio.dpr` 同属「自诞生从未编译过」（全历史仅诞生笔 `7516962d`） |

## 三、为什么「移出库」在这里等于视线转移（这是本单被明令禁止的形态）

1. **doQry 子系统在 15 件红项里只有这一个探针。** 同一目录代码面按丙类口径扫出 **61 行**损坏（`doQryMain.pas` 10、`uDoQryLegacy.pas` 46=42 丙-A + 4 丙-B、`src/uDoQry.pas` 2、`src/uDoQryDialect.pas` 1、`src/uDoQryExecutor.pas` 2；另 `doQry/tasks.md` 文档面 27 行未计）。删掉 demo，这 61 行一个都不再被任何门禁指向。
2. **库工程绿 ≠ 库没问题。** 实测 `prjDoQry.dpr BUILD_EXIT=0` 而 demo 红：因为 `prjDoQry.dpr` 不消费那两个被吞掉的例程，丢导出面对它不可见。demo 是当前唯一能让这个缺陷开口说话的工程。删它＝把一个已存在的生产面 API 缺失改成静默。
3. **该件在 T1 观测面本来就是非阻断的。** 留着它不阻塞任何提交，只如实记 `BUILD_EXIT=1`；删它的收益仅仅是台账上少一行数字。按「数量的下降必须是修复的结果，不是视线的转移」，收益与代价不成比例。
4. 甲不擅自扩大本单范围去「顺手修好」：(i) 改 `DEFAULT_NS` 是门禁本体放宽枚举面，属治理决定；(ii) 按祖先补回 `uDoQry.pas` 的 interface 与整目录 61 行损坏，是 doQry 子系统的一次独立编码修复工单（段1 已确立的祖先法可复用），塞进本单会让「D6 只做测试面 + 三件裁定」的范围失真。

## 四、三条可选路径（交主控选，甲不动手）

| 选项 | 内容 | 代价 | 甲评 |
|---|---|---|---|
| (a) | 另派一笔 doQry 修复单：`src/uDoQry.pas:10/:18` 按 `7516962d` 补回换行与声明 + 全目录 61 行丙类损坏同法清零 + demo 的 `.dpr` 改 `Datasnap.DBClient` 并把跨行 SQL 改成 `+ sLineBreak` 串接 | 一次真实修复，红项 −1 且顺带清掉 61 行债 | **推荐**。数字下降发生在修完之后，不是删掉探针之后 |
| (b) | 只把 demo 的 `uses DBClient` 改成 `Datasnap.DBClient`（1 行） | 首错消失，但立刻暴露第三层的 E2003/E2052，红项不变、只是换了报错 | 不解决问题；且与裁定「移出库」是两个方向，须主控先改裁定 |
| (c) | 维持「移出库」= 删 `doQry/examples/DoQryDemo/DoQryDemo.dpr` + 删 T1 里 `doQry/examples/DoQryDemo/DoQryDemo.dpr` 该行 | 红项 −1，理由写成「平台不适用」 | **否决**：理由本身为假（本件 §二），并制造 §三 1/2 两条静默 |
| （附）| 把 `Datasnap`（以及同样缺的 `Vcl.Samples`）加进 `DEFAULT_NS` | 影响全部「无 `.dproj` 工程」的判定面，属门禁本体变更 | 单列议题交主控：这是真实的门禁配置缺口（本次实测已证明它会制造假 F2613），但不应由修红项的工单顺手改掉 |

## 五、本单实际落地与对判据的影响（如实登记）

- **段3 三项裁定执行 2 项**：`PageDriverSmoke` 移出库（依据 D6-段3-02，缺口是 WebView4Delphi 整包 + 全仓无 `USE_WEBVIEW2` 配置）；`DataAnalyzer`/`DocManager` 补齐（两件 `BUILD_EXIT=0`，D6-段3-01 §二）。DoQryDemo 一项**不执行并出具本件**，T2 清单因此保持 0 件在册（不塞回 T2，工单明禁「塞进 T2 了事」）。
- **判据 5**：按「逐条一致」的严格口径未全达成——2/3 一致，1/3 是本件形式的书面前提更正。
- **判据 6**：15 → 段1(−4) → PageDriverSmoke(−1) → DataAnalyzer(−1) → DocManager(−1) = **8**，满足 ≤10；较段2 论证当时预估的 7 多 1 件，差额正是 DoQryDemo（依前提更正保留为红），不依赖它也不放宽任何门禁。
- **附带更正登记（同段3 的另一处前提偏差）**：「`DataAnalyzer` / `DocManager` ⇒ 补齐（模板应自洽，成本低）」与实测不符——两模板实际各自缺整条 ORM/Logger 层与两个单元实体（DocManager 新建 `Entity.Base.pas`，DataAnalyzer 新建 `Main.Form.*` 与 `Data.Module.*`），并含保留字字段、`TCaption = type string` 上的 `.Trim`、已废弃的 `TJSONArray.AddElement`、record 属性就地赋值（E2064）等 6 类代码级缺陷，README 另有 16/22 行编码损坏需按祖先补回。已在回执 §段3 如实登记，不改工单原文。
