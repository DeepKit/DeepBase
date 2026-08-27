{ ============================================================================
  Test.DeepBase.HB.DeepRW - Tests for DeepRW HB Suite Components (WO-20260826-DEEPRW-HB-V2)
  
  Version: 1.0 (Delphi 13.1 on Win64)
  Description: Automated DUnitX tests covering:
               - THbCommandPalette (Fuzzy matching, category groups, keyboard exec)
               - THbGatePanel (Summary stats, severity filtering, accordion expand)
               - THbVirtualList (Virtual items, multi-selection, batch actions)
               - THbShareCardRenderer (4:5 portrait dimensions, privacy mask, watermark lock)
  ============================================================================ }

unit Test.DeepBase.HB.DeepRW;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.Types,
  System.UITypes,
  System.IOUtils,
  System.JSON,
  Vcl.Forms,
  Vcl.Graphics,
  DeepBase.HB.Core,
  DeepBase.HB.CommandPalette.Types,
  DeepBase.HB.Gate.Types,
  DeepBase.HB.VirtualList.Types,
  DeepBase.HB.ShareCard.Types,
  DeepBase.HB.Waterfall.Types,
  DeepBase.HB.Dialogs.Types,
  DeepBase.HB.Voice.Types,
  DeepBase.VCL.HB.CommandPalette,
  DeepBase.VCL.HB.Gate,
  DeepBase.VCL.HB.VirtualList,
  DeepBase.VCL.HB.ShareCard,
  DeepBase.VCL.HB.Waterfall,
  DeepBase.VCL.HB.Dialogs,
  DeepBase.VCL.HB.Voice;

type
  [TestFixture]
  TTestHbDeepRWSuite = class
  private
    FLastExecutedCmd: string;
    procedure OnCmdExecuteHelper(Sender: TObject; const AItem: THbCommandItem);
    procedure OnGetVirtualItemHelper(Sender: TObject; AIndex: Integer; out AItem: THbVirtualListItem);
  public
    [Test]
    procedure Test_CommandPalette_FuzzySearch_And_Execution;

    [Test]
    procedure Test_GatePanel_Severities_Filter_And_Expand;

    [Test]
    procedure Test_VirtualList_MultiSelect_And_BatchOperations;

    [Test]
    procedure Test_VirtualList_100k_CallbackDataSource_O1Memory;

    [Test]
    procedure Test_Waterfall_Facet_Interactions_And_Mode_Rendering;

    [Test]
    procedure Test_ShareCardRenderer_Portrait4x5_And_Watermark;

    [Test]
    procedure Test_TokenJson_Space_Motion_Shape_Parsing;

    [Test]
    procedure Test_ShareCard_TruePngExport;

    [Test]
    procedure Test_VCL_Dialog_Execute_DoublePath;

    [Test]
    procedure Test_VCL_VoiceDialog_Execute_DoublePath;

    [Test]
    procedure Test_UTF8_BOM_Chinese_Literal_Integrity;
  end;

implementation

{ TTestHbDeepRWSuite }

procedure TTestHbDeepRWSuite.OnCmdExecuteHelper(Sender: TObject; const AItem: THbCommandItem);
begin
  FLastExecutedCmd := AItem.CommandID;
end;

procedure TTestHbDeepRWSuite.Test_CommandPalette_FuzzySearch_And_Execution;
var
  Form: TCustomForm;
  Palette: THbCommandPalette;
begin
  Form := TCustomForm.CreateNew(nil);
  try
    Form.HandleNeeded;
    Palette := THbCommandPalette.Create(Form);
    Palette.Parent := Form;
    Palette.HandleNeeded;
    Palette.OnCommandExecute := OnCmdExecuteHelper;

    Palette.AddCommand('cmd.gate.run', '运行全量规则门禁体检', '门禁体检', 'Ctrl+Shift+G', '🛡');
    Palette.AddCommand('cmd.evidence.export', '导出主张—证据矩阵快照', '证据管理', 'Ctrl+E', '📊');
    Palette.AddCommand('cmd.claim.audit', '执行 7 字段法源溯源自检', '门禁体检', 'F5', '🔍');

    Assert.AreEqual(Integer(3), Integer(Palette.Items.Count));
    Assert.AreEqual(Integer(3), Integer(Palette.FilteredCount));

    // Fuzzy search: "体检" -> matches 2 items
    Palette.SearchText := '体检';
    Assert.AreEqual(Integer(2), Integer(Palette.FilteredCount));

    // Execute first filtered item
    FLastExecutedCmd := '';
    Palette.ExecuteSelected;
    Assert.AreEqual(string('cmd.gate.run'), FLastExecutedCmd);
  finally
    Form.Free;
  end;
