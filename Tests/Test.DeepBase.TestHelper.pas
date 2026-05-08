unit Test.DeepBase.TestHelper;

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.JSON,
  System.Generics.Collections,
  Winapi.Windows,
  Vcl.Forms,
  Vcl.Controls,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.ComCtrls,
  Vcl.Graphics,
  DUnitX.TestFramework,
  DeepBase.TestHelper;

type
  [TestFixture]
  TTestDeepBaseTestHelper = class
  private
    FForm: TForm;
    FPanel: TPanel;
    FButton: TButton;
    FEdit: TEdit;
    FCheckBox: TCheckBox;
    FListBox: TListBox;
    FComboBox: TComboBox;
    FListView: TListView;
    FClicked: Boolean;
    FOriginalSnapshotPath: string;
    FTempSnapshotPath: string;
    procedure ButtonClick(Sender: TObject);
  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_SnapshotPath_Is_Set_And_Directory_Created;

    [Test]
    procedure Test_CaptureFormState_Includes_Form_And_Control_Properties;

    [Test]
    procedure Test_SaveSnapshot_And_GetSnapshot_File_Mode;

    [Test]
    procedure Test_VerifySnapshot_Success_When_State_Unchanged;

    [Test]
    procedure Test_VerifySnapshot_Returns_NotFound_When_Snapshot_Missing;

    [Test]
    procedure Test_VerifySnapshot_Detects_Differences_And_Populates_Diffs;

    [Test]
    procedure Test_ListSnapshots_Includes_Saved_Snapshot;

    [Test]
    procedure Test_DeleteSnapshot_Removes_JSON_And_PNG;

    [Test]
    procedure Test_GetControlValue_And_AssertValue_Work_For_Common_Controls;

    [Test]
    procedure Test_AssertVisible_And_AssertEnabled_Raise_When_Conditions_Not_Met;

    [Test]
    procedure Test_FindControl_And_FindControlByClass_Work_Correctly;

    [Test]
    procedure Test_FindAllControlsByClass_Returns_All_Instances;

    [Test]
    procedure Test_SimulateSelect_ByIndex_And_ByText_Updates_Index;

    [Test]
    procedure Test_SimulateCheck_Updates_Checked_State;

    [Test]
    procedure Test_SimulateInput_Updates_Text;

    [Test]
    procedure Test_SimulateClick_And_DoubleClick_Do_Not_Raise;

    [Test]
    procedure Test_SimulateKeyPress_And_MouseMove_Do_Not_Raise;

    [Test]
    procedure Test_CaptureScreenshot_And_SaveScreenshotToFile_Work;

    [Test]
    procedure Test_SnapshotDiff_And_VerifyResult_Clear_Reset_Fields;
  end;

implementation

{ TTestDeepBaseTestHelper }

procedure TTestDeepBaseTestHelper.Setup;
begin
  FOriginalSnapshotPath := TDeepBaseTestHelper.SnapshotPath;
  FTempSnapshotPath := TPath.Combine(TPath.GetTempPath, 'DeepBaseTestHelperTests');
  TDeepBaseTestHelper.Initialize(nil, FTempSnapshotPath);

  // set up a simple form with a few controls
  FForm := TForm.CreateNew(nil);
  FForm.Name := 'TestHelperForm';
  FForm.Caption := 'Test Form';
  FForm.Width := 400;
  FForm.Height := 300;
  FForm.Position := poDesigned;
  FForm.Left := 100;
  FForm.Top := 300;
  FForm.Visible := True;

  // container panel so we can test recursive control search
  FPanel := TPanel.Create(FForm);
  FPanel.Parent := FForm;
  FPanel.Name := 'pnlContainer';
  FPanel.Align := alClient;

  FButton := TButton.Create(FForm);
  FButton.Parent := FPanel;
  FButton.Name := 'btnOK';
  FButton.Caption := 'OK';
  FButton.Left := 10;
  FButton.Top := 10;
  FButton.OnClick := ButtonClick;

  FEdit := TEdit.Create(FForm);
  FEdit.Parent := FPanel;
  FEdit.Name := 'edtName';
  FEdit.Text := 'John';
  FEdit.Left := 10;
  FEdit.Top := 50;

  FCheckBox := TCheckBox.Create(FForm);
  FCheckBox.Parent := FPanel;
  FCheckBox.Name := 'chkActive';
  FCheckBox.Caption := 'Active';
  FCheckBox.Checked := True;
  FCheckBox.Left := 10;
  FCheckBox.Top := 90;

  FListBox := TListBox.Create(FForm);
  FListBox.Parent := FPanel;
  FListBox.Name := 'lstItems';
  FListBox.Items.Add('One');
  FListBox.Items.Add('Two');
  FListBox.Left := 150;
  FListBox.Top := 10;

  FComboBox := TComboBox.Create(FForm);
  FComboBox.Parent := FPanel;
  FComboBox.Name := 'cboItems';
  FComboBox.Items.Add('Red');
  FComboBox.Items.Add('Green');
  FComboBox.Items.Add('Blue');
  FComboBox.Left := 150;
  FComboBox.Top := 80;

  FListView := TListView.Create(FForm);
  FListView.Parent := FPanel;
  FListView.Name := 'lvItems';
  FListView.ViewStyle := vsReport;
  FListView.Columns.Add.Caption := 'Name';
  FListView.Items.Add.Caption := 'Item1';
  FListView.Items.Add.Caption := 'Item2';
  FListView.Left := 150;
  FListView.Top := 140;
  FListView.Width := 150;
  FListView.Height := 100;

  FClicked := False;

  FForm.Show;
  Application.ProcessMessages;
