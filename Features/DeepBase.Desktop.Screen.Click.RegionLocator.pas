{ ============================================================================
  DeepBase.Desktop.Screen.Click.RegionLocator
  ---------------------------------------------------------------------------
  Description : Patch (template) matching over a captured screen snapshot:
                tells the click layer WHERE a small image occurs, in screen
                coordinates.

  像素层一律复用 DeepBase.Desktop.Perception.ColorMatch：TPixelBuffer 承载快照
  与模板，逐像素容差判定走 TColorMatcher.CheckColorAt，屏幕坐标换算走
  TPixelBuffer.OriginX/OriginY。本单元只新增"块匹配"这一层，不重复实现截屏、
  颜色距离与坐标映射——同一口径的第二套实现会把容差语义拆成两处。

  命中判据：模板内 CheckColorAt 通过的像素占比 >= MinConfidence。

  DPI 不在此处查询：逐监视器 DPI 的真相源是 DPIMapper（VCL TMonitor.PixelsPerInch），
  本单元原先的 GetCurrentScreenDPI/LastSearchTimeMs 无调用方且另立第二套 DPI 口径，已删。

  原头注释宣称的 multi-scale pyramid / sub-pixel cross-correlation refinement
  从未有实现（只有 0.5 占位评分），也没有调用方设置相应旋钮，故连同 MaxScale/
  ScaleStep/FastMode 一起从契约移除，而不是继续挂着假实现。
  ========================================================================== }

unit DeepBase.Desktop.Screen.Click.RegionLocator;

interface

uses
  System.SysUtils,
  System.Types,
  System.Classes,
  System.Math,
  Winapi.Windows,
  DeepBase.Desktop.Perception.ColorMatch;

type
  TMatchResult = record
    Found: Boolean;
    Position: TPoint;   // 匹配块左上角，屏幕坐标；仅 Found=True 时有意义
    Confidence: Double; // 命中像素占比 0..1；未命中恒为 0
    Rect: TRect;        // 匹配块，屏幕坐标
    class function NotFound: TMatchResult; static;
  end;

  TRegionLocatorOptions = record
    MinConfidence: Double; // 默认 0.7
    Tolerance: Integer;    // 三通道绝对差之和上限（0..765），与 TColorPointSpec.Tol 同口径；默认 30
    UseROI: Boolean;
    ROIBounds: TRect;      // 屏幕坐标；UseROI=True 时只在该矩形内搜索
  end;

  // 无状态块匹配：只吃像素缓冲，不触屏幕，可离线单测。
  TTemplateMatcher = class
  public
    // 模板左上角对齐快照屏幕坐标 (AScreenX,AScreenY) 时的命中像素占比。
    // AMaxMismatch = 允许的失配像素数上限；一旦超出立即返回 -1（提前剪枝：
    // 超预算等价于占比必然低于阈值，调用方据此跳过而不必看完整模板）。
    // 传模板面积即得精确占比。模板越出快照的部分按失配计。
    class function ScoreAt(const ASnapshot, ATemplate: TPixelBuffer;
      AScreenX, AScreenY, ATolerance, AMaxMismatch: Integer): Double; static;

    // 在 AROI（屏幕坐标）内按扫描序返回至多 AMaxCount 个命中。
    // 任意两个返回的命中矩形互不相交（以模板宽高抑制邻域）。
    // 无命中返回空数组——本函数不报告"最接近但未达标"的位置。
    class function FindMatches(const ASnapshot, ATemplate: TPixelBuffer;
      const AROI: TRect; ATolerance: Integer; AMinConfidence: Double;
      AMaxCount: Integer): TArray<TMatchResult>; static;
  end;

  IScreenRegionLocator = interface
    ['{9C4E7A31-2F5B-4D8A-9E6C-70B1A5D3F842}']

    // 快照为空时自动抓取主屏；抓取失败一律抛出异常，不静默返回"没找到"。
    function FindTemplate(const ATemplate: TPixelBuffer): TMatchResult;
    function FindTemplateInROI(const ATemplate: TPixelBuffer;
      const AROI: TRect): TMatchResult;
    function FindAllTemplates(const ATemplate: TPixelBuffer;
      AMaxCount: Integer): TArray<TMatchResult>;

    procedure SetOptions(const AOptions: TRegionLocatorOptions);
    function GetOptions: TRegionLocatorOptions;

    // 重新抓取主屏并替换上一帧。
    procedure CaptureScreen;
  end;

  TScreenRegionLocator = class(TInterfacedObject, IScreenRegionLocator)
  private
    FSnapshot: TPixelBuffer; // 本实例持有，Destroy 里 Release
    FOptions: TRegionLocatorOptions;
    procedure EnsureSnapshot;
    function SearchRect: TRect;
    function Scan(const ATemplate: TPixelBuffer; const AROI: TRect;
      AMaxCount: Integer): TArray<TMatchResult>;
  public
    constructor Create;
    destructor Destroy; override;

    function FindTemplate(const ATemplate: TPixelBuffer): TMatchResult;
    function FindTemplateInROI(const ATemplate: TPixelBuffer;
      const AROI: TRect): TMatchResult;
    function FindAllTemplates(const ATemplate: TPixelBuffer;
      AMaxCount: Integer): TArray<TMatchResult>;
    procedure SetOptions(const AOptions: TRegionLocatorOptions);
    function GetOptions: TRegionLocatorOptions;
    procedure CaptureScreen;
  end;

