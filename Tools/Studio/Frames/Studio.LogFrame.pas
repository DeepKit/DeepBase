{ ============================================================================
  Studio.LogFrame - Enhanced Log Viewer
  
  Version: 1.1
  Features:
    - Level filtering (All/DEBUG/INFO/WARN/ERROR/FATAL)
    - Text search in Message and Source
    - Export to CSV
    - Auto-refresh timer
    - Status bar with statistics
  ============================================================================ }

unit Studio.LogFrame;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  System.UITypes,
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
    btnExport: TButton;
    lblLevel: TLabel;
    lblSearch: TLabel;
    cmbLevel: TComboBox;
    edtSearch: TEdit;
    chkAutoRefresh: TCheckBox;
    tmrAutoRefresh: TTimer;
    StatusBar: TStatusBar;
    dlgSave: TSaveDialog;
    procedure btnRefreshClick(Sender: TObject);
    procedure btnClearClick(Sender: TObject);
    procedure btnExportClick(Sender: TObject);
    procedure cmbLevelChange(Sender: TObject);
    procedure edtSearchChange(Sender: TObject);
    procedure chkAutoRefreshClick(Sender: TObject);
    procedure tmrAutoRefreshTimer(Sender: TObject);
    procedure lvLogsDblClick(Sender: TObject);
  private
    FConnection: TFDConnection;
    FTotalCount: Integer;
    FFilteredCount: Integer;
    procedure LoadLogs;
    procedure UpdateStatusBar;
    function GetLevelFilter: string;
    function GetSearchFilter: string;
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

function TfraLog.GetLevelFilter: string;
begin
  if (cmbLevel <> nil) and (cmbLevel.ItemIndex > 0) then
    Result := cmbLevel.Text
  else
    Result := '';
end;

function TfraLog.GetSearchFilter: string;
begin
  if edtSearch <> nil then
    Result := Trim(edtSearch.Text)
  else
    Result := '';
end;

procedure TfraLog.LoadLogs;
var
  Query: TFDQuery;
  Item: TListItem;
  SQL: string;
  LevelFilter, SearchFilter: string;
  WhereClause: string;
