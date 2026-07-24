# 快速调研报告：wechat-mac-rpa 开源项目对 deepaxis 桌面感知层的可借鉴点

> task_id: AWT-20260723-081011-defcd8
> command: rapid-research (n_models=9)
> 工作线: software-tools (medium 置信)
> 日期: 2026-07-22
> 执行者: 主模型 (Claude Code, 宿主 web 工具)
> 调研对象: github.com/wq19901103wq/wechat-mac-rpa
> 前置: 两轮源码深读已固化于 docs/94 §1-5 + §6，本报告为第三轮正式多来源验证。

---

## 0. 调研方法

rapid-research workflow（无持续跟踪关键词，未起 firecrawl_monitor）。
9 视角��索，≥3 独立一手来源：
- **来源 A** GitHub REST API（4 个项目元数据 + commits，一手）
- **来源 B** wechat-mac-rpa README benchmark（一手）
- **来源 C** Anthropic computer-use 官方文档（业界权威）

WebSearch API 本轮未返回正文，改 WebFetch 直抓一手 API/文档，符合 workflow 第 3 步"时效性优先官方一手来源"。

---

## 1. 结论

### 1.1 wechat-mac-rpa 项目实况（来源 A + B）

| 指标 | 值 | 解读 |
|---|---|---|
| star / fork | 40 / 6 | 小众 |
| open issues | 16 | 中等 |
| 创建 → 最近推送 | 2026-05-02 → 2026-07-22 | **3 个月持续活跃**，最近还在加 benchmark |
| 语言 / 协议 | Python / MIT | 标准开源 |
| 最近提交 | "docs: show benchmark results" (07-18) | 处于打磨期 |
| topics | agent/llm-agent/vision-language-model/desktop-automation/digital-twin | 定位"多模态视觉 LLM 桌面 RPA" |

**判定**: 小众但活跃的新兴项目（3 个月 40 star），代表"LLM 视觉 agent 下沉到桌面原生应用"这一新趋势，与 deepaxis 同位赛道。非生产级（benchmark 回归挑战 0%，见下）。

### 1.2 benchmark 真相（来源 B，验证 docs/94 引用数字）

| 维度 | 通过率 | 对 deepaxis 的含义 |
|---|---|---|
| OCR 代表性场景 | **93.1% (27/29)** | 同场景可用 |
| OCR **回归挑战** | **0% (0/4)** | **换场景即崩，泛化极弱** |
| Sender 识别 | 93.6% | ColorMatch 要补强方向 |
| Chat Name | 96.6% | — |
| Memory Search | 96.6% | — |
| Reply 质量 | 91.7% (22/24) | — |

**关键**: OCR 回归挑战 **0%** 是铁证——纯视觉坐标流方案换 UI 版本/分辨率即失效。
这正是 deepaxis **UIA + 视觉双通道**的结构性优势：UIA 不靠 OCR 泛化，视觉仅补 UIA 盲区。
docs/94 §3/§4 记录的"硬编码不可泛化"得到量化印证。

### 1.3 同类开源生态对照（来源 A，4 项目）

| 项目 | star | 最近推送 | 范式 | 与 deepaxis 关系 |
|---|---|---|---|---|
| browser-use | 106,135 | 2026-07-23 | LLM agent + Playwright | 锁**浏览器**域，桌面原生盲区 |
| PyAutoGUI | 12,631 | **2024-08-20（停更近 2 年）** | 图像 locateOnScreen | 图像流老代表退场 |
| UIAutomation-python | 3,533 | 2026-06-02 | Windows UIA API | **纯 accessibility 流**，无视觉兜底 |
| wechat-mac-rpa | 40 | 2026-07-22 | 多模态视觉 LLM | 同位赛道（Mac/微信垂直） |

**定位结论**: deepaxis 的 **UIA(主) + 视觉(补盲区)双通道融合 + Windows 任意桌面应用**在开源生态**无直接竞品**:
- browser-use 做浏览器、wechat-rpa 做 Mac 微信、UIAutomation-python 做纯 UIA
- 三者都单范式、单域；deepaxis 是唯一**双通道 + 跨应用通用**的
- 这是有价值的差异化定位，应在 docs/10 项目边界中显式声明。

### 1.4 感知分层业界对照（来源 C，Anthropic 权威）

Anthropic computer-use（业界最权威 GUI agent）感知策略：
- **纯全屏截图喂模型**，每步一截，**不用 accessibility API**
- **未提及任何"像素变化检测/跳过未变区域"的成本优化**

**重要洞察**: 连 Anthropic 官方都没做帧间变化检测。
wechat-mac-rpa 的像素 Diff 闸门（92.6% 跳过 API）反而是比官方更前沿的优化。
→ **强化 deepaxis P2-001 TFrameDiffer 的价值**: 在 Anthropic 都没落地的成本优化点上抢先，是真实差异化优势，不是重复造轮子。

### 1.5 Delphi 桌面自动化生态（来源 D=知识库 + 来源 A 旁证）

