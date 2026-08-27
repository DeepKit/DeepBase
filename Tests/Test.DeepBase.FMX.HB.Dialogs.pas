{ ============================================================================
  Test.DeepBase.FMX.HB.Dialogs - Unit Tests for FMX Dialog & Voice Contracts

  Version: 1.0 (Delphi 13.1 on Win64)
  Description: Validates FMX modal dialog contracts, option payload structures,
               voice field status confirmations, and summary bar state transitions.
  ============================================================================ }

unit Test.DeepBase.FMX.HB.Dialogs;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.UITypes,
  FMX.Forms,
  DeepBase.HB.Core,
  DeepBase.HB.Dialogs.Types,
  DeepBase.HB.Voice.Types,
  DeepBase.FMX.HB.Theme,
  DeepBase.FMX.HB.Dialogs,
  DeepBase.FMX.HB.Voice;

type
  [TestFixture]
  TTestFmxHbDialogs = class
  public
    [Test]
    procedure Test_FMX_DialogOptions_Structure;

    [Test]
    procedure Test_FMX_SummaryBar_Toggle_And_States;

    [Test]
    procedure Test_FMX_VoiceField_Status_Transitions;

    [Test]
    procedure Test_FMX_Dialog_Execute_OkPath;

    [Test]
    procedure Test_FMX_Dialog_Execute_CancelPath;

    [Test]
    procedure Test_FMX_VoiceDialog_Execute_OkPath;

    [Test]
    procedure Test_FMX_VoiceDialog_Execute_CancelPath;
  end;

implementation

{ TTestFmxHbDialogs }

procedure TTestFmxHbDialogs.Test_FMX_DialogOptions_Structure;
var
  Opts: THbDialogOptions;
begin
  Opts := Default(THbDialogOptions);
  Opts.Title := '高危拦截确认';
  Opts.Summary := '主张审计缺失 7 字段法源依据，确认强制放行？';
  Opts.Kind := dkConfirm;
  Opts.OkCaption := '强制放行';
  Opts.IsDestructive := True;

  Assert.AreEqual(string('高危拦截确认'), Opts.Title);
  Assert.AreEqual(string('主张审计缺失 7 字段法源依据，确认强制放行？'), Opts.Summary);
  Assert.AreEqual(Integer(Ord(dkConfirm)), Integer(Ord(Opts.Kind)));
  Assert.AreEqual(string('强制放行'), Opts.OkCaption);
  Assert.IsTrue(Opts.IsDestructive);
end;

procedure TTestFmxHbDialogs.Test_FMX_SummaryBar_Toggle_And_States;
var
  Bar: THbSummaryBar;
begin
  Bar := THbSummaryBar.Create(nil);
  try
    Bar.StepIndex := 2;
    Bar.Title := '法源特征抽取';
    Bar.SummaryText := '抽取置信度: 98.6%';
    Bar.State := ssCompleted;
    Bar.StatusTone := btSuccess;
    Bar.StatusText := '已完成';

    Assert.AreEqual(Integer(2), Bar.StepIndex);
    Assert.AreEqual(string('法源特征抽取'), Bar.Title);
    Assert.AreEqual(Integer(Ord(ssCompleted)), Integer(Ord(Bar.State)));
    Assert.AreEqual(Integer(Ord(btSuccess)), Integer(Ord(Bar.StatusTone)));

    Assert.IsFalse(Bar.IsExpanded);
    Bar.Toggle;
    Assert.IsTrue(Bar.IsExpanded);
    Bar.Toggle;
    Assert.IsFalse(Bar.IsExpanded);
  finally
    Bar.Free;
  end;
end;

procedure TTestFmxHbDialogs.Test_FMX_VoiceField_Status_Transitions;
var
  Items: TArray<THbVoiceFieldItem>;
  AcceptedCount: Integer;
  I: Integer;
begin
  SetLength(Items, 3);

  Items[0].FieldLabel := '法条条款';
  Items[0].ExtractedValue := '《民法典》第 580 条';
  Items[0].CurrentValue := '《民法典》第 580 条';
  Items[0].Status := vfsAccepted;

  Items[1].FieldLabel := '违约赔偿金额';
  Items[1].ExtractedValue := '¥500,000.00';
  Items[1].CurrentValue := '¥500,000.00';
  Items[1].Status := vfsModified;

  Items[2].FieldLabel := '补充备注';
  Items[2].ExtractedValue := '待人工复核';
  Items[2].CurrentValue := '待人工复核';
  Items[2].Status := vfsPending;

  AcceptedCount := 0;
  for I := Low(Items) to High(Items) do
  begin
    if Items[I].Status in [vfsAccepted, vfsModified] then
      Inc(AcceptedCount);
  end;

  Assert.AreEqual(Integer(2), AcceptedCount);
  Assert.AreEqual(string('《民法典》第 580 条'), Items[0].CurrentValue);
end;

procedure TTestFmxHbDialogs.Test_FMX_Dialog_Execute_OkPath;
var
  OkCalled: Boolean;
  Val, Reason: string;
