unit Main.Form;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.TabControl,
  FMX.StdCtrls, FMX.Layouts, FMX.Objects, FMX.ListView, FMX.ListView.Types,
  FMX.ListView.Appearances, FMX.ListView.Adapters.Base, FMX.Controls.Presentation,
  FMX.Edit, FMX.Memo, FMX.ScrollBox, FMX.Memo.Types,
  UniBase.FMX.Platform, UniBase.FMX.Theme, UniBase.FMX.ListView,
  UniBase.FMX.FormControls;

type
  TMainForm = class(TForm)
    TabControl: TTabControl;
    TabPlatform: TTabItem;
    TabTheme: TTabItem;
    TabListView: TTabItem;
    TabFormControls: TTabItem;
    ToolBar: TToolBar;
    LabelTitle: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    // Platform tab controls
    FPlatformInfo: TMemo;

    // Theme tab controls
    FThemeSwitch: TUniLabeledSwitch;
    FColorPreview: TRectangle;

    // ListView tab controls
    FListView: TUniListView;
    FSearchEdit: TEdit;

    // Form controls tab
    FNameEdit: TUniMaterialEdit;
    FEmailEdit: TUniMaterialEdit;
    FRating: TUniStarRating;
    FChipInput: TUniChipInput;

    procedure SetupPlatformTab;
    procedure SetupThemeTab;
    procedure SetupListViewTab;
    procedure SetupFormControlsTab;

    procedure ThemeSwitchChange(Sender: TObject);
    procedure SearchEditChange(Sender: TObject);
    procedure RefreshList(Sender: TObject);
    procedure LoadMoreItems(Sender: TObject; var HasMore: Boolean);
  public
  end;

var
  MainForm: TMainForm;

implementation

{$R *.fmx}

procedure TMainForm.FormCreate(Sender: TObject);
begin
  // Initialize platform
  LabelTitle.Text := 'UniBase FMX Demo - ' + Platform.PlatformName;

  // Setup tabs
  SetupPlatformTab;
  SetupThemeTab;
  SetupListViewTab;
  SetupFormControlsTab;

  // Apply initial theme
  Theme.FollowSystemTheme;
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  //
end;

procedure TMainForm.SetupPlatformTab;
var
  Info: TStringList;
  Layout: TVertScrollBox;
begin
  Layout := TVertScrollBox.Create(TabPlatform);
  Layout.Parent := TabPlatform;
  Layout.Align := TAlignLayout.Client;
  Layout.Padding.Rect := RectF(16, 16, 16, 16);

  FPlatformInfo := TMemo.Create(Layout);
  FPlatformInfo.Parent := Layout;
  FPlatformInfo.Align := TAlignLayout.Client;
  FPlatformInfo.ReadOnly := True;
  FPlatformInfo.ShowScrollBars := True;

  // Display platform information
  Info := TStringList.Create;
  try
    Info.Add('=== Platform Information ===');
    Info.Add('');
    Info.Add('Platform: ' + Platform.PlatformName);
    Info.Add('Device Type: ' + Platform.DeviceTypeName);
    Info.Add('');
    Info.Add('Platform Checks:');
    Info.Add('  IsWindows: ' + BoolToStr(Platform.IsWindows, True));
    Info.Add('  IsMacOS: ' + BoolToStr(Platform.IsMacOS, True));
    Info.Add('  IsAndroid: ' + BoolToStr(Platform.IsAndroid, True));
    Info.Add('  IsIOS: ' + BoolToStr(Platform.IsIOS, True));
    Info.Add('  IsLinux: ' + BoolToStr(Platform.IsLinux, True));
    Info.Add('');
    Info.Add('Device Checks:');
    Info.Add('  IsMobile: ' + BoolToStr(Platform.IsMobile, True));
    Info.Add('  IsDesktop: ' + BoolToStr(Platform.IsDesktop, True));
    Info.Add('  IsPhone: ' + BoolToStr(Platform.IsPhone, True));
    Info.Add('  IsTablet: ' + BoolToStr(Platform.IsTablet, True));
    Info.Add('');

    var ScreenInfo := Platform.GetScreenInfo;
    Info.Add('Screen Information:');
    Info.Add('  Width: ' + IntToStr(ScreenInfo.Width) + ' px');
    Info.Add('  Height: ' + IntToStr(ScreenInfo.Height) + ' px');
    Info.Add('  Scale: ' + FormatFloat('0.00', ScreenInfo.Scale));
    Info.Add('  Orientation: ' + IntToStr(Ord(ScreenInfo.Orientation)));
    Info.Add('');

    Info.Add('System Paths:');
    Info.Add('  Documents: ' + Platform.DocumentsPath);
    Info.Add('  Cache: ' + Platform.CachePath);
    Info.Add('  Temp: ' + Platform.TempPath);
    Info.Add('  AppData: ' + Platform.AppDataPath);

    FPlatformInfo.Lines.Assign(Info);
  finally
    Info.Free;
  end;
end;

procedure TMainForm.SetupThemeTab;
var
  Layout: TVertScrollBox;
  ColorLayout: TLayout;
  LblPrimary, LblBackground, LblSurface, LblError: TLabel;
  RectPrimary, RectBackground, RectSurface, RectError: TRectangle;
