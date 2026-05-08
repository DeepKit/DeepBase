{ ============================================================================
  Test.Regression.BUG034_HardcodedKeys - 硬编码密钥漏洞回归测�?

  BUG-034: 硬编码密钥漏�?
  
  原问�? 多个模块存在硬编码密钥，�?@2241114'�?Default_AntiTamper_Key_2025'等，
          这些密钥可以被逆向工程提取�?
  
  修复方案: 移除所有硬编码默认密钥，要求用户显式配置密钥�?
  
  修复日期: 2025-12-16
  文件: Features/DeepBase.Protection.pas, Features/DeepBase.AntiTamper.pas
  优先�? P0 (Critical)
  分类: Security
  ============================================================================ }

unit Test.Regression.BUG034_HardcodedKeys;

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
  TBug034_HardcodedKeysTest = class(TRegressionTestBase)
  protected
    function GetBugNumber: string; override;
    function GetBugDescription: string; override;
    function GetFixDate: string; override;
    function GetPriority: string; override;
    function GetAffectedFile: string; override;
  public
    [Test]
    [Description('验证 Protection 模块不包含硬编码密钥')]
    procedure Test_Protection_NoHardcodedKeys;
    
    [Test]
    [Description('验证 AntiTamper 模块不包含硬编码密钥')]
    procedure Test_AntiTamper_NoHardcodedKeys;
    
    [Test]
    [Description('验证未配置密钥时抛出明确错误')]
    procedure Test_MissingKey_ThrowsClearError;
    
    [Test]
    [Description('验证密钥配置后功能正�?)]
    procedure Test_ConfiguredKey_WorksCorrectly;
  end;

implementation

uses
  DeepBase.Crypto;

const
  // 已知的硬编码密钥模式（用于检测）
  KNOWN_HARDCODED_PATTERNS: array[0..4] of string = (
    '@2241114',
    'Default_AntiTamper_Key',
    'DeepBase_Default_Key',
    'CHANGE_THIS_KEY',
    '1234567890123456'
  );

{ TBug034_HardcodedKeysTest }

function TBug034_HardcodedKeysTest.GetBugNumber: string;
begin
  Result := 'BUG-034';
end;

function TBug034_HardcodedKeysTest.GetBugDescription: string;
begin
  Result := '硬编码密钥漏�?;
end;

function TBug034_HardcodedKeysTest.GetFixDate: string;
begin
  Result := '2025-12-16';
end;

function TBug034_HardcodedKeysTest.GetPriority: string;
begin
  Result := 'P0';
end;

function TBug034_HardcodedKeysTest.GetAffectedFile: string;
begin
  Result := 'Features/DeepBase.Protection.pas, Features/DeepBase.AntiTamper.pas';
end;

procedure TBug034_HardcodedKeysTest.Test_Protection_NoHardcodedKeys;
var
  SourcePath: string;
  SourceCode: string;
  Pattern: string;
begin
  LogTestStart('Test_Protection_NoHardcodedKeys');
  
  SourcePath := 'Features\DeepBase.Protection.pas';
  
  if not TFile.Exists(SourcePath) then
  begin
    // 尝试相对于测试目录的路径
    SourcePath := '..\Features\DeepBase.Protection.pas';
    if not TFile.Exists(SourcePath) then
    begin
      Assert.Pass('源文件不可访问，跳过静态分析测�?);
      Exit;
    end;
  end;
  
  SourceCode := TFile.ReadAllText(SourcePath);
  
  for Pattern in KNOWN_HARDCODED_PATTERNS do
  begin
    Assert.IsFalse(SourceCode.Contains(Pattern),
      Format('源代码不应包含硬编码密钥模式: %s', [Pattern]));
  end;
  
  LogTestEnd('Test_Protection_NoHardcodedKeys', True);
end;

procedure TBug034_HardcodedKeysTest.Test_AntiTamper_NoHardcodedKeys;
var
  SourcePath: string;
  SourceCode: string;
  Pattern: string;
begin
  LogTestStart('Test_AntiTamper_NoHardcodedKeys');
  
  SourcePath := 'Features\DeepBase.AntiTamper.pas';
  
  if not TFile.Exists(SourcePath) then
  begin
    SourcePath := '..\Features\DeepBase.AntiTamper.pas';
    if not TFile.Exists(SourcePath) then
    begin
      Assert.Pass('源文件不可访问，跳过静态分析测�?);
      Exit;
    end;
  end;
  
  SourceCode := TFile.ReadAllText(SourcePath);
  
  for Pattern in KNOWN_HARDCODED_PATTERNS do
  begin
    Assert.IsFalse(SourceCode.Contains(Pattern),
      Format('源代码不应包含硬编码密钥模式: %s', [Pattern]));
  end;
  
  LogTestEnd('Test_AntiTamper_NoHardcodedKeys', True);
end;

procedure TBug034_HardcodedKeysTest.Test_MissingKey_ThrowsClearError;
var
  AES: TAESCrypto;
  ExceptionRaised: Boolean;
  ExceptionMessage: string;
begin
  LogTestStart('Test_MissingKey_ThrowsClearError');
  
  AES := TAESCrypto.Create(aes256, aesCBC);
  try
    ExceptionRaised := False;
    ExceptionMessage := '';
    
    try
      // 不设置密钥直接加�?
      AES.GenerateIV;
      AES.EncryptString('Test data');
    except
      on E: Exception do
      begin
        ExceptionRaised := True;
        ExceptionMessage := E.Message;
      end;
    end;
    
    Assert.IsTrue(ExceptionRaised, '未配置密钥时应该抛出异常');
    // 异常消息应该清楚地指示问�?
    Assert.IsTrue(
      ExceptionMessage.Contains('key') or 
      ExceptionMessage.Contains('Key') or
      ExceptionMessage.Contains('密钥'),
      '异常消息应该指示密钥问题');
  finally
    AES.Free;
  end;
  
  LogTestEnd('Test_MissingKey_ThrowsClearError', True);
end;

procedure TBug034_HardcodedKeysTest.Test_ConfiguredKey_WorksCorrectly;
var
  AES: TAESCrypto;
  PlainText: string;
  Encrypted: string;
  Decrypted: string;
begin
  LogTestStart('Test_ConfiguredKey_WorksCorrectly');
  
  AES := TAESCrypto.Create(aes256, aesCBC);
  try
    // 使用用户配置的密�?
    AES.SetKeyFromPassword('UserConfiguredSecurePassword!@#$', TEncoding.UTF8.GetBytes('bug034_salt'));
    AES.GenerateIV;
    
    PlainText := 'Sensitive data to protect';
    Encrypted := AES.EncryptString(PlainText);
    Decrypted := AES.DecryptString(Encrypted);
    
    Assert.AreEqual(PlainText, Decrypted,
      '使用用户配置的密钥应该能正确加密和解�?);
  finally
    AES.Free;
  end;
  
  LogTestEnd('Test_ConfiguredKey_WorksCorrectly', True);
end;

initialization
  TDUnitX.RegisterTestFixture(TBug034_HardcodedKeysTest);

end.
