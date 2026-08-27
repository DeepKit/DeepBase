# 工单 WO-20260827-HB-AUDIT-FIX-VCL（甲号工单 / 开发AI：甲）

> **指派对象**：开发AI 甲（VCL 控件线）
> **工单性质**：审计缺陷修复（P0 全部必修，P1 按序修）
> **基线**：Delphi 13.1 (Athens) · Win64 · dcc64 = `D:\Program Files (x86)\Embarcadero\Studio\37.0\bin\dcc64.exe`
> **来源审计报告**（每条缺陷含路径:行号+代码片段+修复建议，修复前必读）：
> - `D:\_Progs\02Business\DeepBase\CodeReview\20260827-HB-VCL-A.md`（🔴3 / 🟡23 / 🔵18）
> - `D:\_Progs\02Business\DeepBase\CodeReview\20260827-HB-VCL-B.md`（🔴7 / 🟡41 / 🔵30）

---

## P0 · 必修（全部 🔴，共 10 条）

### A 组（来自 VCL-A 报告，基础绘制层）
| # | 文件 | 缺陷 | 修复要求 |
|---|---|---|---|
| A-S1 | `D:\_Progs\02Business\DeepBase\VCL\DeepBase.VCL.HB.Controls.pas`（波及 Cards/Dialogs 等全部圆角容器） | csOpaque + 不擦背景 + 仅填充圆角路径 → 全系控件圆角外露出黑色残角 | 重写 Paint 背景：擦除整个 ClientRect（或 Parent 背景色）后再绘制圆角路径 |
| A-S2 | `D:\_Progs\02Business\DeepBase\VCL\DeepBase.VCL.HB.Tray.pas` | Tray Hint 累积污染 / 拖出释放误触发 | 按报告建议修复 Hint 生命周期与释放路径守卫 |
| A-S3 | `D:\_Progs\02Business\DeepBase\VCL\DeepBase.VCL.HB.Waterfall.pas` | 瀑布组件核心渲染为空壳（published 接口承诺未兑现） | 补齐核心渲染实现；若确属未完成功能，移除空 published 接口并在报告注明 |

### B 组（来自 VCL-B 报告，高阶控件）
| # | 文件 | 缺陷 | 修复要求 |
|---|---|---|---|
| B-S1 | `D:\_Progs\02Business\DeepBase\VCL\DeepBase.VCL.HB.NavTree.pas` | managed record 拷贝时 IconSvg 字段遗漏赋值 → 未初始化托管字段 UB 级崩溃隐患 | 所有 record 拷贝/赋值路径补全全部托管字段（或改用 Finalize/Initialize 正确配对） |
| B-S2 | `D:\_Progs\02Business\DeepBase\VCL\DeepBase.VCL.HB.Grid.pas` | 滚动机制为死代码（百万行虚拟滚动不生效） | 打通滚动→可视区映射→按需绘制链路，保证 O(1) 内存 |
| B-S3 | `D:\_Progs\02Business\DeepBase\VCL\DeepBase.VCL.HB.VirtualList.pas` | 数据全量常驻 + O(N²) 批量加载，O(1) 内存承诺落空 | 改为仅持有可视区渲染状态，数据经回调按需取；批量加载降为 O(N) |
| B-S4 | `D:\_Progs\02Business\DeepBase\VCL\DeepBase.VCL.HB.CommandPalette.pas` | 点击命中与渲染行错位，左键即执行错误命令 | 修命中计算（含滚动偏移与 DPI 缩放）；改为选中项高亮+回车/双击执行 |
| B-S5 | `D:\_Progs\02Business\DeepBase\VCL\DeepBase.VCL.HB.AI.pas` | AI 控件主体空壳 | 补齐或移除承诺接口（同 A-S3 原则） |
| B-S6 | `D:\_Progs\02Business\DeepBase\VCL\DeepBase.VCL.HB.PageControl.pas` | 4 种 published 样式只实现 2 种 | 补齐 4 样式或收敛 published 面 |
| B-S7 | `D:\_Progs\02Business\DeepBase\VCL\DeepBase.VCL.HB.ShareCard.pas` | 输出 BMP 冒充 PNG（扩展名与格式不符） | 真实编码为 PNG（GDI+ encoder 或 WIC） |

## P1 · 高优（第二批，🟡 中精选）
1. Dialogs/Voice/Tray/Waterfall 的 DPI 退化裸像素 → 统一改 `ScaleDIP`/`CurrentPPI`（VCL-A 报告 🟡 各条）；
2. 硬编码魔法颜色改走 `THbTheme.Tokens`（VCL-A/B 报告 🟡 令牌纪律条目）；
3. VirtualList 有/无选区时批量操作条显隐与选区集合同步（B 报告）；
4. Tray/Voice W1057 emoji 字面量编码警告（4 处，跨平台乱码隐患）。

---

## 验收准则（全部满足才可交付）
1. dcc64 编译 0 Error；新增 0 Warning（存量 Hint 不要求清零）；
2. 回归全绿：
   ```powershell
   powershell -ExecutionPolicy Bypass -File D:\_Progs\02Business\DeepBase\Scripts\run_tests.ps1 -Type Unit -Run "Test.DeepBase.HB"
   ```
   结果以实际 junit XML / 日志为准，禁止口头报数；
3. 10 万行 VirtualList/DataGrid 内存占用恒定（可视区决定），需给出实测前后对比数字与测试代码；
4. 交付报告含「生产部署状态」章节（编译/测试进程时间戳）；
5. 每条 P0 修复必须引用审计报告编号（A-S1~B-S7）并逐条标注 已修复/部分修复/不适用+理由。

**交付报告写入**：`D:\_Progs\02Business\DeepBase\CodeReview\20260827-HB-FIX-甲-交付报告.md`
