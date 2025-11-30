# UniBase CLI 工具参考手册

> 版本: 1.0 | 最后更新: 2025-11-29

UniBase CLI 是一个命令行工具，用于数据库管理、国际化处理和配置管理。适合在脚本、CI/CD 流程或终端中使用。

---

## 目录

1. [安装与配置](#安装与配置)
2. [基本用法](#基本用法)
3. [数据库命令 (db)](#数据库命令-db)
4. [国际化命令 (i18n)](#国际化命令-i18n)
5. [配置命令 (config)](#配置命令-config)
6. [全局选项](#全局选项)
7. [退出码](#退出码)
8. [示例场景](#示例场景)
9. [常见问题](#常见问题)

---

## 安装与配置

### 系统要求

- Windows 7/8/10/11
- 命令提示符 (CMD) 或 PowerShell

### 安装方式

1. 将 `UniBaseCLI.exe` 放入 PATH 环境变量目录
2. 或直接使用完整路径运行

### 验证安装

```cmd
UniBaseCLI --version
```

输出示例：
```
UniBase CLI v1.0.0
```

### 获取帮助

```cmd
UniBaseCLI --help
UniBaseCLI <command> --help
```

---

## 基本用法

### 命令格式

```
UniBaseCLI <command> <subcommand> [options] [arguments]
```

### 主要命令

| 命令 | 说明 |
|------|------|
| db | 数据库管理 |
| i18n | 国际化处理 |
| config | 配置管理 |

### 示例

```cmd
# 数据库初始化
UniBaseCLI db init --path "D:\Data\app.db"

# 扫描国际化字符串
UniBaseCLI i18n scan --source "D:\Project\src"

# 获取配置值
UniBaseCLI config get app.name
```

---

## 数据库命令 (db)

数据库命令用于管理 SQLite 数据库。

### 子命令概览

| 子命令 | 说明 |
|--------|------|
| init | 初始化数据库 |
| upgrade | 升级数据库架构 |
| backup | 备份数据库 |
| check | 检查数据库完整性 |

---

### db init

初始化新的数据库文件。

**语法：**
```
UniBaseCLI db init [options]
```

**选项：**
| 选项 | 简写 | 说明 | 默认值 |
|------|------|------|--------|
| --path | -p | 数据库文件路径 | ./data/app.db |
| --schema | -s | 架构文件路径 | 内置架构 |
| --force | -f | 强制覆盖已存在的文件 | false |
| --encoding | -e | 数据库编码 | UTF-8 |

**示例：**
```cmd
# 使用默认路径初始化
UniBaseCLI db init

# 指定路径
UniBaseCLI db init --path "D:\Data\myapp.db"

# 使用自定义架构
UniBaseCLI db init --path "D:\Data\myapp.db" --schema "D:\Schema\custom.sql"

# 强制覆盖
UniBaseCLI db init --path "D:\Data\myapp.db" --force
```

**输出示例：**
```
[INFO] Creating database: D:\Data\myapp.db
[INFO] Applying schema...
[INFO] Creating tables...
[OK] Database initialized successfully.
```

---

### db upgrade

升级数据库架构到最新版本。

**语法：**
```
UniBaseCLI db upgrade [options]
```

**选项：**
| 选项 | 简写 | 说明 | 默认值 |
|------|------|------|--------|
| --path | -p | 数据库文件路径 | ./data/app.db |
| --migrations | -m | 迁移脚本目录 | ./migrations |
| --target | -t | 目标版本号 | 最新版本 |
| --dry-run | -n | 仅显示将执行的操作 | false |

**示例：**
```cmd
# 升级到最新版本
UniBaseCLI db upgrade --path "D:\Data\app.db"

# 升级到指定版本
UniBaseCLI db upgrade --path "D:\Data\app.db" --target 5

# 预览升级操作
UniBaseCLI db upgrade --path "D:\Data\app.db" --dry-run
```

**输出示例：**
```
[INFO] Current version: 3
[INFO] Target version: 5
[INFO] Applying migration 004_add_users_table.sql...
[INFO] Applying migration 005_add_settings.sql...
[OK] Database upgraded to version 5.
```

---

### db backup

备份数据库文件。

**语法：**
```
UniBaseCLI db backup [options]
```

**选项：**
| 选项 | 简写 | 说明 | 默认值 |
|------|------|------|--------|
| --path | -p | 数据库文件路径 | ./data/app.db |
| --output | -o | 备份输出路径 | 自动生成 |
| --compress | -c | 压缩备份文件 | false |

**示例：**
```cmd
# 使用默认命名备份
UniBaseCLI db backup --path "D:\Data\app.db"

# 指定输出路径
UniBaseCLI db backup --path "D:\Data\app.db" --output "D:\Backup\app_20251129.db"

# 压缩备份
UniBaseCLI db backup --path "D:\Data\app.db" --compress
```

**输出示例：**
```
[INFO] Source: D:\Data\app.db
[INFO] Backup: D:\Data\app_backup_20251129_143022.db
[OK] Backup created successfully. Size: 2.5 MB
```

---

### db check

检查数据库完整性。

**语法：**
```
UniBaseCLI db check [options]
```

**选项：**
| 选项 | 简写 | 说明 | 默认值 |
|------|------|------|--------|
| --path | -p | 数据库文件路径 | ./data/app.db |
| --repair | -r | 尝试修复问题 | false |
| --verbose | -v | 详细输出 | false |

**示例：**
```cmd
# 基本检查
UniBaseCLI db check --path "D:\Data\app.db"

# 详细检查
UniBaseCLI db check --path "D:\Data\app.db" --verbose

# 检查并修复
UniBaseCLI db check --path "D:\Data\app.db" --repair
```

**输出示例：**
```
[INFO] Checking database: D:\Data\app.db
[INFO] Integrity check: PASSED
[INFO] Schema validation: PASSED
[INFO] Foreign keys: PASSED
[OK] Database is healthy.
```

---

## 国际化命令 (i18n)

国际化命令用于管理多语言资源。

### 子命令概览

| 子命令 | 说明 |
|--------|------|
| scan | 扫描源代码中的字符串 |
| sync | 同步翻译文件 |
| translate | 自动翻译 |
| export | 导出翻译 |
| import | 导入翻译 |

---

### i18n scan

扫描源代码中需要翻译的字符串。

**语法：**
```
UniBaseCLI i18n scan [options]
```

**选项：**
| 选项 | 简写 | 说明 | 默认值 |
|------|------|------|--------|
| --source | -s | 源代码目录 | ./ |
| --output | -o | 输出文件路径 | ./i18n/strings.json |
| --pattern | -p | 文件匹配模式 | *.pas;*.dfm |
| --function | -f | 翻译函数名 | _ |
| --recursive | -r | 递归扫描子目录 | true |

**示例：**
```cmd
# 扫描当前目录
UniBaseCLI i18n scan

# 扫描指定目录
UniBaseCLI i18n scan --source "D:\Project\src"

# 指定输出文件
UniBaseCLI i18n scan --source "D:\Project\src" --output "D:\I18n\strings.json"

# 自定义匹配模式
UniBaseCLI i18n scan --source "D:\Project" --pattern "*.pas;*.inc"
```

**输出示例：**
```
[INFO] Scanning: D:\Project\src
[INFO] Pattern: *.pas;*.dfm
[INFO] Found 156 translatable strings
[INFO] New strings: 23
[INFO] Existing strings: 133
[OK] Output: D:\I18n\strings.json
```

---

### i18n sync

同步翻译文件，更新缺失的翻译键。

**语法：**
```
UniBaseCLI i18n sync [options]
```

**选项：**
| 选项 | 简写 | 说明 | 默认值 |
|------|------|------|--------|
| --source | -s | 源语言文件 | ./i18n/zh-CN.json |
| --target | -t | 目标语言文件 | 所有语言文件 |
| --remove-unused | -u | 删除未使用的键 | false |

**示例：**
```cmd
# 同步所有语言
UniBaseCLI i18n sync --source "./i18n/zh-CN.json"

# 同步到指定语言
UniBaseCLI i18n sync --source "./i18n/zh-CN.json" --target "./i18n/en-US.json"

# 删除未使用的键
UniBaseCLI i18n sync --source "./i18n/zh-CN.json" --remove-unused
```

**输出示例：**
```
[INFO] Source: zh-CN.json (156 keys)
[INFO] Syncing: en-US.json
  - Added: 23 keys
  - Removed: 5 keys
[INFO] Syncing: ja-JP.json
  - Added: 23 keys
  - Removed: 5 keys
[OK] Sync completed.
```

---

### i18n translate

自动翻译未翻译的字符串。

**语法：**
```
UniBaseCLI i18n translate [options]
```

**选项：**
| 选项 | 简写 | 说明 | 默认值 |
|------|------|------|--------|
| --input | -i | 输入翻译文件 | - |
| --from | -f | 源语言代码 | zh-CN |
| --to | -t | 目标语言代码 | en-US |
| --engine | -e | 翻译引擎 | google |
| --api-key | -k | API 密钥 | 环境变量 |

**支持的翻译引擎：**
- google - Google Translate
- deepl - DeepL
- azure - Azure Translator
- baidu - 百度翻译

**示例：**
```cmd
# 使用 Google 翻译
UniBaseCLI i18n translate --input "./i18n/zh-CN.json" --to "en-US"

# 使用 DeepL
UniBaseCLI i18n translate --input "./i18n/zh-CN.json" --to "ja-JP" --engine deepl

# 指定 API 密钥
UniBaseCLI i18n translate --input "./i18n/zh-CN.json" --to "en-US" --api-key "your-key"
```

**输出示例：**
```
[INFO] Input: ./i18n/zh-CN.json
[INFO] Translating: zh-CN -> en-US
[INFO] Engine: Google Translate
[INFO] Progress: 23/23 strings
[OK] Translation completed. Output: ./i18n/en-US.json
```

---

### i18n export

导出翻译为指定格式。

**语法：**
```
UniBaseCLI i18n export [options]
```

**选项：**
| 选项 | 简写 | 说明 | 默认值 |
|------|------|------|--------|
| --input | -i | 输入翻译文件/目录 | ./i18n |
| --output | -o | 输出文件路径 | - |
| --format | -f | 输出格式 | csv |
| --languages | -l | 导出的语言 | 全部 |

**支持的格式：**
- csv - CSV 表格
- xlsx - Excel 文件
- po - GNU gettext PO
- xliff - XLIFF 2.0
- json - JSON 文件

**示例：**
```cmd
# 导出为 CSV
UniBaseCLI i18n export --input "./i18n" --output "./export/strings.csv"

# 导出为 Excel
UniBaseCLI i18n export --input "./i18n" --output "./export/strings.xlsx" --format xlsx

# 导出指定语言
UniBaseCLI i18n export --input "./i18n" --output "./export/strings.csv" --languages "zh-CN,en-US"
```

**输出示例：**
```
[INFO] Exporting translations...
[INFO] Languages: zh-CN, en-US, ja-JP
[INFO] Strings: 156
[OK] Exported to: ./export/strings.csv
```

---

### i18n import

从外部文件导入翻译。

**语法：**
```
UniBaseCLI i18n import [options]
```

**选项：**
| 选项 | 简写 | 说明 | 默认值 |
|------|------|------|--------|
| --input | -i | 输入文件路径 | - |
| --output | -o | 输出目录 | ./i18n |
| --format | -f | 输入格式 | 自动检测 |
| --merge | -m | 合并模式 | overwrite |

**合并模式：**
- overwrite - 覆盖已有翻译
- skip - 跳过已有翻译
- prompt - 提示用户选择

**示例：**
```cmd
# 从 CSV 导入
UniBaseCLI i18n import --input "./import/strings.csv"

# 指定输出目录
UniBaseCLI i18n import --input "./import/strings.csv" --output "./i18n"

# 跳过已有翻译
UniBaseCLI i18n import --input "./import/strings.csv" --merge skip
```

**输出示例：**
```
[INFO] Importing: ./import/strings.csv
[INFO] Format: CSV (auto-detected)
[INFO] Languages found: zh-CN, en-US, ja-JP
[INFO] Imported: 156 strings
[INFO] Updated: 45 strings
[INFO] Skipped: 111 strings
[OK] Import completed.
```

---

## 配置命令 (config)

配置命令用于管理应用程序配置。

### 子命令概览

| 子命令 | 说明 |
|--------|------|
| get | 获取配置值 |
| set | 设置配置值 |
| export | 导出配置 |
| import | 导入配置 |

---

### config get

获取配置项的值。

**语法：**
```
UniBaseCLI config get <key> [options]
```

**参数：**
| 参数 | 说明 |
|------|------|
| key | 配置键名，支持点号分隔的路径 |

**选项：**
| 选项 | 简写 | 说明 | 默认值 |
|------|------|------|--------|
| --config | -c | 配置文件路径 | ./config/app.ini |
| --format | -f | 输出格式 | value |

**输出格式：**
- value - 仅输出值
- json - JSON 格式
- line - key=value 格式

**示例：**
```cmd
# 获取单个值
UniBaseCLI config get app.name

# 获取嵌套值
UniBaseCLI config get database.connection.host

# JSON 格式输出
UniBaseCLI config get app --format json

# 指定配置文件
UniBaseCLI config get app.name --config "D:\Config\myapp.ini"
```

**输出示例：**
```
# value 格式
MyApplication

# json 格式
{"name": "MyApplication", "version": "1.0.0"}

# line 格式
app.name=MyApplication
```

---

### config set

设置配置项的值。

**语法：**
```
UniBaseCLI config set <key> <value> [options]
```

**参数：**
| 参数 | 说明 |
|------|------|
| key | 配置键名 |
| value | 配置值 |

**选项：**
| 选项 | 简写 | 说明 | 默认值 |
|------|------|------|--------|
| --config | -c | 配置文件路径 | ./config/app.ini |
| --type | -t | 值类型 | string |
| --create | - | 创建不存在的键 | true |

**值类型：**
- string - 字符串
- int - 整数
- float - 浮点数
- bool - 布尔值
- json - JSON 对象

**示例：**
```cmd
# 设置字符串
UniBaseCLI config set app.name "MyApplication"

# 设置整数
UniBaseCLI config set app.port 8080 --type int

# 设置布尔值
UniBaseCLI config set app.debug true --type bool

# 设置 JSON
UniBaseCLI config set database.servers "[\"server1\",\"server2\"]" --type json
```

**输出示例：**
```
[OK] Set app.name = "MyApplication"
```

---

### config export

导出配置到文件。

**语法：**
```
UniBaseCLI config export [options]
```

**选项：**
| 选项 | 简写 | 说明 | 默认值 |
|------|------|------|--------|
| --config | -c | 配置文件路径 | ./config/app.ini |
| --output | -o | 输出文件路径 | stdout |
| --format | -f | 输出格式 | ini |
| --section | -s | 导出的节 | 全部 |

**输出格式：**
- ini - INI 格式
- json - JSON 格式
- yaml - YAML 格式
- env - 环境变量格式

**示例：**
```cmd
# 导出为 JSON
UniBaseCLI config export --format json --output "./config.json"

# 导出指定节
UniBaseCLI config export --section "database" --format json

# 导出为环境变量格式
UniBaseCLI config export --format env --output "./.env"
```

**输出示例：**
```
[INFO] Exporting configuration...
[INFO] Source: ./config/app.ini
[INFO] Format: JSON
[OK] Exported to: ./config.json
```

---

### config import

从文件导入配置。

**语法：**
```
UniBaseCLI config import [options]
```

**选项：**
| 选项 | 简写 | 说明 | 默认值 |
|------|------|------|--------|
| --input | -i | 输入文件路径 | - |
| --config | -c | 目标配置文件 | ./config/app.ini |
| --format | -f | 输入格式 | 自动检测 |
| --merge | -m | 合并模式 | overwrite |

**示例：**
```cmd
# 从 JSON 导入
UniBaseCLI config import --input "./config.json"

# 从环境变量文件导入
UniBaseCLI config import --input "./.env" --format env

# 合并而非覆盖
UniBaseCLI config import --input "./config.json" --merge merge
```

**输出示例：**
```
[INFO] Importing configuration...
[INFO] Source: ./config.json
[INFO] Format: JSON (auto-detected)
[INFO] Imported: 25 settings
[OK] Configuration updated.
```

---

## 全局选项

以下选项适用于所有命令：

| 选项 | 简写 | 说明 |
|------|------|------|
| --help | -h | 显示帮助信息 |
| --version | -V | 显示版本号 |
| --verbose | -v | 详细输出模式 |
| --quiet | -q | 静默模式（仅错误） |
| --no-color | - | 禁用彩色输出 |
| --log | -l | 日志文件路径 |

**示例：**
```cmd
# 详细模式
UniBaseCLI db check --verbose

# 静默模式
UniBaseCLI db backup --quiet

# 输出到日志文件
UniBaseCLI i18n scan --log "./cli.log"
```

---

## 退出码

| 退出码 | 说明 |
|--------|------|
| 0 | 成功 |
| 1 | 一般错误 |
| 2 | 命令行参数错误 |
| 3 | 文件/路径不存在 |
| 4 | 权限不足 |
| 5 | 数据库错误 |
| 6 | 网络错误 |
| 7 | 配置错误 |

**在脚本中使用：**
```cmd
UniBaseCLI db check --path "D:\Data\app.db"
if %ERRORLEVEL% neq 0 (
    echo Database check failed!
    exit /b 1
)
```

```powershell
UniBaseCLI db check --path "D:\Data\app.db"
if ($LASTEXITCODE -ne 0) {
    Write-Error "Database check failed!"
    exit 1
}
```

---

## 示例场景

### 场景 1: CI/CD 数据库迁移

```cmd
@echo off
echo === Database Migration ===

REM 备份当前数据库
UniBaseCLI db backup --path "%DB_PATH%" --compress
if %ERRORLEVEL% neq 0 exit /b 1

REM 执行迁移
UniBaseCLI db upgrade --path "%DB_PATH%" --migrations "./migrations"
if %ERRORLEVEL% neq 0 (
    echo Migration failed, restoring backup...
    copy /Y "%BACKUP_PATH%" "%DB_PATH%"
    exit /b 1
)

REM 验证数据库
UniBaseCLI db check --path "%DB_PATH%"
if %ERRORLEVEL% neq 0 exit /b 1

echo === Migration completed ===
```

### 场景 2: 国际化工作流

```cmd
@echo off
echo === I18n Workflow ===

REM 扫描源代码
UniBaseCLI i18n scan --source "./src" --output "./i18n/strings.json"

REM 同步到各语言文件
UniBaseCLI i18n sync --source "./i18n/zh-CN.json"

REM 自动翻译新字符串
UniBaseCLI i18n translate --input "./i18n/zh-CN.json" --to "en-US"
UniBaseCLI i18n translate --input "./i18n/zh-CN.json" --to "ja-JP"

REM 导出供翻译团队审核
UniBaseCLI i18n export --input "./i18n" --output "./export/translations.xlsx" --format xlsx

echo === I18n workflow completed ===
```

### 场景 3: 配置管理

```powershell
# 根据环境切换配置
$env = $args[0]  # dev, staging, prod

# 导入基础配置
UniBaseCLI config import --input "./config/base.json"

# 导入环境特定配置
UniBaseCLI config import --input "./config/$env.json" --merge merge

# 设置环境标识
UniBaseCLI config set app.environment $env

# 验证配置
$dbHost = UniBaseCLI config get database.host
Write-Host "Database host: $dbHost"
```

### 场景 4: 定期备份脚本

```powershell
# backup.ps1 - 每日备份脚本
$date = Get-Date -Format "yyyyMMdd"
$backupDir = "D:\Backups\$date"

# 创建备份目录
New-Item -ItemType Directory -Path $backupDir -Force

# 备份数据库
UniBaseCLI db backup --path "D:\Data\app.db" --output "$backupDir\app.db" --compress

# 导出配置
UniBaseCLI config export --format json --output "$backupDir\config.json"

# 导出翻译
UniBaseCLI i18n export --input "./i18n" --output "$backupDir\i18n.json" --format json

# 清理 30 天前的备份
Get-ChildItem "D:\Backups" -Directory | Where-Object {
    $_.CreationTime -lt (Get-Date).AddDays(-30)
} | Remove-Item -Recurse -Force

Write-Host "Backup completed: $backupDir"
```

---

## 常见问题

### Q: 如何在无人值守模式下运行？

**A:** 使用 `--quiet` 选项并检查退出码：
```cmd
UniBaseCLI db upgrade --quiet
if %ERRORLEVEL% neq 0 exit /b 1
```

### Q: 如何设置默认配置文件路径？

**A:** 设置环境变量：
```cmd
set UNIBASE_CONFIG=D:\Config\app.ini
```
```powershell
$env:UNIBASE_CONFIG = "D:\Config\app.ini"
```

### Q: 翻译 API 密钥如何安全存储？

**A:** 使用环境变量：
```cmd
set UNIBASE_TRANSLATE_API_KEY=your-api-key
UniBaseCLI i18n translate --input "./i18n/zh-CN.json" --to "en-US"
```

### Q: 如何查看命令执行详情？

**A:** 使用 `--verbose` 选项：
```cmd
UniBaseCLI db upgrade --verbose
```

### Q: 输出乱码怎么办？

**A:** 确保终端使用 UTF-8 编码：
```cmd
chcp 65001
UniBaseCLI i18n scan
```

### Q: 如何在 PowerShell 中使用管道？

**A:** CLI 支持标准输入输出：
```powershell
# 输出到文件
UniBaseCLI config export --format json | Out-File config.json -Encoding UTF8

# 与其他命令组合
UniBaseCLI config get app | ConvertFrom-Json | Select-Object name, version
```

---

## 环境变量

| 变量 | 说明 |
|------|------|
| UNIBASE_CONFIG | 默认配置文件路径 |
| UNIBASE_DB_PATH | 默认数据库路径 |
| UNIBASE_I18N_DIR | 默认国际化目录 |
| UNIBASE_TRANSLATE_API_KEY | 翻译 API 密钥 |
| UNIBASE_LOG_LEVEL | 日志级别 (debug/info/warn/error) |

---

## 命令速查表

### 数据库命令
```cmd
UniBaseCLI db init --path <path>
UniBaseCLI db upgrade --path <path> [--target <version>]
UniBaseCLI db backup --path <path> [--output <path>] [--compress]
UniBaseCLI db check --path <path> [--repair]
```

### 国际化命令
```cmd
UniBaseCLI i18n scan --source <dir> [--output <file>]
UniBaseCLI i18n sync --source <file> [--target <file>]
UniBaseCLI i18n translate --input <file> --to <lang> [--engine <engine>]
UniBaseCLI i18n export --input <dir> --output <file> [--format <fmt>]
UniBaseCLI i18n import --input <file> [--output <dir>]
```

### 配置命令
```cmd
UniBaseCLI config get <key> [--format <fmt>]
UniBaseCLI config set <key> <value> [--type <type>]
UniBaseCLI config export [--format <fmt>] [--output <file>]
UniBaseCLI config import --input <file> [--merge <mode>]
```

---

*文档版本: 1.0*
*最后更新: 2025-11-29*
