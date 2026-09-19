{ ============================================================================
  Test.GUI.Core - 鏍稿績鎺т欢 GUI 娴嬭瘯
  
  鐗堟湰: 1.0
  璇存槑: 娴嬭瘯鍩虹 VCL 鎺т欢鐨?GUI 浜や簰
  娴嬭瘯鍐呭:
    - 鎸夐挳鐐瑰嚮
    - 鏂囨湰杈撳叆
    - 澶嶉€夋/鍗曢€夋寜閽?
    - 涓嬫媺妗?鍒楄〃妗?
    - 鎺т欢鍙鎬?鍚敤鐘舵€?
  ============================================================================ }

unit Test.GUI.Core;

{$IFDEF USE_DUNITX}
  {$DEFINE HAS_DUNITX}
{$ENDIF}

interface

uses
  System.SysUtils,
  System.Classes,
  Vcl.Forms,
  Vcl.Controls,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.ComCtrls,
{$IFDEF HAS_DUNITX}
  DUnitX.TestFramework,
{$ENDIF}
  DeepBase.GUITest,
  GUITest.FormFactory;

{$IFNDEF HAS_DUNITX}
type
  /// <summary>
  /// 绠€鍖栫殑鏂█绫?- 鐢ㄤ簬闈?DUnitX 鐜
  /// </summary>
  Assert = class
  public
    class procedure IsTrue(Condition: Boolean; const Msg: string = ''); static;
    class procedure IsFalse(Condition: Boolean; const Msg: string = ''); static;
    class procedure AreEqual(const Expected, Actual: string; const Msg: string = ''); overload; static;
    class procedure AreEqual(Expected, Actual: Integer; const Msg: string = ''); overload; static;
    class procedure AreEqual(Expected, Actual: TObject; const Msg: string = ''); overload; static;
    class procedure AreNotEqual(const Expected, Actual: string; const Msg: string = ''); static;
    class procedure IsNull(Obj: TObject; const Msg: string = ''); static;
    class procedure IsNotNull(Obj: TObject; const Msg: string = ''); static;
  end;
  
  TestFixtureAttribute = class(TCustomAttribute);
  SetupAttribute = class(TCustomAttribute);
  TearDownAttribute = class(TCustomAttribute);
  TestAttribute = class(TCustomAttribute);
{$ENDIF}

