{ ============================================================================
  DeepBase.FMX.HB.Dock - Docking & Multi-Monitor Proportions for FMX

  Version: 1.0 (Delphi 13.1 on Win64 / Cross-Platform)
  Description: THbFmxDockPanel & THbFmxWindowProportionHelper for FMX.
  ============================================================================ }

unit DeepBase.FMX.HB.Dock;

interface

uses
  System.SysUtils,
  System.Classes,
  FMX.Types,
  FMX.Controls,
  FMX.Forms,
  DeepBase.HB.Core,
  DeepBase.HB.Dock.Types,
  DeepBase.FMX.HB.Theme;

type
  /// <summary>
  /// THbFmxDockPanel: Floatable/Dockable panel container for FMX.
  /// </summary>
  THbFmxDockPanel = class(TControl)
  private
    FTitle: string;
    FPosition: THbDockPosition;
  public
    constructor Create(AOwner: TComponent); override;
  published
    property Align;
    property Title: string read FTitle write FTitle;
    property Position: THbDockPosition read FPosition write FPosition default dpCenterTab;
  end;

implementation

{ THbFmxDockPanel }

constructor THbFmxDockPanel.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Width := 200;
  Height := 200;
  FTitle := 'Dock Panel';
  FPosition := dpCenterTab;
end;

end.
