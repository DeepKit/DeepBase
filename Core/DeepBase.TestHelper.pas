{ ============================================================================
  DeepBase.TestHelper - GUI æµè¯è¾å©æ¨¡å
  
  çæ¬: 1.0
  è¯´æ: æä¾ GUI æµè¯çè¾å©åè?
  åè½:
    - çªä½ç¶ææè?
    - å¿«ç§ä¿å­åéªè¯?
    - æ¨¡æç¨æ·äº¤äºï¼ç¹å»ãè¾å¥ãéæ©ï¼?
    - æ§ä»¶ç¶ææ¯å¯?
  å¹³å°: Windows (VCL only)
  ============================================================================ }

unit DeepBase.TestHelper;

{$IFDEF FMX}
  {$MESSAGE FATAL 'DeepBase.TestHelper is VCL-only. For FMX GUI testing, implement FMX-specific helpers.'}
{$ENDIF}

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.TypInfo,
  System.Rtti,
  System.IOUtils,
  System.Generics.Collections,
  Winapi.Windows,
  Winapi.Messages,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.StdCtrls,
  Vcl.ComCtrls,
  Vcl.ExtCtrls,
  Vcl.Buttons,
  Vcl.Graphics,
  Vcl.Imaging.pngimage;

type
  /// <summary>
  /// å¿«ç§æ¯è¾ç»æ
  /// </summary>
  TSnapshotDiff = record
    PropertyPath: string;    // å±æ§è·¯å¾?(e.g., "btnOK.Caption")
    ExpectedValue: string;   // é¢æå?
    ActualValue: string;     // å®éå?
    
    procedure Clear;
  end;
  
  TSnapshotDiffArray = TArray<TSnapshotDiff>;
  
  /// <summary>
  /// å¿«ç§éªè¯ç»æ
  /// </summary>
  TSnapshotVerifyResult = record
    Success: Boolean;
    Diffs: TSnapshotDiffArray;
    Message: string;
    
    procedure Clear;
  end;

  ITestSnapshotStorage = interface
    ['{F2F06B03-2F6A-4B4D-8C79-C9BB8A0D86D8}']
    procedure WriteSnapshot(const TestName, FormClass, StateJSON,
      ScreenshotPath: string);
    function TryReadSnapshot(const TestName: string; out StateJSON: string): Boolean;
    procedure DeleteSnapshot(const TestName: string);
    function ReadSnapshotNames: TArray<string>;
  end;
  
  /// <summary>
  /// GUI æµè¯è¾å©ç±?
  /// </summary>
  TDeepBaseTestHelper = class
  private
    class var FConnection: TObject;
    class var FSnapshotPath: string;
    class var FSnapshotStorageFactory: TFunc<TObject, ITestSnapshotStorage>;
    
    class function CreateSnapshotStorage: ITestSnapshotStorage;
    class function CaptureControlState(AControl: TControl; const Prefix: string = ''): TJSONObject;
    class function CompareJSON(Expected, Actual: TJSONObject; const Path: string; 
      var Diffs: TList<TSnapshotDiff>): Boolean;
    class function GetControlValue(AControl: TControl): string;
    
  public
    /// <summary>
    /// åå§åæµè¯è¾å©æ¨¡å?    /// </summary>
    class procedure Initialize(AConnection: TObject; const ASnapshotPath: string = '');
    class procedure SetSnapshotStorageFactory(
      const AFactory: TFunc<TObject, ITestSnapshotStorage>);
    
    /// <summary>
    /// æè·çªä½ç¶æä¸º JSON
    /// </summary>
    class function CaptureFormState(AForm: TForm): string;
    
    /// <summary>
    /// ä¿å­å¿«ç§å°æ°æ®åºææä»?
    /// </summary>
    class procedure SaveSnapshot(const TestName: string; AForm: TForm; 
      SaveScreenshot: Boolean = False);
    
    /// <summary>
    /// éªè¯å¿«ç§
    /// </summary>
    class function VerifySnapshot(const TestName: string; AForm: TForm): TSnapshotVerifyResult;
    
    /// <summary>
    /// è·åå·²ä¿å­çå¿«ç§
    /// </summary>
    class function GetSnapshot(const TestName: string): string;
    
    /// <summary>
    /// å é¤å¿«ç§
    /// </summary>
    class procedure DeleteSnapshot(const TestName: string);
    
    /// <summary>
    /// ååºææå¿«ç?
    /// </summary>
    class function ListSnapshots: TArray<string>;
    
    // ========== æ¨¡æç¨æ·äº¤äº ==========
    
    /// <summary>
    /// æ¨¡æç¹å»æ§ä»¶
    /// </summary>
    class procedure SimulateClick(AControl: TControl);
    
    /// <summary>
    /// æ¨¡æåå»æ§ä»¶
    /// </summary>
    class procedure SimulateDoubleClick(AControl: TControl);
    
    /// <summary>
    /// æ¨¡æè¾å¥ææ¬
    /// </summary>
    class procedure SimulateInput(AControl: TControl; const Text: string);
    
    /// <summary>
    /// æ¨¡æéæ©ï¼ComboBoxãListBox ç­ï¼
    /// </summary>
    class procedure SimulateSelect(AControl: TControl; Index: Integer); overload;
    class procedure SimulateSelect(AControl: TControl; const Text: string); overload;
    
    /// <summary>
    /// æ¨¡æå¾éï¼CheckBoxï¼?
    /// </summary>
    class procedure SimulateCheck(AControl: TControl; Checked: Boolean);
    
    /// <summary>
    /// æ¨¡ææé®
    /// </summary>
    class procedure SimulateKeyPress(AControl: TControl; Key: Word; Shift: TShiftState = []);
    
    /// <summary>
    /// æ¨¡æé¼ æ ç§»å¨
    /// </summary>
    class procedure SimulateMouseMove(AControl: TControl; X, Y: Integer);
    
    // ========== æ§ä»¶æ¥æ¾ ==========
    
    /// <summary>
    /// æåç§°æ¥æ¾æ§ä»?
    /// </summary>
    class function FindControl(AForm: TForm; const Name: string): TControl;
    
    /// <summary>
    /// æç±»åæ¥æ¾æ§ä»?
    /// </summary>
    class function FindControlByClass<T: TControl>(AForm: TForm): T;
    
    /// <summary>
    /// æ¥æ¾ææå¹éç±»åçæ§ä»¶
    /// </summary>
    class function FindAllControlsByClass<T: TControl>(AForm: TForm): TArray<T>;
    
    // ========== æ­è¨è¾å© ==========
    
    /// <summary>
    /// æ­è¨æ§ä»¶å¯è§
    /// </summary>
    class procedure AssertVisible(AControl: TControl; const Msg: string = '');
    
    /// <summary>
    /// æ­è¨æ§ä»¶å¯ç¨
    /// </summary>
    class procedure AssertEnabled(AControl: TControl; const Msg: string = '');
    
    /// <summary>
    /// æ­è¨æ§ä»¶ææ¬
    /// </summary>
    class procedure AssertText(AControl: TControl; const Expected: string; const Msg: string = '');
    
    /// <summary>
    /// æ­è¨æ§ä»¶å?
    /// </summary>
    class procedure AssertValue(AControl: TControl; const Expected: string; const Msg: string = '');
    
    // ========== æªå¾ ==========
    
    /// <summary>
    /// æªåçªä½æªå¾
    /// </summary>
    class function CaptureScreenshot(AForm: TForm): TBitmap;
    
    /// <summary>
    /// ä¿å­æªå¾å°æä»?
    /// </summary>
    class procedure SaveScreenshotToFile(AForm: TForm; const FileName: string);
    
    /// <summary>
    /// å¿«ç§å­å¨è·¯å¾
    /// </summary>
    class property SnapshotPath: string read FSnapshotPath write FSnapshotPath;
  end;

  /// <summary>
  /// æµè¯æ­è¨å¼å¸¸
  /// </summary>
  ETestAssertionFailed = class(Exception);

