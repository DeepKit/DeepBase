unit FrameLogViewer;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Graphics, FMX.Controls, FMX.Forms, FMX.Dialogs, FMX.Layouts,
  FMX.Memo, FMX.StdCtrls, FMX.Edit, FMX.ListBox, CtrlMain;

type
  TFrameLogViewer = class(TFrame)
    Layout1: TLayout;
    ToolbarLayout: TLayout;
    Label1: TLabel;
    FilterLayout: TLayout;
    KeywordLabel: TLabel;
    KeywordEdit: TEdit;
    LevelLabel: TLabel;
    LevelComboBox: TComboBox;
    ApplyFilterButton: TButton;
    ClearFilterButton: TButton;
    LogContentLayout: TLayout;
    LogInfoLabel: TLabel;
    LogMemo: TMemo;
    procedure ApplyFilterButtonClick(Sender: TObject);
    procedure ClearFilterButtonClick(Sender: TObject);
  private
    FController: ICtrlMain;
    FCurrentLogLines: TArray<string>;
    procedure LoadLogFile(const AFilePath: string);
  public
    procedure RefreshData;
    procedure SelectLogFile(const AFilePath: string);
  end;

implementation

{$R *.fmx}

procedure TFrameLogViewer.RefreshData;
begin
  LogMemo.Lines.Clear;
  LogInfoLabel.Text := 'No log file selected';
end;

procedure TFrameLogViewer.SelectLogFile(const AFilePath: string);
begin
  if AFilePath <> '' then
    LoadLogFile(AFilePath);
end;

procedure TFrameLogViewer.LoadLogFile(const AFilePath: string);
var
  StartIdx, i: Integer;
begin
  if not FileExists(AFilePath) then
  begin
    LogMemo.Lines.Clear;
    LogInfoLabel.Text := 'File not found: ' + AFilePath;
    Exit;
  end;
  LogMemo.Lines.LoadFromFile(AFilePath);
  if LogMemo.Lines.Count > 1000 then
  begin
    StartIdx := LogMemo.Lines.Count - 1000;
    for i := StartIdx - 1 downto 0 do
      LogMemo.Lines.Delete(0);
  end;
  FCurrentLogLines := LogMemo.Lines.ToStringArray;
  LogInfoLabel.Text := Format('File: %s | Lines: %d', [ExtractFileName(AFilePath), LogMemo.Lines.Count]);
end;

procedure TFrameLogViewer.ApplyFilterButtonClick(Sender: TObject);
var
  Keyword, Level: string;
  FilteredLines: TArray<string>;
  i: Integer;
begin
  Keyword := KeywordEdit.Text;
  if LevelComboBox.ItemIndex >= 0 then
    Level := LevelComboBox.Items[LevelComboBox.ItemIndex]
  else
    Level := 'All';
  if Level = 'All' then
    Level := '';
  FilteredLines := nil;
  SetLength(FilteredLines, 0);
  for i := 0 to Length(FCurrentLogLines) - 1 do
  begin
    if (Keyword = '') or (Pos(Keyword, FCurrentLogLines[i]) > 0) then
    begin
      if (Level = '') or (Pos('[' + Level + ']', FCurrentLogLines[i]) > 0) then
      begin
        SetLength(FilteredLines, Length(FilteredLines) + 1);
        FilteredLines[Length(FilteredLines) - 1] := FCurrentLogLines[i];
      end;
    end;
  end;
  LogMemo.Lines.Clear;
  for i := 0 to Length(FilteredLines) - 1 do
    LogMemo.Lines.Add(FilteredLines[i]);
  LogInfoLabel.Text := Format('Filtered: %d/%d lines', [Length(FilteredLines), Length(FCurrentLogLines)]);
end;

procedure TFrameLogViewer.ClearFilterButtonClick(Sender: TObject);
var
  i: Integer;
begin
  KeywordEdit.Text := '';
  LevelComboBox.ItemIndex := 0;
  LogMemo.Lines.Clear;
  for i := 0 to Length(FCurrentLogLines) - 1 do
    LogMemo.Lines.Add(FCurrentLogLines[i]);
  LogInfoLabel.Text := Format('Showing all %d lines', [Length(FCurrentLogLines)]);
end;

end.
