{ ============================================================================
  UniBase.TestHelper - GUI 测试辅助模块
  
  版本: 1.0
  说明: 提供 GUI 测试的辅助功能
  功能:
    - 窗体状态捕获
    - 快照保存和验证
    - 模拟用户交互（点击、输入、选择）
    - 控件状态比对
  ============================================================================ }

unit UniBase.TestHelper;

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
  Vcl.Imaging.pngimage,
  FireDAC.Comp.Client;

type
  /// <summary>
  /// 快照比较结果
  /// </summary>
  TSnapshotDiff = record
    PropertyPath: string;    // 属性路径 (e.g., "btnOK.Caption")
    ExpectedValue: string;   // 预期值
    ActualValue: string;     // 实际值
    
    procedure Clear;
  end;
  
  TSnapshotDiffArray = TArray<TSnapshotDiff>;
  
  /// <summary>
  /// 快照验证结果
  /// </summary>
  TSnapshotVerifyResult = record
    Success: Boolean;
    Diffs: TSnapshotDiffArray;
    Message: string;
    
    procedure Clear;
  end;
  
  /// <summary>
  /// GUI 测试辅助类
  /// </summary>
  TUniBaseTestHelper = class
  private
    class var FConnection: TFDConnection;
    class var FSnapshotPath: string;
    
    class function CaptureControlState(AControl: TControl; const Prefix: string = ''): TJSONObject;
    class function CompareJSON(Expected, Actual: TJSONObject; const Path: string; 
      var Diffs: TList<TSnapshotDiff>): Boolean;
    class function GetControlValue(AControl: TControl): string;
    
  public
    /// <summary>
    /// 初始化测试辅助模块
    /// </summary>
    class procedure Initialize(AConnection: TFDConnection; const ASnapshotPath: string = '');
    
    /// <summary>
    /// 捕获窗体状态为 JSON
    /// </summary>
    class function CaptureFormState(AForm: TForm): string;
    
    /// <summary>
    /// 保存快照到数据库或文件
    /// </summary>
    class procedure SaveSnapshot(const TestName: string; AForm: TForm; 
      SaveScreenshot: Boolean = False);
    
    /// <summary>
    /// 验证快照
    /// </summary>
    class function VerifySnapshot(const TestName: string; AForm: TForm): TSnapshotVerifyResult;
    
    /// <summary>
    /// 获取已保存的快照
    /// </summary>
    class function GetSnapshot(const TestName: string): string;
    
    /// <summary>
    /// 删除快照
    /// </summary>
    class procedure DeleteSnapshot(const TestName: string);
    
    /// <summary>
    /// 列出所有快照
    /// </summary>
    class function ListSnapshots: TArray<string>;
    
    // ========== 模拟用户交互 ==========
    
    /// <summary>
    /// 模拟点击控件
    /// </summary>
    class procedure SimulateClick(AControl: TControl);
    
    /// <summary>
    /// 模拟双击控件
    /// </summary>
    class procedure SimulateDoubleClick(AControl: TControl);
    
    /// <summary>
    /// 模拟输入文本
    /// </summary>
    class procedure SimulateInput(AControl: TControl; const Text: string);
    
    /// <summary>
    /// 模拟选择（ComboBox、ListBox 等）
    /// </summary>
    class procedure SimulateSelect(AControl: TControl; Index: Integer); overload;
    class procedure SimulateSelect(AControl: TControl; const Text: string); overload;
    
    /// <summary>
    /// 模拟勾选（CheckBox）
    /// </summary>
    class procedure SimulateCheck(AControl: TControl; Checked: Boolean);
    
    /// <summary>
    /// 模拟按键
    /// </summary>
    class procedure SimulateKeyPress(AControl: TControl; Key: Word; Shift: TShiftState = []);
    
    /// <summary>
    /// 模拟鼠标移动
    /// </summary>
    class procedure SimulateMouseMove(AControl: TControl; X, Y: Integer);
    
    // ========== 控件查找 ==========
    
    /// <summary>
    /// 按名称查找控件
    /// </summary>
    class function FindControl(AForm: TForm; const Name: string): TControl;
    
    /// <summary>
    /// 按类型查找控件
    /// </summary>
    class function FindControlByClass<T: TControl>(AForm: TForm): T;
    
    /// <summary>
    /// 查找所有匹配类型的控件
    /// </summary>
    class function FindAllControlsByClass<T: TControl>(AForm: TForm): TArray<T>;
    
    // ========== 断言辅助 ==========
    
    /// <summary>
    /// 断言控件可见
    /// </summary>
    class procedure AssertVisible(AControl: TControl; const Msg: string = '');
    
    /// <summary>
    /// 断言控件启用
    /// </summary>
    class procedure AssertEnabled(AControl: TControl; const Msg: string = '');
    
    /// <summary>
    /// 断言控件文本
    /// </summary>
    class procedure AssertText(AControl: TControl; const Expected: string; const Msg: string = '');
    
    /// <summary>
    /// 断言控件值
    /// </summary>
    class procedure AssertValue(AControl: TControl; const Expected: string; const Msg: string = '');
    
    // ========== 截图 ==========
    
    /// <summary>
    /// 截取窗体截图
    /// </summary>
    class function CaptureScreenshot(AForm: TForm): TBitmap;
    
    /// <summary>
    /// 保存截图到文件
    /// </summary>
    class procedure SaveScreenshotToFile(AForm: TForm; const FileName: string);
    
    /// <summary>
    /// 快照存储路径
    /// </summary>
    class property SnapshotPath: string read FSnapshotPath write FSnapshotPath;
  end;

  /// <summary>
  /// 测试断言异常
  /// </summary>
  ETestAssertionFailed = class(Exception);