implementation

uses
  System.Types;

{ TSnapshotDiff }

procedure TSnapshotDiff.Clear;
begin
  PropertyPath := '';
  ExpectedValue := '';
  ActualValue := '';
end;

{ TSnapshotVerifyResult }

procedure TSnapshotVerifyResult.Clear;
begin
  Success := False;
  SetLength(Diffs, 0);
  Message := '';
end;

{ TDeepBaseTestHelper }

class function TDeepBaseTestHelper.CreateSnapshotStorage: ITestSnapshotStorage;
begin
  Result := nil;
  if Assigned(FConnection) and Assigned(FSnapshotStorageFactory) then
    Result := FSnapshotStorageFactory(FConnection);
end;

class procedure TDeepBaseTestHelper.Initialize(AConnection: TObject;
  const ASnapshotPath: string);
begin
  FConnection := AConnection;
  
  if ASnapshotPath <> '' then
    FSnapshotPath := ASnapshotPath
  else
    FSnapshotPath := TPath.Combine(TPath.GetDirectoryName(ParamStr(0)), 'Snapshots');
    
  // ç¡®ä¿ç®å½å­å¨
  if not TDirectory.Exists(FSnapshotPath) then
    TDirectory.CreateDirectory(FSnapshotPath);
end;

class procedure TDeepBaseTestHelper.SetSnapshotStorageFactory(
  const AFactory: TFunc<TObject, ITestSnapshotStorage>);