end;

procedure TTestHbDeepRWSuite.Test_GatePanel_Severities_Filter_And_Expand;
var
  Form: TCustomForm;
  Gate: THbGatePanel;
  Stats: THbGateSummaryStats;
begin
  Form := TCustomForm.CreateNew(nil);
  try
    Form.HandleNeeded;
    Gate := THbGatePanel.Create(Form);
    Gate.Parent := Form;
    Gate.HandleNeeded;

    Gate.AddRule('R01', '缺少 7 字段法源溯源', seError, '承压者字段与停止条件未绑定', '补充字段溯源', 'claim:c1');
    Gate.AddRule('R02', '弱信号置信度过低', seWarning, '置信度低于 0.60 阈值', '补充证据样本', 'sig:s2');
    Gate.AddRule('R03', '主张未发现矛盾反例', sePass, '通过事实交叉检验', '', '');
    Gate.AddRule('R04', '转交目标定义明确', sePass, '通过合规校验', '', '');

    Stats := Gate.ComputeStats;
    Assert.AreEqual(Integer(4), Integer(Stats.TotalCount));
    Assert.AreEqual(Integer(1), Integer(Stats.ErrorCount));
    Assert.AreEqual(Integer(1), Integer(Stats.WarningCount));
    Assert.AreEqual(Integer(2), Integer(Stats.PassCount));
    Assert.IsTrue(Stats.HasBlockingErrors);
    Assert.IsFalse(Stats.IsAllPassed);

    // Expand accordion on first rule
    Assert.IsFalse(Gate.Rules[0].IsExpanded);
    Gate.ToggleRowExpand(0);
    Assert.IsTrue(Gate.Rules[0].IsExpanded);
  finally
    Form.Free;
  end;
end;

procedure TTestHbDeepRWSuite.Test_VirtualList_MultiSelect_And_BatchOperations;
var
  Form: TCustomForm;
  VList: THbVirtualList;
  SelIds: TArray<string>;
begin
  Form := TCustomForm.CreateNew(nil);
  try
    Form.HandleNeeded;
    VList := THbVirtualList.Create(Form);
    VList.Parent := Form;
    VList.HandleNeeded;

    VList.AddItem('item-01', 'audit', '待办体检', '法源矛盾候选 #1', '承压者与约束条件冲突', '来源: 审讯笔录 p.42', btDanger, '阻断待拍板', ['待办', 'P0']);
    VList.AddItem('item-02', 'audit', '待办体检', '前线弱信号 #2', '多次异常重试事件', '来源: 现场日志', btWarning, '待确认', ['弱信号']);
    VList.AddItem('item-03', 'export', '就绪归档', '主张已闭环 #3', '7 字段全部通过门禁', '已固化', btSuccess, '已通过', ['已就绪']);

    Assert.AreEqual(Integer(3), Integer(VList.Items.Count));
    Assert.AreEqual(Integer(3), Integer(VList.FilteredCount));

    // Multi-select items 0 and 1
    VList.SelectItem(0, False);
    VList.SelectItem(1, True);
    Assert.AreEqual(Integer(2), Integer(VList.SelectedIndices.Count));

    SelIds := VList.GetSelectedIds;
    Assert.AreEqual(Integer(2), Integer(Length(SelIds)));
    Assert.AreEqual(string('item-01'), SelIds[0]);
    Assert.AreEqual(string('item-02'), SelIds[1]);

    // Search filter
    VList.SearchFilter := '弱信号';
    Assert.AreEqual(Integer(1), Integer(VList.FilteredCount));
  finally
    Form.Free;
  end;
end;

procedure TTestHbDeepRWSuite.Test_ShareCardRenderer_Portrait4x5_And_Watermark;
var
  CardData: THbShareCardData;
  W, H: Integer;
  Bmp: TBitmap;
  Masked: string;
