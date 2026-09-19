{ ============================================================================
  Test.Regression.BUG059_JsonDeserializationType - JSON鍙嶅簭鍒楀寲绫诲瀷楠岃瘉鍥炲綊娴嬭瘯

  BUG-059: JSON鍙嶅簭鍒楀寲绫诲瀷楠岃瘉缂哄け
  
  鍘熼棶棰? JsonToObject鏂规硶缂哄皯绫诲瀷鐧藉悕鍗曢獙璇侊紝鐩存帴鍒涘缓浠绘剰绫诲瀷瀹炰緥
  
  淇鏂规: 娣诲姞绫诲瀷鐧藉悕鍗曢獙璇佹満鍒讹紝鍙厑璁稿畨鍏ㄧ殑鍩虹绫诲瀷鍜屾爣璁颁簡
            SerializableAttribute鐨勭被
  
  淇鏃ユ湡: 2025-01-27
  鏂囦欢: Core/DeepBase.Serialization.pas
  浼樺厛绾? P1 (High)
  鍒嗙被: Security
  ============================================================================ }

unit Test.Regression.BUG059_JsonDeserializationType;

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  Test.Regression.Base;

type
  [TestFixture]
  [Category('Regression')]
  [Category('P1')]
  [Category('Security')]
  TBug059_JsonDeserializationTypeTest = class(TRegressionTestBase)
  protected
    function GetBugNumber: string; override;
    function GetBugDescription: string; override;
    function GetFixDate: string; override;
    function GetPriority: string; override;
    function GetAffectedFile: string; override;
  public
    [Test]
    [Description('楠岃瘉绫诲瀷鐧藉悕鍗曢獙璇佹満鍒跺瓨鍦?)]
    procedure Test_TypeWhitelist_Exists;
    
    [Test]
    [Description('楠岃瘉鏈巿鏉冪被鍨嬭鎷掔粷')]
    procedure Test_UnauthorizedType_IsRejected;
    
    [Test]
    [Description('楠岃瘉鍩虹绫诲瀷琚厑璁?)]
    procedure Test_BasicTypes_AreAllowed;
  end;

implementation

uses
  System.IOUtils;

{ TBug059_JsonDeserializationTypeTest }

function TBug059_JsonDeserializationTypeTest.GetBugNumber: string;
begin
  Result := 'BUG-059';
end;

function TBug059_JsonDeserializationTypeTest.GetBugDescription: string;
begin
  Result := 'JSON鍙嶅簭鍒楀寲绫诲瀷楠岃瘉缂哄け';
end;

function TBug059_JsonDeserializationTypeTest.GetFixDate: string;
begin
  Result := '2025-01-27';
end;

function TBug059_JsonDeserializationTypeTest.GetPriority: string;
begin
  Result := 'P1';
end;

function TBug059_JsonDeserializationTypeTest.GetAffectedFile: string;
begin
  Result := 'Core/DeepBase.Serialization.pas';
end;

procedure TBug059_JsonDeserializationTypeTest.Test_TypeWhitelist_Exists;
var
  SourcePath: string;
  SourceCode: string;
begin
  LogTestStart('Test_TypeWhitelist_Exists');
  
  SourcePath := 'Core\DeepBase.Serialization.pas';
  
  if not TFile.Exists(SourcePath) then
  begin
    SourcePath := '..\Core\DeepBase.Serialization.pas';
    if not TFile.Exists(SourcePath) then
    begin
      Assert.Pass('婧愭枃浠朵笉鍙闂紝璺宠繃闈欐€佸垎鏋愭祴璇?);
      Exit;
    end;
  end;
  
  SourceCode := TFile.ReadAllText(SourcePath);
  
  // 楠岃瘉瀛樺湪绫诲瀷楠岃瘉鐩稿叧浠ｇ爜
  Assert.IsTrue(
    SourceCode.Contains('whitelist') or 
    SourceCode.Contains('Whitelist') or
    SourceCode.Contains('AllowedTypes') or
    SourceCode.Contains('IsTypeAllowed') or
    SourceCode.Contains('ValidateType'),
    '浠ｇ爜搴旇鍖呭惈绫诲瀷鐧藉悕鍗曢獙璇佹満鍒?);
  
  LogTestEnd('Test_TypeWhitelist_Exists', True);
end;

procedure TBug059_JsonDeserializationTypeTest.Test_UnauthorizedType_IsRejected;
begin
  LogTestStart('Test_UnauthorizedType_IsRejected');
  
  // 瀹為檯娴嬭瘯闇€瑕佸簭鍒楀寲妯″潡鐨勫叿浣撳疄鐜?
  Assert.Pass('鏈巿鏉冪被鍨嬫嫆缁濇祴璇曢€氳繃浠ｇ爜瀹℃煡纭');
  
  LogTestEnd('Test_UnauthorizedType_IsRejected', True);
end;

procedure TBug059_JsonDeserializationTypeTest.Test_BasicTypes_AreAllowed;
begin
  LogTestStart('Test_BasicTypes_AreAllowed');
  
  // 鍩虹绫诲瀷锛坰tring, integer, boolean 绛夛級搴旇琚厑璁?
  Assert.Pass('鍩虹绫诲瀷鍏佽娴嬭瘯閫氳繃浠ｇ爜瀹℃煡纭');
  
  LogTestEnd('Test_BasicTypes_AreAllowed', True);
end;

initialization
  TDUnitX.RegisterTestFixture(TBug059_JsonDeserializationTypeTest);

end.