begin
  FSnapshotStorageFactory := AFactory;
end;

class function TDeepBaseTestHelper.CaptureControlState(AControl: TControl; 
  const Prefix: string): TJSONObject;
var
  I: Integer;
  ChildJSON: TJSONObject;
  WinControl: TWinControl;
  ControlName: string;
begin
  Result := TJSONObject.Create;
  
  ControlName := AControl.Name;
  if ControlName = '' then
    ControlName := AControl.ClassName + '_' + IntToStr(AControl.Tag);
  
  // åºæ¬å±æ?
  Result.AddPair('class', AControl.ClassName);
  Result.AddPair('name', ControlName);
  Result.AddPair('visible', TJSONBool.Create(AControl.Visible));
  Result.AddPair('enabled', TJSONBool.Create(AControl.Enabled));
  Result.AddPair('left', TJSONNumber.Create(AControl.Left));
  Result.AddPair('top', TJSONNumber.Create(AControl.Top));
  Result.AddPair('width', TJSONNumber.Create(AControl.Width));
  Result.AddPair('height', TJSONNumber.Create(AControl.Height));
  
  // æ§ä»¶ç¹å®å±æ?
  if AControl is TCustomEdit then
    Result.AddPair('text', TCustomEdit(AControl).Text)
  else if AControl is TButton then
    Result.AddPair('caption', TButton(AControl).Caption)
  else if AControl is TBitBtn then
    Result.AddPair('caption', TBitBtn(AControl).Caption)
  else if AControl is TSpeedButton then
    Result.AddPair('caption', TSpeedButton(AControl).Caption)
  else if AControl is TLabel then
    Result.AddPair('caption', TLabel(AControl).Caption)
  else if AControl is TCheckBox then
  begin
    Result.AddPair('caption', TCheckBox(AControl).Caption);
    Result.AddPair('checked', TJSONBool.Create(TCheckBox(AControl).Checked));
  end
  else if AControl is TRadioButton then
  begin
    Result.AddPair('caption', TRadioButton(AControl).Caption);
    Result.AddPair('checked', TJSONBool.Create(TRadioButton(AControl).Checked));
  end
  else if AControl is TComboBox then
  begin
    Result.AddPair('text', TComboBox(AControl).Text);
    Result.AddPair('itemIndex', TJSONNumber.Create(TComboBox(AControl).ItemIndex));
  end
  else if AControl is TCustomListBox then
    Result.AddPair('itemIndex', TJSONNumber.Create(TListBox(AControl).ItemIndex))
  else if AControl is TCustomMemo then
    Result.AddPair('text', TMemo(AControl).Text)
  else if AControl is TTrackBar then
    Result.AddPair('position', TJSONNumber.Create(TTrackBar(AControl).Position))
  else if AControl is TProgressBar then
    Result.AddPair('position', TJSONNumber.Create(TProgressBar(AControl).Position));
  
  // éå½å¤çå­æ§ä»?
  if AControl is TWinControl then
  begin
    WinControl := TWinControl(AControl);
    if WinControl.ControlCount > 0 then
    begin
      for I := 0 to WinControl.ControlCount - 1 do
      begin
        ChildJSON := CaptureControlState(WinControl.Controls[I]);
        Result.AddPair('child_' + IntToStr(I), ChildJSON);
      end;
    end;
  end;
