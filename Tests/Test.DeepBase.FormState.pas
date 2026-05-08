unit Test.DeepBase.FormState;

{*******************************************************************************
  DeepBase FormState 模块单元测试
  
  测试内容:
  - SaveFormState / RestoreFormState
  - 多显示器边界检�?
  - WindowState 处理
  - Extra JSON 字段
*******************************************************************************}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils, System.Classes, System.JSON, System.Types,
  System.Generics.Collections,
  Vcl.Forms, Vcl.Controls,
  DeepBase.Types, DeepBase.Manager, DeepBase.FormState, DeepBase.Storage.Interfaces;

type
  [TestFixture]
  TTestDeepBaseFormState = class
  private
    FFormState: TDeepBaseFormState;
    FTestForm: TForm;
    FManager: TDeepBaseManager;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Test_SaveFormState_Basic;
    
    [Test]
    procedure Test_RestoreFormState_Basic;
    
    [Test]
    procedure Test_SaveRestore_Position;
    
    [Test]
    procedure Test_SaveRestore_Size;
    
    [Test]
    procedure Test_SaveRestore_WindowState_Normal;
    
    [Test]
    procedure Test_SaveRestore_WindowState_Maximized;
    
    [Test]
    procedure Test_RestoreFormState_BoundaryCheck;

    [Test]
    procedure Test_RestoreFormState_ClampsStaleMultiMonitorBounds;
    
    [Test]
    procedure Test_SaveRestore_Extra_JSON;
    
    [Test]
    procedure Test_DeleteFormState;
    
    [Test]
    procedure Test_FormStateExists;
    
    [Test]
    procedure Test_MultipleFormsIsolated;

    [Test]
    procedure Test_StorageInjection_SaveRestoreState;
  end;

implementation

type
  TInMemoryFormStateStorage = class(TInterfacedObject, IFormStateStorage)
  private
    FValues: TDictionary<string, TFormStateData>;
  public
    constructor Create;
    destructor Destroy; override;
    procedure WriteState(const FormName: string; const Data: TFormStateData);
    function ReadState(const FormName: string; out Data: TFormStateData): Boolean;
    procedure DeleteState(const FormName: string);
    function StateExists(const FormName: string): Boolean;
    function ReadFormNames: TArray<string>;
    procedure ClearAll;
  end;

constructor TInMemoryFormStateStorage.Create;
begin
  inherited Create;
  FValues := TDictionary<string, TFormStateData>.Create;
end;

destructor TInMemoryFormStateStorage.Destroy;
begin
  FValues.Free;
  inherited;
end;

procedure TInMemoryFormStateStorage.WriteState(const FormName: string;
  const Data: TFormStateData);
begin
  FValues.AddOrSetValue(FormName, Data);
end;

function TInMemoryFormStateStorage.ReadState(const FormName: string;
  out Data: TFormStateData): Boolean;
begin
  Result := FValues.TryGetValue(FormName, Data);
  if not Result then
    Data.Init;
end;

procedure TInMemoryFormStateStorage.DeleteState(const FormName: string);
begin
  FValues.Remove(FormName);
end;

function TInMemoryFormStateStorage.StateExists(const FormName: string): Boolean;
begin
  Result := FValues.ContainsKey(FormName);
end;

function TInMemoryFormStateStorage.ReadFormNames: TArray<string>;
var
  Pair: TPair<string, TFormStateData>;
begin
  SetLength(Result, 0);
  for Pair in FValues do
  begin
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)] := Pair.Key;
  end;
end;

procedure TInMemoryFormStateStorage.ClearAll;
begin
  FValues.Clear;
end;

{ TTestDeepBaseFormState }

procedure TTestDeepBaseFormState.Setup;
var
  WorkArea: TRect;
  InitialLeft: Integer;
  InitialTop: Integer;
