{ ============================================================================
  DeepBase.VCL.LogListView - 高性能日志列表控件
  
  版本: 1.0
  说明: 使用 OwnerData 模式的 TListView，通过日志查询 port 读取数据
  性能: 10000 条日志渲染流畅
  ============================================================================ }

unit DeepBase.VCL.LogListView;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.UITypes,
  Vcl.Controls,
  Vcl.ComCtrls,
  Vcl.ExtCtrls,
  Vcl.Graphics,
  Vcl.Forms,
  Vcl.Menus,
  DeepBase.Logging,
  DeepBase.Storage.Interfaces,
  DeepBase.Types;

type
  /// <summary>
  /// 日志查看器控件
  /// </summary>
  TLogListView = class(TListView)
  private
    FAutoRefresh: Boolean;
    FRefreshTimer: TTimer;
    FMaxItems: Integer;
    FMinLevel: TLogLevel;
    FCache: TList<TLogViewData>; // OwnerData cache
    
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
  
  FCache := TList<TLogViewData>.Create;
  
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
  Rows: TLogViewDataArray;
  Row: TLogViewData;
begin
  try
    Rows := Logger.ReadRecentLogs(FMinLevel, FMaxItems);

    Items.BeginUpdate;
    try
      FCache.Clear;
      for Row in Rows do
        FCache.Add(Row);

      Items.Count := FCache.Count;
    finally
      Items.EndUpdate;
    end;
  except
    // ignore
  end;
end;

procedure TLogListView.HandleData(Sender: TObject; Item: TListItem);
var
  Entry: TLogViewData;
begin
  if (Item.Index < 0) or (Item.Index >= FCache.Count) then Exit;

  Entry := FCache[Item.Index];
  Item.Caption := Entry.TimestampISO;
  Item.SubItems.Clear;
  Item.SubItems.Add(Entry.LevelText);
  Item.SubItems.Add(Entry.Source);
  Item.SubItems.Add(Entry.MessageText);
  Item.SubItems.Add(IntToStr(Entry.ThreadId));
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
begin
  Logger.ClearLogs;
  RefreshLogs;
end;

end.