begin
  THbDialog.ModalRunner := function(AForm: TForm): TModalResult
  begin
    // Simulate user interaction before confirming
    Result := mrOk;
  end;
  try
    OkCalled := THbDialog.Confirm('高危操作确认', '确认将状态变更为已核验？');
    Assert.IsTrue(OkCalled, 'THbDialog.Confirm should return True on mrOk');

    Val := '默认输入';
    OkCalled := THbDialog.Prompt('输入姓名', '请输入经办人姓名', Val);
    Assert.IsTrue(OkCalled, 'THbDialog.Prompt should return True on mrOk');
    Assert.AreEqual(string('默认输入'), Val);

    Reason := '合规放行说明';
    OkCalled := THbDialog.PromptReason('驳回理由录入', '请输入驳回理由', Reason);
    Assert.IsTrue(OkCalled, 'THbDialog.PromptReason should return True on mrOk');
    Assert.AreEqual(string('合规放行说明'), Reason);
  finally
    THbDialog.ModalRunner := nil;
  end;
end;

procedure TTestFmxHbDialogs.Test_FMX_Dialog_Execute_CancelPath;
var
  CancelCalled: Boolean;
  Val, Reason: string;
begin
  THbDialog.ModalRunner := function(AForm: TForm): TModalResult
  begin
    Result := mrCancel;
  end;
  try
    CancelCalled := THbDialog.Confirm('取消操作确认', '确认关闭？');
    Assert.IsFalse(CancelCalled, 'THbDialog.Confirm should return False on mrCancel');

    Val := '未修改原值';
    CancelCalled := THbDialog.Prompt('输入姓名', '请输入经办人姓名', Val);
    Assert.IsFalse(CancelCalled, 'THbDialog.Prompt should return False on mrCancel');

    Reason := '未修改理由';
    CancelCalled := THbDialog.PromptReason('驳回理由录入', '请输入驳回理由', Reason);
    Assert.IsFalse(CancelCalled, 'THbDialog.PromptReason should return False on mrCancel');
  finally
    THbDialog.ModalRunner := nil;
  end;
end;

procedure TTestFmxHbDialogs.Test_FMX_VoiceDialog_Execute_OkPath;
var
  Items: TArray<THbVoiceFieldItem>;
  ConfirmedCount: Integer;
  OkResult: Boolean;
begin
  SetLength(Items, 3);
  Items[0].FieldKey := 'law_code';
  Items[0].FieldLabel := '适用法条';
  Items[0].ExtractedValue := '《民法典》第580条';
  Items[0].CurrentValue := '《民法典》第580条';
  Items[0].Status := vfsAccepted;

  Items[1].FieldKey := 'amount';
  Items[1].FieldLabel := '索赔金额';
  Items[1].ExtractedValue := '¥200,000.00';
  Items[1].CurrentValue := '¥250,000.00';
  Items[1].Status := vfsModified;

  Items[2].FieldKey := 'memo';
  Items[2].FieldLabel := '附加说明';
  Items[2].ExtractedValue := '录音噪音大待核实';
  Items[2].CurrentValue := '录音噪音大待核实';
  Items[2].Status := vfsDiscarded;

  THbVoiceDialog.ModalRunner := function(AForm: TForm): TModalResult
  begin
    Result := mrOk;
  end;
  try
    OkResult := THbVoiceDialog.Execute('语音识别字段确认', Items, ConfirmedCount);
    Assert.IsTrue(OkResult, 'THbVoiceDialog.Execute should return True on mrOk');
    Assert.AreEqual(Integer(2), ConfirmedCount, 'Confirmed count should match accepted/modified fields');
  finally
    THbVoiceDialog.ModalRunner := nil;
  end;
end;

procedure TTestFmxHbDialogs.Test_FMX_VoiceDialog_Execute_CancelPath;
var
  Items: TArray<THbVoiceFieldItem>;
  ConfirmedCount: Integer;
  CancelResult: Boolean;
begin
  SetLength(Items, 2);
  Items[0].FieldKey := 'law_code';
  Items[0].FieldLabel := '适用法条';
  Items[0].ExtractedValue := '《民法典》第580条';
  Items[0].CurrentValue := '《民法典》第580条';
  Items[0].Status := vfsAccepted;

  Items[1].FieldKey := 'amount';
  Items[1].FieldLabel := '索赔金额';
  Items[1].ExtractedValue := '¥200,000.00';
  Items[1].CurrentValue := '¥200,000.00';
  Items[1].Status := vfsAccepted;

  THbVoiceDialog.ModalRunner := function(AForm: TForm): TModalResult
  begin
    Result := mrCancel;
  end;
  try
    CancelResult := THbVoiceDialog.Execute('语音识别字段确认', Items, ConfirmedCount);
    Assert.IsFalse(CancelResult, 'THbVoiceDialog.Execute should return False on mrCancel');
    Assert.AreEqual(Integer(0), ConfirmedCount, 'Confirmed count should be 0 on cancel');
  finally
    THbVoiceDialog.ModalRunner := nil;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestFmxHbDialogs);

end.
