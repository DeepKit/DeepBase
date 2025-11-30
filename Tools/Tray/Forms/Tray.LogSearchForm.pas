unit Tray.LogSearchForm;

{*******************************************************************************
  UniBaseTray - 日志搜索窗体
  
  功能:
  - 按日期范围筛选日志
  - 按项目筛选
  - 按标签筛选
  - 导出为 Markdown/JSON
*******************************************************************************}

interface

uses
  Winapi.Windows, Winapi.Messages,
  System.SysUtils, System.Classes, System.JSON, System.DateUtils, System.IOUtils,
  System.Generics.Collections,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls,
  Vcl.ExtCtrls, Vcl.ComCtrls, Vcl.Menus,
  Tray.Database;

type
  TLogSearchForm = class(TForm)
  private
    { 筛选区域 }
    FPnlFilter: TPanel;
    FLblDateFrom: TLabel;
    FDtpFrom: TDateTimePicker;
    FLblDateTo: TLabel;
    FDtpTo: TDateTimePicker;
    FCboProject: TComboBox;
    FLblProject: TLabel;
    FCboTags: TComboBox;
    FLblTags: TLabel;
    FBtnSearch: TButton;
    
    { 结果区域 }
    FLvResults: TListView;
    
    { 按钮区域 }
    FPnlButtons: TPanel;
    FBtnExportMD: TButton;
    FBtnExportJSON: TButton;
    FBtnClose: TButton;
    
    { 数据 }
    FResults: TArray<TDevLogRecord>;
    
    procedure CreateUI;
    procedure LoadFilters;
    procedure DoSearch;
    procedure ExportToMarkdown;
    procedure ExportToJSON;
    
    procedure OnBtnSearchClick(Sender: TObject);
    procedure OnBtnExportMDClick(Sender: TObject);
    procedure OnBtnExportJSONClick(Sender: TObject);
    procedure OnBtnCloseClick(Sender: TObject);
    procedure OnResultsDblClick(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
    class procedure Execute;
  end;

implementation

{ TLogSearchForm }

constructor TLogSearchForm.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  
  Caption := '日志搜索';
  Width := 700;
  Height := 500;
  Position := poMainFormCenter;
  
  CreateUI;
  LoadFilters;
  
  // 默认搜索最近7天
  FDtpFrom.Date := Date - 7;
  FDtpTo.Date := Date;
  DoSearch;
end;

procedure TLogSearchForm.CreateUI;
begin
  // 筛选面板
  FPnlFilter := TPanel.Create(Self);
  FPnlFilter.Parent := Self;
  FPnlFilter.Align := alTop;
  FPnlFilter.Height := 45;
  FPnlFilter.BevelOuter := bvNone;
  FPnlFilter.Caption := '';
  
  FLblDateFrom := TLabel.Create(Self);
  FLblDateFrom.Parent := FPnlFilter;
  FLblDateFrom.Caption := '从:';
  FLblDateFrom.Left := 10;
  FLblDateFrom.Top := 14;
  
  FDtpFrom := TDateTimePicker.Create(Self);
  FDtpFrom.Parent := FPnlFilter;
  FDtpFrom.Left := 30;
  FDtpFrom.Top := 10;
  FDtpFrom.Width := 100;
  
  FLblDateTo := TLabel.Create(Self);
  FLblDateTo.Parent := FPnlFilter;
  FLblDateTo.Caption := '到:';
  FLblDateTo.Left := 140;
  FLblDateTo.Top := 14;
  
  FDtpTo := TDateTimePicker.Create(Self);
  FDtpTo.Parent := FPnlFilter;
  FDtpTo.Left := 160;
  FDtpTo.Top := 10;
  FDtpTo.Width := 100;
  
  FLblProject := TLabel.Create(Self);
  FLblProject.Parent := FPnlFilter;
  FLblProject.Caption := '项目:';
  FLblProject.Left := 275;
  FLblProject.Top := 14;
  
  FCboProject := TComboBox.Create(Self);
  FCboProject.Parent := FPnlFilter;
  FCboProject.Left := 310;
  FCboProject.Top := 10;
  FCboProject.Width := 120;
  FCboProject.Style := csDropDownList;
  
  FLblTags := TLabel.Create(Self);
  FLblTags.Parent := FPnlFilter;
  FLblTags.Caption := '标签:';
  FLblTags.Left := 445;
  FLblTags.Top := 14;
  
  FCboTags := TComboBox.Create(Self);
  FCboTags.Parent := FPnlFilter;
  FCboTags.Left := 480;
  FCboTags.Top := 10;
  FCboTags.Width := 100;
  FCboTags.Style := csDropDownList;
  
  FBtnSearch := TButton.Create(Self);
  FBtnSearch.Parent := FPnlFilter;
  FBtnSearch.Caption := '搜索';
  FBtnSearch.Left := 595;
  FBtnSearch.Top := 9;
  FBtnSearch.Width := 70;
  FBtnSearch.OnClick := OnBtnSearchClick;
  
  // 结果列表
  FLvResults := TListView.Create(Self);
  FLvResults.Parent := Self;
  FLvResults.Align := alClient;
  FLvResults.ViewStyle := vsReport;
  FLvResults.ReadOnly := True;
  FLvResults.RowSelect := True;
  FLvResults.GridLines := True;
  FLvResults.OnDblClick := OnResultsDblClick;
  
  with FLvResults.Columns.Add do
  begin
    Caption := '日期';
    Width := 80;
  end;
  with FLvResults.Columns.Add do
  begin
    Caption := '项目';
    Width := 100;
  end;
  with FLvResults.Columns.Add do
  begin
    Caption := '需求';
    Width := 200;
  end;
  with FLvResults.Columns.Add do
  begin
    Caption := '实现';
    Width := 200;
  end;
  with FLvResults.Columns.Add do
  begin
    Caption := '标签';
    Width := 80;
  end;
  
  // 按钮面板
  FPnlButtons := TPanel.Create(Self);
  FPnlButtons.Parent := Self;
  FPnlButtons.Align := alBottom;
  FPnlButtons.Height := 45;
  FPnlButtons.BevelOuter := bvNone;
  FPnlButtons.Caption := '';
  
  FBtnExportMD := TButton.Create(Self);
  FBtnExportMD.Parent := FPnlButtons;
  FBtnExportMD.Caption := '导出 Markdown';
  FBtnExportMD.Left := 10;
  FBtnExportMD.Top := 8;
  FBtnExportMD.Width := 110;
  FBtnExportMD.OnClick := OnBtnExportMDClick;
  
  FBtnExportJSON := TButton.Create(Self);
  FBtnExportJSON.Parent := FPnlButtons;
  FBtnExportJSON.Caption := '导出 JSON';
  FBtnExportJSON.Left := 130;
  FBtnExportJSON.Top := 8;
  FBtnExportJSON.Width := 90;
  FBtnExportJSON.OnClick := OnBtnExportJSONClick;
  
  FBtnClose := TButton.Create(Self);
  FBtnClose.Parent := FPnlButtons;
  FBtnClose.Caption := '关闭';
  FBtnClose.Width := 80;
  FBtnClose.Height := 28;
  FBtnClose.Left := FPnlButtons.Width - 90;
  FBtnClose.Top := 8;
  FBtnClose.Anchors := [akTop, akRight];
  FBtnClose.Cancel := True;
  FBtnClose.OnClick := OnBtnCloseClick;
end;

procedure TLogSearchForm.LoadFilters;
var
  Projects: TArray<string>;
  S: string;
begin
  // 加载项目列表
  FCboProject.Items.Clear;
  FCboProject.Items.Add('(全部)');
  Projects := TrayDB.GetProjectHistory;
  for S in Projects do
    FCboProject.Items.Add(S);
  FCboProject.ItemIndex := 0;
  
  // 加载标签列表
  FCboTags.Items.Clear;
  FCboTags.Items.Add('(全部)');
  FCboTags.Items.Add('Bug修复');
  FCboTags.Items.Add('新功能');
  FCboTags.Items.Add('重构');
  FCboTags.Items.Add('文档');
  FCboTags.Items.Add('测试');
  FCboTags.ItemIndex := 0;
end;

procedure TLogSearchForm.DoSearch;
var
  Logs: TArray<TDevLogRecord>;
  Log: TDevLogRecord;
  Item: TListItem;
  FilterProject: string;
  FilterTag: string;
  MatchProject, MatchTag: Boolean;
  FilteredList: TList<TDevLogRecord>;
begin
  // 获取日期范围内的日志
  Logs := TrayDB.GetLogsByDateRange(FDtpFrom.Date, FDtpTo.Date);
  
  // 获取筛选条件
  if FCboProject.ItemIndex > 0 then
    FilterProject := FCboProject.Text
  else
    FilterProject := '';
    
  if FCboTags.ItemIndex > 0 then
    FilterTag := FCboTags.Text
  else
    FilterTag := '';
  
  // 筛选
  FilteredList := TList<TDevLogRecord>.Create;
  try
    for Log in Logs do
    begin
      // 项目筛选
      if FilterProject <> '' then
        MatchProject := SameText(Log.ProjectName, FilterProject)
      else
        MatchProject := True;
        
      // 标签筛选
      if FilterTag <> '' then
        MatchTag := Pos(FilterTag, Log.Tags) > 0
      else
        MatchTag := True;
        
      if MatchProject and MatchTag then
        FilteredList.Add(Log);
    end;
    
    FResults := FilteredList.ToArray;
  finally
    FilteredList.Free;
  end;
  
  // 显示结果
  FLvResults.Items.Clear;
  for Log in FResults do
  begin
    Item := FLvResults.Items.Add;
    Item.Caption := FormatDateTime('yyyy-mm-dd', Log.LogDate);
    Item.SubItems.Add(Log.ProjectName);
    Item.SubItems.Add(Log.Requirement);
    Item.SubItems.Add(Log.Implementation_);
    Item.SubItems.Add(Log.Tags);
    Item.Data := Pointer(Log.Id);
  end;
  
  Caption := Format('日志搜索 - 共 %d 条记录', [Length(FResults)]);
end;

procedure TLogSearchForm.ExportToMarkdown;
var
  Dlg: TSaveDialog;
  SL: TStringList;
  Log: TDevLogRecord;
  LastDate: TDate;
begin
  if Length(FResults) = 0 then
  begin
    ShowMessage('没有可导出的记录');
    Exit;
  end;
  
  Dlg := TSaveDialog.Create(Self);
  try
    Dlg.Filter := 'Markdown 文件 (*.md)|*.md|所有文件 (*.*)|*.*';
    Dlg.DefaultExt := 'md';
    Dlg.FileName := 'devlog_' + FormatDateTime('yyyymmdd', Date) + '.md';
    
    if Dlg.Execute then
    begin
      SL := TStringList.Create;
      try
        SL.Add('# 开发日志');
        SL.Add('');
        SL.Add(Format('导出时间: %s', [FormatDateTime('yyyy-mm-dd hh:nn', Now)]));
        SL.Add(Format('日期范围: %s ~ %s', [
          FormatDateTime('yyyy-mm-dd', FDtpFrom.Date),
          FormatDateTime('yyyy-mm-dd', FDtpTo.Date)]));
        SL.Add('');
        
        LastDate := 0;
        for Log in FResults do
        begin
          // 按日期分组
          if Log.LogDate <> LastDate then
          begin
            SL.Add('');
            SL.Add('## ' + FormatDateTime('yyyy-mm-dd', Log.LogDate));
            SL.Add('');
            LastDate := Log.LogDate;
          end;
          
          SL.Add(Format('### %s', [Log.ProjectName]));
          if Log.Requirement <> '' then
            SL.Add(Format('- **需求**: %s', [Log.Requirement]));
          if Log.Implementation_ <> '' then
            SL.Add(Format('- **实现**: %s', [Log.Implementation_]));
          if Log.Tags <> '' then
            SL.Add(Format('- **标签**: %s', [Log.Tags]));
          SL.Add('');
        end;
        
        SL.SaveToFile(Dlg.FileName, TEncoding.UTF8);
        ShowMessage('导出成功: ' + Dlg.FileName);
      finally
        SL.Free;
      end;
    end;
  finally
    Dlg.Free;
  end;
end;

procedure TLogSearchForm.ExportToJSON;
var
  Dlg: TSaveDialog;
  JArray: TJSONArray;
  JObj: TJSONObject;
  Log: TDevLogRecord;
begin
  if Length(FResults) = 0 then
  begin
    ShowMessage('没有可导出的记录');
    Exit;
  end;
  
  Dlg := TSaveDialog.Create(Self);
  try
    Dlg.Filter := 'JSON 文件 (*.json)|*.json|所有文件 (*.*)|*.*';
    Dlg.DefaultExt := 'json';
    Dlg.FileName := 'devlog_' + FormatDateTime('yyyymmdd', Date) + '.json';
    
    if Dlg.Execute then
    begin
      JArray := TJSONArray.Create;
      try
        for Log in FResults do
        begin
          JObj := TJSONObject.Create;
          JObj.AddPair('id', TJSONNumber.Create(Log.Id));
          JObj.AddPair('date', FormatDateTime('yyyy-mm-dd', Log.LogDate));
          JObj.AddPair('project', Log.ProjectName);
          JObj.AddPair('requirement', Log.Requirement);
          JObj.AddPair('implementation', Log.Implementation_);
          JObj.AddPair('tags', Log.Tags);
          JObj.AddPair('createdAt', FormatDateTime('yyyy-mm-dd hh:nn:ss', Log.CreatedAt));
          JArray.AddElement(JObj);
        end;
        
        TFile.WriteAllText(Dlg.FileName, JArray.Format(2), TEncoding.UTF8);
        ShowMessage('导出成功: ' + Dlg.FileName);
      finally
        JArray.Free;
      end;
    end;
  finally
    Dlg.Free;
  end;
end;

procedure TLogSearchForm.OnBtnSearchClick(Sender: TObject);
begin
  DoSearch;
end;

procedure TLogSearchForm.OnBtnExportMDClick(Sender: TObject);
begin
  ExportToMarkdown;
end;

procedure TLogSearchForm.OnBtnExportJSONClick(Sender: TObject);
begin
  ExportToJSON;
end;

procedure TLogSearchForm.OnBtnCloseClick(Sender: TObject);
begin
  Close;
end;

procedure TLogSearchForm.OnResultsDblClick(Sender: TObject);
var
  Item: TListItem;
  LogId: Integer;
  Log: TDevLogRecord;
  Msg: string;
begin
  Item := FLvResults.Selected;
  if Item = nil then Exit;
  
  LogId := Integer(Item.Data);
  
  // 查找并显示详情
  for Log in FResults do
  begin
    if Log.Id = LogId then
    begin
      Msg := Format(
        '日期: %s'#13#10 +
        '项目: %s'#13#10 +
        '标签: %s'#13#10#13#10 +
        '需求:'#13#10'%s'#13#10#13#10 +
        '实现:'#13#10'%s',
        [FormatDateTime('yyyy-mm-dd', Log.LogDate),
         Log.ProjectName,
         Log.Tags,
         Log.Requirement,
         Log.Implementation_]);
      ShowMessage(Msg);
      Break;
    end;
  end;
end;

class procedure TLogSearchForm.Execute;
var
  Form: TLogSearchForm;
begin
  Form := TLogSearchForm.Create(Application);
  try
    Form.ShowModal;
  finally
    Form.Free;
  end;
end;

end.