end;

procedure TTestDeepBaseTestHelper.TearDown;
begin
  if Assigned(FForm) then
    FForm.Free;

  if (FTempSnapshotPath <> '') and TDirectory.Exists(FTempSnapshotPath) then
    TDirectory.Delete(FTempSnapshotPath, True);

  TDeepBaseTestHelper.SnapshotPath := FOriginalSnapshotPath;
end;

procedure TTestDeepBaseTestHelper.ButtonClick(Sender: TObject);
begin
  FClicked := True;
end;

procedure TTestDeepBaseTestHelper.Test_SnapshotPath_Is_Set_And_Directory_Created;
begin
  Assert.AreEqual(FTempSnapshotPath, TDeepBaseTestHelper.SnapshotPath);
  Assert.IsTrue(TDirectory.Exists(FTempSnapshotPath), 'Snapshot directory should exist after Initialize');
end;

procedure TTestDeepBaseTestHelper.Test_CaptureFormState_Includes_Form_And_Control_Properties;
var
  JsonStr: string;
  RootObj, ControlObj, ChildObj: TJSONObject;
  Value: TJSONValue;
begin
  JsonStr := TDeepBaseTestHelper.CaptureFormState(FForm);
  RootObj := TJSONObject(TJSONObject.ParseJSONValue(JsonStr));
  try
    Assert.IsNotNull(RootObj, 'Root JSON should not be nil');

    // basic form fields
    Assert.AreEqual(FForm.ClassName, RootObj.GetValue<string>('formClass'));
    Assert.AreEqual(FForm.Name, RootObj.GetValue<string>('formName'));
    Assert.AreEqual(FForm.Caption, RootObj.GetValue<string>('caption'));

    // first top-level control should be our container panel
    Value := RootObj.GetValue('control_0');
    Assert.IsTrue(Value is TJSONObject, 'control_0 should be an object');
    ControlObj := TJSONObject(Value);
    Assert.AreEqual(FPanel.ClassName, ControlObj.GetValue<string>('class'));
    Assert.AreEqual(FPanel.Name, ControlObj.GetValue<string>('name'));

    // and the first child of the panel should be our button
    Value := ControlObj.GetValue('child_0');
    Assert.IsTrue(Value is TJSONObject, 'child_0 should be an object');
    ChildObj := TJSONObject(Value);
    Assert.AreEqual(FButton.ClassName, ChildObj.GetValue<string>('class'));
    Assert.AreEqual(FButton.Name, ChildObj.GetValue<string>('name'));
    Assert.AreEqual(FButton.Caption, ChildObj.GetValue<string>('caption'));
  finally
    RootObj.Free;
  end;
end;

procedure TTestDeepBaseTestHelper.Test_SaveSnapshot_And_GetSnapshot_File_Mode;
var
  SnapshotName: string;
  JsonStr: string;
  FileName: string;