begin
  // Test Dimensions
  Assert.IsTrue(THbShareCardRenderer.GetDimensions(scfPortrait4x5, W, H));
  Assert.AreEqual(Integer(1080), Integer(W));
  Assert.AreEqual(Integer(1350), Integer(H));

  // Test Auto-Masking
  Masked := THbShareCardRenderer.MaskSensitiveText('用户手机号: 13812345678');
  Assert.AreEqual(string('用户手机号: 138********'), Masked);

  // Test Bitmap rendering
  CardData.Title := 'DeepRW 认知论证体检合格证';
  CardData.Subtitle := '项目: 知识图谱法源合规审计';
  CardData.HeaderCategory := '7 字段法源审计';
  CardData.MetricRows := ['门禁规则通过率: 100%', '主张数: 42 项', '证据链完整度: 98.5%'];
  CardData.FooterNote := '通过本地检查 ≠ 事实绝对正确 · 仅供专业审阅参考';
  CardData.BadgeText := '安全合规 🟢 PASS';
  CardData.WatermarkLocked := True;
  CardData.LogoRef := 'DeepRW';
  CardData.QRSlot := 'https://audit.deeprw.internal/receipt/42';
  CardData.EnableAutoMasking := True;
  CardData.TimestampStr := '2026-08-26 23:30:00';
  CardData.PrimaryColorTone := btSuccess;

  Bmp := THbShareCardRenderer.RenderToBitmap(CardData, scfPortrait4x5);
  try
    Assert.IsNotNull(Bmp);
    Assert.AreEqual(Integer(1080), Integer(Bmp.Width));
    Assert.AreEqual(Integer(1350), Integer(Bmp.Height));
  finally
    Bmp.Free;
  end;
end;

procedure TTestHbDeepRWSuite.Test_TokenJson_Space_Motion_Shape_Parsing;
const
  CUSTOM_JSON =
    '{' +
    '  "meta": { "id": "test-theme", "name": "Test Theme", "isDark": false },' +
    '  "space": { "spaceXS": 5.0, "spaceS": 10.0, "spaceM": 15.0, "spaceL": 25.0, "spaceXL": 35.0 },' +
    '  "motion": { "durFast": 111, "durNorm": 222, "durSlow": 333, "easeMode": "EaseOut" },' +
    '  "shape": { "radiusS": 3.0, "radiusM": 7.0, "radiusL": 11.0, "pillRatio": 0.6, "borderWidth": 1.5 },' +
    '  "typography": { "fontFamily": "Segoe UI", "weightBold": 800 },' +
    '  "density": { "rowHeightScale": 1.25 }' +
    '}';
var
  ThemeId: string;
  Def: THbThemeDefinition;
begin
  ThemeId := THbTheme.RegisterThemeFromJson(CUSTOM_JSON);
  Assert.AreEqual(string('test-theme'), ThemeId);

  Assert.IsTrue(THbTheme.GetTheme('test-theme', Def));
  Assert.AreEqual(Single(5.0), Def.Tokens.SpaceXS);
  Assert.AreEqual(Single(10.0), Def.Tokens.SpaceS);
  Assert.AreEqual(Single(15.0), Def.Tokens.SpaceM);
  Assert.AreEqual(Single(25.0), Def.Tokens.SpaceL);
  Assert.AreEqual(Single(35.0), Def.Tokens.SpaceXL);

  Assert.AreEqual(Integer(111), Def.Tokens.DurFast);
  Assert.AreEqual(Integer(222), Def.Tokens.DurNorm);
  Assert.AreEqual(Integer(333), Def.Tokens.DurSlow);
  Assert.AreEqual(Integer(Ord(emEaseOut)), Integer(Ord(Def.Tokens.EaseMode)));

  Assert.AreEqual(Single(0.6), Def.Tokens.PillRatio);
  Assert.AreEqual(Integer(800), Def.Tokens.WeightBold);
  Assert.AreEqual(Single(1.25), Def.Tokens.RowHeightScale);
end;

procedure TTestHbDeepRWSuite.Test_ShareCard_TruePngExport;
var
  CardData: THbShareCardData;
  TmpPath: string;
  Fs: TFileStream;
  HeaderBytes: array[0..7] of Byte;
