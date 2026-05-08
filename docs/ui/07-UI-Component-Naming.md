# DeepBase UI 组件命名与设计规范列�?

本文档列出了 DeepBase 框架中所有标�?UI 组件的规范名称、用途及文件对应关系�?

> **SVG 图示位置**: `docs/ui/svg/components/{ComponentName}.svg`

## 1. 基础配置控件 (Basic Config Controls)

这些控件具有自动绑定 `config.db` 的能力�?

| 组件名称                | 对应文件                  | 说明                        |
|:------------------- |:--------------------- |:------------------------- |
| **TConfigEdit**     | `TConfigEdit.svg`     | 自动绑定配置项的文本编辑框，支持默认值和自动保存�?|
| **TConfigCheckBox** | `TConfigCheckBox.svg` | 自动绑定 Boolean 配置项的复选框�?    |
| **TConfigSpinEdit** | `TConfigSpinEdit.svg` | 自动绑定 Integer 配置项的数值调节框�?  |

## 2. 国际化控�?(i18n Controls)

这些控件支持运行时动态语言切换�?

| 组件名称                  | 对应文件                    | 说明                                  |
|:--------------------- |:----------------------- |:----------------------------------- |
| **TI18nLabel**        | `TI18nLabel.svg`        | 自动翻译 `Caption` 的标签，使用 `TextKey` 绑定�?|
| **TI18nButton**       | `TI18nButton.svg`       | 自动翻译 `Caption` 的按钮�?                |
| **TLanguageComboBox** | `TLanguageComboBox.svg` | 语言选择下拉框，支持显示国旗图标和本地化名称�?            |

## 3. 历史记录控件 (MRU Controls)

用于管理最近使用项（文件、查找记录等）�?

| 组件名称              | 对应文件                | 说明                      |
|:----------------- |:------------------- |:----------------------- |
| **TMRUComboBox**  | `TMRUComboBox.svg`  | 带历史记录下拉列表的组合框，支持自动保存输入�?|
| **TMRUPopupMenu** | `TMRUPopupMenu.svg` | 自动填充最近使用文件列表的弹出菜单�?     |

## 4. 主题与外�?(Theme & Appearance)

| 组件名称               | 对应文件                 | 说明                   |
|:------------------ |:-------------------- |:-------------------- |
| **TThemeComboBox** | `TThemeComboBox.svg` | 主题选择下拉框，支持亮色/暗色分组显示�?|
| **TThemeGallery**  | `TThemeGallery.svg`  | 主题预览画廊，以网格形式展示主题缩略图�?|

## 5. LLM �?AI (LLM Controls)

| 组件名称                 | 对应文件                   | 说明                                     |
|:-------------------- |:---------------------- |:-------------------------------------- |
| **TLLMConfigPanel**  | `TLLMConfigPanel.svg`  | 综合面板，包�?Provider 配置、API Key 管理和调用历史表格�?|
| **TNotificationBar** | `TNotificationBar.svg` | 底部通知栏，用于显示后台 LLM 任务进度和状态�?             |

## 6. 系统与对话框 (System & Dialogs)

| 组件名称                | 对应文件                  | 说明                                  |
|:------------------- |:--------------------- |:----------------------------------- |
| **TWaitForm**       | `TWaitForm.svg`       | 模态等待窗体，支持随机 SVG 动画和进度文本�?           |
| **TLogListView**    | `TLogListView.svg`    | 实时日志显示组件，自动连�?Logger，支持表头分列和颜色分级�?  |
| **TUpdateDialog**   | `TUpdateDialog.svg`   | (TAutoUpdater) 发现新版本时弹出的更新提示与下载对话框�?|
| **TFeedbackDialog** | `TFeedbackDialog.svg` | 用户反馈对话框，支持输入内容、附带日志和系统信息�?          |
| **TDBInitWizard**   | `TDBInitWizard.svg`   | 数据库初始化向导，用于首次运行时的环境配置�?             |

## 7. DeepBase Studio 工具界面 (Studio Interfaces)

这些�?DeepBase Studio 独立管理工具的核心功能界面�?

| 组件名称                         | 对应文件                           | 说明                                 |
|:---------------------------- |:------------------------------ |:---------------------------------- |
| **Studio_MainWindow**        | `Studio_MainWindow.svg`        | Studio 主界面框架，包含导航栏和多标签页工作区�?       |
| **Studio_ProjectManager**    | `Studio_ProjectManager.svg`    | 项目管理界面，用于切换、创建和配置 config.db�?      |
| **Studio_TranslationEditor** | `Studio_TranslationEditor.svg` | 专业�?i18n 翻译网格，支持多语言对照、状态标记和 AI 翻译�?|
| **Studio_LogViewer**         | `Studio_LogViewer.svg`         | 高级日志查看器，支持按级�?时间筛选、全文搜索和堆栈详情�?     |
| **Studio_HotkeyEditor**      | `Studio_HotkeyEditor.svg`      | 快捷键可视化编辑器，支持冲突检测和按键录制�?            |
| **Studio_LicenseManager**    | `Studio_LicenseManager.svg`    | License 生成与管理界面，支持密钥生成和激活状态查看�?    |

## 8. 通用功能对话�?(Common Dialogs)

|| 组件名称                     | 对应文件                       | 说明                        |
||:------------------------ |:-------------------------- |:------------------------- |
|| **TInputDialog**         | `TInputDialog.svg`         | 通用多行输入对话框，支持缩放、字数统计和自定义提示�?|
|| **Dialog_About**         | `Dialog_About.svg`         | 标准关于窗体，显示版本、版权、组件列表和系统信息�?|
|| **Dialog_BackupRestore** | `Dialog_BackupRestore.svg` | 配置数据库的备份与恢复对话框�?          |
|| **Dialog_ExportWizard**  | `Dialog_ExportWizard.svg`  | 通用数据导出向导（用于日志、翻译、配置导出）�?  |

## 9. 认证与授权控�?(Authentication & License)

| 组件名称                    | 对应文件                      | 说明                          |
|:----------------------- |:------------------------- |:--------------------------- |
| **TLicenseStatusPanel** | `TLicenseStatusPanel.svg` | 用户信息展示卡片，显示订阅状态、额度进度、重置日期等�?|
| **TLicenseAuthDialog**  | `TLicenseAuthDialog.svg`  | 卡密验证对话框，支持在线激活和设备码显示�?      |
