{ ============================================================================
  Gallery.FMXMainForm - HB Visual Infrastructure FMX Gallery Application

  Version: 1.0 (Delphi 13.1 on Win64 / Cross-Platform FMX)
  Description: Interactive visual acceptance test and showcase application for
               all 12 vector-rendered HB components across all 10 built-in
               themes and density modes in FireMonkey.
  ============================================================================ }

unit Gallery.FMXMainForm;

interface

uses
  System.SysUtils,
  System.Classes,
  System.UITypes,
  System.Types,
  FMX.Types,
  FMX.Controls,
  FMX.Forms,
  FMX.Dialogs,
  FMX.StdCtrls,
  FMX.ListBox,
  FMX.Layouts,
  FMX.Objects,
  DeepBase.HB.Core,
  DeepBase.HB.Palettes,
  DeepBase.FMX.HB.Theme,
  DeepBase.FMX.HB.Palettes,
  DeepBase.FMX.HB.Controls,
  DeepBase.FMX.HB.Cards;

type
  TFMXGalleryMainForm = class(TForm)
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    FTopBar: TPanel;
    FLblTheme: TLabel;
    FCmbTheme: TComboBox;
    FLblDensity: TLabel;
    FCmbDensity: TComboBox;
    FLblWcag: TLabel;

    FScrollBox: TVertScrollBox;
    FLayoutContent: TLayout;
    FColLeft: TLayout;
    FColRight: TLayout;

    // Left Column Controls (Atomic)
    FSec1: THbSectionHeader;
    FBtnLayout: TLayout;
    FBtnPrimary: THbButton;
    FBtnGhost: THbButton;
    FBtnSoft: THbButton;
    FBtnDanger: THbButton;
    FBtnPill: THbButton;
    FDualBtn: THbDualButton;
    FChipLayout: TLayout;
    FChip1, FChip2, FChip3, FChip4: THbChip;
    FBadgeLayout: TLayout;
    FBadge1, FBadge2, FBadge3: THbBadge;
    FAvatarLayout: TLayout;
    FAvatar1, FAvatar2, FAvatar3, FAvatar4: THbAvatar;
    FRingLayout: TLayout;
    FRing1, FRing2: THbProgressRing;
    FSkeletonLayout: TLayout;
    FSkeleton1, FSkeleton2: THbSkeleton;
    FToast1, FToast2: THbToast;

    // Right Column Controls (Composite & Containers)
    FSec2: THbSectionHeader;
    FCardSurface: THbCard;
    FStat1: THbStatBig;
    FCardHero: THbCard;
    FStatHero: THbStatBig;
    FRow1, FRow2, FRow3: THbListRow;
    FEmptyState: THbEmptyState;

    procedure BuildUI;
    procedure OnThemeComboChange(Sender: TObject);
    procedure OnDensityComboChange(Sender: TObject);
    procedure OnThemeChanged(Sender: TObject);
    procedure UpdateWcagLabel;
  public
  end;

var
  FMXGalleryMainForm: TFMXGalleryMainForm;

implementation

{$R *.fmx}

procedure TFMXGalleryMainForm.FormCreate(Sender: TObject);
begin
  // Register all 10 built-in themes
  DeepBase.HB.Palettes.RegisterBuiltInThemes;

  // Listen to theme engine updates
  THbTheme.AddListener(OnThemeChanged);

  BuildUI;
  UpdateWcagLabel;
end;

procedure TFMXGalleryMainForm.FormDestroy(Sender: TObject);
begin
  THbTheme.RemoveListener(OnThemeChanged);
end;

procedure TFMXGalleryMainForm.OnThemeChanged(Sender: TObject);
begin
  UpdateWcagLabel;
  Invalidate;
end;

procedure TFMXGalleryMainForm.UpdateWcagLabel;
var
  Tokens: THbTokens;
  Reason: string;
  Passed: Boolean;
begin
  Tokens := THbTheme.Tokens;
  Passed := Tokens.ValidateWcagAA(Reason);
  if Passed then
  begin
    FLblWcag.Text := Format('WCAG 2.1 AA 验证: 通过 [墨/地: %.2f:1, 钮/色: %.2f:1]',
      [Tokens.CalculateContrastRatio(Tokens.Ink, Tokens.Surface),
       Tokens.CalculateContrastRatio(Tokens.OnPrimary, Tokens.Primary)]);
  end
  else
  begin
    FLblWcag.Text := 'WCAG 2.1 AA 验证失败: ' + Reason;
  end;
end;

procedure TFMXGalleryMainForm.OnThemeComboChange(Sender: TObject);
var
  ThemeId: string;
  Themes: TArray<THbThemeMetadata>;
  Idx: Integer;