begin
  Layout := TVertScrollBox.Create(TabTheme);
  Layout.Parent := TabTheme;
  Layout.Align := TAlignLayout.Client;
  Layout.Padding.Rect := RectF(16, 16, 16, 16);

  // Theme switch
  FThemeSwitch := TUniLabeledSwitch.Create(Layout);
  FThemeSwitch.Parent := Layout;
  FThemeSwitch.Align := TAlignLayout.Top;
  FThemeSwitch.LabelText := 'Dark Mode';
  FThemeSwitch.IsChecked := Theme.IsDarkMode;
  FThemeSwitch.OnChange := ThemeSwitchChange;
  FThemeSwitch.Margins.Bottom := 20;

  // Color preview section
  ColorLayout := TLayout.Create(Layout);
  ColorLayout.Parent := Layout;
  ColorLayout.Align := TAlignLayout.Top;
  ColorLayout.Height := 300;

  // Primary color
  LblPrimary := TLabel.Create(ColorLayout);
  LblPrimary.Parent := ColorLayout;
  LblPrimary.Position.Y := 0;
  LblPrimary.Text := 'Primary Color';

  RectPrimary := TRectangle.Create(ColorLayout);
  RectPrimary.Parent := ColorLayout;
  RectPrimary.Position.Y := 20;
  RectPrimary.Width := 200;
  RectPrimary.Height := 40;
  RectPrimary.Fill.Color := Theme.CurrentColors.Primary;
  RectPrimary.Stroke.Kind := TBrushKind.None;
  RectPrimary.XRadius := 8;
  RectPrimary.YRadius := 8;

  // Background color
  LblBackground := TLabel.Create(ColorLayout);
  LblBackground.Parent := ColorLayout;
  LblBackground.Position.Y := 70;
  LblBackground.Text := 'Background Color';

  RectBackground := TRectangle.Create(ColorLayout);
  RectBackground.Parent := ColorLayout;
  RectBackground.Position.Y := 90;
  RectBackground.Width := 200;
  RectBackground.Height := 40;
  RectBackground.Fill.Color := Theme.CurrentColors.Background;
  RectBackground.Stroke.Color := $FF888888;
  RectBackground.XRadius := 8;
  RectBackground.YRadius := 8;

  // Surface color
  LblSurface := TLabel.Create(ColorLayout);
  LblSurface.Parent := ColorLayout;
  LblSurface.Position.Y := 140;
  LblSurface.Text := 'Surface Color';

  RectSurface := TRectangle.Create(ColorLayout);
  RectSurface.Parent := ColorLayout;
  RectSurface.Position.Y := 160;
  RectSurface.Width := 200;
  RectSurface.Height := 40;
  RectSurface.Fill.Color := Theme.CurrentColors.Surface;
  RectSurface.Stroke.Color := $FF888888;
  RectSurface.XRadius := 8;
  RectSurface.YRadius := 8;

  // Error color
  LblError := TLabel.Create(ColorLayout);
  LblError.Parent := ColorLayout;
  LblError.Position.Y := 210;
  LblError.Text := 'Error Color';

  RectError := TRectangle.Create(ColorLayout);
  RectError.Parent := ColorLayout;
  RectError.Position.Y := 230;
  RectError.Width := 200;
  RectError.Height := 40;
  RectError.Fill.Color := Theme.CurrentColors.Error;
  RectError.Stroke.Kind := TBrushKind.None;
  RectError.XRadius := 8;
  RectError.YRadius := 8;
end;

procedure TMainForm.SetupListViewTab;
var
  Layout: TLayout;
  SearchLayout: TLayout;
  I: Integer;
begin
  Layout := TLayout.Create(TabListView);
  Layout.Parent := TabListView;
  Layout.Align := TAlignLayout.Client;

  // Search bar
  SearchLayout := TLayout.Create(Layout);
  SearchLayout.Parent := Layout;
  SearchLayout.Align := TAlignLayout.Top;
  SearchLayout.Height := 50;
  SearchLayout.Padding.Rect := RectF(8, 8, 8, 8);

  FSearchEdit := TEdit.Create(SearchLayout);
  FSearchEdit.Parent := SearchLayout;
  FSearchEdit.Align := TAlignLayout.Client;
  FSearchEdit.TextPrompt := 'Search items...';
  FSearchEdit.OnChange := SearchEditChange;

  // Enhanced ListView
  FListView := TUniListView.Create(Layout);
  FListView.Parent := Layout;
  FListView.Align := TAlignLayout.Client;
  FListView.ItemAppearance.ItemHeight := 60;
  FListView.ItemAppearanceObjects.ItemObjects.Text.Font.Size := 16;
  FListView.ItemAppearanceObjects.ItemObjects.Detail.Font.Size := 12;

  // Configure features
  FListView.PullToRefresh := True;
  FListView.InfiniteScroll := True;
  FListView.LoadMoreThreshold := 3;
  FListView.EmptyText := 'No items found';
  FListView.OnRefresh := RefreshList;
  FListView.OnLoadMore := LoadMoreItems;

  // Add sample items
  for I := 1 to 20 do
  begin
    with FListView.Items.Add do
    begin
      Text := 'Item ' + IntToStr(I);
      Detail := 'Detail for item ' + IntToStr(I);
    end;
  end;
