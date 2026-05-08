# 04 - DeepBase 渐进式集成流程图

## 1. 8 步渐进式迁移流程

```mermaid
graph TD
    Start["现有 Delphi 工程"]
    
    Stage1["阶段 1<br/>引入 root.txt<br/>+ config.db 机制"]
    Stage1 -->|创建 root.txt| Action1["写入项目根目录绝对路�?]
    Action1 -->|初始�?config.db| DBInit["创建 Tier 0 表结�?]
    DBInit -->|�?UI 修改| Risk1["风险: �?]
    Risk1 -->|完成| Stage2
    
    Stage2["阶段 2<br/>添加 TFormStateHelper"]
    Stage2 -->|每个主要窗体| AddHelper["拖放 TFormStateHelper"]
    AddHelper -->|设置属性| PropSet["AutoSave=True<br/>AutoRestore=True"]
    PropSet -->|自动保存窗体状态| Behavior1["用户下次启动<br/>窗体恢复位置/大小"]
    Behavior1 -->|完成| Stage3
    
    Stage3["阶段 3<br/>接入日志模块"]
    Stage3 -->|全局异常处理| GlobalHandler["�?.dpr 中添�?br/>Application.OnException"]
    GlobalHandler -->|记录日志| UseLogger["改用 DeepBase.Log()"]
    UseLogger -->|查看日志| ViewLogs["�?Studio �?br/>查看日志查看�?]
    ViewLogs -->|完成| Stage4
    
    Stage4["阶段 4<br/>替换 MRU 控件"]
    Stage4 -->|文件菜单| ReplaceMenu["�?TMRUPopupMenu<br/>替换手工代码"]
    ReplaceMenu -->|自动管理| MRUFunc["最近文�?br/>自动显示"]
    MRUFunc -->|完成| Stage5
    
    Stage5["阶段 5<br/>配置迁移到数据库"]
    Stage5 -->|梳理现有配置| ScanConfig["扫描 Registry/INI<br/>映射�?Settings"]
    ScanConfig -->|批量导入| ImportConfig["导入工具导入<br/>或手工添�?]
    ImportConfig -->|改写代码| ChangeCode["GetRegistry -> GetConfig<br/>WriteRegistry -> SetConfig"]
    ChangeCode -->|测试| TestConfig["测试各项配置<br/>功能完整"]
    TestConfig -->|完成| Stage6
    
    Stage6["阶段 6<br/>文本国际�?]
    Stage6 -->|替换标签| ReplaceLabelI18n["TLabel -> TI18nLabel<br/>设置 TextKey 属�?]
    ReplaceLabelI18n -->|替换按钮| ReplaceBtnI18n["TButton -> TI18nButton"]
    ReplaceBtnI18n -->|设置字符串| SetStrings["设置为英文原�?]
    SetStrings -->|Studio 扫描| ScanI18n["Studio 源码扫描<br/>采集待翻译文�?]
    ScanI18n -->|翻译编辑| TranslateI18n["编辑翻译<br/>支持 LLM 自动翻译"]
    TranslateI18n -->|完成| Stage7
    
    Stage7["阶段 7<br/>运行 Studio"]
    Stage7 -->|启动独立工具| LaunchStudio["双击 DeepBase Studio"]
    LaunchStudio -->|管理所有配置| ManageAll["i18n 管理<br/>日志查看<br/>异常报告<br/>资源管理"]
    ManageAll -->|完成| Stage8
    
    Stage8["阶段 8<br/>添加自动更新"]
    Stage8 -->|拖放组件| AddAutoUpdate["拖放 TAutoUpdater"]
    AddAutoUpdate -->|配置服务| ConfigUpdate["配置检查间�?br/>更新渠道"]
    ConfigUpdate -->|用户提示| UpdateNotif["有新版本�?br/>弹出通知"]
    UpdateNotif -->|完成| End["集成完成<br/>所�?DeepBase<br/>功能就绪"]
    
    Start --> Stage1
    
    style Start fill:#ffcccc\n    style End fill:#99ff99\n    style Stage1 fill:#ffffcc\n    style Stage2 fill:#ffffcc\n    style Stage3 fill:#ffffcc\n    style Stage4 fill:#ffffcc\n    style Stage5 fill:#ffffcc\n    style Stage6 fill:#ffffcc\n    style Stage7 fill:#ffffcc\n    style Stage8 fill:#ffffcc\n```\n\n## 2. 集成决策树\n\n```mermaid\ngraph TD\n    Decision{\"现有工程<br/>集成 DeepBase\"}\n    \n    Decision -->|首要问题| Q1{\"是否需�?br/>国际�?\"}\n    \n    Q1 -->|是| Path_I18n[\"优先级高<br/>阶段 6 前置<br/>使用 TI18nLabel\"]\n    Path_I18n -->|后续| Q2\n    \n    Q1 -->|否| Skip_I18n[\"跳过阶段 6\"]\n    Skip_I18n -->|后续| Q2\n    \n    Q2{\"是否需�?br/>配置管理?\"}\n    \n    Q2 -->|是| Path_Config[\"优先级高<br/>阶段 5 前置<br/>迁移 Registry/INI\"]\n    Path_Config -->|后续| Q3\n    \n    Q2 -->|否| Skip_Config[\"使用默认配置\"]\n    Skip_Config -->|后续| Q3\n    \n    Q3{\"是否需�?br/>窗体状态保�?\"}\n    \n    Q3 -->|是| Path_FormState[\"阶段 2 必需<br/>每个窗体添加<br/>TFormStateHelper\"]\n    Path_FormState -->|后续| Q4\n    \n    Q3 -->|否| Skip_FormState[\"跳过阶段 2\"]\n    Skip_FormState -->|后续| Q4\n    \n    Q4{\"是否需�?br/>日志记录?\"}\n    \n    Q4 -->|是| Path_Log[\"阶段 3 前置<br/>接入日志模块<br/>查看日志\"]\n    Path_Log -->|后续| Q5\n    \n    Q4 -->|否| Skip_Log[\"跳过阶段 3\"]\n    Skip_Log -->|后续| Q5\n    \n    Q5{\"是否需�?br/>自动更新?\"}\n    \n    Q5 -->|是| Path_Update[\"阶段 8 后置<br/>配置更新服务\"]\n    Path_Update -->|后续| Final\n    \n    Q5 -->|否| Skip_Update[\"跳过阶段 8\"]\n    Skip_Update -->|后续| Final\n    \n    Final[\"生成推荐集成方案\"]\n    \n    style Decision fill:#ff9999\n    style Final fill:#99ff99\n```\n\n## 3. 集成检查清单\n\n```mermaid\ngraph LR\n    subgraph PreIntegration[\"集成前准备\"]\n        Check1[\"备份现有代码<br/>git commit\"]\n        Check2[\"了解现有架构<br/>识别配置/i18n\"]\n        Check3[\"准备测试计划\"]\n    end\n    \n    subgraph Stage1Check[\"阶段 1 检查\"]\n        S1C1[\"�?root.txt 创建\"]\n        S1C2[\"�?config.db 初始化\"]\n        S1C3[\"�?表结构验证\"]\n    end\n    \n    subgraph Stage2Check[\"阶段 2 检查\"]\n        S2C1[\"�?主窗体添�?Helper\"]\n        S2C2[\"�?次要窗体添加 Helper\"]\n        S2C3[\"�?测试保存/恢复\"]\n    end\n    \n    subgraph Stage3Check[\"阶段 3 检查\"]\n        S3C1[\"�?异常处理接入\"]\n        S3C2[\"�?日志记录测试\"]\n        S3C3[\"�?查看器验证\"]\n    end\n    \n    subgraph Stage4Check[\"阶段 4 检查\"]\n        S4C1[\"�?TMRUPopupMenu 配置\"]\n        S4C2[\"�?菜单项添加测试\"]\n        S4C3[\"�?MRU 功能验证\"]\n    end\n    \n    subgraph Stage5Check[\"阶段 5 检查\"]\n        S5C1[\"�?配置 Key 定义\"]\n        S5C2[\"�?导入脚本执行\"]\n        S5C3[\"�?代码替换完成\"]\n    end\n    \n    subgraph Stage6Check[\"阶段 6 检查\"]\n        S6C1[\"�?控件替换完成\"]\n        S6C2[\"�?文本扫描成功\"]\n        S6C3[\"�?翻译导入完成\"]\n    end\n    \n    subgraph Stage7Check[\"阶段 7 检查\"]\n        S7C1[\"�?Studio 启动成功\"]\n        S7C2[\"�?所有管理器可用\"]\n        S7C3[\"�?导入导出测试\"]\n    end\n    \n    subgraph Stage8Check[\"阶段 8 检查\"]\n        S8C1[\"�?组件安装成功\"]\n        S8C2[\"�?更新服务配置\"]\n        S8C3[\"�?通知测试\"]\n    end\n    \n    subgraph PostIntegration[\"集成后验证\"]\n        Final1[\"完整功能测试\"]\n        Final2[\"性能基准测试\"]\n        Final3[\"文档更新\"]\n        Final4[\"团队培训\"]\n    end\n    \n    PreIntegration -->|准备完毕| Stage1Check\n    Stage1Check -->|通过| Stage2Check\n    Stage2Check -->|通过| Stage3Check\n    Stage3Check -->|通过| Stage4Check\n    Stage4Check -->|通过| Stage5Check\n    Stage5Check -->|通过| Stage6Check\n    Stage6Check -->|通过| Stage7Check\n    Stage7Check -->|通过| Stage8Check\n    Stage8Check -->|通过| PostIntegration\n    \n    style PreIntegration fill:#ffcccc\n    style PostIntegration fill:#99ff99\n```\n\n## 4. 风险评估与缓解\n\n```mermaid\ngraph TB\n    subgraph Risks[\"潜在风险\"]\n        Risk1[\"风险 1<br/>数据库迁�?br/>现有配置丢失<br/>概率: 中\"]\n        Risk2[\"风险 2<br/>控件替换<br/>功能不兼�?br/>概率: 低\"]\n        Risk3[\"风险 3<br/>性能影响<br/>i18n 缓存不足<br/>概率: 低\"]\n        Risk4[\"风险 4<br/>集成测试不足<br/>隐藏 Bug<br/>概率: 中\"]\n    end\n    \n    subgraph Mitigations[\"缓解方案\"]\n        Mit1[\"�?备份现有配置<br/>�?提前导出/导入测试<br/>�?定义迁移脚本\"]\n        Mit2[\"�?逐个替换控件<br/>�?单元测试覆盖<br/>�?回滚方案\"]\n        Mit3[\"�?调整缓存大小<br/>�?性能基准测试<br/>�?监控内存使用\"]\n        Mit4[\"�?编写集成测试<br/>�?自动化验�?br/>�?QA 检查清单\"]\n    end\n    \n    Risk1 -->|缓解| Mit1\n    Risk2 -->|缓解| Mit2\n    Risk3 -->|缓解| Mit3\n    Risk4 -->|缓解| Mit4\n    \n    style Risks fill:#ff9999\n    style Mitigations fill:#99ccff\n```\n\n## 5. 集成时间表\n\n```mermaid\ngantt\n    title DeepBase 集成时间表（按阶段）\n    dateFormat YYYY-MM-DD\n    \n    section 准备阶段\n    代码备份: prep1, 2025-12-01, 1d\n    架构分析: prep2, after prep1, 2d\n    \n    section 阶段 1-2\n    阶段 1 (root+db): s1, 2025-12-04, 3d\n    阶段 2 (FormState): s2, after s1, 3d\n    \n    section 阶段 3-4\n    阶段 3 (Logging): s3, after s2, 2d\n    阶段 4 (MRU): s4, after s3, 2d\n    \n    section 阶段 5-6\n    阶段 5 (Config): s5, after s4, 5d\n    阶段 6 (i18n): s6, after s5, 5d\n    \n    section 阶段 7-8\n    阶段 7 (Studio): s7, after s6, 2d\n    阶段 8 (Update): s8, after s7, 2d\n    \n    section 验证\n    完整测试: test, after s8, 3d\n    文档更新: doc, after test, 2d\n    培训: train, after doc, 2d\n```\n\n## 6. 回滚计划\n\n```mermaid\ngraph TD\n    Issue{\"集成过程�?br/>出现问题\"}\n    \n    Issue -->|严重程度| Severity{\"问题严重�?\"}\n    \n    Severity -->|轻微| LocalRollback[\"本地回滚<br/>重新分析<br/>调整方案\"]\n    LocalRollback -->|修复| Continue[\"继续集成\"]\n    \n    Severity -->|严重| FullRollback[\"完全回滚<br/>恢复备份代码<br/>git reset\"]\n    FullRollback -->|重新规划| ReAnalyze[\"重新分析<br/>调整集成策略<br/>缩小阶段范围\"]\n    ReAnalyze -->|准备| RestartIntegration[\"从问题阶�?br/>重新开始\"]\n    \n    Continue -->|后续| Next[\"继续下一阶段\"]\n    RestartIntegration -->|后续| Next\n    \n    style Issue fill:#ff6666\n    style FullRollback fill:#ff9999\n    style LocalRollback fill:#ffcccc\n    style Continue fill:#99ff99\n```\n\n---\n\n**生成日期**�?025-11-26  \n**版本**：v0.3  \n**适用范围**：VCL 工程的渐进式集成\n"