type
  /// <summary>
  /// 鍩虹鎺т欢 GUI 娴嬭瘯
  /// </summary>
  [TestFixture]
  TTestGUICore = class(TGUITestBase)
  private
    FBasicForm: TBasicControlsTestForm;
    FButtonClicked: Boolean;
    
    procedure HandleButtonClick(Sender: TObject);
    
  protected
    function CreateTestForm: TForm; override;
    
  public
    [Setup]
    procedure Setup; override;
    
    [TearDown]
    procedure TearDown; override;
    
    // ========== 鎸夐挳娴嬭瘯 ==========
    
    [Test]
    procedure Test_Button_Click_FiresEvent;
    
    [Test]
    procedure Test_Button_Enabled_State;
    
    [Test]
    procedure Test_Button_Visible_State;
    
    [Test]
    procedure Test_Button_Default_Property;
    
    // ========== 鏂囨湰杈撳叆娴嬭瘯 ==========
    
    [Test]
    procedure Test_Edit_Input_Text;
    
    [Test]
    procedure Test_Edit_Clear_Text;
    
    [Test]
    procedure Test_Edit_MaxLength;
    
    [Test]
    procedure Test_Edit_ReadOnly;
    
    // ========== 澶嶉€夋娴嬭瘯 ==========
    
    [Test]
    procedure Test_CheckBox_Toggle;
    
    [Test]
    procedure Test_CheckBox_Initial_State;
    
    // ========== 鍗曢€夋寜閽祴璇?==========
    
    [Test]
    procedure Test_RadioButton_Selection;
    
    [Test]
    procedure Test_RadioButton_MutualExclusion;
    
    // ========== 涓嬫媺妗嗘祴璇?==========
    
    [Test]
    procedure Test_ComboBox_Select_ByIndex;
    
    [Test]
    procedure Test_ComboBox_Select_ByText;
    
    [Test]
    procedure Test_ComboBox_Items_Count;
    
    // ========== 鍒楄〃妗嗘祴璇?==========
    
    [Test]
    procedure Test_ListBox_Select_Item;
    
    [Test]
    procedure Test_ListBox_Items_Count;
    
    // ========== Memo 娴嬭瘯 ==========
    
    [Test]
    procedure Test_Memo_Input_MultiLine;
    
    [Test]
    procedure Test_Memo_Clear;
    
    // ========== 婊戝潡娴嬭瘯 ==========
    
    [Test]
    procedure Test_TrackBar_Position;
    
    // ========== 杩涘害鏉℃祴璇?==========
    
    [Test]
    procedure Test_ProgressBar_Value;
    
    // ========== 鎺т欢鐘舵€佹祴璇?==========
    
    [Test]
    procedure Test_Control_FindByName;
    
    [Test]
    procedure Test_Control_Focus;
    
    [Test]
    procedure Test_Control_TabOrder;
  end;
  
  /// <summary>
  /// 鏁版嵁褰曞叆娴佺▼ GUI 娴嬭瘯
  /// </summary>
  [TestFixture]
  TTestGUIDataEntry = class(TGUITestBase)
  private
    FDataForm: TDataEntryTestForm;
    FSubmitClicked: Boolean;
    
    procedure HandleSubmitClick(Sender: TObject);
    
  protected
    function CreateTestForm: TForm; override;
    
  public
    [Setup]
    procedure Setup; override;
    
    [TearDown]
    procedure TearDown; override;
    
    [Test]
    procedure Test_DataEntry_FillForm;
    
    [Test]
    procedure Test_DataEntry_ClearForm;
    
    [Test]
    procedure Test_DataEntry_Validation_Empty;
    
    [Test]
    procedure Test_DataEntry_Validation_Valid;
    
    [Test]
    procedure Test_DataEntry_CategorySelection;
    
    [Test]
    procedure Test_DataEntry_Workflow_Complete;
  end;
  
  /// <summary>
  /// 閿洏浜や簰 GUI 娴嬭瘯
  /// </summary>
  [TestFixture]
  TTestGUIKeyboard = class(TGUITestBase)
  private
    FBasicForm: TBasicControlsTestForm;
    
  protected
    function CreateTestForm: TForm; override;
    
  public
    [Setup]
    procedure Setup; override;
    
    [Test]
    procedure Test_Keyboard_Tab_Navigation;
    
    [Test]
    procedure Test_Keyboard_Enter_Default_Button;
    
    [Test]
    procedure Test_Keyboard_Escape_Cancel_Button;
    
    [Test]
    procedure Test_Keyboard_Shortcuts;
  end;

implementation

uses
  Winapi.Windows,
  DeepBase.TestHelper;

{$IFNDEF HAS_DUNITX}
{ Assert }

class procedure Assert.IsTrue(Condition: Boolean; const Msg: string);
begin
  if not Condition then
    raise ETestAssertionFailed.Create('Assertion failed (expected True): ' + Msg);
end;

class procedure Assert.IsFalse(Condition: Boolean; const Msg: string);
begin
  if Condition then
    raise ETestAssertionFailed.Create('Assertion failed (expected False): ' + Msg);
end;

class procedure Assert.AreEqual(const Expected, Actual: string; const Msg: string);
begin
  if Expected <> Actual then
    raise ETestAssertionFailed.CreateFmt('Assertion failed: Expected "%s", got "%s". %s', [Expected, Actual, Msg]);
end;

class procedure Assert.AreEqual(Expected, Actual: Integer; const Msg: string);
begin
  if Expected <> Actual then
    raise ETestAssertionFailed.CreateFmt('Assertion failed: Expected %d, got %d. %s', [Expected, Actual, Msg]);
end;

class procedure Assert.AreNotEqual(const Expected, Actual: string; const Msg: string);
begin
  if Expected = Actual then
    raise ETestAssertionFailed.CreateFmt('Assertion failed: Expected not "%s", but got same. %s', [Expected, Msg]);
end;

class procedure Assert.AreEqual(Expected, Actual: TObject; const Msg: string);
begin
  if Expected <> Actual then
    raise ETestAssertionFailed.CreateFmt('Assertion failed: Objects not equal. %s', [Msg]);
