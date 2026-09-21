unit R7P4ProbeUnit;

{ R7-P4 (A18) end-to-end BPL fixture: minimal package exporting one stdcall
  function. Built with the repo dcc64 (CLI builds .bpl fine; R2-DEFERRED
  premise does not hold on this toolchain). }

interface

function ProbeAdd(A, B: Integer): Integer; stdcall;

exports
  ProbeAdd;

implementation

function ProbeAdd(A, B: Integer): Integer; stdcall;
begin
  Result := A + B;
end;

end.
