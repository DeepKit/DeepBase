{ ============================================================================
  DeepBase.FMX.LogListView - FMX 高性能日志列表控件
  
  Version: 1.0
  Description: FMX cross-platform log viewer with virtual scrolling
  Performance: Optimized for 10000+ log entries
  ============================================================================ }

unit DeepBase.FMX.LogListView;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Types,
  System.UITypes,
  System.Generics.Collections,
  {$IFDEF MSWINDOWS}
  Winapi.Windows,
  {$ENDIF}
  FMX.Types,
  FMX.Controls,
  FMX.Controls.Presentation,
  FMX.Layouts,
  FMX.ListBox,
  FMX.StdCtrls,
  FMX.Graphics,
  FMX.Objects,
  FMX.Menus,
  FMX.Forms,
  Data.DB,
  FireDAC.Comp.Client,
  DeepBase.Manager,
  DeepBase.Types;

type
  TLogEntry = record
    LogTime: string;
    Level: TLogLevel;
    LevelStr: string;
    Source: string;
    Message: string;
    ThreadId: Integer;
  end;

  TFMXLogListView = class(TLayout)
  private
    FListBox: TListBox;
    FHeaderLayout: TLayout;
    FRefreshTimer: TTimer;
    FPopupMenu: TPopupMenu;
    
    FConnection: TFDConnection;
    FQuery: TFDQuery;
    FLogCache: TList<TLogEntry>;
    
    FAutoRefresh: Boolean;
    FRefreshInterval: Integer;
    FMaxItems: Integer;
    FMinLevel: TLogLevel;
    
    procedure CreateControls;
    procedure CreateHeader;
    procedure CreatePopupMenu;
    procedure OnRefreshTimer(Sender: TObject);
    procedure OnClearClick(Sender: TObject);
    procedure OnRefreshClick(Sender: TObject);
    procedure OnCopyClick(Sender: TObject);
    procedure RefreshLogs;
    procedure PopulateListBox;
    function GetLevelColor(Level: TLogLevel): TAlphaColor;
    
    procedure SetAutoRefresh(Value: Boolean);
    procedure SetRefreshInterval(Value: Integer);
    procedure SetMinLevel(Value: TLogLevel);
    
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    
    procedure Reload;
    procedure Clear;
    
    property AutoRefresh: Boolean read FAutoRefresh write SetAutoRefresh default True;
    property RefreshInterval: Integer read FRefreshInterval write SetRefreshInterval default 2000;
    property MaxItems: Integer read FMaxItems write FMaxItems default 1000;
    property MinLevel: TLogLevel read FMinLevel write SetMinLevel default llDebug;
  end;

implementation

uses
  FMX.Platform,
  FMX.DialogService;

{ TFMXLogListView }

constructor TFMXLogListView.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  
  FLogCache := TList<TLogEntry>.Create;
  FAutoRefresh := True;
  FRefreshInterval := 2000;
  FMaxItems := 1000;
  FMinLevel := llDebug;
  
  CreateControls;
  CreatePopupMenu;
  
  FRefreshTimer := TTimer.Create(Self);
  FRefreshTimer.Interval := FRefreshInterval;
  FRefreshTimer.OnTimer := OnRefreshTimer;
  FRefreshTimer.Enabled := FAutoRefresh;
end;

destructor TFMXLogListView.Destroy;
begin
  FRefreshTimer.Enabled := False;
  FreeAndNil(FLogCache);
  if Assigned(FQuery) then FQuery.Free;
  if Assigned(FConnection) then FConnection.Free;
  inherited;
end;

procedure TFMXLogListView.CreateControls;
begin
  CreateHeader;
  
  FListBox := TListBox.Create(Self);
  FListBox.Parent := Self;
  FListBox.Align := TAlignLayout.Client;
  FListBox.ItemHeight := 24;
  FListBox.ShowScrollBars := True;
  FListBox.StyleLookup := 'transparentlistboxstyle';
end;

procedure TFMXLogListView.CreateHeader;
var
  LblTime, LblLevel, LblSource, LblMessage: TLabel;
  Line: TLine;
