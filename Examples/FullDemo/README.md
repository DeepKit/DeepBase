# DeepBase Full Demo

综合演示 DeepBase 框架所有核心功能的示例项目�?

## 功能演示

本项目通过 7 个功能页面展�?DeepBase 的主要特性：

### 1. Config (配置管理)
- `TConfigEdit` - 文本配置输入�?
- `TConfigCheckBox` - 布尔配置复选框
- `TConfigSpinEdit` - 数值配置输入框
- 自动保存/加载功能

### 2. i18n (国际�?
- `TLanguageComboBox` - 语言选择�?
- `TI18nLabel` / `TI18nButton` - 自动翻译控件
- 动态语言切换

### 3. Logging (日志)
- `TLogListView` - 日志列表视图
- 不同级别日志记录（Debug/Info/Warning/Error�?

### 4. MRU (最近使�?
- `TMRUComboBox` - MRU 下拉�?
- 添加/清除 MRU 项目

### 5. Theme (主题)
- `TThemeComboBox` - 主题选择�?
- 实时主题切换

### 6. License (许可�?
- `TLicenseStatusPanel` - 许可证状态面�?
- `TLicenseAuthDialog` - 许可证激活对话框
- `TFeedbackDialog` - 反馈对话�?

### 7. Wait/Progress (等待/进度)
- `TWaitForm` - 简单等待对话框
- 带进度条的等待对话框

## 编译要求

- Delphi 10.3+ (推荐 Delphi 12)
- �?DeepBase 源码路径添加到搜索路�?

## 使用方法

1. 打开 `FullDemo.dpr`
2. 添加搜索路径�?
   - `..\..\Core`
   - `..\..\VCL`
3. 编译并运�?

## 数据�?

程序运行时会在可执行文件目录下自动创�?`demo.db` 数据库文件，用于存储�?
- 配置信息
- 日志记录
- MRU 历史
- 窗体状�?

## 目录结构

```
FullDemo/
├── FullDemo.dpr           # 主程序文�?
├── FullDemo.MainForm.pas  # 主窗体单�?
└── README.md              # 本文�?
```

## 许可�?

本示例项目与 DeepBase 框架使用相同许可证�?