procedure InitializeScreenRegionLocator;
function CurrentScreenRegionLocator: IScreenRegionLocator;

implementation

var
  GScreenLocator: IScreenRegionLocator = nil;

{ TMatchResult }

class function TMatchResult.NotFound: TMatchResult;
begin
  Result.Found := False;
  Result.Confidence := 0;
  Result.Position := Point(-1, -1);
  // 记录方法内裸写 Rect 会解析成本记录的 Rect 字段（E2124），取矩形构造函数须限定
  Result.Rect := System.Types.Rect(-1, -1, -1, -1);
end;

{ TTemplateMatcher }

class function TTemplateMatcher.ScoreAt(const ASnapshot, ATemplate: TPixelBuffer;
  AScreenX, AScreenY, ATolerance, AMaxMismatch: Integer): Double;
var
  LocalX, LocalY, TX, TY, Area, Hits, Misses: Integer;
begin
  Area := ATemplate.Width * ATemplate.Height;
  if Area <= 0 then
    Exit(-1);

  Hits := 0;
  Misses := 0;
  for TY := 0 to ATemplate.Height - 1 do
  begin
    LocalY := AScreenY + TY - ASnapshot.OriginY;
    for TX := 0 to ATemplate.Width - 1 do
    begin
      LocalX := AScreenX + TX - ASnapshot.OriginX;
      if TColorMatcher.CheckColorAt(ASnapshot, LocalX, LocalY,
        ATemplate.PixelAt(TX, TY), ATolerance) then
        Inc(Hits)
      else
      begin
        Inc(Misses);
        if Misses > AMaxMismatch then
          Exit(-1);
      end;
    end;
  end;
  Result := Hits / Area;
end;

class function TTemplateMatcher.FindMatches(const ASnapshot, ATemplate: TPixelBuffer;
  const AROI: TRect; ATolerance: Integer; AMinConfidence: Double;
  AMaxCount: Integer): TArray<TMatchResult>;
var
  LeftEdge, TopEdge, RightEdge, BottomEdge: Integer;
  TemplateW, TemplateH, ScanW, ScanH, Area, MaxMismatch: Integer;
  ScreenX, ScreenY, MarkX, MarkY, Index: Integer;
  Suppressed: TBytes;
  Score: Double;
begin
  SetLength(Result, 0);
  TemplateW := ATemplate.Width;
  TemplateH := ATemplate.Height;
  if (AMaxCount < 1) or (TemplateW <= 0) or (TemplateH <= 0) or
    not ASnapshot.IsValid then
    Exit;

  // 搜索面 = AROI ∩ 快照，且模板必须完整放得下
  LeftEdge := Max(AROI.Left, ASnapshot.OriginX);
  TopEdge := Max(AROI.Top, ASnapshot.OriginY);
  RightEdge := Min(AROI.Right, ASnapshot.OriginX + ASnapshot.Width);
  BottomEdge := Min(AROI.Bottom, ASnapshot.OriginY + ASnapshot.Height);
  if (RightEdge - LeftEdge < TemplateW) or (BottomEdge - TopEdge < TemplateH) then
    Exit;

  ScanW := RightEdge - LeftEdge;
  ScanH := BottomEdge - TopEdge;
  Area := TemplateW * TemplateH;
  // 占比阈值的等价失配预算（+1e-6 抵消浮点误差，宁严勿松）
  MaxMismatch := Trunc((1.0 - AMinConfidence) * Area + 1e-6);
  SetLength(Suppressed, ScanW * ScanH);

  for ScreenY := TopEdge to BottomEdge - TemplateH do
    for ScreenX := LeftEdge to RightEdge - TemplateW do
    begin
      Index := (ScreenY - TopEdge) * ScanW + (ScreenX - LeftEdge);
      if Suppressed[Index] <> 0 then
        Continue;

      Score := ScoreAt(ASnapshot, ATemplate, ScreenX, ScreenY, ATolerance, MaxMismatch);
      if Score < 0 then
        Continue;

      SetLength(Result, Length(Result) + 1);
      Result[High(Result)].Found := True;
      Result[High(Result)].Confidence := Score;
      Result[High(Result)].Position := Point(ScreenX, ScreenY);
      Result[High(Result)].Rect := Rect(ScreenX, ScreenY,
        ScreenX + TemplateW, ScreenY + TemplateH);
      if Length(Result) >= AMaxCount then
        Exit;

      // 邻域抑制：两个命中矩形不得共享任何像素
      for MarkY := Max(TopEdge, ScreenY - (TemplateH - 1))
        to Min(BottomEdge - TemplateH, ScreenY + (TemplateH - 1)) do
        for MarkX := Max(LeftEdge, ScreenX - (TemplateW - 1))
          to Min(RightEdge - TemplateW, ScreenX + (TemplateW - 1)) do
          Suppressed[(MarkY - TopEdge) * ScanW + (MarkX - LeftEdge)] := 1;
    end;
