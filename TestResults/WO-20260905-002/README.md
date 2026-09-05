# WO-20260905-002 Task A · 门禁 1–7 基准证据

权威跑：`final/UnitTestResults.xml` · `final/console.log`（2026-09-05）

| Gate | 结果 | 实测要点 |
|------|------|----------|
| 1 冷启动 P95≤800ms | PASS | `gate1-coldstart-timings.csv` |
| 2 10万行滚动 ≤16.6ms/帧 | PASS | paint-only · `gate2-scroll-timings.csv` |
| 3 主题切换 ≤100ms | PASS | `gate3-theme-timings.csv` |
| 4 DPI 重算 ≤30ms + 双缓冲 + 度量 | PASS | `gate4-dpi-timings.csv` · `gate4-screens/` |
| 5 Resize ≤16.6ms/步 | **FAIL** | step0≈22.7ms；worst 见 `gate5-resize-timings.csv` |
| 6 1万实例 0 泄漏 | PASS | GDI/USER 无增长（分批创建避开 USER 上限） |
| 7 触点写入 P95≤2ms | PASS | `gate7-touchpoint-timings.csv` |

## Gate #5 根因（未调阈值）

`THbCard` + `THbFacetWaterfall` 在 `SetBounds` 后 `Form.Update` 同步重绘路径，热路径单步仍常 >16.6ms（本机 step0=22.655ms）。  
**建议修复**：瀑布流 Resize 脏区/虚拟化绘制，避免整树同步 GDI+ 重绘；阈值保持规范 16.6ms。

## 探针

`Examples/HbColdStartProbe/` · `FIRST_PAINT` stdout + `%TEMP%\hb_coldstart_first_paint.marker`