begin
  SnapshotName := 'Test_SaveSnapshot_And_GetSnapshot_File_Mode';

  TDeepBaseTestHelper.SaveSnapshot(SnapshotName, FForm, False {SaveScreenshot});

  // file should exist
  FileName := TPath.Combine(TDeepBaseTestHelper.SnapshotPath, SnapshotName + '.json');
  Assert.IsTrue(TFile.Exists(FileName), 'Snapshot JSON file should be created');

  JsonStr := TDeepBaseTestHelper.GetSnapshot(SnapshotName);
  Assert.IsNotEmpty(JsonStr, 'GetSnapshot should return JSON content');
end;

procedure TTestDeepBaseTestHelper.Test_VerifySnapshot_Success_When_State_Unchanged;
var
  SnapshotName: string;
  ResultRec: TSnapshotVerifyResult;
begin
  SnapshotName := 'Test_VerifySnapshot_Success';
  TDeepBaseTestHelper.SaveSnapshot(SnapshotName, FForm, False);

  ResultRec := TDeepBaseTestHelper.VerifySnapshot(SnapshotName, FForm);
  Assert.IsTrue(ResultRec.Success, 'Snapshot verification should succeed when state is unchanged');
  Assert.AreEqual('Snapshot verified successfully', ResultRec.Message);
end;

procedure TTestDeepBaseTestHelper.Test_VerifySnapshot_Returns_NotFound_When_Snapshot_Missing;
var
  ResultRec: TSnapshotVerifyResult;
  Name: string;
begin
  Name := 'NonExistentSnapshot_' + TGUID.NewGuid.ToString;
  ResultRec := TDeepBaseTestHelper.VerifySnapshot(Name, FForm);
  Assert.IsFalse(ResultRec.Success, 'Success should be False when snapshot is missing');
  Assert.IsTrue(ResultRec.Message.Contains('Snapshot not found'), 'Message should indicate snapshot missing');
end;

procedure TTestDeepBaseTestHelper.Test_VerifySnapshot_Detects_Differences_And_Populates_Diffs;
var
  SnapshotName: string;
  FileName, JsonStr: string;
  Obj: TJSONObject;
  Pair: TJSONPair;
  ResultRec: TSnapshotVerifyResult;
  I: Integer;
  FoundCaptionDiff: Boolean;
begin
  SnapshotName := 'Test_VerifySnapshot_Diff';
  TDeepBaseTestHelper.SaveSnapshot(SnapshotName, FForm, False);

  // load and modify the stored JSON so that expected caption differs from actual
  FileName := TPath.Combine(TDeepBaseTestHelper.SnapshotPath, SnapshotName + '.json');
  JsonStr := TFile.ReadAllText(FileName, TEncoding.UTF8);
  Obj := TJSONObject(TJSONObject.ParseJSONValue(JsonStr));
  try
    if Obj = nil then
      Assert.Fail('Failed to parse snapshot JSON');

    Pair := Obj.RemovePair('caption');
    if Assigned(Pair) then
      Pair.Free;
    Obj.AddPair('caption', 'Changed Caption');

    // also add an extra property that does not exist on the actual form
    Obj.AddPair('extraProp', 'extra');

    TFile.WriteAllText(FileName, Obj.Format(2), TEncoding.UTF8);
  finally
    Obj.Free;
  end;

  ResultRec := TDeepBaseTestHelper.VerifySnapshot(SnapshotName, FForm);
  Assert.IsFalse(ResultRec.Success, 'Verification should fail when JSON differs');
  Assert.IsTrue(Length(ResultRec.Diffs) > 0, 'Diffs should not be empty');

  FoundCaptionDiff := False;
  for I := 0 to High(ResultRec.Diffs) do
  begin
    if ResultRec.Diffs[I].PropertyPath = 'caption' then
    begin
      FoundCaptionDiff := True;
      Assert.AreEqual('"Changed Caption"', ResultRec.Diffs[I].ExpectedValue);
      Assert.AreEqual('"' + FForm.Caption + '"', ResultRec.Diffs[I].ActualValue);
      Break;
    end;
  end;

  Assert.IsTrue(FoundCaptionDiff, 'Should contain a diff for caption');
end;

procedure TTestDeepBaseTestHelper.Test_ListSnapshots_Includes_Saved_Snapshot;
var
  SnapshotName: string;
  Names: TArray<string>;
  Name: string;
  Found: Boolean;
