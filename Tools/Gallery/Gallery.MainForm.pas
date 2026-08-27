{ ============================================================================
  Gallery.MainForm - HB Theme Visual Infrastructure Gallery Application

  Version: 1.0 (Delphi 13.1 on Win64)
  Description: Visual showcase and interactive acceptance form for all 12
               vector-rendered HB components across all 10 built-in themes
               and density modes.
  ============================================================================ }

unit Gallery.MainForm;

interface

uses
  System.SysUtils,
  System.Classes,
  System.UITypes,
  System.UIConsts,
  Winapi.Windows,
  Winapi.Messages,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  DeepBase.VCL.HB.Theme,
  DeepBase.VCL.HB.Palettes,
  DeepBase.VCL.HB.Controls,
  DeepBase.VCL.HB.Cards;

type
  TGalleryMainForm = class(TForm)
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    FTopBar: TPanel;
    FLblTheme: TLabel;
    FCmbTheme: TComboBox;
    FLblDensity: TLabel;
    FCmbDensity: TComboBox;
    FLblWcag: TLabel;

    FScrollBox: TScrollBox;
    FColLeft: TPanel;
    FColRight: TPanel;

    // Left Column Components
    FSec1: THbSectionHeader;
    FBtnPrimary: THbButton;
    FBtnGhost: THbButton;
    FBtnSoft: THbButton;
    FBtnDanger: THbButton;
    FBtnPill: THbButton;
    FDualBtn: THbDualButton;
    FChip1, FChip2, FChip3, FChip4: THbChip;
    FBadge1, FBadge2, FBadge3: THbBadge;
    FAvatar1, FAvatar2, FAvatar3: THbAvatar;
    FRing1, FRing2: THbProgressRing;
    FSkeleton1, FSkeleton2: THbSkeleton;
    FToast1, FToast2: THbToast;

    // Right Column Components
    FSec2: THbSectionHeader;
    FCardSurface: THbCard;
    FStat1, FStat2: THbStatBig;
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
  GalleryMainForm: TGalleryMainForm;

implementation

{$R *.dfm}

procedure TGalleryMainForm.FormCreate(Sender: TObject);
begin
  // Register themes first
  RegisterBuiltInThemes;

  // Listen to theme changes
  THbTheme.AddListener(OnThemeChanged);

  BuildUI;
  UpdateWcagLabel;
end;

procedure TGalleryMainForm.FormDestroy(Sender: TObject);
begin
  THbTheme.RemoveListener(OnThemeChanged);
end;

procedure TGalleryMainForm.OnThemeChanged(Sender: TObject);
var
  Tokens: THbTokens;
begin
  Tokens := THbTheme.Tokens;
  Color := TColor(Tokens.Surface and $00FFFFFF);
  FTopBar.Color := TColor(Tokens.SurfaceAlt and $00FFFFFF);
  FLblTheme.Font.Color := TColor(Tokens.Ink and $00FFFFFF);
  FLblDensity.Font.Color := TColor(Tokens.Ink and $00FFFFFF);
  UpdateWcagLabel;
  Invalidate;
end;

procedure TGalleryMainForm.UpdateWcagLabel;
var
  Tokens: THbTokens;
  Valid: Boolean;
  Reason: string;
begin
  Tokens := THbTheme.Tokens;
  Valid := Tokens.ValidateWcagAA(Reason);
  if Valid then
  begin
    FLblWcag.Caption := '✓ WCAG AA 合规 (对比度 ≥ 4.5:1)';
    FLblWcag.Font.Color := clGreen;
  end
  else
  begin
    FLblWcag.Caption := '⚠ WCAG 对比度警告: ' + Reason;
    FLblWcag.Font.Color := clRed;
  end;
end;

procedure TGalleryMainForm.OnThemeComboChange(Sender: TObject);
var
  ThemeId: string;
begin
  case FCmbTheme.ItemIndex of
    0: ThemeId := 'huanjin-gold';
    1: ThemeId := 'huanjin-night';
    2: ThemeId := 'deeparw-indigo';
    3: ThemeId := 'admin-graphite';
    4: ThemeId := 'jade-emerald';
    5: ThemeId := 'rose-clay';
    6: ThemeId := 'frost-contrast';
    7: ThemeId := 'ocean-deep';
    8: ThemeId := 'violet-dusk';
    9: ThemeId := 'tea-green';
    else ThemeId := 'huanjin-gold';
  end;
  THbTheme.ApplyTheme(ThemeId, THbTheme.CurrentDensity);
end;

procedure TGalleryMainForm.OnDensityComboChange(Sender: TObject);
begin
  if FCmbDensity.ItemIndex = 1 then
    THbTheme.SetDensity(hdCompact)
  else
    THbTheme.SetDensity(hdComfortable);
