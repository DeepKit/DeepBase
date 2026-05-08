# CLAUDE.md

本文件用于约�?AI 辅助开发在 DeepBase 仓库中的默认行为。实际代码风格以仓库现有代码�?`.editorconfig` 为准�?
## EditorConfig

必须遵守仓库根目�?`.editorconfig`�?
- 全局使用 `utf-8`、`crlf`、文件末尾保留换行�?- 默认清理行尾空白；Markdown 文件例外，允许保留行尾空白�?- Delphi 相关文件 `*.pas`、`*.dpr`、`*.dpk`、`*.dfm`、`*.fmx` 使用 2 空格缩进，不使用 Tab�?- `*.md`、`*.json`、`*.yml` 使用 2 空格缩进�?- `*.ps1` 使用 4 空格缩进�?- `*.bat` 使用 `crlf` 行尾�?
## Delphi 代码风格

- 保持现有 Object Pascal 单元结构：文件头注释、`interface`、`implementation`、必要的 `initialization/finalization`�?- 命名遵循 Delphi 习惯：类�?`T*`，接�?`I*`，字�?`F*`，参数优先使�?`A*`，局部变量优先匹配周边代码风格�?- 不引入泛�?`Exception.Create`；业务错误优先使�?`Core/DeepBase.Exceptions.pas` 中的具体异常类，或模块内已有异常类型�?- 创建对象后使�?`try/finally` 释放；析构函数和持有字段按现有代码模式使�?`FreeAndNil`�?- FireDAC SQL 必须参数化；不要把用户输入或外部数据拼接�?SQL�?- 涉及 Windows API、Credential Manager、DPAPI、CNG 等平台能力时，使�?`{$IFDEF MSWINDOWS}` 并保留可编译的非 Windows 路径�?- 修改共享 schema、配置、LLM、安全、DoQry、对象池等公共模块时，需要补充或更新对应 DUnitX 回归测试�?
## 工作�?
- 搜索文件和文本优先使�?`rg`�?- 不回滚用户或其他任务留下的无关改动；只修改当前任务需要的文件�?- 常用单测命令�?
```powershell
powershell -ExecutionPolicy Bypass -File .\Scripts\run_tests.ps1 -Type Unit -CI -Platform Win64
```

- 文档链接修改后运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\Scripts\check_doc_links.ps1 -Path <doc-path>
```
