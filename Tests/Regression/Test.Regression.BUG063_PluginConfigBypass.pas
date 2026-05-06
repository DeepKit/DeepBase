{ ============================================================================
  Test.Regression.BUG063_PluginConfigBypass - 插件配置权限绕过回归测试

  BUG-063: 插件配置权限绕过
  
  原问题: 插件可以通过SetConfig修改任意配置，包括系统级和安全相关配置，
          存在权限提升风险。
  
  修复方案: 实现基于角色的配置访问控制，限制插件只能修改 Plugin. 前缀的配置，
            并禁止修改包含安全关键字的配置项。
  
  修复日期: 2025-01-27
  文件: Core/UniBase.PluginManager.pas
  优先级: P0 (Critical)
  分类: Security
  ============================================================================ }

unit Test.Regression.BUG063_PluginConfigBypass;

interface

uses
  System.SysUtils,
  System.IOUtils,
  DUnitX.TestFramework,
  Test.Regression.Base;

type
  [TestFixture]
  [Category('Regression')]
  [Category('P0')]
  [Category('Security')]
  TBug063_PluginConfigBypassTest = class(TRegressionTestBase)
  private
    FTempDir: string;
  protected
    function GetBugNumber: string; override;
    function GetBugDescription: string; override;
    function GetFixDate: string; override;
    function GetPriority: string; override;
    function GetAffectedFile: string; override;
  public
    [Setup]
    procedure SetUp; override;
    [TearDown]
    procedure TearDown; override;
    
    [Test]
    [Description('验证插件无法修改系统级配置')]
    procedure Test_PluginCannotModifySystemConfig;
    
    [Test]
    [Description('验证插件无法修改安全相关配置 - password')]
    procedure Test_PluginCannotModifyPasswordConfig;
    
    [Test]
    [Description('验证插件无法修改安全相关配置 - secret')]
    procedure Test_PluginCannotModifySecretConfig;
    
    [Test]
    [Description('验证插件无法修改安全相关配置 - token')]
    procedure Test_PluginCannotModifyTokenConfig;
    
    [Test]
    [Description('验证插件无法修改安全相关配置 - key')]
    procedure Test_PluginCannotModifyKeyConfig;
    
    [Test]
    [Description('验证插件可以修改自己的配置 (Plugin.前缀)')]
    procedure Test_PluginCanModifyOwnConfig;
    
    [Test]
    [Description('验证配置前缀检查区分大小写')]
    procedure Test_ConfigPrefixIsCaseSensitive;
  end;

implementation

uses
  UniBase.PluginManager;

{ TBug063_PluginConfigBypassTest }

function TBug063_PluginConfigBypassTest.GetBugNumber: string;
begin
  Result := 'BUG-063';
end;

function TBug063_PluginConfigBypassTest.GetBugDescription: string;
begin
  Result := '插件配置权限绕过';
end;

function TBug063_PluginConfigBypassTest.GetFixDate: string;
begin
  Result := '2025-01-27';
end;

function TBug063_PluginConfigBypassTest.GetPriority: string;
begin
  Result := 'P0';
end;

function TBug063_PluginConfigBypassTest.GetAffectedFile: string;
begin
  Result := 'Core/UniBase.PluginManager.pas';
end;

procedure TBug063_PluginConfigBypassTest.SetUp;
begin
  inherited;
  FTempDir := CreateTempTestDir;
end;

procedure TBug063_PluginConfigBypassTest.TearDown;
begin
  CleanupTempTestDir(FTempDir);
  inherited;
end;

procedure TBug063_PluginConfigBypassTest.Test_PluginCannotModifySystemConfig;
var
  Context: TPluginContext;
  ExceptionRaised: Boolean;
  ExceptionType: string;
begin
  LogTestStart('Test_PluginCannotModifySystemConfig');
  
  Context := TPluginContext.Create(nil, nil, nil, nil, FTempDir);
  try
    ExceptionRaised := False;
    ExceptionType := '';
    
    try
      // 尝试修改系统级配置
      Context.SetConfig('System.Language', 'zh-CN');
    except
      on E: EArgumentException do
      begin
        ExceptionRaised := True;
        ExceptionType := 'EArgumentException';
      end;
      on E: Exception do
      begin
        ExceptionRaised := True;
        ExceptionType := E.ClassName;
      end;
    end;
    
    Assert.IsTrue(ExceptionRaised, '插件修改系统配置应该抛出异常');
    Assert.AreEqual('EArgumentException', ExceptionType, 
      '应该抛出 EArgumentException 表示参数无效');
  finally
    Context.Free;
  end;
  
  LogTestEnd('Test_PluginCannotModifySystemConfig', True);
end;

procedure TBug063_PluginConfigBypassTest.Test_PluginCannotModifyPasswordConfig;
var
  Context: TPluginContext;
  ExceptionRaised: Boolean;