end;

{ TScreenRegionLocator }

constructor TScreenRegionLocator.Create;
begin
  inherited Create;
  FSnapshot.Bitmap := nil;
  FSnapshot.OriginX := 0;
  FSnapshot.OriginY := 0;
  FOptions.MinConfidence := 0.7;
  FOptions.Tolerance := 30;
  FOptions.UseROI := False;
  FOptions.ROIBounds := Rect(0, 0, 0, 0);
end;

destructor TScreenRegionLocator.Destroy;
begin
  FSnapshot.Release;
  inherited Destroy;
end;

function TScreenRegionLocator.SearchRect: TRect;
begin
  if FOptions.UseROI then
    Result := FOptions.ROIBounds
  else
    Result := Rect(FSnapshot.OriginX, FSnapshot.OriginY,
      FSnapshot.OriginX + FSnapshot.Width, FSnapshot.OriginY + FSnapshot.Height);
end;

procedure TScreenRegionLocator.CaptureScreen;
var
  NewBuffer: TPixelBuffer;
begin
  NewBuffer := TColorMatcher.CaptureRegion(
    Rect(0, 0, GetSystemMetrics(SM_CXSCREEN), GetSystemMetrics(SM_CYSCREEN)));
  if not NewBuffer.IsValid then
  begin
    // CaptureRegion 抓不到桌面时返回空缓冲而非抛异常；升格为显式失败，
    // 否则调用方会把"抓不到"误读成"屏幕上没有"。
    NewBuffer.Release;
    raise EInvalidOperation.Create('RegionLocator: 主屏快照抓取失败（无可用桌面会话？）');
  end;
  FSnapshot.Release;
  FSnapshot := NewBuffer;
end;

procedure TScreenRegionLocator.EnsureSnapshot;
begin
  if not FSnapshot.IsValid then
    CaptureScreen;
end;

function TScreenRegionLocator.Scan(const ATemplate: TPixelBuffer;
  const AROI: TRect; AMaxCount: Integer): TArray<TMatchResult>;
begin
  EnsureSnapshot;
  Result := TTemplateMatcher.FindMatches(FSnapshot, ATemplate, AROI,
    FOptions.Tolerance, FOptions.MinConfidence, AMaxCount);
end;

function TScreenRegionLocator.FindTemplate(const ATemplate: TPixelBuffer): TMatchResult;
var
  Hits: TArray<TMatchResult>;
begin
  Hits := Scan(ATemplate, SearchRect, 1);
  if Length(Hits) > 0 then
    Exit(Hits[0]);
  Exit(TMatchResult.NotFound);
end;

function TScreenRegionLocator.FindTemplateInROI(const ATemplate: TPixelBuffer;
  const AROI: TRect): TMatchResult;
var
  Hits: TArray<TMatchResult>;
begin
  Hits := Scan(ATemplate, AROI, 1);
  if Length(Hits) > 0 then
    Exit(Hits[0]);
  Exit(TMatchResult.NotFound);
end;

function TScreenRegionLocator.FindAllTemplates(const ATemplate: TPixelBuffer;
  AMaxCount: Integer): TArray<TMatchResult>;
begin
  Result := Scan(ATemplate, SearchRect, AMaxCount);
end;

procedure TScreenRegionLocator.SetOptions(const AOptions: TRegionLocatorOptions);
begin
  FOptions := AOptions;
end;

function TScreenRegionLocator.GetOptions: TRegionLocatorOptions;
begin
  Result := FOptions;
end;

procedure InitializeScreenRegionLocator;
begin
  if GScreenLocator = nil then
    GScreenLocator := TScreenRegionLocator.Create;
end;

function CurrentScreenRegionLocator: IScreenRegionLocator;
begin
  InitializeScreenRegionLocator;
  Result := GScreenLocator;
end;

initialization
finalization
  GScreenLocator := nil;

end.