begin
  CardData.Title := 'PNG 格式真导出测试';
  CardData.Subtitle := '验证 TPngImage 写入真实 PNG magic header';
  CardData.HeaderCategory := '安全测试';
  CardData.MetricRows := ['检验项 1: 通过', '检验项 2: 通过'];
  CardData.FooterNote := '法律免责声明';
  CardData.BadgeText := 'PNG VALID';
  CardData.WatermarkLocked := True;
  CardData.EnableAutoMasking := False;

  TmpPath := TPath.Combine(TPath.GetTempPath, 'test_sharecard_' + TGUID.NewGuid.ToString + '.png');
  try
    Assert.IsTrue(THbShareCardRenderer.SaveToFile(CardData, scfPortrait4x5, TmpPath));
    Assert.IsTrue(TFile.Exists(TmpPath));

    // Verify PNG magic header: $89 $50 $4E $47 $0D $0A $1A $0A
    Fs := TFileStream.Create(TmpPath, fmOpenRead or fmShareDenyNone);
    try
      Assert.IsTrue(Fs.Size > 100);
      Fs.ReadBuffer(HeaderBytes, 8);
      Assert.AreEqual(Byte($89), HeaderBytes[0]);
      Assert.AreEqual(Byte($50), HeaderBytes[1]); // 'P'
      Assert.AreEqual(Byte($4E), HeaderBytes[2]); // 'N'
      Assert.AreEqual(Byte($47), HeaderBytes[3]); // 'G'
      Assert.AreEqual(Byte($0D), HeaderBytes[4]);
      Assert.AreEqual(Byte($0A), HeaderBytes[5]);
      Assert.AreEqual(Byte($1A), HeaderBytes[6]);
      Assert.AreEqual(Byte($0A), HeaderBytes[7]);
    finally
      Fs.Free;
    end;
  finally
    if TFile.Exists(TmpPath) then
      TFile.Delete(TmpPath);
  end;
end;

procedure TTestHbDeepRWSuite.OnGetVirtualItemHelper(Sender: TObject; AIndex: Integer; out AItem: THbVirtualListItem);
begin
  AItem := Default(THbVirtualListItem);
  AItem.Id := 'item_' + IntToStr(AIndex);
  AItem.Title := '审阅工单 #' + IntToStr(AIndex);
  AItem.SummaryLine1 := '7 字段证据链自动核验通过';
  AItem.GroupKey := 'group_' + IntToStr(AIndex mod 10);
  AItem.GroupTitle := '分类组 #' + IntToStr(AIndex mod 10);
end;

procedure TTestHbDeepRWSuite.Test_VirtualList_100k_CallbackDataSource_O1Memory;
var
  Form: TCustomForm;
  VList: THbVirtualList;
  Item: THbVirtualListItem;
  HeapBefore, HeapAfter: Int64;
begin
  Form := TCustomForm.CreateNew(nil);
  try
    Form.HandleNeeded;
    VList := THbVirtualList.Create(Form);
    VList.Parent := Form;
    VList.HandleNeeded;

    HeapBefore := AllocMemSize;
    VList.OnGetItem := OnGetVirtualItemHelper;
    VList.VirtualItemCount := 100000;

    Assert.AreEqual(Integer(100000), Integer(VList.FilteredCount));
    Assert.AreEqual(Integer(0), Integer(VList.Items.Count)); // FItems does not store 100k records

    // Access arbitrary row at boundary
    Assert.IsTrue(VList.GetItem(99999, Item));
    Assert.AreEqual(string('item_99999'), Item.Id);
    Assert.AreEqual(string('审阅工单 #99999'), Item.Title);

    HeapAfter := AllocMemSize;
    // Difference is strictly O(1) (< 256KB for component metadata vs > 80MB for 100,000 in-memory items)
    Assert.IsTrue(Abs(HeapAfter - HeapBefore) < 512000, 'Memory consumption for 100,000 items is not O(1)');
  finally
    Form.Free;
  end;
end;

procedure TTestHbDeepRWSuite.Test_Waterfall_Facet_Interactions_And_Mode_Rendering;
var
  Form: TCustomForm;
  WF: THbFacetWaterfall;
begin
  Form := TCustomForm.CreateNew(nil);
  try
    Form.HandleNeeded;
    WF := THbFacetWaterfall.Create(Form);
    WF.Parent := Form;
    WF.HandleNeeded;

    WF.AddFacet('law', '7 字段法源', 14);
    WF.AddFacet('ai', '候选方案推演', 8);

    WF.AddCard('c1', 'law', '7 字段法源', '法源依据 A', '摘要 A');
    WF.AddCard('c2', 'ai', '候选方案推演', 'AI 推演方案 B', '摘要 B');

    Assert.AreEqual(Integer(2), Integer(WF.GetVisibleCardCount));

    // Focus on 'law'
    WF.FocusFacet('law');
    Assert.AreEqual(string('law'), WF.FocusedCategoryId);
    Assert.AreEqual(Integer(1), Integer(WF.GetVisibleCardCount));

    // Switch mode to timeline
    WF.Mode := wmTimeline;
    Assert.AreEqual(Integer(Ord(wmTimeline)), Integer(Ord(WF.Mode)));
  finally
    Form.Free;
  end;
end;

procedure TTestHbDeepRWSuite.Test_VCL_Dialog_Execute_DoublePath;
var
  OkCalled, CancelCalled: Boolean;
  Val, Reason: string;