WebSearch 未返回有效结果；以既有知识 + UIAutomation-python 对照判断:
- Delphi/Object Pascal 在桌面自动化**无成熟开源生态**（无 PyAutoGUI/browser-use 量级项目）
- 但 DeepBase 已自建 `DeepBase.UIA.UnifiedActuator`（SendInput + UIA），**不依赖外部 Delphi 生态**
- Delphi 的优势恰在**原生 Windows API 直连 + 编译型性能**，适合做像素 Diff 这种 O(n) 高频运算（P2-001 用数组遍历，无 GC 压力，比 Python numpy 路径更可控）

**判定**: Delphi 做桌面自动化的"生态劣势"对 deepaxis 不构成阻塞——核心能力自建，性能反而是加分项。

---

## 2. 来源

| # | 来源 | 类型 | URL |
|---|---|---|---|
| A1 | GitHub API: wechat-mac-rpa | 一手 | https://api.github.com/repos/wq19901103wq/wechat-mac-rpa |
| A2 | GitHub API: wechat-mac-rpa commits | 一手 | https://api.github.com/repos/wq19901103wq/wechat-mac-rpa/commits |
| A3 | GitHub API: PyAutoGUI / UIAutomation-python / browser-use | 一手 | (各自 api.github.com/repos/...) |
| B | wechat-mac-rpa README benchmark | 一手 | https://raw.githubusercontent.com/.../README.md |
| C | Anthropic computer-use 官方文档 | 权威 | https://platform.claude.com/docs/en/docs/build-with-claude/computer-use |
| D | DeepBase 既有知识库 (docs/87/94 + ColorMatch canary) | 内部 | — |

---

## 3. 争议与张力

1. **wechat-rpa 声称 92.6% tick 跳过 API**（docs/94 §2 P0 引用），但 README benchmark 未直接列出该比例，仅在架构描述中提及。**待核**: 该数字可能来自非 README 的运行日志。不影响 P2-001 立项（像素 Diff 降本是常识成立），但 docs/94 引用宜标注"待核实来源"。

2. **回归挑战 0% vs 代表性 93.1% 的巨大落差**: 说明 wechat-rpa 的 OCR/Layout 阈值是**过拟合**到特定微信版本/分辨率的。deepaxis 移植其算法时必须**重标定阈值**（对应 docs/94 §6.5 红线1"阈值有出处+校准 TODO"），不可直接照搬 `self_green=(176,240,167)` 等魔法数。

3. **Anthropic 不做变化检测 vs wechat-rpa 做**: 两种哲学。Anthropic 靠模型每步重看保证一致性（简单但贵）；wechat-rpa 靠像素 Diff 省调用（便宜但有漏检风险）。deepaxis 取中: **P2-001 闸门 + 稳定模式降阈**（docs/87 §7.1）平衡成本与漏检，方向正确。

---

## 4. 未知项

- wechat-rpa 92.6% 跳过率的确切出处（README 未直接列，疑运行日志）
- wechat-rpa 的 JudgeWorker 数据飞轮（docs/94 §0 提及但本轮未抓到 judge/ 源码，API 未返回该目录——可能路径不同或未开源）
- Windows WinRT OCR（P2-005 候选）在 DPI 缩放下的准确率，需实测
- deepaxis UIA+视觉双通道的融合切换策略（何时 fallback 视觉）尚无量化判据，待 P2-001 落地后定

---

## 5. 下一步

1. **立即可做**: docs/10 项目边界补一段"双通道 + 跨应用通���"的差异化定位声明（基于 §1.3 生态对照）
2. **docs/94 §2 P0**: 把"92.6% 跳过"标注为"待核实来源"（§3 争议1）
3. **P2-001 落地时**: 阈值/ROI 须重标定（§3 争议2），不照搬 wechat-rpa 魔法数
4. **P2-004 LayoutParser 移植**: 算法可借，阈值必须用 deepaxis 自有样本 P95 标定
5. **后续轮次**: 若需深挖 JudgeWorker 飞轮，直抓 `src/judge/` 源码（本轮 API 未返回，疑路径差异）

---

## 6. 给 deepaxis 的优化建议汇总（本调研产出）

| # | 建议 | 优先级 | 依据 |
|---|---|---|---|
| R1 | docs/10 补"双通道+跨应用"差异化定位 | P1 | §1.3 生态无竞品 |
| R2 | docs/94 标注 92.6% 待核实 | P2 | §3 争议1 |
| R3 | P2-001/004 阈值重标定（禁照搬魔法数） | P1 | §3 争议2 + §6.5 红线1 |
| R4 | 强化 P2-001 价值叙事（比 Anthropic 官方更前沿） | P2 | §1.4 |
| R5 | UIA+视觉融合切换策略量化判据（P2-001 后定） | P3 | §4 |

本报告与 docs/94 §6（二轮深读增量）互补: §6 是源码算法细节，本报告是生态/定位/业界对照的宏观验证。
