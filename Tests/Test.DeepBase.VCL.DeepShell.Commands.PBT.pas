{ ============================================================================
  Test.DeepBase.VCL.DeepShell.Commands.PBT - Property tests for menu state
  refresh signalling.

  Properties covered:
    P21: Command State Change Event (Req 15.1)
         Every UpdateCommandState call MUST publish a sekCommandStateChanged
         event on the EventBus with the command id in the Data field.

    P22: Menu Item Reflects State (Req 15.2)
         A subscriber to sekCommandStateChanged MUST be able to look up the
         command by id and observe the new Enabled / Visible values.

  P22 is a contract-level test: it exercises the full publish-then-lookup
  path that TDeepMainForm runs on the main thread without instantiating
  the full VCL form. The test verifies (a) the subscriber receives every
  state-change event in the right order, and (b) TryGetCommand returns
  the freshly applied state.

  Each property test runs >= 100 random iterations.
  ============================================================================ }

unit Test.DeepBase.VCL.DeepShell.Commands.PBT;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.SyncObjs,
  DUnitX.TestFramework,
  DeepBase.VCL.DeepShell.Types,
  DeepBase.VCL.DeepShell.Intf,
  DeepBase.VCL.DeepShell.Events,
  DeepBase.VCL.DeepShell.Commands;

type
  [TestFixture]
  TCommandStatePropertyTests = class
  strict private
    function MakeRandomCommand(out AId: string): TShellCommand;
  public
    [Setup]
    procedure Setup;

    // Feature: deepbase-bug-fixes-p0p1p2, Property 21
    [Test]
    procedure Property21_UpdateCommandStatePublishesEvent;

    // Feature: deepbase-bug-fixes-p0p1p2, Property 22
    [Test]
    procedure Property22_MenuItemReflectsStateOnEvent;
  end;

implementation

{ TCommandStatePropertyTests }

procedure TCommandStatePropertyTests.Setup;
begin
  Randomize;
end;

function TCommandStatePropertyTests.MakeRandomCommand(out AId: string): TShellCommand;
begin
  AId := 'cmd-' + IntToStr(Random(MaxInt));
  Result := TShellCommand.Make(AId, 'Caption ' + AId);
  Result.Enabled := True;
  Result.Visible := True;
end;

// Feature: deepbase-bug-fixes-p0p1p2, Property 21: Every UpdateCommandState
// call publishes a sekCommandStateChanged event whose Data field carries
// the command id. The event is published exactly once per call.
procedure TCommandStatePropertyTests.Property21_UpdateCommandStatePublishesEvent;
var
  LBus: IShellEventBus;
  LMgr: TShellCommandManager;
  LReceivedIds: TList<string>;
  LToken: string;
begin
  LBus := TShellEventBus.Create;
  LMgr := TShellCommandManager.Create(LBus,
    function: TShellContext
    begin
      Result := Default(TShellContext);
    end);
  LReceivedIds := TList<string>.Create;
  try
    LToken := LBus.Subscribe(sekCommandStateChanged,
      procedure(const AEvent: TDeepShellEvent)
      begin
        LReceivedIds.Add(AEvent.Data);
      end);

    for var Iter := 1 to 100 do
    begin
      var LId: string;
      var LCmd := MakeRandomCommand(LId);
      LMgr.RegisterCommand(LCmd);

      var LBefore := LReceivedIds.Count;
      var LEnabled := Random(2) = 0;
      var LVisible := Random(2) = 0;
      LMgr.UpdateCommandState(LId, LEnabled, LVisible);

      Assert.AreEqual(LBefore + 1, LReceivedIds.Count,
        Format('Iter %d: UpdateCommandState must publish exactly one event',
          [Iter]));
      Assert.AreEqual(LId,
        LReceivedIds[LReceivedIds.Count - 1],
        Format('Iter %d: event Data must carry the command id', [Iter]));
    end;
  finally
    if LToken <> '' then
      LBus.Unsubscribe(LToken);
    LReceivedIds.Free;
    LMgr.Free;
    LBus := nil;
  end;
end;

// Feature: deepbase-bug-fixes-p0p1p2, Property 22: Within the same
// main-thread cycle, after a sekCommandStateChanged event, the
// command's TryGetCommand lookup MUST return the freshly applied
// Enabled/Visible state. This is the contract every menu-refresh
// subscriber relies on.
procedure TCommandStatePropertyTests.Property22_MenuItemReflectsStateOnEvent;
var
  LBus: IShellEventBus;
  LMgr: TShellCommandManager;
  LMatchCount: Integer;
  LMismatchDetails: string;
  LToken: string;
begin
  LBus := TShellEventBus.Create;
  LMgr := TShellCommandManager.Create(LBus,
    function: TShellContext
    begin
      Result := Default(TShellContext);
    end);
  LMatchCount := 0;
  LMismatchDetails := '';

  // Pre-register all commands and remember the desired state so the
  // subscriber callback can verify the lookup matches.
  var LExpected := TDictionary<string, TPair<Boolean, Boolean>>.Create;
  try
    LToken := LBus.Subscribe(sekCommandStateChanged,
      procedure(const AEvent: TDeepShellEvent)
      var
        LCmd: TShellCommand;
        LWant: TPair<Boolean, Boolean>;
      begin
        if not LExpected.TryGetValue(AEvent.Data, LWant) then
          Exit;
        if not LMgr.TryGetCommand(AEvent.Data, LCmd) then
        begin
          LMismatchDetails := 'TryGetCommand failed for ' + AEvent.Data;
          Exit;
        end;
        if (LCmd.Enabled = LWant.Key) and (LCmd.Visible = LWant.Value) then
          Inc(LMatchCount)
        else
          LMismatchDetails := Format(
            'cmd=%s want(enabled=%s,visible=%s) got(enabled=%s,visible=%s)',
            [AEvent.Data, BoolToStr(LWant.Key, True),
             BoolToStr(LWant.Value, True),
             BoolToStr(LCmd.Enabled, True),
             BoolToStr(LCmd.Visible, True)]);
      end);

    for var Iter := 1 to 100 do
    begin
      var LId: string;
      var LCmd := MakeRandomCommand(LId);
      LMgr.RegisterCommand(LCmd);

      var LEnabled := Random(2) = 0;
      var LVisible := Random(2) = 0;
      LExpected.AddOrSetValue(LId,
        TPair<Boolean, Boolean>.Create(LEnabled, LVisible));

      LMgr.UpdateCommandState(LId, LEnabled, LVisible);
    end;

    Assert.AreEqual(100, LMatchCount,
      'Subscriber observed mismatched state. Last detail: ' +
      LMismatchDetails);
  finally
    LExpected.Free;
    if LToken <> '' then
      LBus.Unsubscribe(LToken);
    LMgr.Free;
    LBus := nil;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TCommandStatePropertyTests);

end.