implementation

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

{ TUniBaseTestHelper }

class procedure TUniBaseTestHelper.Initialize(AConnection: TFDConnection; 
  const ASnapshotPath: string);
begin
  FConnection := AConnection;
  
  if ASnapshotPath <> '' then
    FSnapshotPath := ASnapshotPath
  else
    FSnapshotPath := TPath.Combine(TPath.GetDirectoryName(ParamStr(0)), 'Snapshots');
    
  // 确保目录存在
  if not TDirectory.Exists(FSnapshotPath) then
    TDirectory.CreateDirectory(FSnapshotPath);
end;

class function TUniBaseTestHelper.CaptureControlState(AControl: TControl; 
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
  
  // 基本属性
  Result.AddPair('class', AControl.ClassName);
  Result.AddPair('name', ControlName);
  Result.AddPair('visible', TJSONBool.Create(AControl.Visible));
  Result.AddPair('enabled', TJSONBool.Create(AControl.Enabled));
  Result.AddPair('left', TJSONNumber.Create(AControl.Left));
  Result.AddPair('top', TJSONNumber.Create(AControl.Top));
  Result.AddPair('width', TJSONNumber.Create(AControl.Width));
  Result.AddPair('height', TJSONNumber.Create(AControl.Height));
  
  // 控件特定属性
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
  
  // 递归处理子控件
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

class function TUniBaseTestHelper.CaptureFormState(AForm: TForm): string;
var
  JSON: TJSONObject;
  I: Integer;
  ChildJSON: TJSONObject;
begin
  JSON := TJSONObject.Create;
  try
    // 窗体属性
    JSON.AddPair('formClass', AForm.ClassName);
    JSON.AddPair('formName', AForm.Name);
    JSON.AddPair('caption', AForm.Caption);
    JSON.AddPair('width', TJSONNumber.Create(AForm.Width));
    JSON.AddPair('height', TJSONNumber.Create(AForm.Height));
    JSON.AddPair('visible', TJSONBool.Create(AForm.Visible));
    
    // 子控件
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

class procedure TUniBaseTestHelper.SaveSnapshot(const TestName: string; AForm: TForm;
  SaveScreenshot: Boolean);
var
  StateJSON: string;
  Query: TFDQuery;
  FileName: string;
  Bitmap: TBitmap;
  ScreenshotPath: string;
begin
  StateJSON := CaptureFormState(AForm);
  
  // 保存到数据库
  if Assigned(FConnection) and FConnection.Connected then
  begin
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := FConnection;
      Query.SQL.Text := 
        'INSERT OR REPLACE INTO TestSnapshots (TestName, FormClass, StateJSON, ScreenshotPath, CreatedAt) ' +
        'VALUES (:Name, :FormClass, :State, :Screenshot, CURRENT_TIMESTAMP)';
      Query.ParamByName('Name').AsString := TestName;
      Query.ParamByName('FormClass').AsString := AForm.ClassName;
      Query.ParamByName('State').AsString := StateJSON;
      
      if SaveScreenshot then
      begin
        ScreenshotPath := TPath.Combine(FSnapshotPath, TestName + '.png');
        SaveScreenshotToFile(AForm, ScreenshotPath);
        Query.ParamByName('Screenshot').AsString := ScreenshotPath;
      end
      else
        Query.ParamByName('Screenshot').AsString := '';
        
      Query.ExecSQL;
    finally
      Query.Free;
    end;
  end
  else
  begin
    // 保存到文件
    FileName := TPath.Combine(FSnapshotPath, TestName + '.json');
    TFile.WriteAllText(FileName, StateJSON, TEncoding.UTF8);
    
    if SaveScreenshot then
    begin
      ScreenshotPath := TPath.Combine(FSnapshotPath, TestName + '.png');
      SaveScreenshotToFile(AForm, ScreenshotPath);
    end;
  end;
end;

class function TUniBaseTestHelper.GetSnapshot(const TestName: string): string;
var
  Query: TFDQuery;
  FileName: string;
begin
  Result := '';
  
  // 优先从数据库读取
  if Assigned(FConnection) and FConnection.Connected then
  begin
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := FConnection;
      Query.SQL.Text := 'SELECT StateJSON FROM TestSnapshots WHERE TestName = :Name';
      Query.ParamByName('Name').AsString := TestName;
      Query.Open;
      
      if not Query.IsEmpty then
        Result := Query.FieldByName('StateJSON').AsString;
    finally
      Query.Free;
    end;
  end;
  
  // 回退到文件
  if Result = '' then
  begin
    FileName := TPath.Combine(FSnapshotPath, TestName + '.json');
    if TFile.Exists(FileName) then
      Result := TFile.ReadAllText(FileName, TEncoding.UTF8);
  end;
end;

class function TUniBaseTestHelper.CompareJSON(Expected, Actual: TJSONObject; 
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
      // 属性缺失
      Diff.Clear;
      Diff.PropertyPath := ChildPath;
      Diff.ExpectedValue := ExpectedValue.ToString;
      Diff.ActualValue := '(missing)';
      Diffs.Add(Diff);
      Result := False;
    end
    else if ExpectedValue is TJSONObject then
    begin
      // 递归比较对象
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
      // 值不匹配
      Diff.Clear;
      Diff.PropertyPath := ChildPath;
      Diff.ExpectedValue := ExpectedValue.ToString;
      Diff.ActualValue := ActualValue.ToString;
      Diffs.Add(Diff);
      Result := False;
    end;
  end;
end;

class function TUniBaseTestHelper.VerifySnapshot(const TestName: string; 
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

class procedure TUniBaseTestHelper.DeleteSnapshot(const TestName: string);
var
  Query: TFDQuery;
  FileName: string;
begin
  // 从数据库删除
  if Assigned(FConnection) and FConnection.Connected then
  begin
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := FConnection;
      Query.SQL.Text := 'DELETE FROM TestSnapshots WHERE TestName = :Name';
      Query.ParamByName('Name').AsString := TestName;
      Query.ExecSQL;
    finally
      Query.Free;
    end;
  end;
  
  // 删除文件
  FileName := TPath.Combine(FSnapshotPath, TestName + '.json');
  if TFile.Exists(FileName) then
    TFile.Delete(FileName);
    
  FileName := TPath.Combine(FSnapshotPath, TestName + '.png');
  if TFile.Exists(FileName) then
    TFile.Delete(FileName);
end;

class function TUniBaseTestHelper.ListSnapshots: TArray<string>;
var
  Query: TFDQuery;
  NameList: TList<string>;
  Files: TArray<string>;
  FileName: string;
begin
  NameList := TList<string>.Create;
  try
    // 从数据库
    if Assigned(FConnection) and FConnection.Connected then
    begin
      Query := TFDQuery.Create(nil);
      try
        Query.Connection := FConnection;
        Query.SQL.Text := 'SELECT DISTINCT TestName FROM TestSnapshots ORDER BY TestName';
        Query.Open;
        
        while not Query.Eof do
        begin
          NameList.Add(Query.FieldByName('TestName').AsString);
          Query.Next;
        end;
      finally
        Query.Free;
      end;
    end;
    
    // 从文件系统
    if TDirectory.Exists(FSnapshotPath) then
    begin
      Files := TDirectory.GetFiles(FSnapshotPath, '*.json');
      for FileName in Files do
      begin
        if NameList.IndexOf(TPath.GetFileNameWithoutExtension(FileName)) < 0 then
          NameList.Add(TPath.GetFileNameWithoutExtension(FileName));
      end;
    end;
    
    Result := NameList.ToArray;
  finally
    NameList.Free;
  end;
end;

class function TUniBaseTestHelper.GetControlValue(AControl: TControl): string;
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

// ========== 模拟用户交互 ==========

class procedure TUniBaseTestHelper.SimulateClick(AControl: TControl);
var
  P: TPoint;
begin
  if not AControl.Visible or not AControl.Enabled then
    Exit;
    
  // 获取控件中心点
  P := AControl.ClientToScreen(Point(AControl.Width div 2, AControl.Height div 2));
  
  // 模拟鼠标点击
  SetCursorPos(P.X, P.Y);
  mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, 0);
  mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, 0);
  
  Application.ProcessMessages;
end;

class procedure TUniBaseTestHelper.SimulateDoubleClick(AControl: TControl);
begin
  SimulateClick(AControl);
  Sleep(50);
  SimulateClick(AControl);
end;

class procedure TUniBaseTestHelper.SimulateInput(AControl: TControl; const Text: string);
var
  I: Integer;
begin
  if not (AControl is TWinControl) then
    Exit;
    
  TWinControl(AControl).SetFocus;
  Application.ProcessMessages;
  
  // 清除现有文本
  if AControl is TCustomEdit then
    TCustomEdit(AControl).Text := '';
    
  // 模拟输入
  for I := 1 to Length(Text) do
  begin
    keybd_event(0, MapVirtualKey(Ord(Text[I]), 0), 0, 0);
    keybd_event(0, MapVirtualKey(Ord(Text[I]), 0), KEYEVENTF_KEYUP, 0);
  end;
  
  // 直接设置文本（更可靠）
  if AControl is TCustomEdit then
    TCustomEdit(AControl).Text := Text
  else if AControl is TCustomMemo then
    TMemo(AControl).Text := Text;
    
  Application.ProcessMessages;
end;

class procedure TUniBaseTestHelper.SimulateSelect(AControl: TControl; Index: Integer);
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

class procedure TUniBaseTestHelper.SimulateSelect(AControl: TControl; const Text: string);
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

class procedure TUniBaseTestHelper.SimulateCheck(AControl: TControl; Checked: Boolean);
begin
  if AControl is TCheckBox then
    TCheckBox(AControl).Checked := Checked
  else if AControl is TRadioButton then
    TRadioButton(AControl).Checked := Checked;
    
  Application.ProcessMessages;
end;

class procedure TUniBaseTestHelper.SimulateKeyPress(AControl: TControl; Key: Word; 
  Shift: TShiftState);
begin
  if AControl is TWinControl then
    TWinControl(AControl).SetFocus;
    
  // 按下修饰键
  if ssShift in Shift then
    keybd_event(VK_SHIFT, 0, 0, 0);
  if ssCtrl in Shift then
    keybd_event(VK_CONTROL, 0, 0, 0);
  if ssAlt in Shift then
    keybd_event(VK_MENU, 0, 0, 0);
    
  // 按键
  keybd_event(Key, 0, 0, 0);
  keybd_event(Key, 0, KEYEVENTF_KEYUP, 0);
  
  // 释放修饰键
  if ssAlt in Shift then
    keybd_event(VK_MENU, 0, KEYEVENTF_KEYUP, 0);
  if ssCtrl in Shift then
    keybd_event(VK_CONTROL, 0, KEYEVENTF_KEYUP, 0);
  if ssShift in Shift then
    keybd_event(VK_SHIFT, 0, KEYEVENTF_KEYUP, 0);
    
  Application.ProcessMessages;
end;

class procedure TUniBaseTestHelper.SimulateMouseMove(AControl: TControl; X, Y: Integer);
var
  P: TPoint;
begin
  P := AControl.ClientToScreen(Point(X, Y));
  SetCursorPos(P.X, P.Y);
  Application.ProcessMessages;
end;

// ========== 控件查找 ==========

class function TUniBaseTestHelper.FindControl(AForm: TForm; const Name: string): TControl;

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

class function TUniBaseTestHelper.FindControlByClass<T>(AForm: TForm): T;
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

class function TUniBaseTestHelper.FindAllControlsByClass<T>(AForm: TForm): TArray<T>;
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

// ========== 断言辅助 ==========

class procedure TUniBaseTestHelper.AssertVisible(AControl: TControl; const Msg: string);
begin
  if not AControl.Visible then
  begin
    if Msg <> '' then
      raise ETestAssertionFailed.Create(Msg)
    else
      raise ETestAssertionFailed.CreateFmt('Control "%s" is not visible', [AControl.Name]);
  end;
end;

class procedure TUniBaseTestHelper.AssertEnabled(AControl: TControl; const Msg: string);
begin
  if not AControl.Enabled then
  begin
    if Msg <> '' then
      raise ETestAssertionFailed.Create(Msg)
    else
      raise ETestAssertionFailed.CreateFmt('Control "%s" is not enabled', [AControl.Name]);
  end;
end;

class procedure TUniBaseTestHelper.AssertText(AControl: TControl; const Expected: string;
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

class procedure TUniBaseTestHelper.AssertValue(AControl: TControl; const Expected: string;
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

// ========== 截图 ==========

class function TUniBaseTestHelper.CaptureScreenshot(AForm: TForm): TBitmap;
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

class procedure TUniBaseTestHelper.SaveScreenshotToFile(AForm: TForm; const FileName: string);
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
