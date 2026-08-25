unit DBClient;

// COMPILE-ONLY STUB (D:\Temp\opencode, NOT part of DeepBase).
// Unlocks dcc64 verification for doQry units where the RAD Studio install
// lacks the real DBClient.dcu (MIDAS not installed).

interface

uses
  System.Classes, Data.DB;

type
  TClientDataSet = class(TDataSet)
  public
    procedure CreateDataSet; reintroduce;
    function RecordCount: Integer; reintroduce;
  end;

implementation

procedure TClientDataSet.CreateDataSet;
begin
  // stub: no-op
end;

function TClientDataSet.RecordCount: Integer;
begin
  Result := 0;
end;

end.
