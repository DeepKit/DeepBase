unit Entity.Base;

{*******************************************************************************
  Document Manager Template - Entity base contract

  Exists because the three template entities declare "constructor Create; override"
  and "function Validate: Boolean; override", which require a virtual anchor in an
  ancestor. ORM mapping attributes themselves come from DeepBase.ORM.Mapping (SSOT).
*******************************************************************************}

interface

type
  TEntityBase = class
  public
    constructor Create; virtual;

    /// <summary>An entity without extra rules is valid by default.</summary>
    function Validate: Boolean; virtual;
  end;

implementation

{ TEntityBase }

constructor TEntityBase.Create;
begin
  inherited Create;
end;

function TEntityBase.Validate: Boolean;
begin
  Result := True;
end;

end.