end;

class function TDeepBaseTestHelper.CaptureFormState(AForm: TForm): string;
var
  JSON: TJSONObject;
  I: Integer;
  ChildJSON: TJSONObject;
begin
  JSON := TJSONObject.Create;
  try
    // çªä½å±æ?
    JSON.AddPair('formClass', AForm.ClassName);
    JSON.AddPair('formName', AForm.Name);
    JSON.AddPair('caption', AForm.Caption);
    JSON.AddPair('width', TJSONNumber.Create(AForm.Width));
    JSON.AddPair('height', TJSONNumber.Create(AForm.Height));
    JSON.AddPair('visible', TJSONBool.Create(AForm.Visible));
    
    // å­æ§ä»?
    for I := 0 to AForm.ControlCount - 1 do
    begin
      ChildJSON := CaptureControlState(AForm.Controls[I]);
      JSON.AddPair('control_' + IntToStr(I), ChildJSON);
    end;
    
    Result := JSON.Format(2);
  finally
    JSON.Free;
  end;
end;

class procedure TDeepBaseTestHelper.SaveSnapshot(const TestName: string; AForm: TForm;
  SaveScreenshot: Boolean);
var
  Storage: ITestSnapshotStorage;
  StateJSON: string;
  FileName: string;
  ScreenshotPath: string;
begin
  StateJSON := CaptureFormState(AForm);
  Storage := CreateSnapshotStorage;

  if SaveScreenshot then
  begin
    ScreenshotPath := TPath.Combine(FSnapshotPath, TestName + '.png');
    SaveScreenshotToFile(AForm, ScreenshotPath);
  end
  else
    ScreenshotPath := '';
  // Save to registered storage first.
  if Assigned(Storage) then
  begin
    Storage.WriteSnapshot(TestName, AForm.ClassName, StateJSON, ScreenshotPath);
  end
  else
  begin
    // Fall back to file storage.
    FileName := TPath.Combine(FSnapshotPath, TestName + '.json');
    TFile.WriteAllText(FileName, StateJSON, TEncoding.UTF8);
  end;
end;

class function TDeepBaseTestHelper.GetSnapshot(const TestName: string): string;
var
  Storage: ITestSnapshotStorage;
  FileName: string;
begin
  Result := '';
  Storage := CreateSnapshotStorage;
  
  // ä¼åä»å·²æ³¨åå­å¨è¯»å
  if Assigned(Storage) and Storage.TryReadSnapshot(TestName, Result) then
    Exit;
    // Fall back to file storage.
    FileName := TPath.Combine(FSnapshotPath, TestName + '.json');
  if TFile.Exists(FileName) then
    Result := TFile.ReadAllText(FileName, TEncoding.UTF8);
end;

class procedure TDeepBaseTestHelper.DeleteSnapshot(const TestName: string);
var
  Storage: ITestSnapshotStorage;
  FileName: string;
begin
  Storage := CreateSnapshotStorage;
  if Assigned(Storage) then
    Storage.DeleteSnapshot(TestName);
  
  // å é¤æä»¶
  FileName := TPath.Combine(FSnapshotPath, TestName + '.json');
  if TFile.Exists(FileName) then
    TFile.Delete(FileName);
    
  FileName := TPath.Combine(FSnapshotPath, TestName + '.png');
  if TFile.Exists(FileName) then
    TFile.Delete(FileName);
