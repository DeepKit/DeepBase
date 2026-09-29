# 纪律 6 交接：A9 新增 initialization 段的编译噪声增量表（供甲 A7-02 噪声归因表覆盖）

口径：同一支一次性 runner（b2_run_fixture.sh / a9_run_combined.sh）、同一份模板，逐单元只差本笔 3 行，
对比修前/修后跑录里的 Hint / Warning 行（码 × 条数 × 文件:行号逐条 diff）。

| 工程（单元） | 修前 Hint 条数 | 修后 Hint 条数 | 逐条同集合 | H2077 | H2443 | H2269 |
|---|---|---|---|---|---|---|
| Test.DeepBase.DesignTime.Registration | 0 | 0 | YES | 0 | 0 | 0 |
| Test.DeepBase.Exceptions | 0 | 0 | YES | 0 | 0 | 0 |
| Test.DeepBase.Speech.Intent.LLMBackend | 0 | 0 | YES | 0 | 0 | 0 |
| Test.Regression.BUG324_WorkerQueueCallbackSafety | 2 | 2 | YES | 2 | 0 | 0 |
| Test.Regression.BUG325_WorkerQueueTimeout | 2 | 2 | YES | 2 | 0 | 0 |
| Test.Regression.BUG328_MetricsConcurrentInit | 1 | 1 | YES | 1 | 0 | 0 |
| Test.Regression.BUG330_SQLiteReaderSchemaCache | 1 | 1 | YES | 1 | 0 | 0 |
| Test.Regression.BUG331_SafeQueryIdentifierValidation | 2 | 2 | YES | 2 | 0 | 0 |
| Test.Regression.BUG333_RecycleAllConnectionsUAF | 18 | 18 | YES | 8 | 10 | 0 |
| 合并面（14 单元同挂一个 runner） | 25 | 25 | YES | 14 | 11 | 0 |

结论：**A9 九笔的 initialization 段引入的 Hint/Warning 增量 = 0**（逐单元与合并面都是零增量，
两侧 Hint 行逐条同集合）。编译器读入行数增量 = 每单元 +3、合并面 +27，与 diff 净增逐行对上，
说明除这三行外没有别的输入变化。A7-02 的噪声归因表不需要为本单留「不明增量」。
