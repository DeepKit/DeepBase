unit FrameConfigEditor;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Graphics, FMX.Controls, FMX.Forms, FMX.Dialogs, FMX.Layouts,
  FMX.StdCtrls, FMX.Edit, FMX.ListBox, CtrlMain;

type
  TFrameConfigEditor = class(TFrame)
    Layout1: TLayout;
    TopLayout: TLayout;
    GroupLabel: TLabel;
    GroupComboBox: TComboBox;
    ConfigListLayout: TLayout;
    ConfigListLabel: TLabel;
    ConfigListBox: TListBox;
    BottomLayout: TLayout;
    DetailLabel: TLabel;
    DetailLayout: TLayout;
    KeyLabel: TLabel;
    KeyEdit: TEdit;
    ValueLabel: TLabel;
    ValueEdit: TEdit;
    ButtonsLayout: TLayout;
    SaveButton: TButton;
    ResetButton: TButton;
    procedure GroupComboBoxChange(Sender: TObject);
    procedure ConfigListBoxItemClick(const Sender: TCustomListBox; const Item: TListBoxItem);
    procedure SaveButtonClick(Sender: TObject);
    procedure ResetButtonClick(Sender: TObject);
  private
    FController: ICtrlMain;
    FCurrentGroup: string;
    FCurrentConfigItems: TArray<TConfigItem>;
    FSelectedItemKey: string;
    procedure LoadConfigGroup(const AGroup: string);
    procedure DisplayConfigItem(const AIndex: Integer);
  public
    procedure RefreshData;
    procedure SelectGroup(const AGroup: string);
  end;

implementation

{$R *.fmx}

procedure TFrameConfigEditor.RefreshData;
begin
  LoadConfigGroup(FCurrentGroup);
end;

procedure TFrameConfigEditor.SelectGroup(const AGroup: string);
var
  i: Integer;
begin
  for i := 0 to GroupComboBox.Items.Count - 1 do
  begin
    if GroupComboBox.Items[i] = AGroup then
    begin
      GroupComboBox.ItemIndex := i;
      LoadConfigGroup(AGroup);
      Exit;
    end;
  end;
end;

procedure TFrameConfigEditor.GroupComboBoxChange(Sender: TObject);
begin
  if GroupComboBox.ItemIndex >= 0 then
  begin
    FCurrentGroup := GroupComboBox.Items[GroupComboBox.ItemIndex];
    LoadConfigGroup(FCurrentGroup);
  end;
end;

procedure TFrameConfigEditor.LoadConfigGroup(const AGroup: string);
var
  i: Integer;
  ListItem: TListBoxItem;
begin
  ConfigListBox.Clear;
  KeyEdit.Text := '';
  ValueEdit.Text := '';
  FSelectedItemKey := '';
  if FController <> nil then
    FCurrentConfigItems := FController.GetConfigsInGroup(AGroup)
  else
    FCurrentConfigItems := nil;
  for i := 0 to Length(FCurrentConfigItems) - 1 do
  begin
    ListItem := TListBoxItem.Create(nil);
    ListItem.Text := FCurrentConfigItems[i].Key + ' = ' + FCurrentConfigItems[i].Value;
    ListItem.Tag := i;
    ConfigListBox.AddObject(ListItem);
  end;
end;

procedure TFrameConfigEditor.ConfigListBoxItemClick(const Sender: TCustomListBox; const Item: TListBoxItem);
begin
  if Item <> nil then
    DisplayConfigItem(Item.Tag);
end;

procedure TFrameConfigEditor.DisplayConfigItem(const AIndex: Integer);
begin
  if (AIndex >= 0) and (AIndex < Length(FCurrentConfigItems)) then
  begin
    FSelectedItemKey := FCurrentConfigItems[AIndex].Key;
    KeyEdit.Text := FCurrentConfigItems[AIndex].Key;
    ValueEdit.Text := FCurrentConfigItems[AIndex].Value;
  end;
end;

procedure TFrameConfigEditor.SaveButtonClick(Sender: TObject);
begin
  if FSelectedItemKey = '' then
  begin
    ShowMessage('Please select a configuration item first');
    Exit;
  end;
  if FController <> nil then
  begin
    if FController.ValidateConfig(FSelectedItemKey, ValueEdit.Text) then
    begin
      FController.SetConfigValue(FSelectedItemKey, ValueEdit.Text);
      ShowMessage('Configuration saved successfully');
      RefreshData;
    end
    else
      ShowMessage('Invalid configuration value');
  end;
end;

procedure TFrameConfigEditor.ResetButtonClick(Sender: TObject);
begin
  if FSelectedItemKey = '' then
    Exit;
  if FController <> nil then
  begin
    ValueEdit.Text := FController.GetConfigValue(FSelectedItemKey);
  end;
end;

end.
