# 03 - DeepBase 数据流向与交互图

## 1. 配置数据�?

```mermaid
graph LR
    App["应用程序"]
    App -->|SetConfig<br/>GetConfig| Manager["TDeepBaseManager"]
    
    Manager -->|调用| ConfigModule["TDeepBaseConfig"]
    ConfigModule -->|SQL 操作| DB[(config.db)]
    
    DB -->|Settings 表| Settings["Settings �?br/>Key-Value 存储"]
    DB -->|ProjectInfo 表| ProjectInfo["ProjectInfo �?br/>项目元信�?]
    
    Manager -->|缓存| Cache["内存缓存<br/>加速访�?]
    Cache -.->|miss| ConfigModule
    
    ConfigModule -->|验证| Validate["ValueType 转换<br/>IsEncrypted 检�?]
    Validate -->|成功| Cache
    Validate -->|失败| Error["返回 Default<br/>记录 WARN 日志"]
    
    style Manager fill:#ff9999
    style ConfigModule fill:#ffcccc
    style DB fill:#99ccff
    style Cache fill:#ffffcc
    style Error fill:#ff6666
```

## 2. 国际化数据流

```mermaid
graph TB
    App["应用程序"]
    
    subgraph I18nFlow["i18n 数据�?]
        App -->|T<br/>TN<br/>TFmt| Manager["TDeepBaseManager"]
        
        Manager -->|查询翻译| I18nModule["TDeepBaseI18n"]
        
        I18nModule -->|1. 检查缓存| Cache["翻译缓存"]
        
        Cache -->|Miss| DB[(config.db)]
        DB -->|I18nTexts 表| I18nTable["I18nTexts �?]
        DB -->|Languages 表| LanguagesTable["Languages �?]
        
        I18nTable -->|查询| Translator["翻译引擎"]
        LanguagesTable -->|当前语言| Translator
        
        Translator -->|返回译文| Cache
        Cache -->|返回应用| App
        
        subgraph Events["事件系统"]
            AppSetLang["应用设置语言"]
            Manager -->|OnLanguageChanged| I18nModule
            I18nModule -->|广播事件| AllI18nControls["所�?i18n 控件"]
            AllI18nControls -->|刷新显示| App
        end
    end
    
    style Manager fill:#ff9999
    style I18nModule fill:#ffcccc
    style Cache fill:#ffffcc
    style DB fill:#99ccff
```

## 3. 日志数据�?

```mermaid
graph TB
    App["应用程序"]
    
    App -->|Log<br/>LogDebug<br/>LogWarn<br/>LogError| Manager["TDeepBaseManager"]
    
    Manager -->|调用| LoggerModule["TDeepBaseLogger"]
    
    LoggerModule -->|检查日志级别| LevelCheck{{"日志级别<br/>是否满足"}}
    
    LevelCheck -->|是| Format["格式化日�?br/>添加时间�?br/>Source"]
    
    Format -->|线程安全队列| Queue["日志队列<br/>消除竞争"]
    
    Queue -->|后台线程| Storage["存储决策"]
    
    Storage -->|Database| DB[(config.db)]
    Storage -->|File| LogFile["logs/ 目录"]
    Storage -->|Both| DBAndFile["同时保存"]
    
    DB -->|Logs 表| LogsTable["Logs �?]
    LogsTable -->|索引| Index["�?Timestamp<br/>�?Level<br/>�?Source"]
    
    LoggerModule -->|定期清理| Cleanup["ClearOldLogs<br/>根据 RetentionDays"]
    Cleanup -->|删除旧记录| DB
    
    LevelCheck -->|否| Drop["丢弃"]
    
    style Manager fill:#ff9999
    style LoggerModule fill:#ffcccc
    style DB fill:#99ccff
    style Queue fill:#ffffcc
```

## 4. MRU 最近使用数据流

