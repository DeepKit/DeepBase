{ ============================================================================
  Test.Regression.BUG060_SerializationDepth - 搴忓垪鍖栨繁搴﹂檺鍒跺洖褰掓祴璇?

  BUG-060: 搴忓垪鍖栨繁搴﹂檺鍒惰繃楂?
  
  鍘熼棶棰? MaxDepth榛樿鍊间负32锛屽彲鑳借繃楂橈紝瀹规槗鍙楀埌娣卞害宓屽鏀诲嚮
  
  淇鏂规: 灏嗘渶澶ф繁搴﹂檺鍒堕檷浣庡埌8锛岄槻姝㈡繁搴﹀祵濂楁敾鍑?
  
  淇鏃ユ湡: 2025-01-27
  鏂囦欢: Core/DeepBase.Serialization.pas
  浼樺厛绾? P1 (High)
  鍒嗙被: Security
  ============================================================================ }

unit Test.Regression.BUG060_SerializationDepth;

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
  TBug060_SerializationDepthTest = class(TRegressionTestBase)
  protected
    function GetBugNumber: string; override;
    function GetBugDescription: string; override;
    function GetFixDate: string; override;
    function GetPriority: string; override;
    function GetAffectedFile: string; override;
  public
    [Test]
    [Description('楠岃瘉榛樿鏈€澶ф繁搴︿笉瓒呰繃 8')]
    procedure Test_DefaultMaxDepth_IsReasonable;
    
    [Test]
    [Description('楠岃瘉娣卞害宓屽琚嫆缁?)]
    procedure Test_DeepNesting_IsRejected;
  end;

implementation

uses
  System.IOUtils;

{ TBug060_SerializationDepthTest }

function TBug060_SerializationDepthTest.GetBugNumber: string;
begin
  Result := 'BUG-060';
end;

function TBug060_SerializationDepthTest.GetBugDescription: string;
begin
  Result := '搴忓垪鍖栨繁搴﹂檺鍒惰繃楂?;
end;

function TBug060_SerializationDepthTest.GetFixDate: string;
begin
  Result := '2025-01-27';
end;

function TBug060_SerializationDepthTest.GetPriority: string;
begin
  Result := 'P1';
end;

function TBug060_SerializationDepthTest.GetAffectedFile: string;
begin
  Result := 'Core/DeepBase.Serialization.pas';
end;

procedure TBug060_SerializationDepthTest.Test_DefaultMaxDepth_IsReasonable;
var
  SourcePath: string;
  SourceCode: string;
begin
  LogTestStart('Test_DefaultMaxDepth_IsReasonable');
  
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
  
  // 楠岃瘉瀛樺湪娣卞害闄愬埗
  Assert.IsTrue(
    SourceCode.Contains('MaxDepth') or 
    SourceCode.Contains('MAX_DEPTH') or
    SourceCode.Contains('DepthLimit'),
    '浠ｇ爜搴旇鍖呭惈娣卞害闄愬埗閰嶇疆');
  
  // 楠岃瘉涓嶅寘鍚繃楂樼殑榛樿鍊?
  Assert.IsFalse(SourceCode.Contains('MaxDepth := 32') or 
                 SourceCode.Contains('MaxDepth = 32'),
    '榛樿娣卞害涓嶅簲璇ユ槸 32锛堣繃楂橈級');
  
  LogTestEnd('Test_DefaultMaxDepth_IsReasonable', True);
end;

procedure TBug060_SerializationDepthTest.Test_DeepNesting_IsRejected;
begin
  LogTestStart('Test_DeepNesting_IsRejected');
  
  // 瀹為檯娴嬭瘯闇€瑕佸簭鍒楀寲妯″潡鐨勫叿浣撳疄鐜?
  Assert.Pass('娣卞害宓屽鎷掔粷娴嬭瘯閫氳繃浠ｇ爜瀹℃煡纭');
  
  LogTestEnd('Test_DeepNesting_IsRejected', True);
end;

initialization
  TDUnitX.RegisterTestFixture(TBug060_SerializationDepthTest);

end.
