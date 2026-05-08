{ ============================================================================
  Studio.QueriesFrame - DoQry Queries Editor Frame
  
  Version: 1.0
  Description: Visual editor for the Queries table in config.db.
               Allows creating, editing, deleting and testing query templates.
  ============================================================================ }

unit Studio.QueriesFrame;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.ComCtrls,
  Vcl.Grids,
  Data.DB,
  FireDAC.Comp.Client;

type
  TfraQueries = class(TFrame)
  private
    FConnection: TFDConnection;

    // Layout controls
    FMainPanel: TPanel;
    FLeftPanel: TPanel;
    FRightPanel: TPanel;
    FSplitter: TSplitter;

    // Left: list of queries
    lblListTitle: TLabel;
    lvQueries: TListView;
    pnlLeftToolbar: TPanel;
    btnNew: TButton;
    btnSave: TButton;
    btnDelete: TButton;
    btnRefresh: TButton;

    // Right: editor
    pnlEditorTop: TPanel;
    lblProcName: TLabel;
    edtProcName: TEdit;
    lblCategory: TLabel;
    edtCategory: TEdit;
    lblDescription: TLabel;
    edtDescription: TEdit;
    lblTimeout: TLabel;
    edtTimeout: TEdit;
    chkEnabled: TCheckBox;

    splRight: TSplitter;
    pnlSql: TPanel;
    lblSQL: TLabel;
    mmoSQL: TMemo;
    pnlParams: TPanel;
    lblParams: TLabel;
    mmoParamSchema: TMemo;

    pnlStatus: TPanel;
    lblStatus: TLabel;

    FLoading: Boolean;

    procedure InitLayout;
    procedure SetStatus(const AText: string; AIsError: Boolean = False);
    procedure LoadQueries;
    procedure LoadQueryItem(AItem: TListItem);
    procedure ClearEditor;
    procedure ApplyToEditor(const AProcName: string);
    procedure SaveCurrent;
    procedure DeleteCurrent;

    // Event handlers
    procedure lvQueriesClick(Sender: TObject);
    procedure btnNewClick(Sender: TObject);
    procedure btnSaveClick(Sender: TObject);
    procedure btnDeleteClick(Sender: TObject);
    procedure btnRefreshClick(Sender: TObject);

  public
    constructor Create(AOwner: TComponent); override;

    procedure SetConnection(AConnection: TFDConnection);
    procedure RefreshData;
  end;

implementation

{$R *.dfm}

{ TfraQueries }

constructor TfraQueries.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  InitLayout;
  SetStatus('Ready - Open a DeepBase config.db to manage Queries');
end;

