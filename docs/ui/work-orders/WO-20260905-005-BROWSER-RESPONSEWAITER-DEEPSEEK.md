# 工单 WO-20260905-005 · Browser ResponseWaiter DeepSeek DOM 兼容修复（开发甲）

> **指派对象**：开发甲（software-tools / 主编码代理）
> **性质**：缺陷修复 + 单次精确 commit
> **基线**：`Features/DeepBase.Browser.ResponseWaiter.pas` 工作区存在未提交的 DeepSeek DOM 兼容补丁（29 insertions / 4 deletions），对应单元测试 9/9 通过
> **规范法源**：`docs/31.hb-test.md` v1.1（G1/G2/G5 轻量门禁）

---

## 背景（现状，主控已核实）

1. `Features/DeepBase.Browser.ResponseWaiter.pas` 中 `getLatestResponse` 逻辑存在未入库补丁：在 `document.querySelectorAll(responseSel)` 失败时，增加对全页 `div` 文本中 `"内容由 AI 生成"` + `"快速模式"/"深度思考"` 标记的容错扫描，并以 `document.title`（剔除 DeepSeek 后缀）兜底。
2. 现有单元测试 `Test.DeepBase.Browser.ResponseWaiter` 9 项已全绿，但未覆盖新增的 DeepSeek 回退路径。
3. 工作区除本单目标文件外，其余 WO-004 已归账，无搭车。

## 任务

1. **单测补强**：在 `Tests/Test.DeepBase.Browser.ResponseWaiter.pas` 中新增 `Test_GetWaiterJS_ContainsDeepSeekFallback`，断言 `BuildWaiterJS` 输出包含以下任意两项即可：
   - `内容由 AI 生成`
   - `快速模式`
   - `深度思考`
   - `replace(/\s*[-–—]\s*DeepSeek\s*$/i, "")`
2. **全量回归**：运行 `Scripts/run_tests.ps1 -Type Unit -FromUnit "Test.DeepBase.Browser.ResponseWaiter"`，确保 10/10 全绿（或沿用现有 9 项 + 本单新增 1 项）。
3. **证据归档**：将测试输出与 `UnitTestResults.xml` 复制到 `TestResults/WO-20260905-005/`。
4. **精确 commit**：
   ```
   fix(browser): add DeepSeek DOM fallback to ResponseWaiter getLatestResponse (WO-20260905-005)
   ```
   仅含：
   - `Features/DeepBase.Browser.ResponseWaiter.pas`
   - `Tests/Test.DeepBase.Browser.ResponseWaiter.pas`
   - `TestResults/WO-20260905-005/*`

## 验收准则

1. `TestResults/WO-20260905-005/UnitTestResults.xml` total >= 9 / failures=0 / errors=0。
2. `git show --stat <commit>` 仅含上述 3 项路径。
3. 新增断言覆盖 DeepSeek 回退 JS 片段。

## 禁止事项

- 禁止修改阈值常量、HB 视觉层文件、AI Choice 相关文件。
- 禁止 `git add -A`。