begin
  Idx := FCmbTheme.ItemIndex;
  Themes := THbTheme.GetAvailableThemes;
  if (Idx >= 0) and (Idx < Length(Themes)) then
  begin
    ThemeId := Themes[Idx].Id;
    THbTheme.ApplyTheme(ThemeId, THbTheme.CurrentDensity);
  end;
end;

procedure TFMXGalleryMainForm.OnDensityComboChange(Sender: TObject);
begin
  if FCmbDensity.ItemIndex = 1 then
    THbTheme.SetDensity(hdCompact)
  else
    THbTheme.SetDensity(hdComfortable);
end;

procedure TFMXGalleryMainForm.BuildUI;
var
  Themes: TArray<THbThemeMetadata>;
  Meta: THbThemeMetadata;
  I, SelIdx: Integer;
begin
  // 1. Top Control Bar
  FTopBar := TPanel.Create(Self);
  FTopBar.Parent := Self;
  FTopBar.Align := TAlignLayout.Top;
  FTopBar.Height := 52;

  FLblTheme := TLabel.Create(FTopBar);
  FLblTheme.Parent := FTopBar;
  FLblTheme.Position.Point := TPointF.Create(16, 16);
  FLblTheme.Text := '主题选择:';
  FLblTheme.Width := 70;

  FCmbTheme := TComboBox.Create(FTopBar);
  FCmbTheme.Parent := FTopBar;
  FCmbTheme.Position.Point := TPointF.Create(90, 12);
  FCmbTheme.Width := 200;
  FCmbTheme.OnChange := OnThemeComboChange;

  Themes := THbTheme.GetAvailableThemes;
  SelIdx := 0;
  for I := 0 to Integer(High(Themes)) do
  begin
    Meta := Themes[I];
    FCmbTheme.Items.Add(Format('%s (%s)', [Meta.Name, Meta.NameEn]));
    if Meta.Id = THbTheme.CurrentId then
      SelIdx := I;
  end;
  FCmbTheme.ItemIndex := SelIdx;

  FLblDensity := TLabel.Create(FTopBar);
  FLblDensity.Parent := FTopBar;
  FLblDensity.Position.Point := TPointF.Create(310, 16);
  FLblDensity.Text := '密度模式:';
  FLblDensity.Width := 70;

  FCmbDensity := TComboBox.Create(FTopBar);
  FCmbDensity.Parent := FTopBar;
  FCmbDensity.Position.Point := TPointF.Create(385, 12);
  FCmbDensity.Width := 140;
  FCmbDensity.Items.Add('舒适 (Comfortable)');
  FCmbDensity.Items.Add('紧凑 (Compact)');
  if THbTheme.CurrentDensity = hdCompact then
    FCmbDensity.ItemIndex := 1
  else
    FCmbDensity.ItemIndex := 0;
  FCmbDensity.OnChange := OnDensityComboChange;

  FLblWcag := TLabel.Create(FTopBar);
  FLblWcag.Parent := FTopBar;
  FLblWcag.Position.Point := TPointF.Create(550, 16);
  FLblWcag.Width := 500;
  FLblWcag.Text := 'WCAG 2.1 AA 验证中...';

  // 2. Scrollable Body
  FScrollBox := TVertScrollBox.Create(Self);
  FScrollBox.Parent := Self;
  FScrollBox.Align := TAlignLayout.Client;

  FLayoutContent := TLayout.Create(FScrollBox);
  FLayoutContent.Parent := FScrollBox;
  FLayoutContent.Align := TAlignLayout.Top;
  FLayoutContent.Height := 760;
  FLayoutContent.Width := 1060;

  // Left Column
  FColLeft := TLayout.Create(FLayoutContent);
  FColLeft.Parent := FLayoutContent;
  FColLeft.Position.Point := TPointF.Create(16, 16);
  FColLeft.Width := 500;
  FColLeft.Height := 720;

  // Right Column
  FColRight := TLayout.Create(FLayoutContent);
  FColRight.Parent := FLayoutContent;
  FColRight.Position.Point := TPointF.Create(536, 16);
  FColRight.Width := 500;
  FColRight.Height := 720;

  // ==================== Left Column: 8 Atomic Controls ====================

  FSec1 := THbSectionHeader.Create(FColLeft);
  FSec1.Parent := FColLeft;
  FSec1.Position.Point := TPointF.Create(0, 0);
  FSec1.Width := 500;
  FSec1.Height := 28;
  FSec1.Title := '1. 基础原子控件 (Atomic Controls)';
  FSec1.Count := 8;
  FSec1.TrailingLink := '规范文档 ' + #$2192;

  // Buttons Row
  FBtnLayout := TLayout.Create(FColLeft);
  FBtnLayout.Parent := FColLeft;
  FBtnLayout.Position.Point := TPointF.Create(0, 36);
  FBtnLayout.Width := 500;
  FBtnLayout.Height := 38;

  FBtnPrimary := THbButton.Create(FBtnLayout);
  FBtnPrimary.Parent := FBtnLayout;
  FBtnPrimary.Position.Point := TPointF.Create(0, 0);
  FBtnPrimary.Caption := '主操作';
  FBtnPrimary.Kind := bkPrimary;
  FBtnPrimary.Width := 90;

  FBtnGhost := THbButton.Create(FBtnLayout);
  FBtnGhost.Parent := FBtnLayout;
  FBtnGhost.Position.Point := TPointF.Create(100, 0);
  FBtnGhost.Caption := '线框';
  FBtnGhost.Kind := bkGhost;
  FBtnGhost.Width := 90;

  FBtnSoft := THbButton.Create(FBtnLayout);
  FBtnSoft.Parent := FBtnLayout;
  FBtnSoft.Position.Point := TPointF.Create(200, 0);
  FBtnSoft.Caption := '柔和';
  FBtnSoft.Kind := bkSoft;
  FBtnSoft.Width := 90;

  FBtnDanger := THbButton.Create(FBtnLayout);
  FBtnDanger.Parent := FBtnLayout;
  FBtnDanger.Position.Point := TPointF.Create(300, 0);
  FBtnDanger.Caption := '警示';
  FBtnDanger.Kind := bkDanger;
  FBtnDanger.Width := 90;

  FBtnPill := THbButton.Create(FBtnLayout);
  FBtnPill.Parent := FBtnLayout;
  FBtnPill.Position.Point := TPointF.Create(400, 0);
  FBtnPill.Caption := '胶囊';
  FBtnPill.Pill := True;
  FBtnPill.Width := 90;

  // Dual Button
  FDualBtn := THbDualButton.Create(FColLeft);
  FDualBtn.Parent := FColLeft;
  FDualBtn.Position.Point := TPointF.Create(0, 86);
  FDualBtn.Width := 300;
  FDualBtn.Height := 38;

  // Chips Row
  FChipLayout := TLayout.Create(FColLeft);
  FChipLayout.Parent := FColLeft;
  FChipLayout.Position.Point := TPointF.Create(0, 136);
  FChipLayout.Width := 500;
  FChipLayout.Height := 32;

  FChip1 := THbChip.Create(FChipLayout);
  FChip1.Parent := FChipLayout;
  FChip1.Position.Point := TPointF.Create(0, 0);
  FChip1.Caption := '全部意向';
  FChip1.Tone := ttBrand;
  FChip1.Selected := True;
  FChip1.Width := 85;

  FChip2 := THbChip.Create(FChipLayout);
  FChip2.Parent := FChipLayout;
  FChip2.Position.Point := TPointF.Create(95, 0);
  FChip2.Caption := '高意向';
  FChip2.Tone := ttSuccess;
  FChip2.Width := 80;

  FChip3 := THbChip.Create(FChipLayout);
  FChip3.Parent := FChipLayout;
  FChip3.Position.Point := TPointF.Create(185, 0);
  FChip3.Caption := '跟进中';
  FChip3.Tone := ttWarning;
  FChip3.Width := 80;

  FChip4 := THbChip.Create(FChipLayout);
  FChip4.Parent := FChipLayout;
  FChip4.Position.Point := TPointF.Create(275, 0);
  FChip4.Caption := '待分配';
  FChip4.Tone := ttDanger;
  FChip4.Closable := True;
  FChip4.Width := 95;

  // Badges Row
  FBadgeLayout := TLayout.Create(FColLeft);
  FBadgeLayout.Parent := FColLeft;
  FBadgeLayout.Position.Point := TPointF.Create(0, 180);
  FBadgeLayout.Width := 500;
  FBadgeLayout.Height := 26;

  FBadge1 := THbBadge.Create(FBadgeLayout);
  FBadge1.Parent := FBadgeLayout;
  FBadge1.Position.Point := TPointF.Create(0, 0);
  FBadge1.Caption := '进行中';
  FBadge1.Tone := btBrand;
  FBadge1.Width := 65;

  FBadge2 := THbBadge.Create(FBadgeLayout);
  FBadge2.Parent := FBadgeLayout;
  FBadge2.Position.Point := TPointF.Create(75, 0);
  FBadge2.Caption := '已归档';
  FBadge2.Tone := btNeutral;
  FBadge2.Width := 65;

  FBadge3 := THbBadge.Create(FBadgeLayout);
  FBadge3.Parent := FBadgeLayout;
  FBadge3.Position.Point := TPointF.Create(150, 0);
  FBadge3.Caption := '急需处理';
  FBadge3.Tone := btDanger;
  FBadge3.Shape := hpSquare;
  FBadge3.Width := 75;

  // Avatars Row
  FAvatarLayout := TLayout.Create(FColLeft);
  FAvatarLayout.Parent := FColLeft;
  FAvatarLayout.Position.Point := TPointF.Create(0, 220);
  FAvatarLayout.Width := 500;
  FAvatarLayout.Height := 52;

  FAvatar1 := THbAvatar.Create(FAvatarLayout);
  FAvatar1.Parent := FAvatarLayout;
  FAvatar1.Position.Point := TPointF.Create(0, 12);
  FAvatar1.Initials := '张';
  FAvatar1.Seed := '张总';
  FAvatar1.Size := avsS;
  FAvatar1.StatusDot := sdOnline;

  FAvatar2 := THbAvatar.Create(FAvatarLayout);
  FAvatar2.Parent := FAvatarLayout;
  FAvatar2.Position.Point := TPointF.Create(40, 6);
  FAvatar2.Initials := '李';
  FAvatar2.Seed := '李经理';
  FAvatar2.Size := avsM;
  FAvatar2.StatusDot := sdOnline;

  FAvatar3 := THbAvatar.Create(FAvatarLayout);
  FAvatar3.Parent := FAvatarLayout;
  FAvatar3.Position.Point := TPointF.Create(90, 0);
  FAvatar3.Initials := '王';
  FAvatar3.Seed := '王顾问';
  FAvatar3.Size := avsL;
  FAvatar3.StatusDot := sdAway;

  FAvatar4 := THbAvatar.Create(FAvatarLayout);
  FAvatar4.Parent := FAvatarLayout;
  FAvatar4.Position.Point := TPointF.Create(150, 0);
  FAvatar4.Initials := 'HB';
  FAvatar4.Seed := '唤金AI';
  FAvatar4.Size := avsL;
  FAvatar4.StatusDot := sdOnline;

  // Progress Rings Row
  FRingLayout := TLayout.Create(FColLeft);
  FRingLayout.Parent := FColLeft;
  FRingLayout.Position.Point := TPointF.Create(0, 286);
  FRingLayout.Width := 500;
  FRingLayout.Height := 54;

  FRing1 := THbProgressRing.Create(FRingLayout);
  FRing1.Parent := FRingLayout;
  FRing1.Position.Point := TPointF.Create(0, 0);
  FRing1.Percent := 75;
  FRing1.Width := 48;
  FRing1.Height := 48;

  FRing2 := THbProgressRing.Create(FRingLayout);
  FRing2.Parent := FRingLayout;
  FRing2.Position.Point := TPointF.Create(70, 0);
  FRing2.Indeterminate := True;
  FRing2.Width := 48;
  FRing2.Height := 48;

  // Skeletons Row
  FSkeletonLayout := TLayout.Create(FColLeft);
  FSkeletonLayout.Parent := FColLeft;
  FSkeletonLayout.Position.Point := TPointF.Create(0, 354);
  FSkeletonLayout.Width := 500;
  FSkeletonLayout.Height := 30;

  FSkeleton1 := THbSkeleton.Create(FSkeletonLayout);
  FSkeleton1.Parent := FSkeletonLayout;
  FSkeleton1.Position.Point := TPointF.Create(0, 5);
  FSkeleton1.Shape := skLine;
  FSkeleton1.Width := 200;
  FSkeleton1.Height := 18;

  FSkeleton2 := THbSkeleton.Create(FSkeletonLayout);
  FSkeleton2.Parent := FSkeletonLayout;
  FSkeleton2.Position.Point := TPointF.Create(220, 0);
  FSkeleton2.Shape := skCircle;
  FSkeleton2.Width := 28;
  FSkeleton2.Height := 28;

  // Toasts
  FToast1 := THbToast.Create(FColLeft);
  FToast1.Parent := FColLeft;
  FToast1.Position.Point := TPointF.Create(0, 400);
  FToast1.Kind := tkSuccess;
  FToast1.MessageText := '同步完成 · 87 条新线索已更新';
  FToast1.AutoDismiss := False;
  FToast1.Width := 340;
  FToast1.Height := 38;

  FToast2 := THbToast.Create(FColLeft);
  FToast2.Parent := FColLeft;
  FToast2.Position.Point := TPointF.Create(0, 450);
  FToast2.Kind := tkWarning;
  FToast2.MessageText := '网络延迟较高，已自动转为离线模式';
  FToast2.AutoDismiss := False;
  FToast2.Width := 340;
  FToast2.Height := 38;

  // ==================== Right Column: 4 Composite Cards ====================

  FSec2 := THbSectionHeader.Create(FColRight);
  FSec2.Parent := FColRight;
  FSec2.Position.Point := TPointF.Create(0, 0);
  FSec2.Width := 500;
  FSec2.Height := 28;
  FSec2.Title := '2. 复合业务容器 (Composite Cards & Rows)';
  FSec2.Count := 4;
  FSec2.TrailingLink := '查看全部 ' + #$2192;

  // Stat Card (Surface)
  FCardSurface := THbCard.Create(FColRight);
  FCardSurface.Parent := FColRight;
  FCardSurface.Position.Point := TPointF.Create(0, 36);
  FCardSurface.Width := 240;
  FCardSurface.Height := 90;
  FCardSurface.Kind := ckSurface;
  FCardSurface.Elevation := elLow;

  FStat1 := THbStatBig.Create(FCardSurface);
  FStat1.Parent := FCardSurface;
  FStat1.Position.Point := TPointF.Create(16, 12);
  FStat1.Width := 208;
  FStat1.Height := 66;
  FStat1.Value := '¥128,500';
  FStat1.Caption := '本月已促成意向金';
  FStat1.TrendText := '18.4%';
  FStat1.TrendUp := True;

  // Stat Card (Hero Gradient)
  FCardHero := THbCard.Create(FColRight);
  FCardHero.Parent := FColRight;
  FCardHero.Position.Point := TPointF.Create(255, 36);
  FCardHero.Width := 240;
  FCardHero.Height := 90;
  FCardHero.Kind := ckHero;
  FCardHero.Elevation := elMedium;

  FStatHero := THbStatBig.Create(FCardHero);
  FStatHero.Parent := FCardHero;
  FStatHero.Position.Point := TPointF.Create(16, 12);
  FStatHero.Width := 208;
  FStatHero.Height := 66;
  FStatHero.Emphasis := peHero;
  FStatHero.Value := '94.2%';
  FStatHero.Caption := 'AI 方案采纳转化率';
  FStatHero.TrendText := '5.1%';
  FStatHero.TrendUp := True;

  // CRM List Rows
  FRow1 := THbListRow.Create(FColRight);
  FRow1.Parent := FColRight;
  FRow1.Position.Point := TPointF.Create(0, 140);
  FRow1.Width := 495;
  FRow1.Height := 56;
  FRow1.AvatarSeed := '张';
  FRow1.Title := '张总 · 华东总代理';
  FRow1.Badge1Text := '3天未联系';
  FRow1.Badge1Tone := btDanger;
  FRow1.ContextText := '上次意向: 订购 200 套 DeepSync 授权，关注交付周期';

  FRow2 := THbListRow.Create(FColRight);
  FRow2.Parent := FColRight;
  FRow2.Position.Point := TPointF.Create(0, 206);
  FRow2.Width := 495;
  FRow2.Height := 56;
  FRow2.AvatarSeed := '王';
  FRow2.Title := '王总监 · 智能装备';
  FRow2.Badge1Text := '已出方案';
  FRow2.Badge1Tone := btBrand;
  FRow2.ContextText := '需求: 接入 10 套工业网关并配置离线同步策略';

  FRow3 := THbListRow.Create(FColRight);
  FRow3.Parent := FColRight;
  FRow3.Position.Point := TPointF.Create(0, 272);
  FRow3.Width := 495;
  FRow3.Height := 56;
  FRow3.AvatarSeed := '赵';
  FRow3.Title := '赵经理 · 自动化工程';
  FRow3.Badge1Text := '暂缓跟进';
  FRow3.Badge1Tone := btNeutral;
  FRow3.ContextText := '预算审批中，预计下周五给明确答复';
  FRow3.Dimmed := True;

  // Empty State
  FEmptyState := THbEmptyState.Create(FColRight);
  FEmptyState.Parent := FColRight;
  FEmptyState.Position.Point := TPointF.Create(0, 342);
  FEmptyState.Width := 495;
  FEmptyState.Height := 170;
  FEmptyState.Title := '暂无待处理高风险工单';
  FEmptyState.HintText := '系统已完成今日全部巡检，当前 48 个数据节点均处于健康同步状态。';
  FEmptyState.ActionCaption := '刷新巡检状态';
end;

end.