procedure TfraQueries.InitLayout;
begin
  FLoading := False;

  // Main panel
  FMainPanel := TPanel.Create(Self);
  FMainPanel.Parent := Self;
  FMainPanel.Align := alClient;
  FMainPanel.BevelOuter := bvNone;

  // Left panel
  FLeftPanel := TPanel.Create(Self);
  FLeftPanel.Parent := FMainPanel;
  FLeftPanel.Align := alLeft;
  FLeftPanel.Width := 260;
  FLeftPanel.BevelOuter := bvNone;

  // Splitter
  FSplitter := TSplitter.Create(Self);
  FSplitter.Parent := FMainPanel;
  FSplitter.Left := FLeftPanel.Width;
  FSplitter.Width := 5;

  // Right panel
  FRightPanel := TPanel.Create(Self);
  FRightPanel.Parent := FMainPanel;
  FRightPanel.Align := alClient;
  FRightPanel.BevelOuter := bvNone;

  // Left toolbar
  pnlLeftToolbar := TPanel.Create(Self);
  pnlLeftToolbar.Parent := FLeftPanel;
  pnlLeftToolbar.Align := alTop;
  pnlLeftToolbar.Height := 36;
  pnlLeftToolbar.BevelOuter := bvNone;

  btnNew := TButton.Create(Self);
  btnNew.Parent := pnlLeftToolbar;
  btnNew.SetBounds(4, 6, 50, 24);
  btnNew.Caption := 'New';
  btnNew.OnClick := btnNewClick;

  btnSave := TButton.Create(Self);
  btnSave.Parent := pnlLeftToolbar;
  btnSave.SetBounds(60, 6, 50, 24);
  btnSave.Caption := 'Save';
  btnSave.OnClick := btnSaveClick;

  btnDelete := TButton.Create(Self);
  btnDelete.Parent := pnlLeftToolbar;
  btnDelete.SetBounds(116, 6, 50, 24);
  btnDelete.Caption := 'Del';
  btnDelete.OnClick := btnDeleteClick;

  btnRefresh := TButton.Create(Self);
  btnRefresh.Parent := pnlLeftToolbar;
  btnRefresh.SetBounds(172, 6, 60, 24);
  btnRefresh.Caption := 'Refresh';
  btnRefresh.OnClick := btnRefreshClick;

  // Left list
  lblListTitle := TLabel.Create(Self);
  lblListTitle.Parent := FLeftPanel;
  lblListTitle.Align := alTop;
  lblListTitle.Caption := 'Queries (ProcName)';
  lblListTitle.Layout := tlCenter;
  lblListTitle.Height := 18;

  lvQueries := TListView.Create(Self);
  lvQueries.Parent := FLeftPanel;
  lvQueries.Align := alClient;
  lvQueries.ViewStyle := vsReport;
  lvQueries.RowSelect := True;
  lvQueries.ReadOnly := True;
  lvQueries.HideSelection := False;
  lvQueries.OnClick := lvQueriesClick;

  with lvQueries.Columns.Add do
  begin
    Caption := 'ProcName';
    Width := 130;
  end;
  with lvQueries.Columns.Add do
  begin
    Caption := 'Category';
    Width := 80;
  end;
  with lvQueries.Columns.Add do
  begin
    Caption := 'Timeout';
    Width := 60;
  end;
  with lvQueries.Columns.Add do
  begin
    Caption := 'Enabled';
    Width := 55;
  end;

  // Right editor top
  pnlEditorTop := TPanel.Create(Self);
  pnlEditorTop.Parent := FRightPanel;
  pnlEditorTop.Align := alTop;
  pnlEditorTop.Height := 80;
  pnlEditorTop.BevelOuter := bvNone;

  lblProcName := TLabel.Create(Self);
  lblProcName.Parent := pnlEditorTop;
  lblProcName.SetBounds(8, 8, 60, 16);
  lblProcName.Caption := 'ProcName:';

  edtProcName := TEdit.Create(Self);
  edtProcName.Parent := pnlEditorTop;
  edtProcName.SetBounds(80, 4, 200, 24);

  lblCategory := TLabel.Create(Self);
  lblCategory.Parent := pnlEditorTop;
  lblCategory.SetBounds(300, 8, 60, 16);
  lblCategory.Caption := 'Category:';

  edtCategory := TEdit.Create(Self);
  edtCategory.Parent := pnlEditorTop;
  edtCategory.SetBounds(365, 4, 160, 24);

  lblTimeout := TLabel.Create(Self);
  lblTimeout.Parent := pnlEditorTop;
  lblTimeout.SetBounds(540, 8, 60, 16);
  lblTimeout.Caption := 'Timeout:';

  edtTimeout := TEdit.Create(Self);
  edtTimeout.Parent := pnlEditorTop;
  edtTimeout.SetBounds(605, 4, 60, 24);
  edtTimeout.Text := '30';

  chkEnabled := TCheckBox.Create(Self);
  chkEnabled.Parent := pnlEditorTop;
  chkEnabled.SetBounds(680, 6, 70, 20);
  chkEnabled.Caption := 'Enabled';
  chkEnabled.Checked := True;

  lblDescription := TLabel.Create(Self);
  lblDescription.Parent := pnlEditorTop;
  lblDescription.SetBounds(8, 44, 70, 16);
  lblDescription.Caption := 'Description:';

  edtDescription := TEdit.Create(Self);
  edtDescription.Parent := pnlEditorTop;
  edtDescription.SetBounds(80, 40, 420, 24);

  // Right SQL / Params split
  splRight := TSplitter.Create(Self);
  splRight.Parent := FRightPanel;
  splRight.Align := alTop;
  splRight.Top := pnlEditorTop.Height + 200;
  splRight.Height := 5;
  splRight.Cursor := crVSplit;

  // SQL panel
  pnlSql := TPanel.Create(Self);
  pnlSql.Parent := FRightPanel;
  pnlSql.Align := alTop;
  pnlSql.Height := 200;
  pnlSql.BevelOuter := bvNone;

  lblSQL := TLabel.Create(Self);
  lblSQL.Parent := pnlSql;
  lblSQL.SetBounds(8, 4, 100, 16);
  lblSQL.Caption := 'SQL Template:';

  mmoSQL := TMemo.Create(Self);
  mmoSQL.Parent := pnlSql;
  mmoSQL.SetBounds(8, 22, 520, 170);
  mmoSQL.Align := alClient;
  mmoSQL.ScrollBars := ssBoth;
  mmoSQL.WordWrap := False;
  mmoSQL.Font.Name := 'Consolas';
  mmoSQL.Font.Size := 10;

  // Params panel
  pnlParams := TPanel.Create(Self);
  pnlParams.Parent := FRightPanel;
  pnlParams.Align := alClient;
  pnlParams.BevelOuter := bvNone;

  lblParams := TLabel.Create(Self);
  lblParams.Parent := pnlParams;
  lblParams.SetBounds(8, 4, 140, 16);
  lblParams.Caption := 'ParamSchema (JSON):';

  mmoParamSchema := TMemo.Create(Self);
  mmoParamSchema.Parent := pnlParams;
  mmoParamSchema.Align := alClient;
  mmoParamSchema.ScrollBars := ssBoth;
  mmoParamSchema.WordWrap := False;
  mmoParamSchema.Font.Name := 'Consolas';
  mmoParamSchema.Font.Size := 10;

  // Status panel
  pnlStatus := TPanel.Create(Self);
  pnlStatus.Parent := FRightPanel;
  pnlStatus.Align := alBottom;
  pnlStatus.Height := 24;
  pnlStatus.BevelOuter := bvLowered;

  lblStatus := TLabel.Create(Self);
  lblStatus.Parent := pnlStatus;
  lblStatus.Align := alClient;
  lblStatus.Alignment := taLeftJustify;
  lblStatus.Layout := tlCenter;
  lblStatus.Caption := '';