begin
  FManager := DeepBase.Manager.DeepBase;
  if not FManager.IsInitialized then
    FManager.InitializeWithDB(':memory:');
  FFormState := FManager.FormState;
  
  // 创建测试窗体
  FTestForm := TForm.CreateNew(nil);
  // Component name must be a valid identifier (no braces / no dashes)
  FTestForm.Name := 'TestForm_' +
    StringReplace(
      StringReplace(
        StringReplace(TGUID.NewGuid.ToString, '-', '', [rfReplaceAll]),
        '{', '', [rfReplaceAll]
      ),
      '}', '', [rfReplaceAll]
    );
  // Ensure window handle exists before setting bounds; otherwise Windows will pick default placement
  // and GetWindowPlacement() may not reflect our assigned Left/Top values.
  FTestForm.HandleNeeded;

  WorkArea := Screen.WorkAreaRect;
  InitialLeft := 100;
  InitialTop := 300;

  // Keep requested baseline coordinates (Left=100, Top=300) while ensuring
  // the form still fits when runner desktop/workarea is constrained.
  if InitialLeft < WorkArea.Left then
    InitialLeft := WorkArea.Left;
  if InitialTop < WorkArea.Top then
    InitialTop := WorkArea.Top;
  if InitialLeft + 400 > WorkArea.Right then
    InitialLeft := WorkArea.Right - 400;
  if InitialTop + 300 > WorkArea.Bottom then
    InitialTop := WorkArea.Bottom - 300;
  if InitialLeft < WorkArea.Left then
    InitialLeft := WorkArea.Left;
  if InitialTop < WorkArea.Top then
    InitialTop := WorkArea.Top;

  FTestForm.SetBounds(InitialLeft, InitialTop, 400, 300);
  FTestForm.WindowState := wsNormal;
end;

procedure TTestDeepBaseFormState.TearDown;
begin
  if FTestForm <> nil then
  begin
    FFormState.DeleteFormState(FTestForm.Name);
    FreeAndNil(FTestForm);
  end;
  FFormState := nil;
end;

procedure TTestDeepBaseFormState.Test_SaveFormState_Basic;
begin
  Assert.WillNotRaise(
    procedure
    begin
      FFormState.SaveFormState(FTestForm);
    end,
    Exception,
    'SaveFormState should not raise'
  );
end;

procedure TTestDeepBaseFormState.Test_RestoreFormState_Basic;
begin
  FFormState.SaveFormState(FTestForm);
  
  Assert.WillNotRaise(
    procedure
    begin
      FFormState.RestoreFormState(FTestForm);
    end,
    Exception,
    'RestoreFormState should not raise'
  );
end;

procedure TTestDeepBaseFormState.Test_SaveRestore_Position;
var
  OrigLeft, OrigTop: Integer;
begin
  OrigLeft := 150;
  OrigTop := 200;
  
  FTestForm.Left := OrigLeft;
  FTestForm.Top := OrigTop;
  FFormState.SaveFormState(FTestForm);
  
  // 改变位置
  FTestForm.Left := 0;
  FTestForm.Top := 0;
  
  // 恢复
  FFormState.RestoreFormState(FTestForm);
  
  Assert.AreEqual(OrigLeft, FTestForm.Left, '左边位置应该恢复');
  Assert.AreEqual(OrigTop, FTestForm.Top, '顶部位置应该恢复');
end;

procedure TTestDeepBaseFormState.Test_SaveRestore_Size;
var
  OrigWidth, OrigHeight: Integer;
begin
  OrigWidth := 500;
  OrigHeight := 400;
  
  FTestForm.Width := OrigWidth;
  FTestForm.Height := OrigHeight;
  FFormState.SaveFormState(FTestForm);
  
  // 改变大小
  FTestForm.Width := 200;
  FTestForm.Height := 100;
  
  // 恢复
  FFormState.RestoreFormState(FTestForm);
  
  Assert.AreEqual(OrigWidth, FTestForm.Width, '宽度应该恢复');
  Assert.AreEqual(OrigHeight, FTestForm.Height, '高度应该恢复');