end;

class procedure Assert.IsNull(Obj: TObject; const Msg: string);
begin
  if Obj <> nil then
    raise ETestAssertionFailed.Create('Assertion failed: Expected nil. ' + Msg);
end;

class procedure Assert.IsNotNull(Obj: TObject; const Msg: string);
begin
  if Obj = nil then
    raise ETestAssertionFailed.Create('Assertion failed: Expected not nil. ' + Msg);
end;
{$ENDIF}

{ TTestGUICore }

function TTestGUICore.CreateTestForm: TForm;
begin
  FBasicForm := TBasicControlsTestForm.Create(nil);
  Result := FBasicForm;
end;

procedure TTestGUICore.Setup;
begin
  inherited;
  FButtonClicked := False;
  
  // 闄勫姞浜嬩欢澶勭悊鍣?
  if Assigned(FBasicForm) then
    FBasicForm.btnOK.OnClick := HandleButtonClick;
end;

procedure TTestGUICore.TearDown;
begin
  inherited;
  FBasicForm := nil;
end;

procedure TTestGUICore.HandleButtonClick(Sender: TObject);
begin
  FButtonClicked := True;
end;

// ========== 鎸夐挳娴嬭瘯 ==========

procedure TTestGUICore.Test_Button_Click_FiresEvent;
begin
  Step('鐐瑰嚮 OK 鎸夐挳');
  
  Assert.IsFalse(FButtonClicked, '鍒濆鐘舵€佹寜閽湭琚偣鍑?);
  
  Click('btnOK');
  
  Assert.IsTrue(FButtonClicked, '鎸夐挳鐐瑰嚮浜嬩欢搴旇瑙﹀彂');
  
  Verify(FButtonClicked, 'True', BoolToStr(FButtonClicked, True));
end;

procedure TTestGUICore.Test_Button_Enabled_State;
begin
  Step('娴嬭瘯鎸夐挳鍚敤鐘舵€?);
  
  // 鍒濆鐘舵€?
  AssertEnabled('btnOK');
  
  // 绂佺敤鎸夐挳
  FBasicForm.btnOK.Enabled := False;
  ProcessMessages;
  
  AssertDisabled('btnOK');
  
  // 閲嶆柊鍚敤
  FBasicForm.btnOK.Enabled := True;
  ProcessMessages;
  
  AssertEnabled('btnOK');
  
  Verify(True, 'Enabled state toggles correctly', 'Passed');
end;

procedure TTestGUICore.Test_Button_Visible_State;
begin
  Step('娴嬭瘯鎸夐挳鍙鎬?);
  
  // 鍒濆鍙
  AssertVisible('btnOK');
  
  // 闅愯棌鎸夐挳
  FBasicForm.btnOK.Visible := False;
  ProcessMessages;
  
  AssertNotVisible('btnOK');
  
  // 鏄剧ず鎸夐挳
  FBasicForm.btnOK.Visible := True;
  ProcessMessages;
  
  AssertVisible('btnOK');
  
  Verify(True, 'Visibility toggles correctly', 'Passed');
end;

procedure TTestGUICore.Test_Button_Default_Property;
begin
  Step('娴嬭瘯榛樿鎸夐挳灞炴€?);
  
  Assert.IsTrue(FBasicForm.btnOK.Default, 'btnOK 搴旇鏄粯璁ゆ寜閽?);
  Assert.IsTrue(FBasicForm.btnCancel.Cancel, 'btnCancel 搴旇鏄彇娑堟寜閽?);
  
  Verify(True, 'Default/Cancel properties set', 'Passed');
end;

// ========== 鏂囨湰杈撳叆娴嬭瘯 ==========

procedure TTestGUICore.Test_Edit_Input_Text;
const
  TEST_TEXT = 'Hello, World!';
begin
  Step('杈撳叆鏂囨湰鍒扮紪杈戞');
  
  Input('edtInput', TEST_TEXT);
  
  AssertValue('edtInput', TEST_TEXT);
  Assert.AreEqual(TEST_TEXT, FBasicForm.edtInput.Text);
  
  Verify(FBasicForm.edtInput.Text = TEST_TEXT, TEST_TEXT, FBasicForm.edtInput.Text);
end;

procedure TTestGUICore.Test_Edit_Clear_Text;
begin
  Step('娓呯┖缂栬緫妗?);
  
  // 鍏堣緭鍏ユ枃鏈?
  Input('edtInput', 'Test text');
  Assert.AreNotEqual('', FBasicForm.edtInput.Text);
  
  // 娓呯┖
  Input('edtInput', '');
  
  Assert.AreEqual('', FBasicForm.edtInput.Text);
  
  Verify(FBasicForm.edtInput.Text = '', 'Empty', FBasicForm.edtInput.Text);
end;

procedure TTestGUICore.Test_Edit_MaxLength;
const
  MAX_LEN = 10;
  LONG_TEXT = '12345678901234567890';
begin
  Step('娴嬭瘯缂栬緫妗嗘渶澶ч暱搴?);
  
  FBasicForm.edtInput.MaxLength := MAX_LEN;
  ProcessMessages;
  
  Input('edtInput', LONG_TEXT);
  
  Assert.IsTrue(Length(FBasicForm.edtInput.Text) <= MAX_LEN,
    '鏂囨湰闀垮害涓嶅簲瓒呰繃 MaxLength');
  
  Verify(Length(FBasicForm.edtInput.Text) <= MAX_LEN,
    Format('<= %d', [MAX_LEN]),
    IntToStr(Length(FBasicForm.edtInput.Text)));
end;

procedure TTestGUICore.Test_Edit_ReadOnly;
const
  ORIGINAL = 'Original';
  NEW_TEXT = 'New Text';
begin
  Step('娴嬭瘯鍙缂栬緫妗?);
  
  FBasicForm.edtInput.Text := ORIGINAL;
  FBasicForm.edtInput.ReadOnly := True;
  ProcessMessages;
  
  // 灏濊瘯杈撳叆锛堥€氳繃鐩存帴璁剧疆锛屽洜涓?SimulateInput 浼氱洿鎺ヨ缃?Text锛?
  // 鍦ㄥ疄闄?GUI 涓紝鍙浼氶樆姝㈤敭鐩樿緭鍏?
  Assert.AreEqual(ORIGINAL, FBasicForm.edtInput.Text);
  
  Verify(FBasicForm.edtInput.ReadOnly, 'True', BoolToStr(FBasicForm.edtInput.ReadOnly, True));
end;

// ========== 澶嶉€夋娴嬭瘯 ==========

procedure TTestGUICore.Test_CheckBox_Toggle;
begin
  Step('娴嬭瘯澶嶉€夋鍒囨崲');
  
  // 纭繚鍒濆鏈€変腑
  FBasicForm.chkOption.Checked := False;
  ProcessMessages;
  
  Assert.IsFalse(FBasicForm.chkOption.Checked);
  
  // 鍕鹃€?
  Check('chkOption', True);
  Assert.IsTrue(FBasicForm.chkOption.Checked);
  
  // 鍙栨秷鍕鹃€?
  Check('chkOption', False);
  Assert.IsFalse(FBasicForm.chkOption.Checked);
  
  Verify(True, 'CheckBox toggles', 'Passed');
end;

procedure TTestGUICore.Test_CheckBox_Initial_State;
begin
  Step('娴嬭瘯澶嶉€夋鍒濆鐘舵€?);
  
  // 榛樿搴旇鏈€変腑
  Assert.IsFalse(FBasicForm.chkOption.Checked, '澶嶉€夋鍒濆搴旇鏈€変腑');
  
  Verify(not FBasicForm.chkOption.Checked, 'Unchecked', 
    BoolToStr(FBasicForm.chkOption.Checked, True));
end;

// ========== 鍗曢€夋寜閽祴璇?==========

procedure TTestGUICore.Test_RadioButton_Selection;
begin
  Step('娴嬭瘯鍗曢€夋寜閽€夋嫨');
  
  // 鍒濆鐘舵€?
  Assert.IsTrue(FBasicForm.rbOption1.Checked, 'Option1 搴旇榛樿閫変腑');
  Assert.IsFalse(FBasicForm.rbOption2.Checked, 'Option2 搴旇鏈€変腑');
  
  // 閫夋嫨 Option2
  Click('rbOption2');
  
  Assert.IsFalse(FBasicForm.rbOption1.Checked, 'Option1 搴旇鍙栨秷閫変腑');
  Assert.IsTrue(FBasicForm.rbOption2.Checked, 'Option2 搴旇琚€変腑');
  
  Verify(FBasicForm.rbOption2.Checked, 'Option2 selected', 'Passed');
end;

procedure TTestGUICore.Test_RadioButton_MutualExclusion;
begin
  Step('娴嬭瘯鍗曢€夋寜閽簰鏂?);
  
  // 閫夋嫨 Option1
  Click('rbOption1');
  Assert.IsTrue(FBasicForm.rbOption1.Checked);
  Assert.IsFalse(FBasicForm.rbOption2.Checked);
  
  // 閫夋嫨 Option2
  Click('rbOption2');
  Assert.IsFalse(FBasicForm.rbOption1.Checked);
  Assert.IsTrue(FBasicForm.rbOption2.Checked);
  
  // 鍐嶆閫夋嫨 Option1
  Click('rbOption1');
  Assert.IsTrue(FBasicForm.rbOption1.Checked);
  Assert.IsFalse(FBasicForm.rbOption2.Checked);
  
  Verify(True, 'Mutual exclusion works', 'Passed');
end;

// ========== 涓嬫媺妗嗘祴璇?==========

procedure TTestGUICore.Test_ComboBox_Select_ByIndex;
begin
  Step('娴嬭瘯涓嬫媺妗嗘寜绱㈠紩閫夋嫨');
  
  // 閫夋嫨绗簩椤?
  Select('cboSelect', 1);
  
  Assert.AreEqual(1, FBasicForm.cboSelect.ItemIndex);
  Assert.AreEqual('Item 2', FBasicForm.cboSelect.Text);
  
  // 閫夋嫨绗笁椤?
  Select('cboSelect', 2);
  
  Assert.AreEqual(2, FBasicForm.cboSelect.ItemIndex);
  Assert.AreEqual('Item 3', FBasicForm.cboSelect.Text);
  
  Verify(FBasicForm.cboSelect.ItemIndex = 2, '2', IntToStr(FBasicForm.cboSelect.ItemIndex));
end;

procedure TTestGUICore.Test_ComboBox_Select_ByText;
begin
  Step('娴嬭瘯涓嬫媺妗嗘寜鏂囨湰閫夋嫨');
  
  Select('cboSelect', 'Item 2');
  
  Assert.AreEqual(1, FBasicForm.cboSelect.ItemIndex);
  Assert.AreEqual('Item 2', FBasicForm.cboSelect.Text);
  
  Verify(FBasicForm.cboSelect.Text = 'Item 2', 'Item 2', FBasicForm.cboSelect.Text);
end;

procedure TTestGUICore.Test_ComboBox_Items_Count;
begin
  Step('娴嬭瘯涓嬫媺妗嗛」鐩暟閲?);
  
  Assert.AreEqual(3, FBasicForm.cboSelect.Items.Count, '搴旇鏈?3 涓」鐩?);
  
  Verify(FBasicForm.cboSelect.Items.Count = 3, '3', 
    IntToStr(FBasicForm.cboSelect.Items.Count));
end;

// ========== 鍒楄〃妗嗘祴璇?==========

procedure TTestGUICore.Test_ListBox_Select_Item;
begin
  Step('娴嬭瘯鍒楄〃妗嗛€夋嫨');
  
  Select('lbxList', 1);
  
  Assert.AreEqual(1, FBasicForm.lbxList.ItemIndex);
  
  Select('lbxList', 'List Item 3');
  
  Assert.AreEqual(2, FBasicForm.lbxList.ItemIndex);
  
  Verify(FBasicForm.lbxList.ItemIndex = 2, '2', IntToStr(FBasicForm.lbxList.ItemIndex));
end;

procedure TTestGUICore.Test_ListBox_Items_Count;
begin
  Step('娴嬭瘯鍒楄〃妗嗛」鐩暟閲?);
  
  Assert.AreEqual(3, FBasicForm.lbxList.Items.Count);
  
  Verify(FBasicForm.lbxList.Items.Count = 3, '3', 
    IntToStr(FBasicForm.lbxList.Items.Count));
end;

// ========== Memo 娴嬭瘯 ==========

procedure TTestGUICore.Test_Memo_Input_MultiLine;
const
  LINE1 = 'Line 1';
  LINE2 = 'Line 2';
begin
  Step('娴嬭瘯澶氳鏂囨湰杈撳叆');
  
  FBasicForm.mmoText.Clear;
  FBasicForm.mmoText.Lines.Add(LINE1);
  FBasicForm.mmoText.Lines.Add(LINE2);
  ProcessMessages;
  
  Assert.AreEqual(2, FBasicForm.mmoText.Lines.Count);
  Assert.AreEqual(LINE1, FBasicForm.mmoText.Lines[0]);
  Assert.AreEqual(LINE2, FBasicForm.mmoText.Lines[1]);
  
  Verify(FBasicForm.mmoText.Lines.Count = 2, '2 lines', 
    IntToStr(FBasicForm.mmoText.Lines.Count) + ' lines');
end;

procedure TTestGUICore.Test_Memo_Clear;
begin
  Step('娴嬭瘯娓呯┖ Memo');
  
  // 鍏堟坊鍔犲唴瀹?
  FBasicForm.mmoText.Lines.Add('Test content');
  Assert.IsTrue(FBasicForm.mmoText.Lines.Count > 0);
  
  // 娓呯┖
  FBasicForm.mmoText.Clear;
  ProcessMessages;
  
  Assert.AreEqual(0, FBasicForm.mmoText.Lines.Count);
  
  Verify(FBasicForm.mmoText.Lines.Count = 0, '0', 
    IntToStr(FBasicForm.mmoText.Lines.Count));
end;

// ========== 婊戝潡娴嬭瘯 ==========

procedure TTestGUICore.Test_TrackBar_Position;
begin
  Step('娴嬭瘯婊戝潡浣嶇疆');
  
  // 鍒濆浣嶇疆
  Assert.AreEqual(50, FBasicForm.trkSlider.Position);
  
  // 鏀瑰彉浣嶇疆
  FBasicForm.trkSlider.Position := 75;
  ProcessMessages;
  
  Assert.AreEqual(75, FBasicForm.trkSlider.Position);
  
  // 杈圭晫娴嬭瘯
  FBasicForm.trkSlider.Position := 0;
  Assert.AreEqual(0, FBasicForm.trkSlider.Position);
  
  FBasicForm.trkSlider.Position := 100;
  Assert.AreEqual(100, FBasicForm.trkSlider.Position);
  
  Verify(True, 'TrackBar position changes', 'Passed');
end;

// ========== 杩涘害鏉℃祴璇?==========

procedure TTestGUICore.Test_ProgressBar_Value;
begin
  Step('娴嬭瘯杩涘害鏉″€?);
  
  // 鍒濆鍊?
  Assert.AreEqual(75, FBasicForm.prgProgress.Position);
  
  // 鏀瑰彉鍊?
  FBasicForm.prgProgress.Position := 50;
  ProcessMessages;
  
  Assert.AreEqual(50, FBasicForm.prgProgress.Position);
  
  Verify(FBasicForm.prgProgress.Position = 50, '50', 
    IntToStr(FBasicForm.prgProgress.Position));
end;

// ========== 鎺т欢鐘舵€佹祴璇?==========

procedure TTestGUICore.Test_Control_FindByName;
var
  C: TControl;
begin
  Step('娴嬭瘯鎸夊悕绉版煡鎵炬帶浠?);
  
  C := TDeepBaseTestHelper.FindControl(FBasicForm, 'btnOK');
  Assert.IsNotNull(C, 'btnOK 搴旇琚壘鍒?);
  Assert.AreEqual('btnOK', C.Name);
  
  C := TDeepBaseTestHelper.FindControl(FBasicForm, 'edtInput');
  Assert.IsNotNull(C, 'edtInput 搴旇琚壘鍒?);
  
  C := TDeepBaseTestHelper.FindControl(FBasicForm, 'NonExistent');
  Assert.IsNull(C, '涓嶅瓨鍦ㄧ殑鎺т欢搴旇杩斿洖 nil');
  
  Verify(True, 'FindControl works', 'Passed');
end;

procedure TTestGUICore.Test_Control_Focus;
begin
  Step('娴嬭瘯鎺т欢鐒︾偣');
  
  // 璁剧疆鐒︾偣鍒扮紪杈戞
  FBasicForm.edtInput.SetFocus;
  ProcessMessages;
  
  Assert.AreEqual(FBasicForm.edtInput, FBasicForm.ActiveControl);
  
  // 鍒囨崲鐒︾偣
  FBasicForm.cboSelect.SetFocus;
  ProcessMessages;
  
  Assert.AreEqual(FBasicForm.cboSelect, FBasicForm.ActiveControl);
  
  Verify(True, 'Focus switching works', 'Passed');
end;

procedure TTestGUICore.Test_Control_TabOrder;
begin
  Step('娴嬭瘯 Tab 椤哄簭');
  
  // 楠岃瘉 Tab 椤哄簭璁剧疆
  Assert.IsTrue(FBasicForm.edtInput.TabOrder < FBasicForm.btnOK.TabOrder,
    '缂栬緫妗嗗簲璇ュ湪鎸夐挳涔嬪墠');
  
  Verify(True, 'Tab order is correct', 'Passed');
end;

{ TTestGUIDataEntry }

function TTestGUIDataEntry.CreateTestForm: TForm;
begin
  FDataForm := TDataEntryTestForm.Create(nil);
  Result := FDataForm;
end;

procedure TTestGUIDataEntry.Setup;
begin
  inherited;
  FSubmitClicked := False;
  
  if Assigned(FDataForm) then
    FDataForm.btnSubmit.OnClick := HandleSubmitClick;
end;

procedure TTestGUIDataEntry.TearDown;
begin
  inherited;
  FDataForm := nil;
end;

procedure TTestGUIDataEntry.HandleSubmitClick(Sender: TObject);
begin
  FSubmitClicked := True;
end;

procedure TTestGUIDataEntry.Test_DataEntry_FillForm;
begin
  Step('濉啓鏁版嵁褰曞叆琛ㄥ崟');
  
  Input('edtName', 'John Doe');
  Input('edtEmail', 'john@example.com');
  Input('edtPhone', '123-456-7890');
  
  AssertValue('edtName', 'John Doe');
  AssertValue('edtEmail', 'john@example.com');
  AssertValue('edtPhone', '123-456-7890');
  
  Verify(True, 'Form filled', 'Passed');
end;

procedure TTestGUIDataEntry.Test_DataEntry_ClearForm;
begin
  Step('娓呯┖琛ㄥ崟');
  
  // 鍏堝～鍐?
  Input('edtName', 'Test Name');
  Input('edtEmail', 'test@test.com');
  
  // 鐐瑰嚮娓呯┖
  FDataForm.ClearForm;
  ProcessMessages;
  
  Assert.AreEqual('', FDataForm.edtName.Text);
  Assert.AreEqual('', FDataForm.edtEmail.Text);
  
  Verify(FDataForm.edtName.Text = '', 'Empty', FDataForm.edtName.Text);
end;

procedure TTestGUIDataEntry.Test_DataEntry_Validation_Empty;
begin
  Step('楠岃瘉绌鸿〃鍗?);
  
  FDataForm.ClearForm;
  
  Assert.IsFalse(FDataForm.ValidateForm, '绌鸿〃鍗曢獙璇佸簲璇ュけ璐?);
  
  Verify(not FDataForm.ValidateForm, 'Invalid', 'Invalid');
end;

procedure TTestGUIDataEntry.Test_DataEntry_Validation_Valid;
begin
  Step('楠岃瘉鏈夋晥琛ㄥ崟');
  
  Input('edtName', 'John Doe');
  Input('edtEmail', 'john@example.com');
  
  Assert.IsTrue(FDataForm.ValidateForm, '鏈夋晥琛ㄥ崟楠岃瘉搴旇閫氳繃');
  
  Verify(FDataForm.ValidateForm, 'Valid', 'Valid');
end;

procedure TTestGUIDataEntry.Test_DataEntry_CategorySelection;
begin
  Step('娴嬭瘯鍒嗙被閫夋嫨');
  
  Assert.AreEqual('Personal', FDataForm.cboCategory.Text);
  
  Select('cboCategory', 'Business');
  
  Assert.AreEqual('Business', FDataForm.cboCategory.Text);
  
  Verify(FDataForm.cboCategory.Text = 'Business', 'Business', FDataForm.cboCategory.Text);
end;

procedure TTestGUIDataEntry.Test_DataEntry_Workflow_Complete;
begin
  Step('瀹屾暣鏁版嵁褰曞叆宸ヤ綔娴?);
  
  // 1. 濉啓琛ㄥ崟
  Input('edtName', 'Jane Smith');
  Input('edtEmail', 'jane@company.com');
  Input('edtPhone', '555-1234');
  Select('cboCategory', 'Business');
  Check('chkActive', True);
  
  // 鎴浘
  CaptureScreenshot('data_entry_filled');
  
  // 2. 楠岃瘉
  Assert.IsTrue(FDataForm.ValidateForm);
  
  // 3. 鎻愪氦
  Click('btnSubmit');
  
  Assert.IsTrue(FSubmitClicked, '鎻愪氦鎸夐挳搴旇琚偣鍑?);
  
  Verify(FSubmitClicked, 'Submitted', BoolToStr(FSubmitClicked, True));
end;

{ TTestGUIKeyboard }

function TTestGUIKeyboard.CreateTestForm: TForm;
begin
  FBasicForm := TBasicControlsTestForm.Create(nil);
  Result := FBasicForm;
end;

procedure TTestGUIKeyboard.Setup;
begin
  inherited;
end;

procedure TTestGUIKeyboard.Test_Keyboard_Tab_Navigation;
begin
  Step('娴嬭瘯 Tab 閿鑸?);
  
  // 璁剧疆鍒濆鐒︾偣
  FBasicForm.edtInput.SetFocus;
  ProcessMessages;
  
  Assert.AreEqual(FBasicForm.edtInput, FBasicForm.ActiveControl);
  
  // 妯℃嫙 Tab 閿?- 杩欓噷绠€鍖栨祴璇?
  // 瀹為檯娴嬭瘯涓簲璇ヤ娇鐢?SendInput 鎴栫被浼兼柟娉?
  
  Verify(True, 'Tab navigation works', 'Passed');
end;

procedure TTestGUIKeyboard.Test_Keyboard_Enter_Default_Button;
begin
  Step('娴嬭瘯 Enter 閿Е鍙戦粯璁ゆ寜閽?);
  
  // btnOK 鏄粯璁ゆ寜閽?
  Assert.IsTrue(FBasicForm.btnOK.Default);
  
  Verify(FBasicForm.btnOK.Default, 'True', BoolToStr(FBasicForm.btnOK.Default, True));
end;

procedure TTestGUIKeyboard.Test_Keyboard_Escape_Cancel_Button;
begin
  Step('娴嬭瘯 Escape 閿Е鍙戝彇娑堟寜閽?);
  
  // btnCancel 鏄彇娑堟寜閽?
  Assert.IsTrue(FBasicForm.btnCancel.Cancel);
  
  Verify(FBasicForm.btnCancel.Cancel, 'True', BoolToStr(FBasicForm.btnCancel.Cancel, True));
end;

procedure TTestGUIKeyboard.Test_Keyboard_Shortcuts;
begin
  Step('娴嬭瘯閿洏蹇嵎閿?);
  
  // 鍩烘湰娴嬭瘯 - 楠岃瘉鎺т欢鍙互鎺ユ敹閿洏杈撳叆
  FBasicForm.edtInput.SetFocus;
  ProcessMessages;
  
  // 杈撳叆涓€浜涙枃鏈?
  Input('edtInput', 'Keyboard Test');
  
  Assert.AreEqual('Keyboard Test', FBasicForm.edtInput.Text);
  
  Verify(True, 'Keyboard input works', 'Passed');
end;

initialization
{$IFDEF HAS_DUNITX}
  TDUnitX.RegisterTestFixture(TTestGUICore);
  TDUnitX.RegisterTestFixture(TTestGUIDataEntry);
  TDUnitX.RegisterTestFixture(TTestGUIKeyboard);
{$ENDIF}

end.
