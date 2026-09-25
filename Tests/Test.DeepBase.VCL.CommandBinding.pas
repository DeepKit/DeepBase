unit Test.DeepBase.VCL.CommandBinding;

(********************************************************************************
  Test.DeepBase.VCL.CommandBinding - B2-14 回归

  被测面：TMVVMFormBase / TMVVMFrameBase.BindCommand 建立的按钮↔命令绑定归谁所有。
  旧实现把绑定登记进模块级 GCommandBindings，只在单元 finalization 释放，且
  UnregisterCommandBinding 零调用点 ⇒ 宿主窗体销毁后按钮成了野指针，绑定还挂在命令的
  CanExecuteChanged 订阅面上；命令任一状态变化触发回调，就解引用已释放的按钮。

  断言建在「订阅面」而不是「有没有崩」：访问已释放内存是否立刻 AV 取决于堆状态，
  拿它当判据会做出偶绿用例。所以这里自带一把观测型命令 TObservedCommand，
  把 Add/Remove 的订阅计数暴露成可断言的事实：
    宿主销毁后 HandlerCount 必须回到 0（绑定被释放并退订）
    按钮先销毁后 HandlerCount 必须回到 0（绑定自行脱钩）
  工单点名的「循环建销后触发命令不再 AV」按原样另立一条用例，异常用 try/except 收住
  并连轮次报出，不靠进程崩溃当判据。

  宿主只用窗体侧：TMVVMFrameBase 无法在无 IDE 的环境里实例化——TCustomFrame.Create 对
  任何非 TFrame 后代都强制加载同名 DFM 资源，缺失即 EResNotFound（实测，见 B2-14 证据），
  TCustomForm 尚有 CreateNew 可绕过，TFrame 没有对应构造器。框架侧那条写点由「两处 BindCommand
  收敛到同一个绑定构造函数」在结构上覆盖，运行用例缺口如实登记报主控。
*******************************************************************************)

interface

uses
  System.SysUtils,
  System.Rtti,
  System.TypInfo,
  System.Classes,
  Vcl.Forms,
  Vcl.StdCtrls,
  DUnitX.TestFramework,
  DeepBase.MVVM,
  DeepBase.VCL.MVVMControls;

type
  /// <summary>订阅者列表：命名类型。两处内联声明的匿名动态数组在 dcc64 下不互兼容（E2008）。</summary>
  THandlerList = array of TCanExecuteChangedEvent;

  /// <summary>把 ICommand 的订阅面变成可断言的计数；不执行真实动作，只记账。</summary>
  TObservedCommand = class(TInterfacedObject, ICommand)
  strict private
    FHandlers: THandlerList;
    FExecuteCount: Integer;
    function GetHandlerCount: Integer;
    class function SameHandler(const Left, Right: TCanExecuteChangedEvent): Boolean; static;
  public
    procedure Execute(const Parameter: TValue);
    function CanExecute(const Parameter: TValue): Boolean;
    procedure AddCanExecuteChangedHandler(Handler: TCanExecuteChangedEvent);
    procedure RemoveCanExecuteChangedHandler(Handler: TCanExecuteChangedEvent);
    procedure RaiseCanExecuteChanged;
    property HandlerCount: Integer read GetHandlerCount;
    property ExecuteCount: Integer read FExecuteCount;
  end;

  /// <summary>被测宿主：只能走 CreateNew。TCustomForm.Create 对任何非 TForm 后代都要求
  /// 同名 DFM 资源（实测 EResNotFound: Resource TResourcelessMVVMForm not found），
  /// CreateNew 是「无资源窗体」的公开入口；BindCommand 不依赖 Create 里初始化的绑定管理器。</summary>
  TResourcelessMVVMForm = class(TMVVMFormBase)
  end;

  [TestFixture]
  TTestMVVMCommandBinding = class
  strict private
    const ROUNDS = 50;
  private
    FHost: TResourcelessMVVMForm;
    /// <summary>无主按钮：生命周期与宿主不同，专门走「按钮先死」那条路径。</summary>
    FLooseButton: TButton;
    FOriginalClickCount: Integer;
    class function NewHost: TResourcelessMVVMForm; static;
    procedure HandleOriginalClick(Sender: TObject);  public
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_Host_Destroy_Detaches_Binding_From_Command;
    [Test]
    procedure Test_Repeated_Create_Destroy_Loop_Trigger_Stays_Safe;
    [Test]
    procedure Test_Button_Destroyed_Alone_Detaches_Binding;
    [Test]
    procedure Test_Click_Semantics_And_OnClick_Restored_On_Host_Destroy;
    [Test]
    procedure Test_Enabled_State_Follows_Command;
  end;