end;

procedure TTestDeepBaseFormState.Test_SaveRestore_WindowState_Normal;
begin
  FTestForm.WindowState := wsNormal;
  FFormState.SaveFormState(FTestForm);
  
  FTestForm.WindowState := wsMinimized;
  
  FFormState.RestoreFormState(FTestForm);
  
  Assert.AreEqual(Ord(wsNormal), Ord(FTestForm.WindowState), 'WindowState 应该恢复�?Normal');
end;

procedure TTestDeepBaseFormState.Test_SaveRestore_WindowState_Maximized;
begin
  FTestForm.WindowState := wsMaximized;
  FFormState.SaveFormState(FTestForm);
  
  FTestForm.WindowState := wsNormal;
  
  FFormState.RestoreFormState(FTestForm);
  
  Assert.AreEqual(Ord(wsMaximized), Ord(FTestForm.WindowState), 'WindowState 应该恢复�?Maximized');
end;

procedure TTestDeepBaseFormState.Test_RestoreFormState_BoundaryCheck;
begin
  // 保存一个超出屏幕范围的位置
  FTestForm.Left := -10000;
  FTestForm.Top := -10000;
  FFormState.SaveFormState(FTestForm);
  
  // 恢复时应该自动调整到有效范围
  FFormState.RestoreFormState(FTestForm);
  
  // 窗体应该在可见范围内
  Assert.IsTrue(FTestForm.Left >= -FTestForm.Width, '左边位置应该在合理范围内');
  Assert.IsTrue(FTestForm.Top >= -FTestForm.Height, '顶部位置应该在合理范围内');
end;

procedure TTestDeepBaseFormState.Test_RestoreFormState_ClampsStaleMultiMonitorBounds;
var
  Storage: IFormStateStorage;
  LocalFormState: TDeepBaseFormState;
  Data: TFormStateData;
  FormRect: TRect;
  WorkArea: TRect;
  I: Integer;
  FitsOnMonitor: Boolean;
  VirtualRight: Integer;
  VirtualBottom: Integer;
begin
  Storage := TInMemoryFormStateStorage.Create;
  LocalFormState := TDeepBaseFormState.Create(Storage);
  try
    VirtualRight := Screen.DesktopRect.Right;
    VirtualBottom := Screen.DesktopRect.Bottom;

    Data.Init;
    Data.Left := VirtualRight + 5000;
    Data.Top := VirtualBottom + 5000;
    Data.Width := 50000;
    Data.Height := 50000;
    Data.WindowState := 0;
    Data.MonitorIndex := 99;

    LocalFormState.SaveState(FTestForm.Name, Data);
    LocalFormState.RestoreFormState(FTestForm);

    FormRect := Rect(FTestForm.Left, FTestForm.Top,
      FTestForm.Left + FTestForm.Width,
      FTestForm.Top + FTestForm.Height);
    FitsOnMonitor := False;
    for I := 0 to Screen.MonitorCount - 1 do
    begin
      WorkArea := Screen.Monitors[I].WorkareaRect;
      if (FormRect.Left >= WorkArea.Left) and
         (FormRect.Top >= WorkArea.Top) and
         (FormRect.Right <= WorkArea.Right) and
         (FormRect.Bottom <= WorkArea.Bottom) then
      begin
        FitsOnMonitor := True;
        Break;
      end;
    end;

    Assert.IsTrue(FitsOnMonitor,
      'Stale multi-monitor bounds should be clamped into a current monitor work area');
  finally
    LocalFormState.Free;
  end;
end;

procedure TTestDeepBaseFormState.Test_SaveRestore_Extra_JSON;
var
  ExtraJson: TJSONObject;
  RestoredExtra: string;