```mermaid
graph TB
    App["应用程序"]
    
    App -->|打开文件<br/>打开项目| FileAction["文件操作"]
    
    FileAction -->|调用| AddMRU["AddMRU<br/>Category, ItemKey"]
    
    AddMRU -->|调用| MRUModule["TDeepBaseMRU"]
    
    MRUModule -->|检查是否存在| Query{"项目是否<br/>已在 MRU"}
    
    Query -->|是| Update["更新记录<br/>LastAccess<br/>AccessCount++"]
    Query -->|否| Insert["插入新记�?]
    
    Update -->|写入| DB[(config.db)]
    Insert -->|写入| DB
    
    DB -->|MRU 表| MRUTable["MRU �?]
    
    subgraph Display["MRU 显示流程"]\n        TMRUPopupMenu["TMRUPopupMenu"]   \n        TMRUComboBox["TMRUComboBox"]\n        Manager["TDeepBaseManager"]\n        \n        TMRUPopupMenu -->|GetMRUList| Manager\n        TMRUComboBox -->|GetMRUList| Manager\n        Manager -->|查询最近项| MRUModule2["TDeepBaseMRU"]\n        MRUModule2 -->|按时间排序| MRUTable2["MRU �?]\n        MRUTable2 -->|返回�?N 条| Display_Result["显示在菜�?组合�?]\n    end\n    \n    MRUModule -->|清理无效项| RemoveInvalid["RemoveInvalidMRU<br/>检查文件是否存�?]\n    RemoveInvalid -->|不存在则删除| DB\n    \n    style App fill:#ffcccc\n    style MRUModule fill:#ffcccc\n    style DB fill:#99ccff\n    style MRUTable fill:#ccffcc\n```

## 5. 主题数据�?

```mermaid\ngraph TB\n    App[\"应用程序\"]\n    \n    App -->|ApplyTheme| Manager[\"TDeepBaseManager\"]\n    \n    Manager -->|调用| ThemeModule[\"TDeepBaseTheme\"]\n    \n    ThemeModule -->|加载主题配置| DB[(config.db)]\n    DB -->|Themes 表| ThemesTable[\"Themes �?br/>StyleFile 路径\"]\n    \n    ThemesTable -->|读取| StyleFile[\"VCL Style 文件<br/>assets/styles/*.vsf\"]\n    \n    ThemeModule -->|应用样式| VCLApplication[\"VCL Application\"]\n    VCLApplication -->|OnThemeChanged| Manager\n    \n    Manager -->|广播事件| AllControls[\"所有订阅的控件\"]\n    AllControls -->|刷新| App\n    \n    ThemeModule -->|保存选择| SetConfig[\"SetConfig<br/>App.Theme\"]\n    SetConfig -->|更新| Settings[(Settings �?]\n    \n    subgraph Metadata[\"主题元数据\"]\n        Name[\"Name<br/>主题标识\"]\n        IsDark[\"IsDark<br/>深色标记\"]\n        IsBuiltIn[\"IsBuiltIn<br/>内置标记\"]\n        SortOrder[\"SortOrder<br/>排序\"]\n    end\n    \n    style Manager fill:#ff9999\n    style ThemeModule fill:#ffcccc\n    style DB fill:#99ccff\n    style ThemesTable fill:#ccffcc\n```

## 6. 快捷键数据流

```mermaid
graph TB
    App["应用程序"]
    
    App -->|RegisterDefaultHotkeys| Manager["TDeepBaseManager"]
    
    Manager -->|初始化| HotkeysModule["TDeepBaseHotkeys"]
    
    HotkeysModule -->|检查数据库| DB[(config.db)]
    
    DB -->|Hotkeys 表| HotkeysTable["Hotkeys �?br/>ActionName-Shortcut"]
    
    HotkeysTable -->|存在| LoadExisting["加载已保存快捷键"]
    HotkeysTable -->|首次| InsertDefaults["插入默认快捷�?]
    
    LoadExisting -->|应用到应用| ApplyHotkeys["应用快捷�?br/>TForm.KeyPreview"]
    InsertDefaults -->|应用到应用| ApplyHotkeys
    
    subgraph UserAction["用户操作"]\n        UserPress[\"用户按下快捷键\"]\n        UserPress -->|匹配| GetHotkey[\"GetHotkey<br/>ActionName\"]\n        GetHotkey -->|缓存命中| Cache[\"内存缓存\"]\n        Cache -->|执行对应动作| App\n    end\n    \n    App -->|SetHotkey| UpdateHotkey["更新快捷�?br/>检查冲�?]  \n    UpdateHotkey -->|检查无冲突| WriteDB["写入数据库\"]\n    WriteDB -->|更新| HotkeysTable\n    UpdateHotkey -->|冲突| ConflictError["返回冲突通知\"]\n    \n    style Manager fill:#ff9999\n    style HotkeysModule fill:#ffcccc\n    style DB fill:#99ccff\n```

## 7. 窗体状态数据流