end;

procedure TGalleryMainForm.BuildUI;
begin
  // 1. Top Control Bar
  FTopBar := TPanel.Create(Self);
  FTopBar.Parent := Self;
  FTopBar.Align := alTop;
  FTopBar.Height := 48;
  FTopBar.BevelOuter := bvNone;

  FLblTheme := TLabel.Create(Self);
  FLblTheme.Parent := FTopBar;
  FLblTheme.Caption := '选择主题:';
  FLblTheme.Left := 16;
  FLblTheme.Top := 15;

  FCmbTheme := TComboBox.Create(Self);
  FCmbTheme.Parent := FTopBar;
  FCmbTheme.Style := csDropDownList;
  FCmbTheme.Left := 80;
  FCmbTheme.Top := 12;
  FCmbTheme.Width := 160;
  FCmbTheme.Items.Add('暖金·曜 (默认亮色)');
  FCmbTheme.Items.Add('墨金·夜 (暗色沉浸)');
  FCmbTheme.Items.Add('数脉·靛 (科技商务)');
  FCmbTheme.Items.Add('玄石·极 (中台后台)');
  FCmbTheme.Items.Add('翠微·碧 (生机健康)');
  FCmbTheme.Items.Add('赤陶·暮 (温暖消费)');
  FCmbTheme.Items.Add('凝霜·素 (高对比可读)');
  FCmbTheme.Items.Add('沧海·蓝 (企业稳健)');
  FCmbTheme.Items.Add('紫暮·夜 (典雅智能)');
  FCmbTheme.Items.Add('茶青·韵 (自然雅致)');
  FCmbTheme.ItemIndex := 0;
  FCmbTheme.OnChange := OnThemeComboChange;

  FLblDensity := TLabel.Create(Self);
  FLblDensity.Parent := FTopBar;
  FLblDensity.Caption := '密度模式:';
  FLblDensity.Left := 260;
  FLblDensity.Top := 15;

  FCmbDensity := TComboBox.Create(Self);
  FCmbDensity.Parent := FTopBar;
  FCmbDensity.Style := csDropDownList;
  FCmbDensity.Left := 325;
  FCmbDensity.Top := 12;
  FCmbDensity.Width := 110;
  FCmbDensity.Items.Add('舒适 (默认)');
  FCmbDensity.Items.Add('紧凑 (小屏)');
  FCmbDensity.ItemIndex := 0;
  FCmbDensity.OnChange := OnDensityComboChange;

  FLblWcag := TLabel.Create(Self);
  FLblWcag.Parent := FTopBar;
  FLblWcag.Left := 460;
  FLblWcag.Top := 15;
  FLblWcag.Font.Style := [fsBold];

  // 2. Scrollable Body
  FScrollBox := TScrollBox.Create(Self);
  FScrollBox.Parent := Self;
  FScrollBox.Align := alClient;
  FScrollBox.BorderStyle := bsNone;

  // Left Column (Atomic)
  FColLeft := TPanel.Create(Self);
  FColLeft.Parent := FScrollBox;
  FColLeft.Width := 520;
  FColLeft.Height := 900;
  FColLeft.Align := alLeft;
  FColLeft.BevelOuter := bvNone;
  FColLeft.Padding.Left := 16;
  FColLeft.Padding.Right := 16;
  FColLeft.Padding.Top := 16;

  // Right Column (Composite Cards)
  FColRight := TPanel.Create(Self);
  FColRight.Parent := FScrollBox;
  FColRight.Width := 540;
  FColRight.Height := 900;
  FColRight.Align := alClient;
  FColRight.BevelOuter := bvNone;
  FColRight.Padding.Left := 16;
  FColRight.Padding.Right := 16;
  FColRight.Padding.Top := 16;

  // Populate Left Column
  FSec1 := THbSectionHeader.Create(Self);
  FSec1.Parent := FColLeft;
  FSec1.SetBounds(16, 16, 480, 28);
  FSec1.Title := '基础原子控件 (Atomic Controls)';
  FSec1.Count := 9;
  FSec1.TrailingLink := '查看文档 ↗';

  // Buttons
  FBtnPrimary := THbButton.Create(Self);
  FBtnPrimary.Parent := FColLeft;
  FBtnPrimary.SetBounds(16, 56, 100, 36);
  FBtnPrimary.Caption := '主操作';
  FBtnPrimary.Kind := bkPrimary;

  FBtnGhost := THbButton.Create(Self);
  FBtnGhost.Parent := FColLeft;
  FBtnGhost.SetBounds(126, 56, 100, 36);
  FBtnGhost.Caption := '幽灵按钮';
  FBtnGhost.Kind := bkGhost;

  FBtnSoft := THbButton.Create(Self);
  FBtnSoft.Parent := FColLeft;
  FBtnSoft.SetBounds(236, 56, 100, 36);
  FBtnSoft.Caption := '柔和按钮';
  FBtnSoft.Kind := bkSoft;

  FBtnDanger := THbButton.Create(Self);
  FBtnDanger.Parent := FColLeft;
  FBtnDanger.SetBounds(346, 56, 100, 36);
  FBtnDanger.Caption := '危险操作';
  FBtnDanger.Kind := bkDanger;

  // Dual Button & Pill
  FDualBtn := THbDualButton.Create(Self);
  FDualBtn.Parent := FColLeft;
  FDualBtn.SetBounds(16, 104, 260, 36);
  FDualBtn.CaptionFree := '开场白 · 免费';
  FDualBtn.CaptionPoints := 'AI 方案';
  FDualBtn.PointsCost := 5;

  FBtnPill := THbButton.Create(Self);
  FBtnPill.Parent := FColLeft;
  FBtnPill.SetBounds(286, 104, 120, 36);
  FBtnPill.Caption := '圆角胶囊';
  FBtnPill.Pill := True;

  // Chips
  FChip1 := THbChip.Create(Self);
  FChip1.Parent := FColLeft;
  FChip1.SetBounds(16, 152, 70, 28);
  FChip1.Caption := '全部';
  FChip1.Selected := True;

  FChip2 := THbChip.Create(Self);
  FChip2.Parent := FColLeft;
  FChip2.SetBounds(96, 152, 90, 28);
  FChip2.Caption := '高价值客户';
  FChip2.Tone := ttBrand;
  FChip2.Closable := True;

  FChip3 := THbChip.Create(Self);
  FChip3.Parent := FColLeft;
  FChip3.SetBounds(196, 152, 80, 28);
  FChip3.Caption := '已跟进';
  FChip3.Tone := ttSuccess;

  FChip4 := THbChip.Create(Self);
  FChip4.Parent := FColLeft;
  FChip4.SetBounds(286, 152, 80, 28);
  FChip4.Caption := '待挽回';
  FChip4.Tone := ttDanger;

  // Badges & Avatars
  FBadge1 := THbBadge.Create(Self);
  FBadge1.Parent := FColLeft;
  FBadge1.SetBounds(16, 192, 70, 22);
  FBadge1.Caption := '失联97天';
  FBadge1.Tone := btDanger;

  FBadge2 := THbBadge.Create(Self);
  FBadge2.Parent := FColLeft;
  FBadge2.SetBounds(96, 192, 60, 22);
  FBadge2.Caption := 'VIP客户';
  FBadge2.Tone := btBrand;

  FBadge3 := THbBadge.Create(Self);
  FBadge3.Parent := FColLeft;
  FBadge3.SetBounds(166, 192, 60, 22);
  FBadge3.Caption := '方形徽章';
  FBadge3.Shape := hpSquare;
  FBadge3.Tone := btSuccess;

  FAvatar1 := THbAvatar.Create(Self);
  FAvatar1.Parent := FColLeft;
  FAvatar1.SetBounds(250, 190, 32, 32);
  FAvatar1.Initials := '张';
  FAvatar1.Seed := '张';
  FAvatar1.StatusDot := sdOnline;

  FAvatar2 := THbAvatar.Create(Self);
  FAvatar2.Parent := FColLeft;
  FAvatar2.SetBounds(292, 186, 40, 40);
  FAvatar2.Initials := '李';
  FAvatar2.Seed := '李';
  FAvatar2.Size := avsL;
  FAvatar2.StatusDot := sdAway;

  FAvatar3 := THbAvatar.Create(Self);
  FAvatar3.Parent := FColLeft;
  FAvatar3.SetBounds(342, 186, 40, 40);
  FAvatar3.Initials := '王';
  FAvatar3.Seed := '王';
  FAvatar3.Size := avsL;
  FAvatar3.StatusDot := sdOffline;

  // Progress Rings & Skeleton
  FRing1 := THbProgressRing.Create(Self);
  FRing1.Parent := FColLeft;
  FRing1.SetBounds(16, 236, 64, 64);
  FRing1.Percent := 75.0;

  FRing2 := THbProgressRing.Create(Self);
  FRing2.Parent := FColLeft;
  FRing2.SetBounds(96, 236, 64, 64);
  FRing2.Indeterminate := True;

  FSkeleton1 := THbSkeleton.Create(Self);
  FSkeleton1.Parent := FColLeft;
  FSkeleton1.SetBounds(180, 240, 220, 16);

  FSkeleton2 := THbSkeleton.Create(Self);
  FSkeleton2.Parent := FColLeft;
  FSkeleton2.SetBounds(180, 268, 160, 16);

  // Toasts
  FToast1 := THbToast.Create(Self);
  FToast1.Parent := FColLeft;
  FToast1.SetBounds(16, 320, 380, 38);
  FToast1.Kind := tkSuccess;
  FToast1.MessageText := '操作成功：客户已加入跟进提醒列表';

  FToast2 := THbToast.Create(Self);
  FToast2.Parent := FColLeft;
  FToast2.SetBounds(16, 368, 380, 38);
  FToast2.Kind := tkWarning;
  FToast2.MessageText := 'AI 点数余额不足 5 点，请及时充值';

  // Populate Right Column
  FSec2 := THbSectionHeader.Create(Self);
  FSec2.Parent := FColRight;
  FSec2.SetBounds(16, 16, 480, 28);
  FSec2.Title := '业务复合容器与卡片 (Containers & Cards)';
  FSec2.Count := 4;

  // Hero Card
  FCardHero := THbCard.Create(Self);
  FCardHero.Parent := FColRight;
  FCardHero.SetBounds(16, 56, 460, 80);
  FCardHero.Kind := ckHero;

  FStatHero := THbStatBig.Create(Self);
  FStatHero.Parent := FCardHero;
  FStatHero.SetBounds(16, 12, 200, 56);
  FStatHero.Value := '386';
  FStatHero.Caption := '沉睡总资产 (万元)';
  FStatHero.Emphasis := peHero;

  // Surface Card with stats
  FCardSurface := THbCard.Create(Self);
  FCardSurface.Parent := FColRight;
  FCardSurface.SetBounds(16, 148, 460, 80);
  FCardSurface.Kind := ckSurface;

  FStat1 := THbStatBig.Create(Self);
  FStat1.Parent := FCardSurface;
  FStat1.SetBounds(16, 12, 180, 56);
  FStat1.Value := '43';
  FStat1.Caption := '沉睡高价值客户 (人)';

  FStat2 := THbStatBig.Create(Self);
  FStat2.Parent := FCardSurface;
  FStat2.SetBounds(220, 12, 180, 56);
  FStat2.Value := '12';
  FStat2.Caption := '今日已唤醒 (人)';
  FStat2.Emphasis := peNormal;

  // List Rows
  FRow1 := THbListRow.Create(Self);
  FRow1.Parent := FColRight;
  FRow1.SetBounds(16, 240, 460, 56);
  FRow1.AvatarSeed := '张';
  FRow1.Title := '张姐';
  FRow1.Badge1Text := '失联97天';
  FRow1.ContextText := '上次：问完价格没回她 · 历史成交 2 单';
  FRow1.FreeButtonText := '开场白 · 免费';
  FRow1.PointsButtonText := 'AI 方案';
  FRow1.PointsCost := 5;

  FRow2 := THbListRow.Create(Self);
  FRow2.Parent := FColRight;
  FRow2.SetBounds(16, 304, 460, 56);
  FRow2.AvatarSeed := '李';
  FRow2.Title := '李总 (华南)';
  FRow2.Badge1Text := '失联120天';
  FRow2.ContextText := '上次：咨询了升级版 · 意向极高';
  FRow2.FreeButtonText := '开场白 · 免费';
  FRow2.PointsButtonText := 'AI 方案';
  FRow2.PointsCost := 5;

  FRow3 := THbListRow.Create(Self);
  FRow3.Parent := FColRight;
  FRow3.SetBounds(16, 368, 460, 56);
  FRow3.AvatarSeed := '王';
  FRow3.Title := '王经理';
  FRow3.Badge1Text := '已跟进';
  FRow3.Badge1Tone := btSuccess;
  FRow3.ContextText := '今天 09:30 已发送唤醒方案 · 等待回复';
  FRow3.FreeButtonText := '查看记录';
  FRow3.PointsButtonText := '二次追问';
  FRow3.PointsCost := 3;
  FRow3.Dimmed := True;

  // Empty State
  FEmptyState := THbEmptyState.Create(Self);
  FEmptyState.Parent := FColRight;
  FEmptyState.SetBounds(16, 440, 460, 160);
  FEmptyState.Glyph := '🪙';
  FEmptyState.Title := '还没有待挽回的客户';
  FEmptyState.Hint := '你的联系人都在健康活跃期，这是极好的状态';
  FEmptyState.ActionCaption := '去扫描新的沉睡线索';

  OnThemeChanged(Self);
end;

end.
