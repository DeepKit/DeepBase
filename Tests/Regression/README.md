# DeepBase 回归测试目录

## 概述

本目录包含针�?DeepBase 框架已修�?Bug 的回归测试。每个测试确保特定的 Bug 修复不会在后续开发中被意外破坏�?

## 目录结构

```
Tests/Regression/
├── README.md                              # 本文�?
├── Test.Regression.Base.pas               # 回归测试基类
├── RegressionTestRegistry.pas             # 测试注册�?
├── BugTestMapping.md                      # Bug-测试映射文档
├── Test.Regression.BUG058_XOREncryption.pas
├── Test.Regression.BUG062_PluginSandbox.pas
└── ...
```

## 命名规范

所有回归测试文件必须遵循以下命名格式：

```
Test.Regression.BUG{number}_{ShortDescription}.pas
```

示例�?
- `Test.Regression.BUG058_XOREncryption.pas`
- `Test.Regression.BUG062_PluginSandbox.pas`

## 测试分类

使用 DUnitX �?`[Category]` 属性对测试进行分类�?

| 分类 | 说明 |
|------|------|
| `Regression` | 所有回归测试必须包含此分类 |
| `P0` | Critical 级别 Bug |
| `P1` | High 级别 Bug |
| `P2` | Medium 级别 Bug |
| `P3` | Low 级别 Bug |
| `Security` | 安全相关 Bug |
| `Memory` | 内存相关 Bug |
| `Concurrency` | 并发相关 Bug |

## 如何添加新的回归测试

1. 创建测试文件，遵循命名规�?
2. 继承 `TRegressionTestBase` 基类
3. 实现必要的抽象方法：
   - `GetBugNumber`: 返回 Bug 编号（如 'BUG-058'�?
   - `GetBugDescription`: 返回 Bug 描述
   - `GetFixDate`: 返回修复日期
4. 添加测试方法，使�?`[Test]` 属�?
5. 添加适当�?`[Category]` 属�?
6. 在测试类上方添加文档注释，说明原问题和修复方�?
7. 更新 `RegressionTestRegistry.pas` �?`Tests/Regression/BugTestMapping.md`

## 测试模板

```pascal
unit Test.Regression.BUGxxx_Description;

interface

uses
  DUnitX.TestFramework,
  Test.Regression.Base;

type
  /// <summary>
  /// BUG-xxx: [Bug 标题]
  /// 
  /// 原问�? [描述原始问题]
  /// 修复方案: [描述修复方案]
  /// 修复日期: [YYYY-MM-DD]
  /// 文件: [受影响的源文件]
  /// </summary>
  [TestFixture]
  [Category('Regression')]
  [Category('Px')]  // P0, P1, P2, P3
  TBugxxx_DescriptionTest = class(TRegressionTestBase)
  protected
    function GetBugNumber: string; override;
    function GetBugDescription: string; override;
    function GetFixDate: string; override;
  public
    [Test]
    [Description('测试描述')]
    procedure Test_SomeScenario;
  end;

implementation

// ... 实现 ...

end.
```

## 运行回归测试

```powershell
# 只运行回归测�?
.\Scripts\run_tests.ps1 -Type Regression

# 运行所有测试（包括回归测试�?
.\Scripts\run_tests.ps1 -Type All

# 只运�?P0 级别回归测试
.\Tests\DeepBaseTests.exe --include:P0 --include:Regression
```

## 相关文档

- [Bug 修复记录](../../bugfix.md)
- [安全与测试](../../docs/07.03.DeepBase-4H-安全与测�?v1.0.md)
