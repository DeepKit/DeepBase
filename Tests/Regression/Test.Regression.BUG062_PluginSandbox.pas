{ ============================================================================
  Test.Regression.BUG062_PluginSandbox - 插件沙箱逃逸风险回归测�?

  BUG-062: 插件沙箱逃逸风�?
  
  原问�? 插件加载缺乏安全验证，存在路径遍历和代码完整性风险�?
          恶意插件可能通过 ../.. 路径访问系统敏感文件�?
  
  修复方案: 添加插件路径验证 (IsValidPluginPath) 和数字签名验证机�?
            (VerifyPluginSignature)，确保插件只能从指定目录加载�?
  
  修复日期: 2025-01-27
  文件: Core/DeepBase.PluginManager.pas
  优先�? P0 (Critical)
  分类: Security
  ============================================================================ }

unit Test.Regression.BUG062_PluginSandbox;

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  DUnitX.TestFramework,
  Test.Regression.Base,
  DeepBase.Plugin;

type
  [TestFixture]
  [Category('Regression')]
  [Category('P0')]
  [Category('Security')]
  TBug062_PluginSandboxTest = class(TRegressionTestBase)
  private
    FTempPluginsDir: string;
    FErrorFired: Boolean;
    FLastErrorMessage: string;
    procedure HandlePluginError(Sender: TObject; const Args: TPluginErrorEventArgs);
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
    [Description('验证路径遍历攻击被阻�?- 使用 ../ 尝试逃�?)]
    procedure Test_PathTraversal_WithDotDot_ShouldBeBlocked;
    
    [Test]
    [Description('验证绝对路径攻击被阻�?)]
    procedure Test_AbsolutePath_OutsidePluginsDir_ShouldBeBlocked;
    
    [Test]
    [Description('验证合法插件路径被允�?)]
    procedure Test_ValidPluginPath_ShouldBeAllowed;
    
    [Test]
    [Description('验证�?BPL 文件被拒�?)]
    procedure Test_NonBPLFile_ShouldBeRejected;
    
    [Test]
    [Description('验证插件配置访问控制 - 只能修改 Plugin. 前缀的配�?)]
    procedure Test_PluginConfigAccess_ShouldBeLimited;
  end;

implementation

uses
  DeepBase.PluginManager;

{ TBug062_PluginSandboxTest }

function TBug062_PluginSandboxTest.GetBugNumber: string;
begin
  Result := 'BUG-062';
end;

function TBug062_PluginSandboxTest.GetBugDescription: string;
begin
  Result := '插件沙箱逃逸风�?;
end;

function TBug062_PluginSandboxTest.GetFixDate: string;
begin
  Result := '2025-01-27';
end;

function TBug062_PluginSandboxTest.GetPriority: string;
begin
  Result := 'P0';
end;

function TBug062_PluginSandboxTest.GetAffectedFile: string;
begin
  Result := 'Core/DeepBase.PluginManager.pas';
end;

procedure TBug062_PluginSandboxTest.SetUp;
begin
  inherited;
  // 创建临时插件目录
  FTempPluginsDir := TPath.Combine(TPath.GetTempPath, 'DeepBasePluginTest_' + IntToStr(TThread.GetTickCount));
  TDirectory.CreateDirectory(FTempPluginsDir);
end;

procedure TBug062_PluginSandboxTest.TearDown;
begin
  // 清理临时目录
  if TDirectory.Exists(FTempPluginsDir) then
  begin
    try
      TDirectory.Delete(FTempPluginsDir, True);
    except
      // 忽略清理错误
    end;
  end;
  inherited;
end;

procedure TBug062_PluginSandboxTest.HandlePluginError(Sender: TObject; const Args: TPluginErrorEventArgs);
begin
  FErrorFired := True;
  FLastErrorMessage := Args.ErrorMessage;
end;

procedure TBug062_PluginSandboxTest.Test_PathTraversal_WithDotDot_ShouldBeBlocked;
var
  PluginManager: TDeepBasePluginManager;
  MaliciousPath: string;
  LoadResult: Boolean;
begin
  LogTestStart('Test_PathTraversal_WithDotDot_ShouldBeBlocked');
  
  PluginManager := TDeepBasePluginManager.Create(FTempPluginsDir, nil);
  try
    FErrorFired := False;
    FLastErrorMessage := '';
    
    // 设置错误事件处理�?
    PluginManager.OnPluginError := HandlePluginError;
    
    // 尝试使用路径遍历攻击
    MaliciousPath := TPath.Combine(FTempPluginsDir, '..\..\..\Windows\System32\malicious.bpl');
    
    LoadResult := PluginManager.LoadPlugin(MaliciousPath);
    
    Assert.IsFalse(LoadResult, '路径遍历攻击应该被阻止，LoadPlugin 应返�?False');
    Assert.IsTrue(FErrorFired, '应该触发错误事件');
    if FErrorFired then
      Assert.IsTrue(FLastErrorMessage.Contains('path') or FLastErrorMessage.Contains('Invalid'),
        '错误消息应该指示路径问题');
  finally
    PluginManager.Free;
  end;
  
  LogTestEnd('Test_PathTraversal_WithDotDot_ShouldBeBlocked', True);
end;

procedure TBug062_PluginSandboxTest.Test_AbsolutePath_OutsidePluginsDir_ShouldBeBlocked;
var
  PluginManager: TDeepBasePluginManager;
  MaliciousPath: string;
  LoadResult: Boolean;
begin
  LogTestStart('Test_AbsolutePath_OutsidePluginsDir_ShouldBeBlocked');
  
  PluginManager := TDeepBasePluginManager.Create(FTempPluginsDir, nil);
  try
    // 尝试加载插件目录外的绝对路径
    MaliciousPath := 'C:\Windows\System32\kernel32.dll';
    
    LoadResult := PluginManager.LoadPlugin(MaliciousPath);
    
    Assert.IsFalse(LoadResult, '插件目录外的绝对路径应该被阻�?);
  finally
    PluginManager.Free;
  end;
  
  LogTestEnd('Test_AbsolutePath_OutsidePluginsDir_ShouldBeBlocked', True);
end;

procedure TBug062_PluginSandboxTest.Test_ValidPluginPath_ShouldBeAllowed;
var
  PluginManager: TDeepBasePluginManager;
  ValidPath: string;
  DummyBPLPath: string;
begin
  LogTestStart('Test_ValidPluginPath_ShouldBeAllowed');
  
  // 创建一个虚拟的 BPL 文件（只是为了测试路径验证）
  DummyBPLPath := TPath.Combine(FTempPluginsDir, 'TestPlugin.bpl');
  TFile.WriteAllText(DummyBPLPath, 'dummy');
  
  PluginManager := TDeepBasePluginManager.Create(FTempPluginsDir, nil);
  try
    ValidPath := DummyBPLPath;
    
    // 注意：这里会因为文件不是真正�?BPL 而失败，
    // 但路径验证应该通过（错误应该是 "Failed to load BPL" 而不�?"Invalid path"�?
    FErrorFired := False;
    FLastErrorMessage := '';
    PluginManager.OnPluginError := HandlePluginError;
    
    // 尝试加载（会因为不是真正�?BPL 而失败，但路径验证应该通过�?
    PluginManager.LoadPlugin(ValidPath);
    
    if FErrorFired then
      Assert.IsFalse(FLastErrorMessage.Contains('Invalid plugin path'),
        '合法路径不应该触发路径验证错�?);
    
    // 如果到达这里，说明路径验证通过�?
    Assert.Pass('合法插件路径验证通过');
  finally
    PluginManager.Free;
  end;
  
  LogTestEnd('Test_ValidPluginPath_ShouldBeAllowed', True);
end;

procedure TBug062_PluginSandboxTest.Test_NonBPLFile_ShouldBeRejected;
var
  PluginManager: TDeepBasePluginManager;
  NonBPLPath: string;
  LoadResult: Boolean;
begin
  LogTestStart('Test_NonBPLFile_ShouldBeRejected');
  
  // 创建一个非 BPL 文件
  NonBPLPath := TPath.Combine(FTempPluginsDir, 'malicious.exe');
  TFile.WriteAllText(NonBPLPath, 'dummy');
  
  PluginManager := TDeepBasePluginManager.Create(FTempPluginsDir, nil);
  try
    LoadResult := PluginManager.LoadPlugin(NonBPLPath);
    
    Assert.IsFalse(LoadResult, '�?BPL 文件应该被拒�?);
  finally
    PluginManager.Free;
  end;
  
  LogTestEnd('Test_NonBPLFile_ShouldBeRejected', True);
end;

procedure TBug062_PluginSandboxTest.Test_PluginConfigAccess_ShouldBeLimited;
var
  Context: TPluginContext;
  ExceptionRaised: Boolean;
begin
  LogTestStart('Test_PluginConfigAccess_ShouldBeLimited');
  
  // 创建插件上下�?
  Context := TPluginContext.Create(
    function(const Key, Default: string): string
    begin
      Result := Default;
    end,
    procedure(const Key, Value: string)
    begin
      // 这个不应该被调用，因为应该在 SetConfig 中抛出异�?
    end,
    nil,
    nil,
    FTempPluginsDir
  );
  
  try
    // 测试 1: 尝试设置�?Plugin. 前缀的配置应该失�?
    ExceptionRaised := False;
    try
      Context.SetConfig('System.DangerousSetting', 'malicious_value');
    except
      on E: EArgumentException do
        ExceptionRaised := True;
    end;
    Assert.IsTrue(ExceptionRaised, '设置�?Plugin. 前缀的配置应该抛出异�?);
    
    // 测试 2: 尝试设置安全相关配置应该失败
    ExceptionRaised := False;
    try
      Context.SetConfig('Plugin.password', 'stolen_password');
    except
      on E: EInvalidOpException do
        ExceptionRaised := True;
    end;
    Assert.IsTrue(ExceptionRaised, '设置安全相关配置应该抛出异常');
    
    // 测试 3: 设置合法�?Plugin. 配置应该成功
    ExceptionRaised := False;
    try
      Context.SetConfig('Plugin.MyPlugin.Setting', 'valid_value');
    except
      ExceptionRaised := True;
    end;
    Assert.IsFalse(ExceptionRaised, '设置合法�?Plugin. 配置应该成功');
    
  finally
    Context.Free;
  end;
  
  LogTestEnd('Test_PluginConfigAccess_ShouldBeLimited', True);
end;

initialization
  TDUnitX.RegisterTestFixture(TBug062_PluginSandboxTest);

end.