implementation

{ TObservedCommand }

class function TObservedCommand.SameHandler(
  const Left, Right: TCanExecuteChangedEvent): Boolean;
begin
  Result := (TMethod(Left).Code = TMethod(Right).Code) and
            (TMethod(Left).Data = TMethod(Right).Data);
end;

function TObservedCommand.GetHandlerCount: Integer;
begin
  Result := Length(FHandlers);
end;

procedure TObservedCommand.Execute(const Parameter: TValue);
begin
  Inc(FExecuteCount);
end;

function TObservedCommand.CanExecute(const Parameter: TValue): Boolean;
begin
  Result := True;
end;

procedure TObservedCommand.AddCanExecuteChangedHandler(Handler: TCanExecuteChangedEvent);
var
  i: Integer;
begin
  for i := 0 to High(FHandlers) do
    if SameHandler(FHandlers[i], Handler) then
      Exit;
  SetLength(FHandlers, Length(FHandlers) + 1);
  FHandlers[High(FHandlers)] := Handler;
end;

procedure TObservedCommand.RemoveCanExecuteChangedHandler(Handler: TCanExecuteChangedEvent);
var
  Kept: THandlerList;
  i: Integer;
begin
  for i := 0 to High(FHandlers) do
    if not SameHandler(FHandlers[i], Handler) then
    begin
      SetLength(Kept, Length(Kept) + 1);
      Kept[High(Kept)] := FHandlers[i];
    end;
  FHandlers := Kept;
end;

procedure TObservedCommand.RaiseCanExecuteChanged;
var
  Snapshot: THandlerList;
  i: Integer;
begin
  // 先快照再回调：真实命令也得扛住「处理器在通知过程中退订」，观测型命令不能反过来替被测面遮掩
  Snapshot := Copy(FHandlers);
  for i := 0 to High(Snapshot) do
    Snapshot[i](Self);
end;

{ TTestMVVMCommandBinding }

class function TTestMVVMCommandBinding.NewHost: TResourcelessMVVMForm;
begin
  Result := TResourcelessMVVMForm.CreateNew(nil);
end;

procedure TTestMVVMCommandBinding.HandleOriginalClick(Sender: TObject);
begin
  Inc(FOriginalClickCount);
end;

procedure TTestMVVMCommandBinding.TearDown;
begin
  FreeAndNil(FHost);
  FreeAndNil(FLooseButton);
  FOriginalClickCount := 0;
end;

{ 宿主窗体销毁 ⇒ 绑定必须随之释放并从命令退订（工单：绑定由宿主持有，销毁时统一注销）。 }
procedure TTestMVVMCommandBinding.Test_Host_Destroy_Detaches_Binding_From_Command;
var
  Command: TObservedCommand;
  AsCommand: ICommand;
  Button: TButton;
begin
  Command := TObservedCommand.Create;
  AsCommand := Command;
  FHost := NewHost;
  Button := TButton.Create(FHost);
  FHost.BindCommand(Button, AsCommand, TValue.Empty);
  Assert.AreEqual(1, Command.HandlerCount, 'BindCommand must leave exactly one subscriber on the command');

  FreeAndNil(FHost);

  Assert.AreEqual(0, Command.HandlerCount,
    'B2-14: no button-binding subscriber may survive host destruction');
  Command.RaiseCanExecuteChanged;
  Assert.AreEqual(0, Command.HandlerCount, 'subscription face must stay empty after the command is raised');
end;

{ 工单点名判据：反复创建销毁窗体后触发命令不再 AV。异常收住并带轮次报出，进程不崩也算红。 }
procedure TTestMVVMCommandBinding.Test_Repeated_Create_Destroy_Loop_Trigger_Stays_Safe;
var
  Command: TObservedCommand;
  AsCommand: ICommand;
  Host: TResourcelessMVVMForm;
  i: Integer;
  Failure: string;
begin
  Command := TObservedCommand.Create;
  AsCommand := Command;
  Failure := '';
  for i := 1 to ROUNDS do
  begin
    try
      Host := NewHost;
      try
        Host.BindCommand(TButton.Create(Host), AsCommand, TValue.Empty);
      finally
        Host.Free;
      end;
      Command.RaiseCanExecuteChanged;
      if Command.HandlerCount <> 0 then
        Failure := Failure + Format(' round=%d subscribers=%d;', [i, Command.HandlerCount]);
    except
      on E: Exception do
        Failure := Failure + Format(' round=%d raised %s: %s;', [i, E.ClassName, E.Message]);
    end;
    if Failure <> '' then
      Break;
  end;
  Assert.AreEqual('', Failure,
    Format('B2-14: create/destroy loop of %d rounds raised or kept stale subscribers (stops at first)', [ROUNDS]) + Failure);