```mermaid
graph TB\n    App["应用程序\"]\n    Form[\"TForm<br/>窗体\"]\n    \n    App -->|创建| Form\n    Form -->|创建| FormStateHelper[\"TFormStateHelper\"]\n    \n    FormStateHelper -->|AutoRestore=True| RestoreState[\"RestoreFormState\"]\n    \n    RestoreState -->|加载| Manager[\"TDeepBaseManager\"]\n    Manager -->|查询| DB[(config.db)]\n    DB -->|FormStates 表| FormStatesTable[\"FormStates �?br/>FormName �?Key\"]\n    \n    FormStatesTable -->|读取| State[\"位置/大小/状态\"]\n    State -->|验证多显示器| MonitorCheck{\"显示�?br/>范围检查\"}\n    MonitorCheck -->|有效| Apply[\"应用状�?br/>Set Left/Top/Width/Height\"]\n    MonitorCheck -->|超出范围| UseDefault[\"使用默认位置\"]\n    \n    Apply -->|恢复完成| Form\n    UseDefault -->|恢复完成| Form\n    \n    Form -->|用户调整窗体| UserAction[\"窗口移动/缩放\"]\n    Form -->|关闭| FormClose[\"OnClose 事件\"]\n    \n    FormStateHelper -->|AutoSave=True| SaveOnClose[\"SaveFormState\"]\n    \n    SaveOnClose -->|收集| Collect[\"收集窗体状�?br/>包括 Extra JSON\"]\n    Collect -->|保存| Manager2[\"TDeepBaseManager\"]\n    Manager2 -->|更新或插入| DB2[(config.db)]\n    DB2 -->|FormStates 表| FormStatesTable2\n    \n    style Manager fill:#ff9999\n    style FormStateHelper fill:#ffcccc\n    style DB fill:#99ccff\n    style FormStatesTable fill:#ccffcc\n```

## 8. 完整的应用启动流�?

```mermaid
graph TD\n    Start[\"应用启动\"]\n    \n    Start -->|1. 检�?root.txt| CheckRoot{\"root.txt<br/>存在\"}\n    CheckRoot -->|否| CreateRoot[\"创建 root.txt<br/>使用 EXE �?APPDATA\"]\n    CreateRoot -->|路径| InitDB\n    CheckRoot -->|是| ParseRoot[\"解析 root.txt<br/>支持 INI 扩展\"]\n    ParseRoot -->|config.db 路径| InitDB\n    \n    InitDB[\"2. 初始�?config.db\"]\n    InitDB -->|检查存在| CheckDB{\"数据�?br/>存在\"}\n    CheckDB -->|否| CreateDB[\"创建新数据库<br/>应用 Tier 0 Schema\"]\n    CheckDB -->|是| VerifyDB[\"验证表结构完整性\"]\n    \n    CreateDB -->|创建完成| VerifyDB\n    VerifyDB -->|检查失败| RecoverDB[\"尝试修复或提示用户\"]\n    VerifyDB -->|成功| InitManager\n    \n    InitManager[\"3. 初始�?TDeepBaseManager\"]\n    InitManager -->|创建实例| ManagerCreate[\"TDeepBaseManager.Create\"]\n    ManagerCreate -->|调用| Initialize[\"Initialize<br/>连接数据库\"]\n    \n    Initialize -->|创建子模块| CreateSubModules[\"创建 Config<br/>i18n<br/>Logging<br/>MRU 等\"]\n    CreateSubModules -->|加载语言| LoadLanguage[\"读取 Languages �?br/>加载当前语言设置\"]\n    \n    LoadLanguage -->|加载翻译| LoadI18n[\"预加�?i18nTexts<br/>构建翻译缓存\"]\n    LoadI18n -->|加载主题| LoadTheme[\"读取 Themes �?br/>应用主题\"]\n    \n    LoadTheme -->|加载快捷键| LoadHotkeys[\"读取 Hotkeys �?br/>注册快捷键\"]\n    LoadHotkeys -->|成功| Ready[\"DeepBase 初始化完成\"]\n    \n    Ready -->|4. 创建 UI| CreateUI[\"应用程序创建主窗体\"]\n    CreateUI -->|添加| AddControls[\"添加 DeepBase 控件<br/>TFormStateHelper<br/>TI18nLabel 等\"]\n    \n    AddControls -->|恢复| RestoreForms[\"恢复窗体状�?br/>�?FormStates 表\"]\n    RestoreForms -->|显示| Show[\"显示应用界面\"]\n    \n    style Start fill:#ffcccc\n    style InitManager fill:#ff9999\n    style Ready fill:#99ff99\n    style Show fill:#99ff99\n```

---

**生成日期**�?025-11-26  \n**版本**：v0.3  \n**涵盖模块**：Config、i18n、Logging、MRU、Theme、Hotkeys、FormState\n"