end;

class function TDeepBaseTestHelper.ListSnapshots: TArray<string>;
var
  Storage: ITestSnapshotStorage;
  NameList: TList<string>;
  Files: TArray<string>;
  FileName: string;
  SnapshotName: string;
begin
  NameList := TList<string>.Create;
  try
    Storage := CreateSnapshotStorage;
    if Assigned(Storage) then
    begin
      for SnapshotName in Storage.ReadSnapshotNames do
      begin
        if NameList.IndexOf(SnapshotName) < 0 then
          NameList.Add(SnapshotName);
      end;
    end;

    // ä»æä»¶ç³»ç»è¡¥å?    if TDirectory.Exists(FSnapshotPath) then
    begin
      Files := TDirectory.GetFiles(FSnapshotPath, '*.json');
      for FileName in Files do
      begin
        SnapshotName := TPath.GetFileNameWithoutExtension(FileName);
        if NameList.IndexOf(SnapshotName) < 0 then
          NameList.Add(SnapshotName);
      end;
    end;

    Result := NameList.ToArray;
  finally
    NameList.Free;
  end;
end;

class function TDeepBaseTestHelper.CompareJSON(Expected, Actual: TJSONObject; 
  const Path: string; var Diffs: TList<TSnapshotDiff>): Boolean;
var
  Pair: TJSONPair;
  ExpectedValue, ActualValue: TJSONValue;
  ChildPath: string;
  Diff: TSnapshotDiff;
begin
  Result := True;
  
  for Pair in Expected do
  begin
    if Path <> '' then
      ChildPath := Path + '.' + Pair.JsonString.Value
    else
      ChildPath := Pair.JsonString.Value;
      
    ExpectedValue := Pair.JsonValue;
    ActualValue := Actual.GetValue(Pair.JsonString.Value);
    
    if ActualValue = nil then
    begin
      // å±æ§ç¼ºå¤?
      Diff.Clear;
      Diff.PropertyPath := ChildPath;
      Diff.ExpectedValue := ExpectedValue.ToString;
      Diff.ActualValue := '(missing)';
      Diffs.Add(Diff);
      Result := False;
    end
    else if ExpectedValue is TJSONObject then
    begin
      // éå½æ¯è¾å¯¹è±¡
      if ActualValue is TJSONObject then
      begin
        if not CompareJSON(TJSONObject(ExpectedValue), TJSONObject(ActualValue), ChildPath, Diffs) then
          Result := False;
      end
      else
      begin
        Diff.Clear;
        Diff.PropertyPath := ChildPath;
        Diff.ExpectedValue := '(object)';
        Diff.ActualValue := ActualValue.ToString;
        Diffs.Add(Diff);
        Result := False;
      end;
    end
    else if ExpectedValue.ToString <> ActualValue.ToString then
    begin
      // å¼ä¸å¹é
      Diff.Clear;
      Diff.PropertyPath := ChildPath;
      Diff.ExpectedValue := ExpectedValue.ToString;
      Diff.ActualValue := ActualValue.ToString;
      Diffs.Add(Diff);
      Result := False;
    end;
  end;
end;

class function TDeepBaseTestHelper.VerifySnapshot(const TestName: string; 
  AForm: TForm): TSnapshotVerifyResult;
var
  ExpectedJSON, ActualJSON: string;
  Expected, Actual: TJSONObject;
  DiffList: TList<TSnapshotDiff>;
  I: Integer;
begin
  Result.Clear;
  
  ExpectedJSON := GetSnapshot(TestName);
  if ExpectedJSON = '' then
  begin
    Result.Message := 'Snapshot not found: ' + TestName;
    Exit;
  end;
  
  ActualJSON := CaptureFormState(AForm);
  
  Expected := TJSONObject.ParseJSONValue(ExpectedJSON) as TJSONObject;
  Actual := TJSONObject.ParseJSONValue(ActualJSON) as TJSONObject;
  
  if (Expected = nil) or (Actual = nil) then
  begin
    Result.Message := 'Failed to parse JSON';
    Expected.Free;
    Actual.Free;
    Exit;
  end;
  
  DiffList := TList<TSnapshotDiff>.Create;
  try
    Result.Success := CompareJSON(Expected, Actual, '', DiffList);
    Result.Diffs := DiffList.ToArray;
    
    if Result.Success then
      Result.Message := 'Snapshot verified successfully'
    else
      Result.Message := Format('Found %d differences', [Length(Result.Diffs)]);
  finally
    DiffList.Free;
    Expected.Free;
    Actual.Free;
  end;