begin
  LogTestStart('Test_PluginCannotModifyPasswordConfig');
  
  Context := TPluginContext.Create(nil, nil, nil, nil, FTempDir);
  try
    ExceptionRaised := False;
    
    try
      // 尝试修改包含 password 的配置
      Context.SetConfig('Plugin.MyPlugin.password', 'stolen');
    except
      on E: EInvalidOpException do
        ExceptionRaised := True;
    end;
    
    Assert.IsTrue(ExceptionRaised, 
      '插件修改包含 password 的配置应该抛出 EInvalidOpException');
  finally
    Context.Free;
  end;
  
  LogTestEnd('Test_PluginCannotModifyPasswordConfig', True);
end;

procedure TBug063_PluginConfigBypassTest.Test_PluginCannotModifySecretConfig;
var
  Context: TPluginContext;
  ExceptionRaised: Boolean;
begin
  LogTestStart('Test_PluginCannotModifySecretConfig');
  
  Context := TPluginContext.Create(nil, nil, nil, nil, FTempDir);
  try
    ExceptionRaised := False;
    
    try
      Context.SetConfig('Plugin.MyPlugin.api_secret', 'stolen');
    except
      on E: EInvalidOpException do
        ExceptionRaised := True;
    end;
    
    Assert.IsTrue(ExceptionRaised, 
      '插件修改包含 secret 的配置应该抛出 EInvalidOpException');
  finally
    Context.Free;
  end;
  
  LogTestEnd('Test_PluginCannotModifySecretConfig', True);
end;

procedure TBug063_PluginConfigBypassTest.Test_PluginCannotModifyTokenConfig;
var
  Context: TPluginContext;
  ExceptionRaised: Boolean;
begin
  LogTestStart('Test_PluginCannotModifyTokenConfig');
  
  Context := TPluginContext.Create(nil, nil, nil, nil, FTempDir);
  try
    ExceptionRaised := False;
    
    try
      Context.SetConfig('Plugin.MyPlugin.access_token', 'stolen');
    except
      on E: EInvalidOpException do
        ExceptionRaised := True;
    end;
    
    Assert.IsTrue(ExceptionRaised, 
      '插件修改包含 token 的配置应该抛出 EInvalidOpException');
  finally
    Context.Free;
  end;
  
  LogTestEnd('Test_PluginCannotModifyTokenConfig', True);
end;

procedure TBug063_PluginConfigBypassTest.Test_PluginCannotModifyKeyConfig;
var
  Context: TPluginContext;
  ExceptionRaised: Boolean;
begin
  LogTestStart('Test_PluginCannotModifyKeyConfig');
  
  Context := TPluginContext.Create(nil, nil, nil, nil, FTempDir);
  try
    ExceptionRaised := False;
    
    try
      Context.SetConfig('Plugin.MyPlugin.api_key', 'stolen');
    except
      on E: EInvalidOpException do
        ExceptionRaised := True;
    end;
    
    Assert.IsTrue(ExceptionRaised, 
      '插件修改包含 key 的配置应该抛出 EInvalidOpException');
  finally
    Context.Free;
  end;
  
  LogTestEnd('Test_PluginCannotModifyKeyConfig', True);
end;

procedure TBug063_PluginConfigBypassTest.Test_PluginCanModifyOwnConfig;
var
  Context: TPluginContext;
  ConfigSet: Boolean;
  SetValue: string;
begin
  LogTestStart('Test_PluginCanModifyOwnConfig');
  
  ConfigSet := False;
  SetValue := '';
  
  Context := TPluginContext.Create(
    nil,
    procedure(const Key, Value: string)
    begin
      ConfigSet := True;
      SetValue := Value;
    end,
    nil, nil, FTempDir);
  try
    // 设置合法的插件配置
    Context.SetConfig('Plugin.MyPlugin.DisplayName', 'Test Plugin');
    
    Assert.IsTrue(ConfigSet, '合法的插件配置应该被设置');
    Assert.AreEqual('Test Plugin', SetValue, '配置值应该正确传递');
  finally
    Context.Free;
  end;
  
  LogTestEnd('Test_PluginCanModifyOwnConfig', True);
end;

procedure TBug063_PluginConfigBypassTest.Test_ConfigPrefixIsCaseSensitive;
var
  Context: TPluginContext;
  ExceptionRaised: Boolean;
begin
  LogTestStart('Test_ConfigPrefixIsCaseSensitive');
  
  Context := TPluginContext.Create(nil, nil, nil, nil, FTempDir);
  try
    // 测试小写 plugin. 前缀（应该失败，因为要求 Plugin.）
    ExceptionRaised := False;
    try
      Context.SetConfig('plugin.MyPlugin.Setting', 'value');
    except
      on E: EArgumentException do
        ExceptionRaised := True;
    end;
    
    Assert.IsTrue(ExceptionRaised, 
      '小写 plugin. 前缀应该被拒绝（要求 Plugin.）');
  finally
    Context.Free;
  end;
  
  LogTestEnd('Test_ConfigPrefixIsCaseSensitive', True);
end;

initialization
  TDUnitX.RegisterTestFixture(TBug063_PluginConfigBypassTest);

end.
