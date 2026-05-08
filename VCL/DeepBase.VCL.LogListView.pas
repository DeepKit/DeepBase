{ ============================================================================
  DeepBase.VCL.LogListView - 高性能日志列表控件
  
  版本: 1.0
  说明: 使用 OwnerData 模式的 TListView，直接绑定 Log 数据库
  性能: 10000 条日志渲染流畅
  ============================================================================ }

unit DeepBase.VCL.LogListView;

interface

uses
  System.SysUtils,
  System.Classes,
  System.UITypes,
  Vcl.Controls,
  Vcl.ComCtrls,
  Vcl.ExtCtrls,
  Vcl.Graphics,
  Vcl.Forms,
  Vcl.Menus,
  Data.DB,
  FireDAC.Comp.Client,
  DeepBase.Manager,
  DeepBase.Types;

type
  /// <summary>
  /// 日志查看器控件
  /// </summary>
  TLogListView = class(TListView)
  private
    FConnection: TFDConnection;
    FQuery: TFDQuery;
    FAutoRefresh: Boolean;
    FRefreshTimer: TTimer;
    FMaxItems: Integer;
    FMinLevel: TLogLevel;
    FCache: TStringList; // 简单缓存用于 OwnerData
    // 注意：为了真正的 OwnerData 数据库分页，我们需要 Limit/Offset
    // 这里简化：读取最近 N 条到内存缓存
    
    FPopup: TPopupMenu;
    
    procedure OnTimer(Sender: TObject);
    procedure RefreshLogs;
    procedure CreateDefaultColumns;
    procedure SetupPopupMenu;
    procedure OnClearClick(Sender: TObject);
    procedure OnRefreshClick(Sender: TObject);
    
  protected
    procedure CreateWnd; override;
    procedure HandleData(Sender: TObject; Item: TListItem);
    procedure HandleCustomDrawItem(Sender: TCustomListView; Item: TListItem; State: TCustomDrawState; var DefaultDraw: Boolean);
    
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    
    procedure Reload;
    
  published
    property AutoRefresh: Boolean read FAutoRefresh write FAutoRefresh default True;
    property MaxItems: Integer read FMaxItems write FMaxItems default 1000;
    property MinLevel: TLogLevel read FMinLevel write FMinLevel default llDebug;
  end;

implementation

{ TLogListView }

constructor TLogListView.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ViewStyle := vsReport;
  OwnerData := True;
  ReadOnly := True;
  RowSelect := True;
  GridLines := True;
  
  FMaxItems := 1000;
  FMinLevel := llDebug;
  FAutoRefresh := True;
  
  FCache := TStringList.Create;
  
  FRefreshTimer := TTimer.Create(Self);
  FRefreshTimer.Interval := 2000; // 2s
  FRefreshTimer.OnTimer := OnTimer;
  FRefreshTimer.Enabled := False;

  OnData := HandleData;
  OnCustomDrawItem := HandleCustomDrawItem;
  
  SetupPopupMenu;
end;

destructor TLogListView.Destroy;
begin
  FreeAndNil(FCache);
  if Assigned(FQuery) then FQuery.Free;
  if Assigned(FConnection) then FConnection.Free; // 如果我们拥有它
  inherited;
end;

procedure TLogListView.CreateWnd;
begin
  inherited;
  if not (csDesigning in ComponentState) then
  begin
    CreateDefaultColumns;
    if FAutoRefresh then
      FRefreshTimer.Enabled := True;
    Reload;
  end;
end;

procedure TLogListView.CreateDefaultColumns;
var
  Col: TListColumn;
begin
  if Columns.Count > 0 then Exit;
  
  Col := Columns.Add;
  Col.Caption := 'Time';
  Col.Width := 140;
  
  Col := Columns.Add;
  Col.Caption := 'Level';
  Col.Width := 60;
  
  Col := Columns.Add;
  Col.Caption := 'Source';
  Col.Width := 100;
  
  Col := Columns.Add;
  Col.Caption := 'Message';
  Col.Width := 400;
  
  Col := Columns.Add;
  Col.Caption := 'Thread';
  Col.Width := 60;
end;

procedure TLogListView.SetupPopupMenu;
var
  Item: TMenuItem;
begin
  FPopup := TPopupMenu.Create(Self);
  
  Item := TMenuItem.Create(FPopup);
  Item.Caption := 'Refresh';
  Item.OnClick := OnRefreshClick;
  FPopup.Items.Add(Item);
  
  Item := TMenuItem.Create(FPopup);
  Item.Caption := '-';
  FPopup.Items.Add(Item);
  
  Item := TMenuItem.Create(FPopup);
  Item.Caption := 'Clear Logs (Database)';
  Item.OnClick := OnClearClick;
  FPopup.Items.Add(Item);
  
  PopupMenu := FPopup;
