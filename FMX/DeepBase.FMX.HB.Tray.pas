{ ============================================================================
  DeepBase.FMX.HB.Tray - Modern Token-Driven Tray Icon & Popup Menu for FMX

  Version: 1.0 (Delphi 13.1 on Win64 / Cross-Platform)
  Description: Modern HB-themed Tray Menu for FMX:
               - Cross-platform menu structures & token styling for FMX
  ============================================================================ }

unit DeepBase.FMX.HB.Tray;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Types,
  System.UITypes,
  System.Generics.Collections,
  FMX.Types,
  FMX.Controls,
  FMX.Forms,
  FMX.Menus,
  DeepBase.HB.Core,
  DeepBase.HB.Tray.Types,
  DeepBase.FMX.HB.Theme;

type
  /// <summary>
  /// Single item in the FMX HB Tray Menu.
  /// </summary>
  THbFmxTrayMenuItem = class
  private
    FData: THbTrayMenuItemData;
    FOnClick: TNotifyEvent;
  public
    constructor Create;
    property Data: THbTrayMenuItemData read FData write FData;
    property OnClick: TNotifyEvent read FOnClick write FOnClick;
  end;

  /// <summary>
  /// THbFmxTrayMenu: Token-driven tray menu container for FMX.
  /// </summary>
  THbFmxTrayMenu = class(TComponent)
  private
    FHeader: THbTrayHeaderData;
    FItems: TObjectList<THbFmxTrayMenuItem>;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure SetHeader(const ATitle: string; const ASubtitle: string = ''; const AVersion: string = ''; ATone: THbBadgeTone = btSuccess; AHasDot: Boolean = True);
    function AddItem(const ACaption: string; AOnClick: TNotifyEvent = nil; const AShortcut: string = ''; AIsDefault: Boolean = False): THbFmxTrayMenuItem;
    function AddCheckItem(const ACaption: string; AOnClick: TNotifyEvent; AIsChecked: Boolean = False): THbFmxTrayMenuItem;
    function AddSeparator: THbFmxTrayMenuItem;
    procedure Clear;
    property Header: THbTrayHeaderData read FHeader write FHeader;
    property Items: TObjectList<THbFmxTrayMenuItem> read FItems;
  end;

implementation

{ THbFmxTrayMenuItem }

constructor THbFmxTrayMenuItem.Create;
begin
  inherited Create;
  FData.Kind := tikItem;
  FData.IsEnabled := True;
  FData.BadgeTone := btBrand;
end;

{ THbFmxTrayMenu }

constructor THbFmxTrayMenu.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FItems := TObjectList<THbFmxTrayMenuItem>.Create(True);
  FHeader.Visible := False;
end;

destructor THbFmxTrayMenu.Destroy;
begin
  FItems.Free;
  inherited;
end;

procedure THbFmxTrayMenu.SetHeader(const ATitle, ASubtitle, AVersion: string; ATone: THbBadgeTone; AHasDot: Boolean);
begin
  FHeader.Title := ATitle;
  FHeader.Subtitle := ASubtitle;
  FHeader.VersionText := AVersion;
  FHeader.Tone := ATone;
  FHeader.HasBreathingDot := AHasDot;
  FHeader.Visible := True;
end;

function THbFmxTrayMenu.AddItem(const ACaption: string; AOnClick: TNotifyEvent; const AShortcut: string; AIsDefault: Boolean): THbFmxTrayMenuItem;
begin
  Result := THbFmxTrayMenuItem.Create;
  Result.FData.Caption := ACaption;
  Result.FData.ShortcutText := AShortcut;
  Result.FData.IsDefault := AIsDefault;
  Result.OnClick := AOnClick;
  FItems.Add(Result);
end;

function THbFmxTrayMenu.AddCheckItem(const ACaption: string; AOnClick: TNotifyEvent; AIsChecked: Boolean): THbFmxTrayMenuItem;
begin
  Result := THbFmxTrayMenuItem.Create;
  Result.FData.Caption := ACaption;
  Result.FData.Kind := tikCheck;
  Result.FData.IsChecked := AIsChecked;
  Result.OnClick := AOnClick;
  FItems.Add(Result);
end;

function THbFmxTrayMenu.AddSeparator: THbFmxTrayMenuItem;
begin
  Result := THbFmxTrayMenuItem.Create;
  Result.FData.Kind := tikSeparator;
  FItems.Add(Result);
end;

procedure THbFmxTrayMenu.Clear;
begin
  FItems.Clear;
end;

end.
