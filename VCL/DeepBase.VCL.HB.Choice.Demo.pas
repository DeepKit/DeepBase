{ ============================================================================
  DeepBase.VCL.HB.Choice.Demo - Comprehensive Showcase for HB AI Choice Standard

  Version: 2.0 (Delphi 13.1 on Win64)
  Description: Interactive Demonstration for HB AI Choice Interaction Standard:
               - Showcase 1: AI Intent & Icebreaker Flow (Continuous 2 -> 1)
               - Showcase 2: Contact List Compact (Mode B clmRow Compact)
               - Showcase 3: AI Uncertainty / No Reliable Candidates State
               - Showcase 4: Generic AI Writing Assistant (Multi-Layout Switcher)
               - Full keyboard (0-9 / NumPad) & mouse multi-modal telemetry log
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
    FCmbShowcase: THbComboBox;
    FCmbLayout: THbComboBox;
    FLblResult: TLabel;
    FLblTelemetry: TLabel;

    FCurrentFlowStep: Integer;

    procedure OnChoiceAction(Sender: TObject; const AAction: THbChoiceAction);
    procedure OnShowcaseChange(Sender: TObject);
    procedure OnLayoutChange(Sender: TObject);
    procedure LoadShowcase(AShowcaseIdx: Integer);
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
  Caption := 'HB AI Choice Interaction Standard - 交互标准全景演示';
  Width := 1120;
  Height := 720;
  Position := poScreenCenter;

  FPnlTop := TPanel.Create(Self);
  FPnlTop.Parent := Self;
  FPnlTop.Align := alTop;
  FPnlTop.Height := 56;
  FPnlTop.BevelOuter := bvNone;

  FCmbShowcase := THbComboBox.Create(FPnlTop);
  FCmbShowcase.Parent := FPnlTop;
  FCmbShowcase.Left := 16;
  FCmbShowcase.Top := 12;
  FCmbShowcase.Width := 240;
  FCmbShowcase.Items.Add('场景 1: 联系人意图与开场');
  FCmbShowcase.Items.Add('场景 2: 资料快速整理 (Row)');
  FCmbShowcase.Items.Add('场景 3: AI 无法形成可靠候选 (NoCandidates)');
  FCmbShowcase.Items.Add('场景 4: 通用 AI·文档写作与润色助手');
  FCmbShowcase.ItemIndex := 0;
  FCmbShowcase.OnChange := OnShowcaseChange;

  FCmbLayout := THbComboBox.Create(FPnlTop);
  FCmbLayout.Parent := FPnlTop;
  FCmbLayout.Left := 268;
  FCmbLayout.Top := 12;
  FCmbLayout.Width := 150;
  FCmbLayout.Items.Add('Mode A: 标准卡片叠 (Deck)');
  FCmbLayout.Items.Add('Mode B: 紧凑行 (Row)');
  FCmbLayout.Items.Add('Mode C: 编号列表 (List)');
  FCmbLayout.Items.Add('Mode D: 行内轻选择 (Inline)');
  FCmbLayout.ItemIndex := 0;
  FCmbLayout.OnChange := OnLayoutChange;

  FLblResult := TLabel.Create(FPnlTop);
  FLblResult.Parent := FPnlTop;
  FLblResult.Left := 436;
  FLblResult.Top := 10;
  FLblResult.Caption := '当前选择: 未选 (按键盘 1-7, 8, 9, 0 或点击)';

  FLblTelemetry := TLabel.Create(FPnlTop);
  FLblTelemetry.Parent := FPnlTop;
  FLblTelemetry.Left := 436;
  FLblTelemetry.Top := 30;
  FLblTelemetry.Font.Color := clGray;
  FLblTelemetry.Caption := '输入源: None | 动作意图: None';

  FPnlLeft := TPanel.Create(Self);
  FPnlLeft.Parent := Self;
  FPnlLeft.Align := alLeft;
  FPnlLeft.Width := 460;
  FPnlLeft.BevelOuter := bvNone;

  FDeck := THbChoiceDeck.Create(FPnlLeft);
  FDeck.Parent := FPnlLeft;
  FDeck.Align := alClient;
  FDeck.OnAction := OnChoiceAction;

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
  FCurrentFlowStep := 1;
  LoadShowcase(0);

  // Setup right waterfall inspector
  FWall.Clear;
  FWall.AddFacet('std', 'HB AI Choice 核心交互协议', 4);
  FWall.AddFacet('rule', '焦点与键盘纪律', 3);

  FWall.AddCard('s1', 'std', 'HB AI Choice 核心交互协议', '1–7 动态候选空间', 'Key 1 为推荐项，支持0-7动态项，非强迫凑满',
    'DeepBase.VCL.HB.Choice.pas', wisNormal, btBrand, '', 0);
  FWall.AddCard('s2', 'std', 'HB AI Choice 核心交互协议', '8 重新生成 (Regenerate)', '上下文重构，禁止自动写入业务决策或破坏状态',
    'DeepBase.HB.Choice.Types.pas', wisNormal, btBrand, 's1', 1);
  FWall.AddCard('s3', 'std', 'HB AI Choice 核心交互协议', '9 人类覆写 (Human Override)', '一等公民，支持单行/多行内置输入与打破预设框架 (Frame Rejection)',
    'DeepBase.HB.Choice.Types.pas', wisNormal, btBrand, 's1', 1);
  FWall.AddCard('s4', 'std', 'HB AI Choice 核心交互协议', '0 导航返回 (Navigation Back)', '纯粹导航回退，严禁映射为业务拒绝 (Reject/Decline)',
    'DeepBase.HB.Choice.Types.pas', wisNormal, btBrand, 's1', 1);

  FWall.AddCard('r1', 'rule', '焦点与键盘纪律', 'Text Entry Owns Keyboard', '文本输入框/IME激活期间，绝对暂停 0–9 快捷键拦截',
    'DeepBase.VCL.HB.Choice.pas', wisNormal, btSuccess, '', 0);
  FWall.AddCard('r2', 'rule', '焦点与键盘纪律', 'Active Choice Surface', '任一时刻全局唯一 Active Deck 响应按键，防止多实例冲突',
    'DeepBase.VCL.HB.Choice.pas', wisNormal, btSuccess, 'r1', 1);
  FWall.AddCard('r3', 'rule', '焦点与键盘纪律', 'Truthful AI States', '诚实呈现 NoReliableCandidates 与 Error，杜绝把技术异常包装成AI无候选',
    'DeepBase.HB.Choice.Types.pas', wisNormal, btSuccess, 'r1', 1);

  FWall.Granularity := gMedium;
end;

procedure THbChoiceAndWaterfallDemoForm.LoadShowcase(AShowcaseIdx: Integer);
begin
  FDeck.ResetToReady;
  case AShowcaseIdx of
    0: // Intent & Flow
    begin
      FCurrentFlowStep := 1;
      FDeck.LayoutMode := clmDeck;
      FCmbLayout.ItemIndex := 0;
      FDeck.ContextTitle := 'AI：你这次想怎么联系他？';
      FDeck.StepInfo := '步骤 1/2';
      FDeck.Clear;
      FDeck.AddOption(1, '跟进上次的事', '聊聊上次方案的进展与反馈', True);
      FDeck.AddOption(2, '重新联系', '很长时间没联系，重新打个招呼', False);
      FDeck.AddOption(3, '问候近况', '轻松闲聊，不涉及具体业务', False);
      FDeck.AddOption(4, '邀请参加活动', '发送产品发布会/沙龙邀请', False);
      FDeck.AddOption(5, '催一下进度', '礼貌提醒上次约定的交付时间', False);
      FDeck.AddStandardControls(True, True, True);
    end;

    1: // Contact Tidy (Mode B)
    begin
      FDeck.LayoutMode := clmRow;
      FCmbLayout.ItemIndex := 1;
      FDeck.ContextTitle := '刘老师的资料还可以补什么？';
      FDeck.StepInfo := '快速整理';
      FDeck.Clear;
      FDeck.AddOption(1, '补真实姓名', '', True);
      FDeck.AddOption(2, '修改备注', '', False);
      FDeck.AddOption(3, '加标签', '', False);
      FDeck.AddOption(4, '补手机号', '', False);
      FDeck.AddOption(5, '关系备注', '', False);
      FDeck.AddOption(6, '先这样', '', False);
      FDeck.AddStandardControls(False, True, True); // No regenerate, keep 9 and 0
    end;

    2: // AI Uncertainty / No Reliable Candidates
    begin
      FDeck.LayoutMode := clmDeck;
      FCmbLayout.ItemIndex := 0;
      FDeck.ContextTitle := '联系意图分析';
      FDeck.StepInfo := '信息不足';
      FDeck.Clear;
      FDeck.SetNoReliableCandidates('目前的信息还不足以给出可靠候选。');
      FDeck.AddOption(8, '再试一次', '重新检索并生成', False);
      FDeck.AddOption(9, '自己说明', '手动补充具体诉求与上下文', False);
      FDeck.AddOption(0, '返回', '回退到上一界面', False);
    end;

    3: // Generic AI Writing Assistant
    begin
      FDeck.LayoutMode := clmDeck;
      FCmbLayout.ItemIndex := 0;
      FDeck.ContextTitle := 'AI 写作助手：你希望怎么处理这段文字？';
      FDeck.StepInfo := '段落润色';
      FDeck.Clear;
      FDeck.AddOption(1, '缩短篇幅', '提炼核心要点，删除冗余词句', True);
      FDeck.AddOption(2, '更加专业', '使用行业标准术语，提升严谨度', False);
      FDeck.AddOption(3, '更加友好', '语气亲切温和，拉近与读者距离', False);
      FDeck.AddOption(4, '提取行动项 (Action Items)', '将文字转为清晰的 Todo 待办列表', False);
      FDeck.AddOption(5, '转换为商务邮件格式', '增加标准邮件问候、正文与署名结构', False);
      FDeck.AddStandardControls(True, True, True);
    end;
  end;
end;

procedure THbChoiceAndWaterfallDemoForm.OnChoiceAction(Sender: TObject; const AAction: THbChoiceAction);
var
  SourceStr, KindStr: string;
begin
  case AAction.InputSource of
    cisMouse:         SourceStr := 'Mouse (鼠标点击)';
    cisKeyboard:      SourceStr := 'Keyboard (主键盘数字)';
    cisNumPad:        SourceStr := 'NumPad (小键盘数字)';
    cisVoice:         SourceStr := 'Voice (语音指令)';
    cisAccessibility: SourceStr := 'Accessibility (无障碍)';
    cisProgrammatic:  SourceStr := 'Programmatic (代码触发)';
  end;

  case AAction.Kind of
    cakCandidate:  KindStr := 'Candidate (候选选择)';
    cakRegenerate: KindStr := 'Regenerate (重新生成)';
    cakFreeInput:  KindStr := 'FreeInput (人类覆写/输入)';
    cakBack:       KindStr := 'Back (导航返回)';
  end;

  FLblResult.Caption := Format('当前触发: Key [%d] "%s" (时间: %s)',
    [AAction.Key, AAction.Text, FormatDateTime('hh:nn:ss.zzz', Now)]);
  FLblTelemetry.Caption := Format('输入源: %s | 动作意图: %s', [SourceStr, KindStr]);

  // Demo Continuous Flow for Showcase 0
  if FCmbShowcase.ItemIndex = 0 then
  begin
    if (FCurrentFlowStep = 1) and (AAction.Key in [1..5]) then
    begin
      // Advance to Step 2
      FCurrentFlowStep := 2;
      FDeck.ContextTitle := 'AI：更想怎么开场？';
      FDeck.StepInfo := '步骤 2/2';
      FDeck.Clear;
      FDeck.AddOption(1, '自然一点', '像熟人重新联系，不直接谈具体业务', True);
      FDeck.AddOption(2, '先聊近况', '询问最近的工作与生活状态', False);
      FDeck.AddOption(3, '从以前的事切入', '提及上次合作或交流的话题', False);
      FDeck.AddOption(4, '直接一点', '说明来意，高效沟通', False);
      FDeck.AddStandardControls(True, True, True);
    end
    else if (FCurrentFlowStep = 2) and (AAction.Key = 0) then
    begin
      // Return to Step 1
      LoadShowcase(0);
    end
    else if AAction.Key = 8 then
    begin
      // Simulate light regeneration
      FDeck.BeginRegenerate;
      // In real app, async LLM returns new candidates; here we reset after state check
    end;
  end;
end;

procedure THbChoiceAndWaterfallDemoForm.OnShowcaseChange(Sender: TObject);
begin
  LoadShowcase(FCmbShowcase.ItemIndex);
end;

procedure THbChoiceAndWaterfallDemoForm.OnLayoutChange(Sender: TObject);
begin
  if FCmbLayout.ItemIndex in [0..3] then
    FDeck.LayoutMode := THbChoiceLayoutMode(FCmbLayout.ItemIndex);
end;

end.
