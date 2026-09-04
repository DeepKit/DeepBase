{ ============================================================================
  DeepBase.VCL.HB.Choice.Demo - Minimal Demo Form for HB Choice, Waterfall & Granularity

  Version: 1.0 (Delphi 13.1 on Win64)
  Description: Demonstrates:
               - THbChoiceDeck with 0-9 options (Key 1 recommended, 8 regen, 9 input, 0 back)
               - THbFacetWaterfall with nested parent-child hierarchy & collapse
               - THbGranularity 6-tier switcher
  ============================================================================ }

unit DeepBase.VCL.HB.Choice.Demo;

{$WARN IMPLICIT_STRING_CAST OFF}

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Classes,
  System.UITypes,
  Vcl.Forms,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.StdCtrls,
  DeepBase.HB.Core,
  DeepBase.HB.Choice.Types,
  DeepBase.HB.Waterfall.Types,
  DeepBase.VCL.HB.Theme,
  DeepBase.VCL.HB.Controls,
  DeepBase.VCL.HB.Choice,
  DeepBase.VCL.HB.Waterfall,
  DeepBase.VCL.HB.Inputs;

type
  THbChoiceAndWaterfallDemoForm = class(TForm)
  private
    FPnlTop: TPanel;
    FPnlLeft: TPanel;
    FPnlRight: TPanel;
    FDeck: THbChoiceDeck;
    FWall: THbFacetWaterfall;
    FCmbGranularity: THbComboBox;
    FLblResult: TLabel;

    procedure OnChoiceSelect(Sender: TObject; AKey: Integer);
    procedure OnGranularityChange(Sender: TObject);
  public
    constructor CreateNew(AOwner: TComponent; Dummy: Integer = 0); override;
    procedure InitializeDemo;
  end;

procedure ShowHBChoiceDemo;

implementation

procedure ShowHBChoiceDemo;
var
  Frm: THbChoiceAndWaterfallDemoForm;
begin
  Frm := THbChoiceAndWaterfallDemoForm.CreateNew(nil);
  try
    Frm.InitializeDemo;
    Frm.ShowModal;
  finally
    Frm.Free;
  end;
end;

{ THbChoiceAndWaterfallDemoForm }

constructor THbChoiceAndWaterfallDemoForm.CreateNew(AOwner: TComponent; Dummy: Integer);
begin
  inherited CreateNew(AOwner, Dummy);
  Caption := 'HB 0-9 选择控件 + 嵌套瀑布 + 信息粒度示例';
  Width := 1024;
  Height := 680;
  Position := poScreenCenter;

  FPnlTop := TPanel.Create(Self);
  FPnlTop.Parent := Self;
  FPnlTop.Align := alTop;
  FPnlTop.Height := 50;
  FPnlTop.BevelOuter := bvNone;

  FCmbGranularity := THbComboBox.Create(FPnlTop);
  FCmbGranularity.Parent := FPnlTop;
  FCmbGranularity.Left := 16;
  FCmbGranularity.Top := 10;
  FCmbGranularity.Width := 180;
  FCmbGranularity.Items.Add('0. 超粗 (gCoarsest)');
  FCmbGranularity.Items.Add('1. 粗 (gCoarse)');
  FCmbGranularity.Items.Add('2. 适中 (gMedium · 默认)');
  FCmbGranularity.Items.Add('3. 较细 (gFine)');
  FCmbGranularity.Items.Add('4. 细 (gFiner)');
  FCmbGranularity.Items.Add('5. 极细 (gFinest)');
  FCmbGranularity.ItemIndex := 2;
  FCmbGranularity.OnChange := OnGranularityChange;

  FLblResult := TLabel.Create(FPnlTop);
  FLblResult.Parent := FPnlTop;
  FLblResult.Left := 220;
  FLblResult.Top := 16;
  FLblResult.Caption := '当前选择: 未选 (按键盘 1-7, 8, 9, 0 或点击)';

  FPnlLeft := TPanel.Create(Self);
  FPnlLeft.Parent := Self;
  FPnlLeft.Align := alLeft;
  FPnlLeft.Width := 380;
  FPnlLeft.BevelOuter := bvNone;

  FDeck := THbChoiceDeck.Create(FPnlLeft);
  FDeck.Parent := FPnlLeft;
  FDeck.Align := alClient;
  FDeck.OnChoice := OnChoiceSelect;

  FPnlRight := TPanel.Create(Self);
  FPnlRight.Parent := Self;
  FPnlRight.Align := alClient;
  FPnlRight.BevelOuter := bvNone;

  FWall := THbFacetWaterfall.Create(FPnlRight);
  FWall.Parent := FPnlRight;
  FWall.Align := alClient;
