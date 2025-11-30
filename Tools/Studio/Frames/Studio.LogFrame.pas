unit Studio.LogFrame;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ComCtrls, Vcl.ExtCtrls,
  Vcl.StdCtrls,
  FireDAC.Comp.Client;

type
  TfraLog = class(TFrame)
    pnlLog: TPanel;
    lvLogs: TListView;
    pnlToolbar: TPanel;
    btnRefresh: TButton;
    btnClear: TButton;
    procedure btnRefreshClick(Sender: TObject);
    procedure btnClearClick(Sender: TObject);
  private
    FConnection: TFDConnection;
    procedure LoadLogs;
  public
    procedure SetConnection(AConnection: TFDConnection);
    procedure RefreshData;
  end;

implementation

{$R *.dfm}

procedure TfraLog.SetConnection(AConnection: TFDConnection);
begin
  FConnection := AConnection;
end;

procedure TfraLog.RefreshData;
begin
  LoadLogs;
end;

procedure TfraLog.LoadLogs;
var
  Query: TFDQuery;
  Item: TListItem;
begin
  if lvLogs = nil then Exit;
  lvLogs.Items.Clear;
  
  if (FConnection = nil) or (not FConnection.Connected) then Exit;
  
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 
      'SELECT LogTime, LogLevel, Source, Message, ThreadId ' +
      'FROM Logs ORDER BY Id DESC LIMIT 500';
    try
      Query.Open;
      
      while not Query.Eof do
      begin
        Item := lvLogs.Items.Add;
        Item.Caption := Query.FieldByName('LogTime').AsString;
        Item.SubItems.Add(Query.FieldByName('LogLevel').AsString);
        Item.SubItems.Add(Query.FieldByName('Source').AsString);
        Item.SubItems.Add(Query.FieldByName('Message').AsString);
        Query.Next;
      end;
    except
      // Table may not exist
    end;
  finally
    Query.Free;
  end;
end;

procedure TfraLog.btnRefreshClick(Sender: TObject);
begin
  LoadLogs;
end;

procedure TfraLog.btnClearClick(Sender: TObject);
var
  Query: TFDQuery;
begin
  if (FConnection = nil) or (not FConnection.Connected) then Exit;
  
  if MessageDlg('Clear all logs?', mtConfirmation, [mbYes, mbNo], 0) = mrYes then
  begin
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := FConnection;
      Query.SQL.Text := 'DELETE FROM Logs';
      try
        Query.ExecSQL;
        LoadLogs;
      except
        // Ignore
      end;
    finally
      Query.Free;
    end;
  end;
end;

end.
