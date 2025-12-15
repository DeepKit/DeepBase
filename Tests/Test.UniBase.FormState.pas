unit Test.UniBase.FormState;

{*******************************************************************************
  UniBase FormState 模块单元测试
  
  测试内容:
  - SaveFormState / RestoreFormState
  - 多显示器边界检查
  - WindowState 处理
  - Extra JSON 字段
*******************************************************************************}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils, System.Classes, System.JSON,
  Vcl.Forms, Vcl.Controls,
  UniBase.Types, UniBase.Manager, UniBase.FormState;

type
  [TestFixture]
  TTestUniBaseFormState = class
  private
    FFormState: TUniBaseFormState;
    FTestForm: TForm;
    FManager: TUniBaseManager;
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
    procedure Test_SaveRestore_Extra_JSON;
    
    [Test]
    procedure Test_DeleteFormState;
    
    [Test]
    procedure Test_FormStateExists;
    
    [Test]
    procedure Test_MultipleFormsIsolated;
  end;

implementation

{ TTestUniBaseFormState }

procedure TTestUniBaseFormState.Setup;
begin
  FManager := UniBase.Manager.UniBase;
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

  FTestForm.SetBounds(100, 100, 400, 300);
  FTestForm.WindowState := wsNormal;
end;

procedure TTestUniBaseFormState.TearDown;
begin
  if FTestForm <> nil then
  begin
    FFormState.DeleteFormState(FTestForm.Name);
    FreeAndNil(FTestForm);
  end;
  FFormState := nil;
end;

procedure TTestUniBaseFormState.Test_SaveFormState_Basic;
begin
  Assert.WillNotRaise(
    procedure
    begin
      FFormState.SaveFormState(FTestForm);
    end,
    Exception,
    'SaveFormState 不应该抛出异常'
  );
end;

procedure TTestUniBaseFormState.Test_RestoreFormState_Basic;
begin
  FFormState.SaveFormState(FTestForm);
  
  Assert.WillNotRaise(
    procedure
    begin
      FFormState.RestoreFormState(FTestForm);
    end,
    Exception,
    'RestoreFormState 不应该抛出异常'
  );
end;

procedure TTestUniBaseFormState.Test_SaveRestore_Position;
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

procedure TTestUniBaseFormState.Test_SaveRestore_Size;
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

procedure TTestUniBaseFormState.Test_SaveRestore_WindowState_Normal;
begin
  FTestForm.WindowState := wsNormal;
  FFormState.SaveFormState(FTestForm);
  
  FTestForm.WindowState := wsMinimized;
  
  FFormState.RestoreFormState(FTestForm);
  
  Assert.AreEqual(Ord(wsNormal), Ord(FTestForm.WindowState), 'WindowState 应该恢复为 Normal');
end;

procedure TTestUniBaseFormState.Test_SaveRestore_WindowState_Maximized;
begin
  FTestForm.WindowState := wsMaximized;
  FFormState.SaveFormState(FTestForm);
  
  FTestForm.WindowState := wsNormal;
  
  FFormState.RestoreFormState(FTestForm);
  
  Assert.AreEqual(Ord(wsMaximized), Ord(FTestForm.WindowState), 'WindowState 应该恢复为 Maximized');
end;

procedure TTestUniBaseFormState.Test_RestoreFormState_BoundaryCheck;
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

procedure TTestUniBaseFormState.Test_SaveRestore_Extra_JSON;
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
  
  Assert.IsNotEmpty(RestoredExtra, 'Extra 字段不应该为空');
  Assert.Contains(RestoredExtra, 'customValue', 'Extra 应该包含自定义值');
end;

procedure TTestUniBaseFormState.Test_DeleteFormState;
begin
  FFormState.SaveFormState(FTestForm);
  Assert.IsTrue(FFormState.FormStateExists(FTestForm.Name), '保存后应该存在');
  
  FFormState.DeleteFormState(FTestForm.Name);
  
  Assert.IsFalse(FFormState.FormStateExists(FTestForm.Name), '删除后不应该存在');
end;

procedure TTestUniBaseFormState.Test_FormStateExists;
var
  RandomName: string;
begin
  RandomName := 'NonExistent_' + TGUID.NewGuid.ToString;
  
  Assert.IsFalse(FFormState.FormStateExists(RandomName), '不存在的窗体状态应该返回 False');
  
  FFormState.SaveFormState(FTestForm);
  
  Assert.IsTrue(FFormState.FormStateExists(FTestForm.Name), '保存后应该返回 True');
end;

procedure TTestUniBaseFormState.Test_MultipleFormsIsolated;
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
    
    // 改变值
    FTestForm.Left := 0;
    Form2.Left := 0;
    
    // 恢复
    FFormState.RestoreFormState(FTestForm);
    FFormState.RestoreFormState(Form2);
    
    Assert.AreEqual(100, FTestForm.Left, '第一个窗体位置应该正确');
    Assert.AreEqual(200, Form2.Left, '第二个窗体位置应该正确');
    Assert.AreEqual(400, FTestForm.Width, '第一个窗体宽度应该正确');
    Assert.AreEqual(600, Form2.Width, '第二个窗体宽度应该正确');
  finally
    FFormState.DeleteFormState(Form2.Name);
    Form2.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestUniBaseFormState);

end.