end;

procedure TfraQueries.SetConnection(AConnection: TFDConnection);
begin
  FConnection := AConnection;

  if Assigned(FConnection) and FConnection.Connected then
    SetStatus('Connected - Click Refresh to load Queries')
  else
  begin
    SetStatus('No database connection', True);
    lvQueries.Items.Clear;
    ClearEditor;
  end;
end;

procedure TfraQueries.RefreshData;
begin
  LoadQueries;
end;

procedure TfraQueries.SetStatus(const AText: string; AIsError: Boolean);
begin
  if not Assigned(lblStatus) then
    Exit;
  lblStatus.Caption := AText;
  if AIsError then
    lblStatus.Font.Color := clRed
  else
    lblStatus.Font.Color := clWindowText;
end;

procedure TfraQueries.ClearEditor;
begin
  FLoading := True;
  try
    edtProcName.Text := '';
    edtCategory.Text := '';
    edtDescription.Text := '';
    edtTimeout.Text := '30';
    chkEnabled.Checked := True;
    mmoSQL.Clear;
    mmoParamSchema.Clear;
  finally
    FLoading := False;
  end;
end;

procedure TfraQueries.LoadQueries;
var
  Q: TFDQuery;
  Item: TListItem;
begin
  lvQueries.Items.Clear;
  if (FConnection = nil) or (not FConnection.Connected) then
  begin
    SetStatus('No database connection', True);
    Exit;
  end;

  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConnection;
    Q.SQL.Text :=
      'SELECT ProcName, Category, TimeoutSec, IsEnabled ' +
      'FROM Queries ORDER BY Category, ProcName';
    try
      Q.Open;
    except
      on E: Exception do
      begin
        SetStatus('Failed to load Queries table: ' + E.Message, True);
        Exit;
      end;
    end;

    FLoading := True;
    try
      while not Q.Eof do
      begin
        Item := lvQueries.Items.Add;
        Item.Caption := Q.FieldByName('ProcName').AsString;
        Item.SubItems.Add(Q.FieldByName('Category').AsString);
        Item.SubItems.Add(Q.FieldByName('TimeoutSec').AsString);
        if Q.FieldByName('IsEnabled').AsInteger <> 0 then
          Item.SubItems.Add('Yes')
        else
          Item.SubItems.Add('No');
        Q.Next;
      end;
    finally
      FLoading := False;
    end;

    SetStatus(Format('Loaded %d Queries', [lvQueries.Items.Count]));
  finally
    Q.Free;
  end;
end;

procedure TfraQueries.LoadQueryItem(AItem: TListItem);
var
  Q: TFDQuery;
  ProcName: string;
begin
  if (AItem = nil) or (FConnection = nil) or (not FConnection.Connected) then
    Exit;

  ProcName := AItem.Caption;
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConnection;
    Q.SQL.Text := 'SELECT * FROM Queries WHERE ProcName = :ProcName';
    Q.ParamByName('ProcName').AsString := ProcName;
    Q.Open;

    if not Q.Eof then
    begin
      FLoading := True;
      try
        edtProcName.Text := Q.FieldByName('ProcName').AsString;
        edtCategory.Text := Q.FieldByName('Category').AsString;
        edtDescription.Text := Q.FieldByName('Description').AsString;
        edtTimeout.Text := Q.FieldByName('TimeoutSec').AsString;
        chkEnabled.Checked := Q.FieldByName('IsEnabled').AsInteger <> 0;
        mmoSQL.Text := Q.FieldByName('SQL').AsString;
        mmoParamSchema.Text := Q.FieldByName('ParamSchema').AsString;
      finally
        FLoading := False;
      end;
    end;
  finally
    Q.Free;
  end;
end;

procedure TfraQueries.ApplyToEditor(const AProcName: string);
var
  I: Integer;