end;

procedure THbChoiceAndWaterfallDemoForm.InitializeDemo;
begin
  // 1. Setup Choice Deck
  FDeck.Clear;
  FDeck.AddOption(1, '方案 A：重构核心视觉系统', '面向长期维护，彻底解耦', True);
  FDeck.AddOption(2, '方案 B：增量补齐缺失组件', '快速满足下游需求', False);
  FDeck.AddOption(3, '方案 C：桥接外部第三方适配器', '过渡方案，后续收束', False);
  FDeck.AddStandardControls(True, True, True);

  // 2. Setup Waterfall
  FWall.Clear;
  FWall.AddFacet('req', '需求与意图', 4);
  FWall.AddFacet('arch', '架构设计', 3);

  // Nested cards with properties and links
  FWall.AddCard('r1', 'req', '需求与意图', '总目标：AsWish 统一选择与展示', '0-9 键选 + 嵌套包含',
    '基于 AsWish 统一交互契约规范构建完整 HB 视觉体系', 'AsWish-统一选择交互标准-v1.md',
    wisNormal, btBrand, '', 0, wlkDoc, 'docs/AsWish-统一选择交互标准-v1.md',
    [THbCardProperty.Create('工单', 'WO-20260830-005'), THbCardProperty.Create('模块', 'ChoiceDeck+Waterfall')]);

  FWall.AddCard('c1', 'req', '需求与意图', '模块 1：THbChoiceDeck', '0-9 键选等价',
    '键盘 1-7/8/9/0 直达，鼠标点击等价，四类语义色 Token', 'DeepBase.VCL.HB.Choice.pas',
    wisNormal, btBrand, 'r1', 1, wlkSymbol, 'DeepBase.VCL.HB.Choice.THbChoiceDeck',
    [THbCardProperty.Create('支持键位', '1..7, 8, 9, 0'), THbCardProperty.Create('状态机', 'Normal/Hover/Pressed/Disabled/Focus')]);

  FWall.AddCard('c2', 'req', '需求与意图', '模块 2：THbWaterfall 嵌套', 'ParentId + Depth 折叠展开',
    '28px 固定层级缩进，左侧 28px L0-L5 数字色标，右侧下拉详情', 'DeepBase.VCL.HB.Waterfall.pas',
    wisNormal, btBrand, 'r1', 1, wlkSymbol, 'DeepBase.VCL.HB.Waterfall.THbFacetWaterfall',
    [THbCardProperty.Create('缩进标准', '28px per depth'), THbCardProperty.Create('色标', 'L0..L5 Tokenized')]);

  FWall.AddCard('gc1', 'req', '需求与意图', '细节 2.1：信息粒度 6 档联动', 'Depth 与粒度过滤',
    '超粗/粗/适中/较细/细/极细 六档展示缩放，与排版密度正交', 'DeepBase.HB.Core.pas',
    wisNormal, btBrand, 'c2', 2, wlkDoc, 'docs/WO-20260830-005-开发甲-HB-0-9选择控件与嵌套瀑布与信息粒度交付报告.md',
    [THbCardProperty.Create('粒度枚举', 'gCoarsest..gFinest'), THbCardProperty.Create('默认档位', 'gMedium')]);

  FWall.AddCard('a1', 'arch', '架构设计', '设计准则：单一真相源 (SSOT)', '无硬编码颜色，全 Token 化',
    '所有视觉元素严格从 THbTokens 提取，浅深主题自适应', '', wisNormal, btSuccess, '', 0);

  FWall.AddCard('a2', 'arch', '架构设计', '设计准则：高 DPI 与五态齐备', '96..384 DPI 矢量无损适配',
    '动态 ScalePixels / ScaleDIP 自适应', '', wisNormal, btSuccess, 'a1', 1);

  FWall.Granularity := gMedium;
end;

procedure THbChoiceAndWaterfallDemoForm.OnChoiceSelect(Sender: TObject; AKey: Integer);
begin
  FLblResult.Caption := Format('当前选择: Key [%d] (触发时间: %s)', [AKey, FormatDateTime('hh:nn:ss.zzz', Now)]);
end;

procedure THbChoiceAndWaterfallDemoForm.OnGranularityChange(Sender: TObject);
begin
  if FCmbGranularity.ItemIndex in [0..5] then
  begin
    FWall.Granularity := THbGranularity(FCmbGranularity.ItemIndex);
    FLblResult.Caption := Format('粒度已切换为: %s (显示卡片数: %d)',
      [FCmbGranularity.Items[FCmbGranularity.ItemIndex], FWall.GetVisibleCardCount]);
  end;
end;

end.