begin
  SnapshotName := 'Test_ListSnapshots';
  TDeepBaseTestHelper.SaveSnapshot(SnapshotName, FForm, False);

  Names := TDeepBaseTestHelper.ListSnapshots;
  Found := False;
  for Name in Names do
  begin
    if SameText(Name, SnapshotName) then
    begin
      Found := True;
      Break;
    end;
  end;

  Assert.IsTrue(Found, 'Saved snapshot name should be returned by ListSnapshots');
end;

procedure TTestDeepBaseTestHelper.Test_DeleteSnapshot_Removes_JSON_And_PNG;
var
  SnapshotName: string;
  JsonFile, PngFile: string;
begin
  SnapshotName := 'Test_DeleteSnapshot';
  TDeepBaseTestHelper.SaveSnapshot(SnapshotName, FForm, False);

  JsonFile := TPath.Combine(TDeepBaseTestHelper.SnapshotPath, SnapshotName + '.json');
  PngFile := TPath.Combine(TDeepBaseTestHelper.SnapshotPath, SnapshotName + '.png');

  // create a dummy PNG file so we can test deletion logic
  TFile.WriteAllText(PngFile, 'dummy', TEncoding.UTF8);

  Assert.IsTrue(TFile.Exists(JsonFile), 'JSON snapshot file should exist before deletion');
  Assert.IsTrue(TFile.Exists(PngFile), 'PNG file should exist before deletion');

  TDeepBaseTestHelper.DeleteSnapshot(SnapshotName);

  Assert.IsFalse(TFile.Exists(JsonFile), 'JSON snapshot file should be deleted');
  Assert.IsFalse(TFile.Exists(PngFile), 'PNG file should be deleted');
end;

procedure TTestDeepBaseTestHelper.Test_GetControlValue_And_AssertValue_Work_For_Common_Controls;
begin
  // baseline direct properties
  Assert.AreEqual('John', FEdit.Text);
  Assert.IsTrue(FCheckBox.Checked);

  // AssertValue should not raise when values match (edit and checkbox)
  TDeepBaseTestHelper.AssertValue(FEdit, 'John');
  TDeepBaseTestHelper.AssertValue(FCheckBox, 'True');

  // and should raise when values differ for checkbox
  Assert.WillRaise(
    procedure
    begin
      TDeepBaseTestHelper.AssertValue(FCheckBox, 'False');
    end,
    ETestAssertionFailed
  );
end;

procedure TTestDeepBaseTestHelper.Test_AssertVisible_And_AssertEnabled_Raise_When_Conditions_Not_Met;
begin
  // visible
  FButton.Visible := False;
  Assert.WillRaise(
    procedure
    begin
      TDeepBaseTestHelper.AssertVisible(FButton);
    end,
    ETestAssertionFailed
  );

  // enabled
  FButton.Visible := True;
  FButton.Enabled := False;
  Assert.WillRaise(
    procedure
    begin
      TDeepBaseTestHelper.AssertEnabled(FButton);
    end,
    ETestAssertionFailed
  );
end;

procedure TTestDeepBaseTestHelper.Test_FindControl_And_FindControlByClass_Work_Correctly;
var
  Ctrl: TControl;
  EditCtrl: TEdit;
begin
  Ctrl := TDeepBaseTestHelper.FindControl(FForm, 'btnOK');
  Assert.IsTrue(Assigned(Ctrl), 'FindControl should find btnOK');
  Assert.AreSame(FButton, Ctrl, 'FindControl should return the correct button instance');

  EditCtrl := TDeepBaseTestHelper.FindControlByClass<TEdit>(FForm);
  Assert.IsTrue(Assigned(EditCtrl), 'FindControlByClass should find an edit control');
  Assert.AreSame(FEdit, EditCtrl, 'FindControlByClass should return our FEdit');
end;

procedure TTestDeepBaseTestHelper.Test_FindAllControlsByClass_Returns_All_Instances;
var
  Buttons: TArray<TButton>;
begin
  Buttons := TDeepBaseTestHelper.FindAllControlsByClass<TButton>(FForm);
  Assert.IsTrue(Length(Buttons) >= 1, 'At least one TButton should be found');
  Assert.AreSame(FButton, Buttons[0], 'First button in the list should be our FButton');
end;