begin
  if lvLogs = nil then Exit;
  lvLogs.Items.BeginUpdate;
  try
    lvLogs.Items.Clear;
    FFilteredCount := 0;
    FTotalCount := 0;
    
    if (FConnection = nil) or (not FConnection.Connected) then
    begin
      UpdateStatusBar;
      Exit;
    end;
    
    LevelFilter := GetLevelFilter;
    SearchFilter := GetSearchFilter;
    
    // Build WHERE clause
    WhereClause := '';
    if LevelFilter <> '' then
    begin
      if LevelFilter = 'WARN' then
        WhereClause := 'LogLevel IN (''WARN'', ''WARNING'')'
      else
        WhereClause := 'LogLevel = ''' + LevelFilter + '''';
    end;
    
    if SearchFilter <> '' then
    begin
      if WhereClause <> '' then
        WhereClause := WhereClause + ' AND ';
      WhereClause := WhereClause + 
        '(Message LIKE ''%' + SearchFilter + '%'' OR Source LIKE ''%' + SearchFilter + '%'')';
    end;
    
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := FConnection;
      
      // Get total count
      Query.SQL.Text := 'SELECT COUNT(*) FROM Logs';
      try
        Query.Open;
        FTotalCount := Query.Fields[0].AsInteger;
        Query.Close;
      except
        FTotalCount := 0;
      end;
      
      // Build main query
      SQL := 'SELECT LogTime, LogLevel, Source, Message, ThreadId FROM Logs';
      if WhereClause <> '' then
        SQL := SQL + ' WHERE ' + WhereClause;
      SQL := SQL + ' ORDER BY Id DESC LIMIT 1000';
      
      Query.SQL.Text := SQL;
      try
        Query.Open;
        
        while not Query.Eof do
        begin
          Item := lvLogs.Items.Add;
          Item.Caption := Query.FieldByName('LogTime').AsString;
          Item.SubItems.Add(Query.FieldByName('LogLevel').AsString);
          Item.SubItems.Add(Query.FieldByName('Source').AsString);
          Item.SubItems.Add(Query.FieldByName('Message').AsString);
          Item.Data := Pointer(Query.FieldByName('ThreadId').AsInteger);
          Inc(FFilteredCount);
          Query.Next;
        end;
      except
        // Table may not exist
      end;
    finally
      Query.Free;
    end;
  finally
    lvLogs.Items.EndUpdate;
  end;
  
  UpdateStatusBar;
end;

procedure TfraLog.UpdateStatusBar;
begin
  if StatusBar = nil then Exit;
  
  StatusBar.Panels[0].Text := Format('Showing: %d', [FFilteredCount]);
  StatusBar.Panels[1].Text := Format('Total: %d logs', [FTotalCount]);
  if chkAutoRefresh.Checked then
    StatusBar.Panels[2].Text := 'Auto'
  else
    StatusBar.Panels[2].Text := '';
end;

procedure TfraLog.btnRefreshClick(Sender: TObject);
begin
  LoadLogs;
end;

procedure TfraLog.cmbLevelChange(Sender: TObject);
begin
  LoadLogs;
end;

procedure TfraLog.edtSearchChange(Sender: TObject);
begin
  // Delay search to avoid too many queries
  // For simplicity, search on each change
  LoadLogs;
end;

procedure TfraLog.chkAutoRefreshClick(Sender: TObject);
begin
  tmrAutoRefresh.Enabled := chkAutoRefresh.Checked;
  UpdateStatusBar;
end;

procedure TfraLog.tmrAutoRefreshTimer(Sender: TObject);
begin
  LoadLogs;
end;

procedure TfraLog.lvLogsDblClick(Sender: TObject);
var
  Item: TListItem;
  Msg: string;
begin
  Item := lvLogs.Selected;
  if Item = nil then Exit;
  
  Msg := Format('Time: %s' + #13#10 +
                'Level: %s' + #13#10 +
                'Source: %s' + #13#10 +
                'Thread: %d' + #13#10#13#10 +
                'Message:' + #13#10 + '%s',
    [Item.Caption, 
     Item.SubItems[0], 
     Item.SubItems[1], 
     NativeInt(Item.Data),
     Item.SubItems[2]]);
  
  ShowMessage(Msg);
end;

procedure TfraLog.btnExportClick(Sender: TObject);
var
  SL: TStringList;
  I: Integer;
  Item: TListItem;
begin
  if lvLogs.Items.Count = 0 then
  begin
    ShowMessage('No logs to export');
    Exit;
  end;
  
  if not dlgSave.Execute then Exit;
  
  SL := TStringList.Create;
  try
    // Header
    SL.Add('"Time","Level","Source","Message"');
    
    // Data
    for I := 0 to lvLogs.Items.Count - 1 do
    begin
      Item := lvLogs.Items[I];
      SL.Add(Format('"%s","%s","%s","%s"',
        [Item.Caption,
         Item.SubItems[0],
         Item.SubItems[1],
         StringReplace(Item.SubItems[2], '"', '""', [rfReplaceAll])]));
    end;
    
    SL.SaveToFile(dlgSave.FileName, TEncoding.UTF8);
    ShowMessage(Format('Exported %d logs to %s', [lvLogs.Items.Count, dlgSave.FileName]));
  finally
    SL.Free;
  end;
end;

procedure TfraLog.btnClearClick(Sender: TObject);
var
  Query: TFDQuery;
begin
  if (FConnection = nil) or (not FConnection.Connected) then Exit;
  
  if MessageDlg('Clear all logs? This cannot be undone.', mtConfirmation, [mbYes, mbNo], 0) = mrYes then
  begin
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := FConnection;
      Query.SQL.Text := 'DELETE FROM Logs';
      try
        Query.ExecSQL;
        LoadLogs;
      except
        on E: Exception do
          ShowMessage('Error clearing logs: ' + E.Message);
      end;
    finally
      Query.Free;
    end;
  end;
end;

end.
