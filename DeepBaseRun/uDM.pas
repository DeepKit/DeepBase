unit uDM;

interface

uses
  System.SysUtils, System.Classes,
  FireDAC.Comp.Client, FireDAC.Comp.UI,
  FireDAC.VCLUI.Wait,
  DeepBase.Exceptions;

type
  TDM = class(TDataModule)
    FDConnection: TFDConnection;
    procedure DataModuleCreate(Sender: TObject);
  private
    { Private declarations }
    procedure InitializeDatabase;
  public
    { Public declarations }
    function GetConnection: TFDConnection;
  end;

var
  DM: TDM;

implementation

{%CLASSGROUP 'FMX.Controls.TControl'}

{$R *.dfm}

procedure TDM.DataModuleCreate(Sender: TObject);
begin
  InitializeDatabase;
end;

procedure TDM.InitializeDatabase;
var
  ConfigDBPath: string;
begin
  try
    ConfigDBPath := GetCurrentDir + '\config.db';
    
    FDConnection.Params.Clear;
    FDConnection.Params.Add('DriverID=SQLite');
    FDConnection.Params.Add('Database=' + ConfigDBPath);
    FDConnection.Connected := True;
  except
    on E: Exception do
      raise EDatabaseException.Create('Failed to initialize database: ' + E.Message);
  end;
end;

function TDM.GetConnection: TFDConnection;
begin
  Result := FDConnection;
end;

end.
