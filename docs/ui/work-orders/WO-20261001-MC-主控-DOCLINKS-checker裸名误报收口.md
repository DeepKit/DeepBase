# WO-20261001-MC-主控-DOCLINKS checker 裸名误报收口（主控派单 · P2）

**单号**：`WO-20261001-MC-主控-DOCLINKS`
**派单**：主控（2026-10-01，甲 `WO-20261001-MC-甲-A16` 验收收口时派生；MC1 项 2 的遗留面）
**优先级**：P2
**授权面**：`Scripts/check_doc_links.ps1`
**禁动区**：`Core/**`、`contracts/**`、`Features/DeepBase.Licensing.pas`、`Tests/**`、`09_工程脚本/**`

---

## 〇、纪律与口径

1. 零信任：判据全部主控亲跑留档，优先隔离 `--detach` 树。
2. MC1 项 2 修的是「管道符崩溃」与「`GetFullPath` 抛异常整脚本中止」两条；本单修**第三面**——裸名误报。三者独立，不得混为一笔。
3. 一笔 H15 原子提交，显式 pathspec，选项在 `--` 前，禁 push。台账状态槽归主控。

---

## 一、现象与已亲证读数

`Scripts/check_doc_links.ps1` 的命令空间只扫 6 个扩展名（`:26` 正则 `md|pas|dpk|dproj|ps1|bat|sql`），
并按「候选是否含路径分隔符」选解析根（`:28`）：

```powershell
$base = if ($link.Contains("/") -or $link.Contains("\")) { $repoRoot } else { $targetDir }
```

**只豁免裸 `.pas`**（`:47-48`）：

```powershell
if (-not $hasPathSeparator -and ([IO.Path]::GetExtension($candidate) -eq ".pas")) { continue }
```

⇒ 裸 `.md` / `.ps1` / `.dpk` / `.dproj` / `.bat` / `.sql` 全部回落 `$targetDir`（**被检查文档自己所在目录**）解析，
仓根文件必误报。

**已亲证的两个面（主控 2026-10-01）**：

| 文档 | EXIT | 断链清单 | 性质 |
|---|---|---|---|
| `docs/ui/work-orders/00-主控派单总表.md` | 1 | **10 条**：.pas/.dpr/.dproj/.dpk、check_doc_links.ps1、dclDeepBaseFMX.dpk、DeepBaseCommerce.dpk、DeepBaseFMX.dpk、DeepBaseServices.dpk、DeepBaseTests.dproj、README-版本管理员.md、README-许可证服务.md、run_tests.ps1 | 全部为裸名（无分隔符）⇒ 误报 |
| `./CHANGELOG.md` | 1 | **3 条**：Persistence/DeepBase.External.BCryptDecrypt.pas 等三路径（详见 §二，此处不包裹以免复现误报） | 见 §二 |

对照已做实：干净隔离树 `@248283b` 跑同一台账，**逐条同一**（EXIT=1 / 同样 10 条）
⇒ 是存量，非 `a3cae16` 回归。

---

## 二、CHANGELOG 三形态独立于裸名问题（须一并处理）

`./CHANGELOG.md:63` 原文（反引号包裹处按本单教训改写为裸文本，否则本工单自身即恒红）：

> - Persistence/DeepBase.External.BCryptDecrypt.pas、Persistence/DeepBase.External.SQLiteReader.pas、VCL/DeepBase.AutoFix.ErrorRecorder.VCL.pas（无引用的孤立旧实现）。

三文件**确实不存在**（主控 `[ -f ]` 逐件核实 MISSING），且该行语义就是「这些是被删掉的孤立旧实现」。
⇒ 这不是误报，是 checker 缺一种「文档有意记录已删除路径」的表达能力。修法必须覆盖此形态，
否则收口后 CHANGELOG 仍恒红。

---

## 三、修法方向（执行方裁后落）

1. **裸名豁免扩面**：`:47-48` 的 `.pas` 特判扩为该命令空间全部扩展名（或反过来——裸名一律跳过，
   只校验带分隔符的候选）。前者改动小、语义稳。
2. **已删路径的显式退出**：给文档一种标记（如行内 `<!-- nolink -->` 或约定前缀）使该行候选不校验；
   或者让 checker 对「不存在但文档明确写为删除」的形态不判红。**须先与主控确认选型再落**。
3. 不得为了转绿而放宽「真断链」判定：判据 4 的反向样本必须仍然红。

---

## 四、判据（fail-closed，全部主控亲跑留档）

| # | 判据 | 期望 |
|---|---|---|
| 1 | 修后跑 `00-主控派单总表.md` | EXIT=0 或断链数显著下降且**逐条归因**（不得仍是 10 条原样） |
| 2 | 修后跑 `./CHANGELOG.md` | EXIT=0 |
| 3 | 真断链反向样本 | 构造一个**确实不存在且非裸名**的路径引用，必须仍判红（证门禁仍有牙） |
| 4 | 负样本三件（MC1 项 2 已建） | 不复发、仍全过 |
| 5 | 四门 | eol / encoding / mojibake / evidence-encoding EXIT=0（**不含 contract-gate**，该门既存红另单） |
| 6 | 仓内全量文档扫一遍 | 汇总「修前 EXIT=1 的文档集合」与「修后 EXIT=1 的文档集合」，差集逐条说明 |
| 7 | 提交纪律 | 单笔 H15，显式 pathspec，未 push |

---

## 五、不在本单（已登记）

- MC1 项 2 的管道符崩溃与 `GetFullPath` try/catch（已闭环 `a8ffef4`）。
- `contract-gate` 既存红（另单 `WO-20261001-MC-主控-CONTRACTGATE`）。
- 文档内容本身的订正（除为通过判据必需的标记外，不改台账/CHANGELOG 正文语义）。

---

## 六、执行结论（执行方回填）

（待执行方回执填写：判据 1–7 逐条读数、修前/修后文档集合差集、提交哈希、未 push 声明。）