begin
  ExtraJson := TJSONObject.Create;
  try
    ExtraJson.AddPair('customField', 'customValue');
    ExtraJson.AddPair('splitterPos', TJSONNumber.Create(250));
    
    FFormState.SaveFormState(FTestForm, ExtraJson.ToString);
  finally
    ExtraJson.Free;
  end;
  
  RestoredExtra := FFormState.GetFormStateExtra(FTestForm.Name);
  
  Assert.IsNotEmpty(RestoredExtra, 'Extra field should not be empty');
  Assert.Contains(RestoredExtra, 'customValue', 'Extra should contain custom value');
end;

procedure TTestDeepBaseFormState.Test_DeleteFormState;
begin
  FFormState.SaveFormState(FTestForm);
  Assert.IsTrue(FFormState.FormStateExists(FTestForm.Name), 'state should exist after save');
  
  FFormState.DeleteFormState(FTestForm.Name);
  
  Assert.IsFalse(FFormState.FormStateExists(FTestForm.Name), '删除后不应该存在');
end;

procedure TTestDeepBaseFormState.Test_FormStateExists;
var
  RandomName: string;
begin
  RandomName := 'NonExistent_' + TGUID.NewGuid.ToString;
  
  Assert.IsFalse(FFormState.FormStateExists(RandomName), 'missing form state should return False');
  
  FFormState.SaveFormState(FTestForm);
  
  Assert.IsTrue(FFormState.FormStateExists(FTestForm.Name), 'saved form state should return True');
end;

procedure TTestDeepBaseFormState.Test_MultipleFormsIsolated;
var
  Form2: TForm;
begin
  Form2 := TForm.CreateNew(nil);
  try
    Form2.Name := 'TestForm2_' +
      StringReplace(
        StringReplace(
          StringReplace(TGUID.NewGuid.ToString, '-', '', [rfReplaceAll]),
          '{', '', [rfReplaceAll]
        ),
        '}', '', [rfReplaceAll]
      );
    Form2.HandleNeeded;
    Form2.SetBounds(200, 100, 600, 300);

    FTestForm.HandleNeeded;
    FTestForm.SetBounds(100, 100, 400, 300);
    
    FFormState.SaveFormState(FTestForm);
    FFormState.SaveFormState(Form2);
    
    // 改变�?
    FTestForm.Left := 0;
    Form2.Left := 0;
    
    // 恢复
    FFormState.RestoreFormState(FTestForm);
    FFormState.RestoreFormState(Form2);
    
    Assert.AreEqual(100, FTestForm.Left, 'first form left should be restored');
    Assert.AreEqual(200, Form2.Left, 'second form left should be restored');
    Assert.AreEqual(400, FTestForm.Width, 'first form width should be restored');
    Assert.AreEqual(600, Form2.Width, 'second form width should be restored');
  finally
    FFormState.DeleteFormState(Form2.Name);
    Form2.Free;
  end;
end;

procedure TTestDeepBaseFormState.Test_StorageInjection_SaveRestoreState;
var
  Storage: IFormStateStorage;
  LocalFormState: TDeepBaseFormState;
  InputData, OutputData: TFormStateData;
begin
  Storage := TInMemoryFormStateStorage.Create;
  LocalFormState := TDeepBaseFormState.Create(Storage);
  try
    InputData.Init;
    InputData.Left := 123;
    InputData.Top := 456;
    InputData.Width := 789;
    InputData.Height := 321;
    InputData.WindowState := 2;
    InputData.Extra := '{"k":"v"}';

    LocalFormState.SaveState('Form_A', InputData);
    Assert.IsTrue(LocalFormState.RestoreState('Form_A', OutputData),
      'Injected storage should restore previously saved state');
    Assert.AreEqual(InputData.Left, OutputData.Left);
    Assert.AreEqual(InputData.Top, OutputData.Top);
    Assert.AreEqual(InputData.Width, OutputData.Width);
    Assert.AreEqual(InputData.Height, OutputData.Height);
    Assert.AreEqual(InputData.WindowState, OutputData.WindowState);
    Assert.AreEqual(InputData.Extra, OutputData.Extra);
  finally
    LocalFormState.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestDeepBaseFormState);

end.