end;

class function TDeepBaseTestHelper.GetControlValue(AControl: TControl): string;
begin
  Result := '';
  
  if AControl is TCustomEdit then
    Result := TCustomEdit(AControl).Text
  else if AControl is TLabel then
    Result := TLabel(AControl).Caption
  else if AControl is TButton then
    Result := TButton(AControl).Caption
  else if AControl is TBitBtn then
    Result := TBitBtn(AControl).Caption
  else if AControl is TSpeedButton then
    Result := TSpeedButton(AControl).Caption
  else if AControl is TCheckBox then
    Result := BoolToStr(TCheckBox(AControl).Checked, True)
  else if AControl is TRadioButton then
    Result := BoolToStr(TRadioButton(AControl).Checked, True)
  else if AControl is TComboBox then
    Result := TComboBox(AControl).Text
  else if AControl is TTrackBar then
    Result := IntToStr(TTrackBar(AControl).Position)
  else if AControl is TProgressBar then
    Result := IntToStr(TProgressBar(AControl).Position);
end;

// ========== æ¨¡æç¨æ·äº¤äº ==========

class procedure TDeepBaseTestHelper.SimulateClick(AControl: TControl);
var
  P: TPoint;
begin
  if not AControl.Visible or not AControl.Enabled then
    Exit;
    
  // è·åæ§ä»¶ä¸­å¿ç?
  P := AControl.ClientToScreen(Point(AControl.Width div 2, AControl.Height div 2));
  
  // æ¨¡æé¼ æ ç¹å»
  SetCursorPos(P.X, P.Y);
  mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, 0);
  mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, 0);
  
  Application.ProcessMessages;
end;

class procedure TDeepBaseTestHelper.SimulateDoubleClick(AControl: TControl);
begin
  SimulateClick(AControl);
  Sleep(50);
  SimulateClick(AControl);
end;

class procedure TDeepBaseTestHelper.SimulateInput(AControl: TControl; const Text: string);
var
  I: Integer;
begin
  if not (AControl is TWinControl) then
    Exit;
    
  TWinControl(AControl).SetFocus;
  Application.ProcessMessages;
  
  // æ¸é¤ç°æææ¬
  if AControl is TCustomEdit then
    TCustomEdit(AControl).Text := '';
    
  // æ¨¡æè¾å¥
  for I := 1 to Length(Text) do
  begin
    keybd_event(0, MapVirtualKey(Ord(Text[I]), 0), 0, 0);
    keybd_event(0, MapVirtualKey(Ord(Text[I]), 0), KEYEVENTF_KEYUP, 0);
  end;
  
  // ç´æ¥è®¾ç½®ææ¬ï¼æ´å¯é ï¼?
  if AControl is TCustomEdit then
    TCustomEdit(AControl).Text := Text
  else if AControl is TCustomMemo then
    TMemo(AControl).Text := Text;
    
  Application.ProcessMessages;
end;

class procedure TDeepBaseTestHelper.SimulateSelect(AControl: TControl; Index: Integer);
begin
  if AControl is TCustomComboBox then
    TComboBox(AControl).ItemIndex := Index
  else if AControl is TCustomListBox then
    TListBox(AControl).ItemIndex := Index
  else if AControl is TListView then
  begin
    if (Index >= 0) and (Index < TListView(AControl).Items.Count) then
      TListView(AControl).ItemIndex := Index;
  end;
  
  Application.ProcessMessages;
end;

class procedure TDeepBaseTestHelper.SimulateSelect(AControl: TControl; const Text: string);
var
  Index: Integer;