end;

procedure TLogListView.OnTimer(Sender: TObject);
begin
  if Visible then
    RefreshLogs;
end;

procedure TLogListView.Reload;
begin
  RefreshLogs;
end;

procedure TLogListView.RefreshLogs;
var
  Q: TFDQuery;
  S: string;
begin
  if not DeepBase.Manager.DeepBase.IsInitialized then Exit;
  
  // 使用新的 Connection 以免干扰主线程
  // 注意：频繁创建销毁 Connection 性能不好，建议复用或使用 Manager 的连接池（如果有）
  // 这里简化：复用内部连接
  if FConnection = nil then
  begin
    FConnection := TFDConnection.Create(nil);
    FConnection.DriverName := 'SQLite';
    FConnection.Params.Database := DeepBase.Manager.DeepBase.ConfigDBPath;
    FConnection.Params.Values['LockingMode'] := 'Normal';
    FConnection.Params.Values['JournalMode'] := 'WAL';
    FConnection.LoginPrompt := False;
    try
      FConnection.Connected := True;
    except
      Exit;
    end;
  end;
  
  if FQuery = nil then
  begin
    FQuery := TFDQuery.Create(nil);
    FQuery.Connection := FConnection;
  end;
  
  try
    // 适配新的 Tier 1 schema: Level 是 INTEGER (0-4)
    FQuery.SQL.Text := 
      'SELECT LogTime, Level, Source, Message, ThreadId, StackTrace ' +
      'FROM Logs ' +
      'WHERE Level >= :MinLevel ' +
      'ORDER BY Id DESC LIMIT :Max';
    FQuery.ParamByName('MinLevel').AsInteger := Ord(FMinLevel);
    FQuery.ParamByName('Max').AsInteger := FMaxItems;
    FQuery.Open;
    
    Items.BeginUpdate;
    try
      FCache.Clear;
      while not FQuery.Eof do
      begin
        // 将一行数据打包成 CSV 格式存入 StringList
        // 格式: Time|LevelInt|Source|Msg|Thread
        S := Format('%s|%d|%s|%s|%d', [
          FQuery.FieldByName('LogTime').AsString,
          FQuery.FieldByName('Level').AsInteger,
          FQuery.FieldByName('Source').AsString,
          FQuery.FieldByName('Message').AsString,
          FQuery.FieldByName('ThreadId').AsInteger
        ]);
        FCache.Add(S);
        FQuery.Next;
      end;
      
      Items.Count := FCache.Count;
    finally
      Items.EndUpdate;
    end;
    FQuery.Close;
  except
    // ignore
  end;
end;

procedure TLogListView.HandleData(Sender: TObject; Item: TListItem);
var
  Parts: TArray<string>;
  DataStr: string;
  LevelInt: Integer;
begin
  if (Item.Index < 0) or (Item.Index >= FCache.Count) then Exit;
  
  DataStr := FCache[Item.Index];
  Parts := DataStr.Split(['|']);
  
  if Length(Parts) >= 5 then
  begin
    Item.Caption := Parts[0]; // Time
    Item.SubItems.Clear;
    
    // 将数字级别转换为字符串
    LevelInt := StrToIntDef(Parts[1], 1);
    Item.SubItems.Add(LogLevelToStr(TLogLevel(LevelInt))); // Level
    
    Item.SubItems.Add(Parts[2]); // Source
    Item.SubItems.Add(Parts[3]); // Message
    Item.SubItems.Add(Parts[4]); // Thread
  end;
end;

procedure TLogListView.HandleCustomDrawItem(Sender: TCustomListView; Item: TListItem; State: TCustomDrawState; var DefaultDraw: Boolean);
var
  Lvl: string;
begin
  if Item.SubItems.Count > 0 then
  begin
    Lvl := Item.SubItems[0];
    if (Lvl = 'ERROR') or (Lvl = 'FATAL') then
    begin
      Sender.Canvas.Font.Color := clRed;
      if Lvl = 'FATAL' then
        Sender.Canvas.Font.Style := [fsBold];
    end
    else if Lvl = 'WARN' then
      Sender.Canvas.Font.Color := $000080FF // Orange
    else if Lvl = 'DEBUG' then
      Sender.Canvas.Font.Color := clGray;
  end;
end;

procedure TLogListView.OnRefreshClick(Sender: TObject);
begin
  RefreshLogs;
end;

procedure TLogListView.OnClearClick(Sender: TObject);
var
  Cmd: TFDCommand;
begin
  if FConnection <> nil then
  begin
    Cmd := TFDCommand.Create(nil);
    try
      Cmd.Connection := FConnection;
      Cmd.CommandText.Text := 'DELETE FROM Logs';
      Cmd.Execute;
      RefreshLogs;
    finally
      Cmd.Free;
    end;
  end;
end;

end.