end;

procedure TMainForm.SetupFormControlsTab;
var
  Layout: TVertScrollBox;
  LblRating, LblChips: TLabel;
  BtnValidate: TButton;
begin
  Layout := TVertScrollBox.Create(TabFormControls);
  Layout.Parent := TabFormControls;
  Layout.Align := TAlignLayout.Client;
  Layout.Padding.Rect := RectF(16, 16, 16, 16);

  // Name input with Material Design style
  FNameEdit := TUniMaterialEdit.Create(Layout);
  FNameEdit.Parent := Layout;
  FNameEdit.Align := TAlignLayout.Top;
  FNameEdit.LabelText := 'Full Name';
  FNameEdit.HelperText := 'Enter your full name';
  FNameEdit.Required := True;
  FNameEdit.Margins.Bottom := 16;

  // Email input with validation
  FEmailEdit := TUniMaterialEdit.Create(Layout);
  FEmailEdit.Parent := Layout;
  FEmailEdit.Align := TAlignLayout.Top;
  FEmailEdit.LabelText := 'Email Address';
  FEmailEdit.HelperText := 'Enter a valid email address';
  FEmailEdit.Required := True;
  FEmailEdit.AddValidator(TUniMaterialEdit.EmailValidator);
  FEmailEdit.Margins.Bottom := 24;

  // Star rating
  LblRating := TLabel.Create(Layout);
  LblRating.Parent := Layout;
  LblRating.Align := TAlignLayout.Top;
  LblRating.Text := 'Rate this app:';
  LblRating.Margins.Bottom := 8;

  FRating := TUniStarRating.Create(Layout);
  FRating.Parent := Layout;
  FRating.Align := TAlignLayout.Top;
  FRating.Rating := 3;
  FRating.StarSize := 40;
  FRating.Margins.Bottom := 24;

  // Chip input
  LblChips := TLabel.Create(Layout);
  LblChips.Parent := Layout;
  LblChips.Align := TAlignLayout.Top;
  LblChips.Text := 'Tags (press Enter to add):';
  LblChips.Margins.Bottom := 8;

  FChipInput := TUniChipInput.Create(Layout);
  FChipInput.Parent := Layout;
  FChipInput.Align := TAlignLayout.Top;
  FChipInput.Height := 80;
  FChipInput.MaxChips := 5;
  FChipInput.SetChips(['Delphi', 'FMX', 'Cross-Platform']);
  FChipInput.Margins.Bottom := 24;

  // Validate button
  BtnValidate := TButton.Create(Layout);
  BtnValidate.Parent := Layout;
  BtnValidate.Align := TAlignLayout.Top;
  BtnValidate.Text := 'Validate Form';
  BtnValidate.Height := 44;
  BtnValidate.OnClick := procedure(Sender: TObject)
    var
      IsValid: Boolean;
    begin
      IsValid := FNameEdit.Validate and FEmailEdit.Validate;
      if IsValid then
        ShowMessage('Form is valid!')
      else
        ShowMessage('Please fix the errors above.');
    end;
end;

procedure TMainForm.ThemeSwitchChange(Sender: TObject);
begin
  if FThemeSwitch.IsChecked then
    Theme.SetDarkMode
  else
    Theme.SetLightMode;

  // Update form background
  Fill.Color := Theme.CurrentColors.Background;
end;

procedure TMainForm.SearchEditChange(Sender: TObject);
begin
  FListView.Search(FSearchEdit.Text);
end;

procedure TMainForm.RefreshList(Sender: TObject);
begin
  // Simulate async refresh
  TThread.CreateAnonymousThread(
    procedure
    begin
      Sleep(1500); // Simulate network delay
      TThread.Synchronize(nil,
        procedure
        var
          I: Integer;
        begin
          FListView.Items.Clear;
          for I := 1 to 20 do
          begin
            with FListView.Items.Add do
            begin
              Text := 'Refreshed Item ' + IntToStr(I);
              Detail := 'Updated at ' + TimeToStr(Now);
            end;
          end;
          FListView.EndRefresh;
        end);
    end).Start;
end;

procedure TMainForm.LoadMoreItems(Sender: TObject; var HasMore: Boolean);
var
  StartIndex: Integer;
begin
  StartIndex := FListView.Items.Count;

  // Simulate async load
  TThread.CreateAnonymousThread(
    procedure
    var
      I: Integer;
      LocalStart: Integer;
    begin
      LocalStart := StartIndex;
      Sleep(1000); // Simulate network delay
      TThread.Synchronize(nil,
        procedure
        begin
          for I := 1 to 10 do
          begin
            with FListView.Items.Add do
            begin
              Text := 'Item ' + IntToStr(LocalStart + I);
              Detail := 'Loaded at ' + TimeToStr(Now);
            end;
          end;
          // Stop loading after 50 items
          FListView.EndLoadMore(FListView.Items.Count < 50);
        end);
    end).Start;
end;

end.