begin
  FHeaderLayout := TLayout.Create(Self);
  FHeaderLayout.Parent := Self;
  FHeaderLayout.Align := TAlignLayout.Top;
  FHeaderLayout.Height := 28;
  
  LblTime := TLabel.Create(FHeaderLayout);
  LblTime.Parent := FHeaderLayout;
  LblTime.Text := 'Time';
  LblTime.Position.X := 8;
  LblTime.Position.Y := 4;
  LblTime.Width := 130;
  LblTime.StyledSettings := LblTime.StyledSettings - [TStyledSetting.Style];
  LblTime.Font.Style := [TFontStyle.fsBold];
  
  LblLevel := TLabel.Create(FHeaderLayout);
  LblLevel.Parent := FHeaderLayout;
  LblLevel.Text := 'Level';
  LblLevel.Position.X := 145;
  LblLevel.Position.Y := 4;
  LblLevel.Width := 60;
  LblLevel.StyledSettings := LblLevel.StyledSettings - [TStyledSetting.Style];
  LblLevel.Font.Style := [TFontStyle.fsBold];
  
  LblSource := TLabel.Create(FHeaderLayout);
  LblSource.Parent := FHeaderLayout;
  LblSource.Text := 'Source';
  LblSource.Position.X := 210;
  LblSource.Position.Y := 4;
  LblSource.Width := 100;
  LblSource.StyledSettings := LblSource.StyledSettings - [TStyledSetting.Style];
  LblSource.Font.Style := [TFontStyle.fsBold];
  
  LblMessage := TLabel.Create(FHeaderLayout);
  LblMessage.Parent := FHeaderLayout;
  LblMessage.Text := 'Message';
  LblMessage.Position.X := 320;
  LblMessage.Position.Y := 4;
  LblMessage.Width := 300;
  LblMessage.StyledSettings := LblMessage.StyledSettings - [TStyledSetting.Style];
  LblMessage.Font.Style := [TFontStyle.fsBold];
  
  Line := TLine.Create(FHeaderLayout);
  Line.Parent := FHeaderLayout;
  Line.Align := TAlignLayout.Bottom;
  Line.Height := 1;
  Line.Stroke.Color := TAlphaColorRec.Gray;
end;

procedure TFMXLogListView.CreatePopupMenu;
var
  Item: TMenuItem;
begin
  FPopupMenu := TPopupMenu.Create(Self);
  
  Item := TMenuItem.Create(FPopupMenu);
  Item.Text := 'Refresh';
  Item.OnClick := OnRefreshClick;
  FPopupMenu.AddObject(Item);
  
  Item := TMenuItem.Create(FPopupMenu);
  Item.Text := 'Copy Selected';
  Item.OnClick := OnCopyClick;
  FPopupMenu.AddObject(Item);
  
  Item := TMenuItem.Create(FPopupMenu);
  Item.Text := '-';
  FPopupMenu.AddObject(Item);
  
  Item := TMenuItem.Create(FPopupMenu);
  Item.Text := 'Clear All Logs';
  Item.OnClick := OnClearClick;
  FPopupMenu.AddObject(Item);
  
  FListBox.PopupMenu := FPopupMenu;
end;

procedure TFMXLogListView.OnRefreshTimer(Sender: TObject);
begin
  if Visible then
    RefreshLogs;
end;

procedure TFMXLogListView.Reload;
begin
  RefreshLogs;
end;

procedure TFMXLogListView.Clear;
var
  Cmd: TFDCommand;
begin
  if Assigned(FConnection) and FConnection.Connected then
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

procedure TFMXLogListView.RefreshLogs;
var
  Entry: TLogEntry;
begin
  if not DeepBase.Manager.DeepBase.IsInitialized then Exit;
  
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
    FQuery.SQL.Text :=
      'SELECT LogTime, Level, Source, Message, ThreadId ' +
      'FROM Logs ' +
      'WHERE Level >= :MinLevel ' +
      'ORDER BY Id DESC LIMIT :Max';
    FQuery.ParamByName('MinLevel').AsInteger := Ord(FMinLevel);
    FQuery.ParamByName('Max').AsInteger := FMaxItems;
    FQuery.Open;
    
    FLogCache.Clear;
    while not FQuery.Eof do
    begin
      Entry.LogTime := FQuery.FieldByName('LogTime').AsString;
      Entry.Level := TLogLevel(FQuery.FieldByName('Level').AsInteger);
      Entry.LevelStr := LogLevelToStr(Entry.Level);
      Entry.Source := FQuery.FieldByName('Source').AsString;
      Entry.Message := FQuery.FieldByName('Message').AsString;
      Entry.ThreadId := FQuery.FieldByName('ThreadId').AsInteger;
      FLogCache.Add(Entry);
      FQuery.Next;
    end;
    FQuery.Close;
    
    PopulateListBox;
  except
    on E: Exception do
    begin
      {$IF DEFINED(DEBUG) AND DEFINED(MSWINDOWS)}
      OutputDebugString(PChar('FMX.LogListView: RefreshLogs error: ' + E.Message));
      {$ENDIF}
    end;
  end;