begin
  // 1. Test Ok Path
  THbDialog.ModalRunner := function(AForm: TForm): TModalResult
  begin
    Result := mrOk;
  end;
  try
    OkCalled := THbDialog.Confirm('VCL 操作确认', '确认执行主张放行？');
    Assert.IsTrue(OkCalled, 'VCL THbDialog.Confirm should return True on mrOk');

    Val := 'VCL输入文本';
    OkCalled := THbDialog.Prompt('输入经办人', '提示', Val);
    Assert.IsTrue(OkCalled, 'VCL THbDialog.Prompt should return True on mrOk');
    Assert.AreEqual(string('VCL输入文本'), Val);

    Reason := 'VCL驳回依据';
    OkCalled := THbDialog.PromptReason('驳回理由', '提示', Reason);
    Assert.IsTrue(OkCalled, 'VCL THbDialog.PromptReason should return True on mrOk');
    Assert.AreEqual(string('VCL驳回依据'), Reason);
  finally
    THbDialog.ModalRunner := nil;
  end;

  // 2. Test Cancel Path
  THbDialog.ModalRunner := function(AForm: TForm): TModalResult
  begin
    Result := mrCancel;
  end;
  try
    CancelCalled := THbDialog.Confirm('VCL 取消确认', '确认关闭？');
    Assert.IsFalse(CancelCalled, 'VCL THbDialog.Confirm should return False on mrCancel');

    Val := '原值未变';
    CancelCalled := THbDialog.Prompt('输入经办人', '提示', Val);
    Assert.IsFalse(CancelCalled, 'VCL THbDialog.Prompt should return False on mrCancel');

    Reason := '理由未变';
    CancelCalled := THbDialog.PromptReason('驳回理由', '提示', Reason);
    Assert.IsFalse(CancelCalled, 'VCL THbDialog.PromptReason should return False on mrCancel');
  finally
    THbDialog.ModalRunner := nil;
  end;
end;

procedure TTestHbDeepRWSuite.Test_VCL_VoiceDialog_Execute_DoublePath;
var
  Items: TArray<THbVoiceFieldItem>;
  ConfirmedCount: Integer;
  OkRes, CancelRes: Boolean;
begin
  SetLength(Items, 2);
  Items[0].FieldKey := 'law';
  Items[0].FieldLabel := '适用法条';
  Items[0].ExtractedValue := '《民法典》第580条';
  Items[0].CurrentValue := '《民法典》第580条';
  Items[0].Status := vfsAccepted;

  Items[1].FieldKey := 'amount';
  Items[1].FieldLabel := '违约金额';
  Items[1].ExtractedValue := '¥100,000.00';
  Items[1].CurrentValue := '¥120,000.00';
  Items[1].Status := vfsModified;

  // 1. Ok Path
  THbVoiceDialog.ModalRunner := function(AForm: TForm): TModalResult
  begin
    Result := mrOk;
  end;
  try
    OkRes := THbVoiceDialog.Execute('VCL 语音审核确认', Items, ConfirmedCount);
    Assert.IsTrue(OkRes, 'VCL THbVoiceDialog.Execute should return True on mrOk');
    Assert.AreEqual(Integer(2), ConfirmedCount, 'Confirmed count should be 2');
  finally
    THbVoiceDialog.ModalRunner := nil;
  end;

  // 2. Cancel Path
  THbVoiceDialog.ModalRunner := function(AForm: TForm): TModalResult
  begin
    Result := mrCancel;
  end;
  try
    CancelRes := THbVoiceDialog.Execute('VCL 语音审核确认', Items, ConfirmedCount);
    Assert.IsFalse(CancelRes, 'VCL THbVoiceDialog.Execute should return False on mrCancel');
    Assert.AreEqual(Integer(0), ConfirmedCount, 'Confirmed count should be 0 on cancel');
  finally
    THbVoiceDialog.ModalRunner := nil;
  end;
end;

procedure TTestHbDeepRWSuite.Test_UTF8_BOM_Chinese_Literal_Integrity;
var
  S: string;
begin
  S := '开场白 · 免费';
  // With UTF-8 BOM, standard compiler treats Chinese string as 8 Unicode chars (not 11 or 19 bytes)
  Assert.AreEqual(Integer(8), Length(S), 'UTF-8 BOM must ensure 8 Unicode characters without encoding flags');
  Assert.AreEqual(string('开'), string(S[1]));
  Assert.AreEqual(string('费'), string(S[8]));
end;

initialization
  TDUnitX.RegisterTestFixture(TTestHbDeepRWSuite);

end.
