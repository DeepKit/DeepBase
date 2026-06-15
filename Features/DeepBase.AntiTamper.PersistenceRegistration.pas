{ ============================================================================
  DeepBase.AntiTamper.PersistenceRegistration

  Wires the feature-level anti-tamper API to the Persistence storage adapter
  without exposing FireDAC types to Features or UI units.
  ============================================================================ }

unit DeepBase.AntiTamper.PersistenceRegistration;

interface

procedure RegisterAntiTamperPersistence;

implementation

uses
  DeepBase.AntiTamper,
  DeepBase.Persistence.Protection.FireDAC,
  DeepBase.Storage.Interfaces;

procedure RegisterAntiTamperPersistence;
begin
  TAntiTamperPackage.SetImageStorageFactory(
    function(const DatabasePath: string): IAntiTamperImageStorage
    begin
      Result := CreateAntiTamperImageStorage(DatabasePath);
    end);
end;

initialization
  RegisterAntiTamperPersistence;

end.