procedure TTestDeepBaseTestHelper.Test_SimulateSelect_ByIndex_And_ByText_Updates_Index;
begin
  // ComboBox by index
  TDeepBaseTestHelper.SimulateSelect(FComboBox, 1);
  Assert.AreEqual(1, FComboBox.ItemIndex, 'ComboBox index should be updated');

  // ListBox by text
  TDeepBaseTestHelper.SimulateSelect(FListBox, 'Two');
  Assert.AreEqual(FListBox.Items.IndexOf('Two'), FListBox.ItemIndex, 'ListBox index should be updated by text');

  // ListView by index
  TDeepBaseTestHelper.SimulateSelect(FListView, 0);
  Assert.AreEqual(0, FListView.ItemIndex, 'ListView index should be updated');
end;

procedure TTestDeepBaseTestHelper.Test_SimulateCheck_Updates_Checked_State;
begin
  TDeepBaseTestHelper.SimulateCheck(FCheckBox, False);
  Assert.IsFalse(FCheckBox.Checked, 'CheckBox should be unchecked');

  TDeepBaseTestHelper.SimulateCheck(FCheckBox, True);
  Assert.IsTrue(FCheckBox.Checked, 'CheckBox should be checked');
end;

procedure TTestDeepBaseTestHelper.Test_SimulateInput_Updates_Text;
begin
  TDeepBaseTestHelper.SimulateInput(FEdit, 'Alice');
  Assert.AreEqual('Alice', FEdit.Text, 'SimulateInput should update edit text');
end;

procedure TTestDeepBaseTestHelper.Test_SimulateClick_And_DoubleClick_Do_Not_Raise;
begin
  // If these raise any exception, the test will fail automatically
  TDeepBaseTestHelper.SimulateClick(FButton);
  TDeepBaseTestHelper.SimulateDoubleClick(FButton);
end;

procedure TTestDeepBaseTestHelper.Test_SimulateKeyPress_And_MouseMove_Do_Not_Raise;
var
  OldPos: TPoint;
begin
  GetCursorPos(OldPos);
  // If these raise any exception, the test will fail automatically
  TDeepBaseTestHelper.SimulateKeyPress(FEdit, Ord('A'));
  TDeepBaseTestHelper.SimulateMouseMove(FButton, 5, 5);
  // best-effort: restore cursor position
  SetCursorPos(OldPos.X, OldPos.Y);
end;

procedure TTestDeepBaseTestHelper.Test_CaptureScreenshot_And_SaveScreenshotToFile_Work;
var
  Bitmap: TBitmap;
  PngFile: string;
begin
  Bitmap := TDeepBaseTestHelper.CaptureScreenshot(FForm);
  try
    Assert.IsNotNull(Bitmap, 'CaptureScreenshot should return a bitmap');
    Assert.AreEqual(FForm.Width, Bitmap.Width, 'Bitmap width should match form');
    Assert.AreEqual(FForm.Height, Bitmap.Height, 'Bitmap height should match form');
  finally
    Bitmap.Free;
  end;

  PngFile := TPath.Combine(TDeepBaseTestHelper.SnapshotPath, 'Test_Screenshot.png');
  if TFile.Exists(PngFile) then
    TFile.Delete(PngFile);

  TDeepBaseTestHelper.SaveScreenshotToFile(FForm, PngFile);
  Assert.IsTrue(TFile.Exists(PngFile), 'SaveScreenshotToFile should create PNG file');
end;

procedure TTestDeepBaseTestHelper.Test_SnapshotDiff_And_VerifyResult_Clear_Reset_Fields;
var
  D: TSnapshotDiff;
  R: TSnapshotVerifyResult;
begin
  D.PropertyPath := 'path';
  D.ExpectedValue := 'expected';
  D.ActualValue := 'actual';
  D.Clear;
  Assert.AreEqual('', D.PropertyPath);
  Assert.AreEqual('', D.ExpectedValue);
  Assert.AreEqual('', D.ActualValue);

  R.Success := True;
  SetLength(R.Diffs, 1);
  R.Message := 'msg';
  R.Clear;
  Assert.IsFalse(R.Success, 'Clear should reset Success to False');
  Assert.AreEqual(Integer(0), Integer(Length(R.Diffs)), 'Clear should reset Diffs length to 0');
  Assert.AreEqual('', R.Message, 'Clear should reset Message to empty');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestDeepBaseTestHelper);

end.
