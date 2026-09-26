program B2Seg0Probe;
{$APPTYPE CONSOLE}
{ B2 seg-0 forensic probe (evidence input, not part of any build face).
  Answers two questions by measurement instead of by hearsay:
    P1 can TryGetValue<string> read back a TJSONBool value? (B2-01 literal claim)
    P2 does a second Enter on TCriticalSection from the same thread block? (B2-11 lock premise)
  Uses RTL only, so it never touches Features/ or Tests/. }
uses
  System.SysUtils, System.SyncObjs, System.JSON, Winapi.Windows;

procedure ProbeJSONBool;
var
  Fld, Outer: TJSONObject;
  S: string;
  B: Boolean;
  V: TJSONValue;
begin
  WriteLn('== P1 JSON boolean round trip ==');
  Outer := TJSONObject.Create;
  try
    Fld := TJSONObject.Create;
    Fld.AddPair('booleanValue', TJSONBool.Create(True));
    Outer.AddPair('is_active', Fld);
    WriteLn('serialized       : ', Outer.ToJSON);
    WriteLn('TryGetValue<string> = ', Fld.TryGetValue<string>('booleanValue', S), ' / value=[', S, ']');
    WriteLn('SameText(value,''true'') = ', SameText(S, 'true'));
    WriteLn('TryGetValue<Boolean> = ', Fld.TryGetValue<Boolean>('booleanValue', B), ' / value=', B);
    if Fld.TryGetValue('booleanValue', V) then
      WriteLn('runtime class    : ', V.ClassName);
  finally
    Outer.Free;
  end;
end;

procedure ProbeRecursiveLock;
var
  L: TCriticalSection;
begin
  WriteLn('== P2 TCriticalSection re-entrancy ==');
  L := TCriticalSection.Create;
  try
    L.Enter;
    try
      WriteLn('first Enter  : ok');
      L.Enter;
      try
        WriteLn('second Enter : returned without blocking');
      finally
        L.Leave;
      end;
    finally
      L.Leave;
    end;
    WriteLn('CONCLUSION: same-thread re-entrant = True (no deadlock on this primitive)');
  finally
    L.Free;
  end;
end;

begin
  try
    ProbeJSONBool;
    ProbeRecursiveLock;
  except
    on E: Exception do
      WriteLn('PROBE-EXCEPTION ', E.ClassName, ': ', E.Message);
  end;
end.