end;

{ 按钮独立于宿主销毁（Owner 不同）：绑定不得留下解引用已释放按钮的回调。 }
procedure TTestMVVMCommandBinding.Test_Button_Destroyed_Alone_Detaches_Binding;
var
  Command: TObservedCommand;
  AsCommand: ICommand;
begin
  Command := TObservedCommand.Create;
  AsCommand := Command;
  FHost := NewHost;
  FLooseButton := TButton.Create(nil);
  FHost.BindCommand(FLooseButton, AsCommand, TValue.Empty);
  Assert.AreEqual(1, Command.HandlerCount, 'BindCommand must leave exactly one subscriber on the command');

  FreeAndNil(FLooseButton);

  Assert.AreEqual(0, Command.HandlerCount,
    'B2-14: binding must detach itself when the button dies before its host');
  Command.RaiseCanExecuteChanged;
  Assert.AreEqual(0, Command.HandlerCount, 'subscription face must stay empty after the command is raised');
end;

{ 正向语义回归 + 还原证据：绑定不改点击语义（执行命令 + 回调原有 OnClick）；宿主销毁后
  按钮的 OnClick 必须逐字节还原成绑定前那个处理器。
  为什么必须比指针而不能只靠「再点一次看行为」：绑定对象被释放时，Delphi 会把它的接口字段
  自动置空，于是残留的悬垂 OnClick 走进 HandleClick 后什么都不执行——行为上看起来「恰好正确」，
  野指针却还挂在活的按钮上（该对象内存一旦被复用就是 AV）。实测这条差异只有指针断言咬得住。
  按钮故意用无主按钮：只有它活得比宿主久，还原与否才看得见。 }
procedure TTestMVVMCommandBinding.Test_Click_Semantics_And_OnClick_Restored_On_Host_Destroy;
var
  Command: TObservedCommand;
  AsCommand: ICommand;
  Before, After: TNotifyEvent;
begin
  Command := TObservedCommand.Create;
  AsCommand := Command;
  FHost := NewHost;
  FLooseButton := TButton.Create(nil);
  FLooseButton.OnClick := HandleOriginalClick;
  Before := FLooseButton.OnClick;
  FHost.BindCommand(FLooseButton, AsCommand, TValue.Empty);

  FLooseButton.Click;
  Assert.AreEqual(1, Command.ExecuteCount, 'click must execute the command once');
  Assert.AreEqual(1, FOriginalClickCount, 'binding must keep and chain the button original OnClick');

  FreeAndNil(FHost);

  After := FLooseButton.OnClick;
  Assert.AreEqual(NativeInt(TMethod(Before).Code), NativeInt(TMethod(After).Code),
    'B2-14: OnClick code pointer must be restored to the pre-binding handler');
  Assert.AreEqual(NativeInt(TMethod(Before).Data), NativeInt(TMethod(After).Data),
    'B2-14: OnClick data pointer must be restored to the pre-binding handler');

  FOriginalClickCount := 0;
  FLooseButton.Click;
  Assert.AreEqual(1, Command.ExecuteCount, 'button must not execute the command after its host is gone');
  Assert.AreEqual(1, FOriginalClickCount, 'original OnClick must be live again after host destruction');
end;

{ Enabled 同步的两条线：绑定时的初值、命令通知时的刷新，都由这一条用例钉住。 }
procedure TTestMVVMCommandBinding.Test_Enabled_State_Follows_Command;
var
  CanRun: Boolean;
  Command: ICommand;
  Button: TButton;
begin
  CanRun := False;
  Command := TRelayCommand.Create(
    procedure
    begin
    end,
    function: Boolean
    begin
      Result := CanRun
    end);
  FHost := NewHost;
  Button := TButton.Create(FHost);
  Button.Enabled := True;

  FHost.BindCommand(Button, Command, TValue.Empty);
  Assert.IsFalse(Button.Enabled, 'Enabled must follow the CanExecute initial value after BindCommand');

  CanRun := True;
  Command.RaiseCanExecuteChanged;
  Assert.IsTrue(Button.Enabled, 'RaiseCanExecuteChanged must drive button Enabled');

  CanRun := False;
  Command.RaiseCanExecuteChanged;
  Assert.IsFalse(Button.Enabled, 'Enabled must go back to False when CanExecute turns False');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestMVVMCommandBinding);

end.