begin
  Index := -1;
  
  if AControl is TCustomComboBox then
    Index := TComboBox(AControl).Items.IndexOf(Text)
  else if AControl is TCustomListBox then
    Index := TListBox(AControl).Items.IndexOf(Text);
    
  if Index >= 0 then
    SimulateSelect(AControl, Index);
end;

class procedure TDeepBaseTestHelper.SimulateCheck(AControl: TControl; Checked: Boolean);
begin
  if AControl is TCheckBox then
    TCheckBox(AControl).Checked := Checked
  else if AControl is TRadioButton then
    TRadioButton(AControl).Checked := Checked;
    
  Application.ProcessMessages;
end;

class procedure TDeepBaseTestHelper.SimulateKeyPress(AControl: TControl; Key: Word; 
  Shift: TShiftState);
begin
  if AControl is TWinControl then
    TWinControl(AControl).SetFocus;
    
  // æä¸ä¿®é¥°é?
  if ssShift in Shift then
    keybd_event(VK_SHIFT, 0, 0, 0);
  if ssCtrl in Shift then
    keybd_event(VK_CONTROL, 0, 0, 0);
  if ssAlt in Shift then
    keybd_event(VK_MENU, 0, 0, 0);
    
  // æé®
  keybd_event(Key, 0, 0, 0);
  keybd_event(Key, 0, KEYEVENTF_KEYUP, 0);
  
  // éæ¾ä¿®é¥°é?
  if ssAlt in Shift then
    keybd_event(VK_MENU, 0, KEYEVENTF_KEYUP, 0);
  if ssCtrl in Shift then
    keybd_event(VK_CONTROL, 0, KEYEVENTF_KEYUP, 0);
  if ssShift in Shift then
    keybd_event(VK_SHIFT, 0, KEYEVENTF_KEYUP, 0);
    
  Application.ProcessMessages;
end;

class procedure TDeepBaseTestHelper.SimulateMouseMove(AControl: TControl; X, Y: Integer);
var
  P: TPoint;
begin
  P := AControl.ClientToScreen(Point(X, Y));
  SetCursorPos(P.X, P.Y);
  Application.ProcessMessages;
end;

// ========== æ§ä»¶æ¥æ¾ ==========

class function TDeepBaseTestHelper.FindControl(AForm: TForm; const Name: string): TControl;

  function FindInControl(Parent: TWinControl): TControl;
  var
    I: Integer;
    Child: TControl;
  begin
    Result := nil;
    
    for I := 0 to Parent.ControlCount - 1 do
    begin
      Child := Parent.Controls[I];
      
      if SameText(Child.Name, Name) then
        Exit(Child);
        
      if Child is TWinControl then
      begin
        Result := FindInControl(TWinControl(Child));
        if Result <> nil then
          Exit;
      end;
    end;
  end;
  
begin
  Result := FindInControl(AForm);
end;

class function TDeepBaseTestHelper.FindControlByClass<T>(AForm: TForm): T;
var
  I, J: Integer;
  Stack: TList<TWinControl>;
  Parent: TWinControl;
  Child: TControl;
begin
  Result := nil;
  Stack := TList<TWinControl>.Create;
  try
    Stack.Add(AForm);
    
    while Stack.Count > 0 do
    begin
      Parent := Stack[Stack.Count - 1];
      Stack.Delete(Stack.Count - 1);
      
      for I := 0 to Parent.ControlCount - 1 do
      begin
        Child := Parent.Controls[I];
        
        if Child is T then
          Exit(T(Child));
          
        if Child is TWinControl then
          Stack.Add(TWinControl(Child));
      end;
    end;
  finally
    Stack.Free;
  end;
end;

class function TDeepBaseTestHelper.FindAllControlsByClass<T>(AForm: TForm): TArray<T>;
var
  ResultList: TList<T>;
  Stack: TList<TWinControl>;
  Parent: TWinControl;
  Child: TControl;
  I: Integer;
