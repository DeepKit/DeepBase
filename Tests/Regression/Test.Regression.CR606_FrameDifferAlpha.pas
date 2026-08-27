{ ============================================================================
  Test.Regression.CR606_FrameDifferAlpha - Perception 差分器 alpha 缺陷回归

  现象: 注入两帧完全相同的 pf32bit(alpha=0) 位图，第二帧被判为 Changed。
  根因: SampleSignature 用 Canvas.Draw 拷贝到工作位图，GDI 对全透明源
        走 AlphaBlend 且目标像素保持未初始化 → 签名随机不同。
  修复: pf32 源改扫描行确定性拷贝 + rgbReserved 归一化 255。
       (CR-606: 实体显卡下依旧复现，排除环境因素，确认为真实缺陷)
  ============================================================================ }

unit Test.Regression.CR606_FrameDifferAlpha;

{$POINTERMATH ON}

interface

uses
  System.SysUtils,
  Winapi.Windows,
  Vcl.Graphics,
  DUnitX.TestFramework,
  Test.Regression.Base,
  DeepBase.Desktop.Perception.Engine;

type
  [TestFixture]
  [Category('regression')]
  TCR606FrameDifferAlphaTest = class(TRegressionTestBase)
  private
    class function MakeSolidBitmap(AColor: TColor; AW, AH: Integer): TBitmap; static;
  protected
    function GetBugNumber: string; override;
    function GetBugDescription: string; override;
    function GetFixDate: string; override;
    function GetPriority: string; override;
    function GetAffectedFile: string; override;
  public
    [Test]
    procedure Test_IdenticalAlpha0Frames_SecondIsUnchanged;

    [Test]
    procedure Test_DifferentAlpha0Frames_StillDetectedAsChanged;
  end;

implementation

class function TCR606FrameDifferAlphaTest.MakeSolidBitmap(AColor: TColor;
  AW, AH: Integer): TBitmap;
var
  X, Y: Integer;
  LRow: PRGBQuad;
begin
  Result := TBitmap.Create;
  Result.PixelFormat := pf32bit;
  Result.SetSize(AW, AH);
  for Y := 0 to AH - 1 do
  begin
    LRow := Result.ScanLine[Y];
    for X := 0 to AW - 1 do
    begin
      LRow[X].rgbRed := GetRValue(AColor);
      LRow[X].rgbGreen := GetGValue(AColor);
      LRow[X].rgbBlue := GetBValue(AColor);
      LRow[X].rgbReserved := 0; // 与 Perception 测试同构：alpha=0 触发缺陷路径
    end;
  end;
end;

function TCR606FrameDifferAlphaTest.GetBugNumber: string;
begin
  Result := 'CR-606';
end;

function TCR606FrameDifferAlphaTest.GetBugDescription: string;
begin
  Result := 'FrameDiffer judged identical alpha=0 frames as changed due to uninitialized work bitmap via Canvas.Draw';
end;

function TCR606FrameDifferAlphaTest.GetFixDate: string;
begin
  Result := '2026-08-24';
end;

function TCR606FrameDifferAlphaTest.GetPriority: string;
begin
  Result := 'P1';
end;

function TCR606FrameDifferAlphaTest.GetAffectedFile: string;
begin
  Result := 'Features\DeepBase.Desktop.Perception.Engine.pas';
end;

procedure TCR606FrameDifferAlphaTest.Test_IdenticalAlpha0Frames_SecondIsUnchanged;
var
  Differ: TFrameDiffer;
  B1, B2: TBitmap;
begin
  Differ := TFrameDiffer.Create(0.004);
  try
    B1 := MakeSolidBitmap(clNavy, 80, 80);
    try
      Assert.IsTrue(Differ.IsChanged(B1), 'first frame seeds as changed');
    finally
      B1.Free;
    end;

    B2 := MakeSolidBitmap(clNavy, 80, 80); // 全新实例、内容相同
    try
      Assert.IsFalse(Differ.IsChanged(B2),
        'identical second frame must be judged static (pre-fix: random garbage diff)');
    finally
      B2.Free;
    end;
  finally
    Differ.Free;
  end;
end;

procedure TCR606FrameDifferAlphaTest.Test_DifferentAlpha0Frames_StillDetectedAsChanged;
var
  Differ: TFrameDiffer;
  B1, B2: TBitmap;
begin
  Differ := TFrameDiffer.Create(0.004);
  try
    B1 := MakeSolidBitmap(clNavy, 80, 80);
    try
      Assert.IsTrue(Differ.IsChanged(B1));

      B2 := MakeSolidBitmap(clRed, 80, 80);
      try
        Assert.IsTrue(Differ.IsChanged(B2),
          'genuinely different frame must still be detected');
      finally
        B2.Free;
      end;
    finally
      B1.Free;
    end;
  finally
    Differ.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TCR606FrameDifferAlphaTest);

end.
