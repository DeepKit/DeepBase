unit Studio.ConfigFrame;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  System.UITypes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.Grids, Vcl.ValEdit,
  Vcl.StdCtrls, Vcl.ExtCtrls,
  FireDAC.Stan.Param,
  FireDAC.Comp.Client;

type
  TfraConfig = class(TFrame)
    pnlToolbar: TPanel;
    vleConfig: TValueListEditor;
    btnRefresh: TButton;
    btnAdd: TButton;
    btnDelete: TButton;
    procedure btnRefreshClick(Sender: TObject);
    procedure btnDeleteClick(Sender: TObject);
    procedure btnAddClick(Sender: TObject);
    procedure vleConfigStringsChange(Sender: TObject);
  private
    FConnection: TFDConnection;
    procedure LoadConfig;
  public
    procedure SetConnection(AConnection: TFDConnection);
    procedure RefreshData;
  published
    // For design-time access
    property btnAddPublished: TButton read btnAdd;
  end;

implementation

{$R *.dfm}

procedure TfraConfig.SetConnection(AConnection: TFDConnection);
begin
  FConnection := AConnection;
end;

procedure TfraConfig.RefreshData;
begin
  LoadConfig;
end;

procedure TfraConfig.LoadConfig;
var
  Query: TFDQuery;
begin
  vleConfig.Strings.Clear;
  if FConnection = nil then Exit;
  if not FConnection.Connected then Exit;
  
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'SELECT Key, Value FROM Settings ORDER BY Key';
    Query.Open;
    
    while not Query.Eof do
    begin
      vleConfig.InsertRow(
        Query.FieldByName('Key').AsString,
        Query.FieldByName('Value').AsString,
        True
      );
      Query.Next;
    end;
  finally
    Query.Free;
  end;
end;

procedure TfraConfig.btnRefreshClick(Sender: TObject);
begin
  LoadConfig;
end;

procedure TfraConfig.btnAddClick(Sender: TObject);
var
  Key, Value: string;
  Query: TFDQuery;
begin
  if FConnection = nil then
  begin
    ShowMessage('No database connection');
    Exit;
  end;
  if not FConnection.Connected then
  begin
    ShowMessage('Database not connected');
    Exit;
  end;
  
  Key := InputBox('Add Config', 'Enter Key:', '');
  if Key = '' then
    Exit;
  
  Value := InputBox('Add Config', 'Enter Value:', '');
  if Value = '' then
    Exit;
  
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'INSERT OR REPLACE INTO Settings (Key, Value) VALUES (:Key, :Value)';
    Query.ParamByName('Key').AsString := Key;
    Query.ParamByName('Value').AsString := Value;
    try
      Query.ExecSQL;
      ShowMessage('Config added successfully');
      LoadConfig;
    except
      on E: Exception do
        ShowMessage('Error: ' + E.Message);
    end;
  finally
    Query.Free;
  end;
end;

procedure TfraConfig.btnDeleteClick(Sender: TObject);
var
  Key: string;
  Row: Integer;
  Query: TFDQuery;
begin
  if FConnection = nil then Exit;
  if not FConnection.Connected then Exit;
  
  Row := vleConfig.Row;
  if Row <= 0 then Exit;
  
  Key := vleConfig.Keys[Row];
  if MessageDlg('Delete config "' + Key + '"?', mtConfirmation, [mbYes, mbNo], 0) = mrYes then
  begin
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := FConnection;
      Query.SQL.Text := 'DELETE FROM Settings WHERE Key = :Key';
      Query.ParamByName('Key').AsString := Key;
      Query.ExecSQL;
      LoadConfig;
    finally
      Query.Free;
    end;
  end;
end;

procedure TfraConfig.vleConfigStringsChange(Sender: TObject);
begin
  // This event fires on every keystroke in the editor
  // TValueListEditor doesn't have a good cell edit complete event
  // Users should manually click Refresh or use Add/Delete buttons
end;

end.
