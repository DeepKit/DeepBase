{ ============================================================================
  SamplePlugin - UniBase Sample Plugin
  
  Demonstrates how to create a plugin for UniBase framework.
  
  Features demonstrated:
  - Implementing IUniBasePlugin interface
  - Using TUniBasePluginBase for convenience
  - Accessing plugin context for config, translation, logging
  - Providing menu items (IUniBasePluginUI)
  - Handling framework events (IUniBasePluginEvents)
  ============================================================================ }

unit SamplePlugin;

interface

uses
  System.SysUtils,
  System.Classes,
  Vcl.Forms,
  Vcl.Dialogs,
  UniBase.Plugin;

type
  /// <summary>
  /// Sample plugin implementation showing best practices
  /// </summary>
  TSamplePlugin = class(TUniBasePluginBase, IUniBasePluginUI, IUniBasePluginEvents)
  private
    FCounter: Integer;
  protected
    function DoGetPluginInfo: TPluginInfo; override;
    function DoInitialize: Boolean; override;
    function DoFinalize: Boolean; override;
  public
    constructor Create;
    
    // IUniBasePluginUI
    function GetMenuItems: TArray<TPluginMenuItem>;
    function GetToolbarItems: TArray<TPluginToolbarItem>;
    function GetSettingsPage(AOwner: TComponent): TFrame;
    procedure OnMenuClick(const MenuItemID: string);
    procedure OnToolbarClick(const ToolbarItemID: string);
    
    // IUniBasePluginEvents
    procedure OnLanguageChanged(const NewLanguage: string);
    procedure OnThemeChanged(const NewTheme: string);
    procedure OnConfigChanged(const Key, OldValue, NewValue: string);
  end;

const
  /// <summary>Unique identifier for this plugin</summary>
  SAMPLE_PLUGIN_GUID: TGUID = '{A1B2C3D4-E5F6-4A5B-6C7D-8E9F0A1B2C3D}';
  
  // Menu item IDs
  MENU_SHOW_INFO = 'SamplePlugin.ShowInfo';
  MENU_INCREMENT = 'SamplePlugin.Increment';
  MENU_ABOUT = 'SamplePlugin.About';

/// <summary>
/// Plugin registration function - exported from BPL
/// </summary>
function RegisterPlugin: IUniBasePlugin; export;

implementation

function RegisterPlugin: IUniBasePlugin;
begin
  Result := TSamplePlugin.Create;
end;

{ TSamplePlugin }

constructor TSamplePlugin.Create;
begin
  inherited Create;
  FCounter := 0;
end;

function TSamplePlugin.DoGetPluginInfo: TPluginInfo;
begin
  Result := MakePluginInfo(
    SAMPLE_PLUGIN_GUID,
    'Sample Plugin',                    // Name
    '1.0.0',                            // Version
    'UniBase Team',                     // Author
    'A sample plugin demonstrating the UniBase plugin API. ' +
    'Shows how to add menu items, handle events, and access framework services.',
    [pcMenuItems, pcEventHandler],      // Capabilities
    '0.3'                               // Min UniBase version
  );
  Result.URL := 'https://github.com/example/unibase-sample-plugin';
end;

function TSamplePlugin.DoInitialize: Boolean;
begin
  // Log initialization
  if Context <> nil then
    Context.Log('Sample Plugin initializing...', 1);
  
  // Load saved counter from config
  if Context <> nil then
    FCounter := StrToIntDef(Context.GetConfig('SamplePlugin.Counter', '0'), 0);
  
  Result := True;
  
  if Context <> nil then
    Context.Log('Sample Plugin initialized successfully', 1);
end;

function TSamplePlugin.DoFinalize: Boolean;
begin
  // Save counter to config
  if Context <> nil then
  begin
    Context.SetConfig('SamplePlugin.Counter', IntToStr(FCounter));
    Context.Log('Sample Plugin finalizing...', 1);
  end;
  
  Result := True;