begin
  for I := 0 to lvQueries.Items.Count - 1 do
  begin
    if SameText(lvQueries.Items[I].Caption, AProcName) then
    begin
      lvQueries.ItemIndex := I;
      LoadQueryItem(lvQueries.Items[I]);
      Exit;
    end;
  end;
end;

procedure TfraQueries.SaveCurrent;
var
  Q: TFDQuery;
  ProcName: string;
  TimeoutSec: Integer;
  IsEnabled: Integer;
  NowStr: string;
begin
  if (FConnection = nil) or (not FConnection.Connected) then
  begin
    SetStatus('No database connection', True);
    Exit;
  end;

  ProcName := Trim(edtProcName.Text);
  if ProcName = '' then
  begin
    MessageDlg('ProcName cannot be empty.', mtWarning, [mbOK], 0);
    Exit;
  end;

  TimeoutSec := StrToIntDef(Trim(edtTimeout.Text), 30);
  IsEnabled := Ord(chkEnabled.Checked);
  NowStr := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', Now);

  Q := TFDQuery.Create(nil);
  try
    try
      Q.Connection := FConnection;

      // First try UPDATE
      Q.SQL.Text :=
        'UPDATE Queries SET ' +
        '  SQL = :SQL, ' +
        '  Description = :Description, ' +
        '  Category = :Category, ' +
        '  TimeoutSec = :TimeoutSec, ' +
        '  ParamSchema = :ParamSchema, ' +
        '  IsEnabled = :IsEnabled, ' +
        '  UpdatedAt = :UpdatedAt ' +
        'WHERE ProcName = :ProcName';
      Q.ParamByName('ProcName').AsString := ProcName;
      Q.ParamByName('SQL').AsString := mmoSQL.Text;
      Q.ParamByName('Description').AsString := edtDescription.Text;
      Q.ParamByName('Category').AsString := edtCategory.Text;
      Q.ParamByName('TimeoutSec').AsInteger := TimeoutSec;
      Q.ParamByName('ParamSchema').AsString := mmoParamSchema.Text;
      Q.ParamByName('IsEnabled').AsInteger := IsEnabled;
      Q.ParamByName('UpdatedAt').AsString := NowStr;

      Q.ExecSQL;

      if Q.RowsAffected = 0 then
      begin
        // Insert new row
        Q.SQL.Text :=
          'INSERT INTO Queries ' +
          '  (ProcName, SQL, Description, Category, TimeoutSec, ParamSchema, IsEnabled, CreatedAt, UpdatedAt) ' +
          'VALUES ' +
          '  (:ProcName, :SQL, :Description, :Category, :TimeoutSec, :ParamSchema, :IsEnabled, :CreatedAt, :UpdatedAt)';
        Q.ParamByName('CreatedAt').AsString := NowStr;
        Q.ParamByName('UpdatedAt').AsString := NowStr;
        Q.ExecSQL;
      end;

      SetStatus('Saved: ' + ProcName);
      LoadQueries;
      ApplyToEditor(ProcName);
    except
      on E: Exception do
        SetStatus('Save failed: ' + E.Message, True);
    end;
  finally
    Q.Free;
  end;
end;

procedure TfraQueries.DeleteCurrent;
var
  ProcName: string;
  Q: TFDQuery;
  Res: Integer;
begin
  if (FConnection = nil) or (not FConnection.Connected) then
  begin
    SetStatus('No database connection', True);
    Exit;
  end;

  ProcName := Trim(edtProcName.Text);
  if ProcName = '' then
    Exit;

  Res := MessageDlg(Format('Delete query "%s"?', [ProcName]), mtConfirmation, [mbYes, mbNo], 0);
  if Res <> mrYes then
    Exit;

  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConnection;
    Q.SQL.Text := 'DELETE FROM Queries WHERE ProcName = :ProcName';
    Q.ParamByName('ProcName').AsString := ProcName;
    Q.ExecSQL;
    SetStatus('Deleted: ' + ProcName);
  finally
    Q.Free;
  end;

  LoadQueries;
  ClearEditor;
end;

{ Event handlers }

procedure TfraQueries.lvQueriesClick(Sender: TObject);
begin
  if FLoading then Exit;
  if lvQueries.Selected <> nil then
    LoadQueryItem(lvQueries.Selected);
end;

procedure TfraQueries.btnNewClick(Sender: TObject);
begin
  ClearEditor;
  edtProcName.SetFocus;
  SetStatus('New query - enter ProcName and details, then click Save');
end;

procedure TfraQueries.btnSaveClick(Sender: TObject);
begin
  SaveCurrent;
end;

procedure TfraQueries.btnDeleteClick(Sender: TObject);
begin
  DeleteCurrent;
end;

procedure TfraQueries.btnRefreshClick(Sender: TObject);
begin
  LoadQueries;
end;

end.