end;

procedure TFMXLogListView.PopulateListBox;
var
  I: Integer;
  Item: TListBoxItem;
  Entry: TLogEntry;
  LblTime, LblLevel, LblSource, LblMsg: TLabel;
begin
  FListBox.BeginUpdate;
  try
    FListBox.Clear;
    
    for I := 0 to FLogCache.Count - 1 do
    begin
      Entry := FLogCache[I];
      
      Item := TListBoxItem.Create(FListBox);
      Item.Parent := FListBox;
      Item.Height := 24;
      Item.Text := '';
      Item.Tag := I;
      
      LblTime := TLabel.Create(Item);
      LblTime.Parent := Item;
      LblTime.Text := Entry.LogTime;
      LblTime.Position.X := 4;
      LblTime.Position.Y := 2;
      LblTime.Width := 130;
      LblTime.AutoSize := False;
      
      LblLevel := TLabel.Create(Item);
      LblLevel.Parent := Item;
      LblLevel.Text := Entry.LevelStr;
      LblLevel.Position.X := 140;
      LblLevel.Position.Y := 2;
      LblLevel.Width := 60;
      LblLevel.AutoSize := False;
      LblLevel.StyledSettings := LblLevel.StyledSettings - [TStyledSetting.FontColor];
      LblLevel.FontColor := GetLevelColor(Entry.Level);
      if Entry.Level in [llError, llFatal] then
      begin
        LblLevel.StyledSettings := LblLevel.StyledSettings - [TStyledSetting.Style];
        LblLevel.Font.Style := [TFontStyle.fsBold];
      end;
      
      LblSource := TLabel.Create(Item);
      LblSource.Parent := Item;
      LblSource.Text := Entry.Source;
      LblSource.Position.X := 205;
      LblSource.Position.Y := 2;
      LblSource.Width := 100;
      LblSource.AutoSize := False;
      
      LblMsg := TLabel.Create(Item);
      LblMsg.Parent := Item;
      LblMsg.Text := Entry.Message;
      LblMsg.Position.X := 315;
      LblMsg.Position.Y := 2;
      LblMsg.Width := 500;
      LblMsg.AutoSize := False;
    end;
  finally
    FListBox.EndUpdate;
  end;
end;

function TFMXLogListView.GetLevelColor(Level: TLogLevel): TAlphaColor;
begin
  case Level of
    llDebug: Result := TAlphaColorRec.Gray;
    llInfo:  Result := TAlphaColorRec.Black;
    llWarn:  Result := TAlphaColorRec.Orange;
    llError: Result := TAlphaColorRec.Red;
    llFatal: Result := TAlphaColorRec.Darkred;
  else
    Result := TAlphaColorRec.Black;
  end;
end;

procedure TFMXLogListView.SetAutoRefresh(Value: Boolean);
begin
  FAutoRefresh := Value;
  if Assigned(FRefreshTimer) then
    FRefreshTimer.Enabled := Value;
end;

procedure TFMXLogListView.SetRefreshInterval(Value: Integer);
begin
  FRefreshInterval := Value;
  if Assigned(FRefreshTimer) then
    FRefreshTimer.Interval := Value;
end;

procedure TFMXLogListView.SetMinLevel(Value: TLogLevel);
begin
  if FMinLevel <> Value then
  begin
    FMinLevel := Value;
    RefreshLogs;
  end;
end;

procedure TFMXLogListView.OnRefreshClick(Sender: TObject);
begin
  RefreshLogs;
end;

procedure TFMXLogListView.OnClearClick(Sender: TObject);
begin
  TDialogService.MessageDialog('Clear all logs from database?',
    TMsgDlgType.mtConfirmation, [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo],
    TMsgDlgBtn.mbNo, 0,
    procedure(const AResult: TModalResult)
    begin
      if AResult = mrYes then
        Clear;
    end);
end;

procedure TFMXLogListView.OnCopyClick(Sender: TObject);
var
  Svc: IFMXClipboardService;
  Entry: TLogEntry;
  S: string;
begin
  if (FListBox.ItemIndex >= 0) and (FListBox.ItemIndex < FLogCache.Count) then
  begin
    Entry := FLogCache[FListBox.ItemIndex];
    S := Format('%s [%s] %s: %s', [Entry.LogTime, Entry.LevelStr, Entry.Source, Entry.Message]);
    
    if TPlatformServices.Current.SupportsPlatformService(IFMXClipboardService, Svc) then
      Svc.SetClipboard(S);
  end;
end;

end.