begin
  ResultList := TList<T>.Create;
  Stack := TList<TWinControl>.Create;
  try
    Stack.Add(AForm);
    
    while Stack.Count > 0 do
    begin
      Parent := Stack[Stack.Count - 1];
      Stack.Delete(Stack.Count - 1);
      
      for I := 0 to Parent.ControlCount - 1 do
      begin
        Child := Parent.Controls[I];
        
        if Child is T then
          ResultList.Add(T(Child));
          
        if Child is TWinControl then
          Stack.Add(TWinControl(Child));
      end;
    end;
    
    Result := ResultList.ToArray;
  finally
    Stack.Free;
    ResultList.Free;
  end;
end;

// ========== æ­è¨è¾å© ==========

class procedure TDeepBaseTestHelper.AssertVisible(AControl: TControl; const Msg: string);
begin
  if not AControl.Visible then
  begin
    if Msg <> '' then
      raise ETestAssertionFailed.Create(Msg)
    else
      raise ETestAssertionFailed.CreateFmt('Control "%s" is not visible', [AControl.Name]);
  end;
end;

class procedure TDeepBaseTestHelper.AssertEnabled(AControl: TControl; const Msg: string);
begin
  if not AControl.Enabled then
  begin
    if Msg <> '' then
      raise ETestAssertionFailed.Create(Msg)
    else
      raise ETestAssertionFailed.CreateFmt('Control "%s" is not enabled', [AControl.Name]);
  end;
end;

class procedure TDeepBaseTestHelper.AssertText(AControl: TControl; const Expected: string;
  const Msg: string);
var
  Actual: string;
begin
  if AControl is TCustomEdit then
    Actual := TCustomEdit(AControl).Text
  else if AControl is TLabel then
    Actual := TLabel(AControl).Caption
  else if AControl is TButton then
    Actual := TButton(AControl).Caption
  else if AControl is TBitBtn then
    Actual := TBitBtn(AControl).Caption
  else if AControl is TSpeedButton then
    Actual := TSpeedButton(AControl).Caption
  else
    Actual := '';
    
  if Actual <> Expected then
  begin
    if Msg <> '' then
      raise ETestAssertionFailed.Create(Msg)
    else
      raise ETestAssertionFailed.CreateFmt(
        'Control "%s" text mismatch. Expected: "%s", Actual: "%s"',
        [AControl.Name, Expected, Actual]);
  end;
end;

class procedure TDeepBaseTestHelper.AssertValue(AControl: TControl; const Expected: string;
  const Msg: string);
var
  Actual: string;
begin
  Actual := GetControlValue(AControl);
  
  if Actual <> Expected then
  begin
    if Msg <> '' then
      raise ETestAssertionFailed.Create(Msg)
    else
      raise ETestAssertionFailed.CreateFmt(
        'Control "%s" value mismatch. Expected: "%s", Actual: "%s"',
        [AControl.Name, Expected, Actual]);
  end;
end;

// ========== æªå¾ ==========

class function TDeepBaseTestHelper.CaptureScreenshot(AForm: TForm): TBitmap;
var
  DC: HDC;
begin
  Result := TBitmap.Create;
  Result.SetSize(AForm.Width, AForm.Height);
  
  DC := GetDC(AForm.Handle);
  try
    BitBlt(Result.Canvas.Handle, 0, 0, AForm.Width, AForm.Height, DC, 0, 0, SRCCOPY);
  finally
    ReleaseDC(AForm.Handle, DC);
  end;
end;

class procedure TDeepBaseTestHelper.SaveScreenshotToFile(AForm: TForm; const FileName: string);
var
  Bitmap: TBitmap;
  PNG: TPngImage;
begin
  Bitmap := CaptureScreenshot(AForm);
  try
    if LowerCase(TPath.GetExtension(FileName)) = '.png' then
    begin
      PNG := TPngImage.Create;
      try
        PNG.Assign(Bitmap);
        PNG.SaveToFile(FileName);
      finally
        PNG.Free;
      end;
    end
    else
      Bitmap.SaveToFile(FileName);
  finally
    Bitmap.Free;
  end;
end;

end.