end;

function TSamplePlugin.GetMenuItems: TArray<TPluginMenuItem>;
begin
  SetLength(Result, 3);
  
  // Show Info menu item
  Result[0].ID := MENU_SHOW_INFO;
  Result[0].Caption := '&Show Plugin Info';
  Result[0].ParentPath := 'Tools/Sample Plugin';
  Result[0].Position := 100;
  Result[0].Shortcut := 'Ctrl+Shift+I';
  Result[0].IconName := 'info';
  Result[0].Enabled := True;
  Result[0].Visible := True;
  
  // Increment Counter menu item
  Result[1].ID := MENU_INCREMENT;
  Result[1].Caption := '&Increment Counter';
  Result[1].ParentPath := 'Tools/Sample Plugin';
  Result[1].Position := 110;
  Result[1].Shortcut := '';
  Result[1].IconName := 'plus';
  Result[1].Enabled := True;
  Result[1].Visible := True;
  
  // About menu item
  Result[2].ID := MENU_ABOUT;
  Result[2].Caption := '&About Sample Plugin...';
  Result[2].ParentPath := 'Help';
  Result[2].Position := 900;
  Result[2].Shortcut := '';
  Result[2].IconName := 'help';
  Result[2].Enabled := True;
  Result[2].Visible := True;
end;

function TSamplePlugin.GetToolbarItems: TArray<TPluginToolbarItem>;
begin
  // This plugin doesn't provide toolbar items
  SetLength(Result, 0);
end;

function TSamplePlugin.GetSettingsPage(AOwner: TComponent): TFrame;
begin
  // This plugin doesn't provide a settings page
  Result := nil;
end;

procedure TSamplePlugin.OnMenuClick(const MenuItemID: string);
var
  Info: TPluginInfo;
  Msg: string;
begin
  if MenuItemID = MENU_SHOW_INFO then
  begin
    Info := GetPluginInfo;
    Msg := Format(
      'Plugin: %s'#13#10 +
      'Version: %s'#13#10 +
      'Author: %s'#13#10 +
      'State: %s'#13#10 +
      'Counter: %d',
      [Info.Name, Info.Version, Info.Author, PluginStateToStr(State), FCounter]
    );
    ShowMessage(Msg);
  end
  else if MenuItemID = MENU_INCREMENT then
  begin
    Inc(FCounter);
    ShowMessage(Format('Counter incremented to: %d', [FCounter]));
    
    if Context <> nil then
      Context.Log(Format('Counter incremented to %d', [FCounter]), 1);
  end
  else if MenuItemID = MENU_ABOUT then
  begin
    Info := GetPluginInfo;
    ShowMessage(Format(
      '%s v%s'#13#10#13#10 +
      '%s'#13#10#13#10 +
      'By: %s'#13#10 +
      'URL: %s',
      [Info.Name, Info.Version, Info.Description, Info.Author, Info.URL]
    ));
  end;
end;

procedure TSamplePlugin.OnToolbarClick(const ToolbarItemID: string);
begin
  // Not implemented - no toolbar items
end;

procedure TSamplePlugin.OnLanguageChanged(const NewLanguage: string);
begin
  if Context <> nil then
    Context.Log(Format('Sample Plugin: Language changed to %s', [NewLanguage]), 1);
end;

procedure TSamplePlugin.OnThemeChanged(const NewTheme: string);
begin
  if Context <> nil then
    Context.Log(Format('Sample Plugin: Theme changed to %s', [NewTheme]), 1);
end;

procedure TSamplePlugin.OnConfigChanged(const Key, OldValue, NewValue: string);
begin
  // Only log non-plugin config changes to avoid recursion
  if not Key.StartsWith('SamplePlugin.') then
  begin
    if Context <> nil then
      Context.Log(Format('Sample Plugin: Config %s changed from "%s" to "%s"', 
        [Key, OldValue, NewValue]), 0);
  end;
end;

end.
