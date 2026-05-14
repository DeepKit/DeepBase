{ ============================================================================
  Demo.Providers

  Fake providers (structure / main view / inspector / settings page) so the
  demo can show every shell area without a real backend.
  ============================================================================ }

unit Demo.Providers;

interface

uses
  System.SysUtils,
  System.Classes,
  Vcl.Controls,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  DeepBase.VCL.DeepShell.Types,
  DeepBase.VCL.DeepShell;

type
  TDemoStructureProvider = class(TInterfacedObject, IShellStructureProvider)
  public
    function ProviderId: string;
    function GetTreeNames: TArray<string>;
    function GetRootNodes(const ATreeName: string): TArray<TShellObjectRef>;
    function HasChildren(const ANode: TShellObjectRef): Boolean;
    function GetChildren(const ANode: TShellObjectRef): TArray<TShellObjectRef>;
    function GetDisplayText(const ANode: TShellObjectRef): string;
  end;

  TDemoMainViewProvider = class(TInterfacedObject, IShellMainViewProvider)
  public
    function ProviderId: string;
    function CanOpen(const ARef: TShellObjectRef): Boolean;
    function GetViewForObject(const ARef: TShellObjectRef): TShellViewInfo;
    function CreateViewControl(AOwner: TComponent;
      const ARef: TShellObjectRef; const AInfo: TShellViewInfo): TControl;
  end;

  TDemoInspectorProvider = class(TInterfacedObject, IShellInspectorProvider)
  public
    function ProviderId: string;
    function CanInspect(const ARef: TShellObjectRef): Boolean;
    function GetProperties(const ARef: TShellObjectRef): TArray<TShellProperty>;
    function GetRelations(const ARef: TShellObjectRef): TArray<TShellRelation>;
    function GetIssues(const ARef: TShellObjectRef): TArray<TShellIssue>;
  end;

  TDemoSettingsPageProvider = class(TInterfacedObject, ISettingsPageProvider)
  public
    function PageId: string;
    function Caption: string;
    function GroupName: string;
    function CreatePage(AOwner: TComponent): TControl;
    procedure Apply;
    procedure Cancel;
    procedure RestoreDefaults;
  end;

implementation

const
  PROVIDER_ID = 'demo';

{ TDemoStructureProvider }

function TDemoStructureProvider.ProviderId: string;
begin
  Result := PROVIDER_ID;
end;

function TDemoStructureProvider.GetTreeNames: TArray<string>;
begin
  Result := ['Project'];
end;

function TDemoStructureProvider.GetRootNodes(
  const ATreeName: string): TArray<TShellObjectRef>;
begin
  Result := [
    TShellObjectRef.Make('node-1', 'folder', PROVIDER_ID, 'Documents'),
    TShellObjectRef.Make('node-2', 'folder', PROVIDER_ID, 'Reports')
  ];
end;

function TDemoStructureProvider.HasChildren(const ANode: TShellObjectRef): Boolean;
begin
  Result := ANode.Kind = 'folder';
end;

function TDemoStructureProvider.GetChildren(
  const ANode: TShellObjectRef): TArray<TShellObjectRef>;
begin
  if ANode.Id = 'node-1' then
    Result := [
      TShellObjectRef.Make('doc-1', 'doc', PROVIDER_ID, 'Welcome.md'),
      TShellObjectRef.Make('doc-2', 'doc', PROVIDER_ID, 'Notes.md')
    ]
  else if ANode.Id = 'node-2' then
    Result := [
      TShellObjectRef.Make('rpt-1', 'doc', PROVIDER_ID, 'Q1 report')
    ]
  else
    Result := nil;
end;

function TDemoStructureProvider.GetDisplayText(const ANode: TShellObjectRef): string;
begin
  Result := ANode.DisplayName;
end;

{ TDemoMainViewProvider }

function TDemoMainViewProvider.ProviderId: string;
begin
  Result := PROVIDER_ID;
end;

function TDemoMainViewProvider.CanOpen(const ARef: TShellObjectRef): Boolean;
begin
  Result := ARef.Kind = 'doc';
end;

function TDemoMainViewProvider.GetViewForObject(
  const ARef: TShellObjectRef): TShellViewInfo;
begin
  Result := TShellViewInfo.Make(
    'view.' + ARef.Id, svkText, ARef.DisplayName,
    Format('# %s' + sLineBreak + sLineBreak +
           'This is a fake demo view rendered by Demo.MainViewProvider.' +
           sLineBreak + sLineBreak +
           'Object id: %s' + sLineBreak + 'Kind: %s',
           [ARef.DisplayName, ARef.Id, ARef.Kind]));
end;

function TDemoMainViewProvider.CreateViewControl(AOwner: TComponent;
  const ARef: TShellObjectRef; const AInfo: TShellViewInfo): TControl;
begin
  // The demo only emits svkText views, so the shell handles rendering and
  // this method is not invoked. Return nil for safety.
  Result := nil;
end;

{ TDemoInspectorProvider }

function TDemoInspectorProvider.ProviderId: string;
begin
  Result := PROVIDER_ID;
end;

function TDemoInspectorProvider.CanInspect(const ARef: TShellObjectRef): Boolean;
begin
  Result := True;
end;

function TDemoInspectorProvider.GetProperties(
  const ARef: TShellObjectRef): TArray<TShellProperty>;
var
  LProp: TShellProperty;
begin
  SetLength(Result, 3);
  LProp.Name := 'Id'; LProp.Value := ARef.Id; LProp.Group := 'Identity'; LProp.ReadOnly := True;
  Result[0] := LProp;
  LProp.Name := 'Kind'; LProp.Value := ARef.Kind; LProp.Group := 'Identity'; LProp.ReadOnly := True;
  Result[1] := LProp;
  LProp.Name := 'Provider'; LProp.Value := ARef.ProviderId; LProp.Group := 'Identity'; LProp.ReadOnly := True;
  Result[2] := LProp;
end;

function TDemoInspectorProvider.GetRelations(
  const ARef: TShellObjectRef): TArray<TShellRelation>;
begin
  Result := nil;
end;

function TDemoInspectorProvider.GetIssues(
  const ARef: TShellObjectRef): TArray<TShellIssue>;
begin
  Result := nil;
end;

{ TDemoSettingsPageProvider }

function TDemoSettingsPageProvider.PageId: string;
begin
  Result := 'demo.general';
end;

function TDemoSettingsPageProvider.Caption: string;
begin
  Result := 'Demo General';
end;

function TDemoSettingsPageProvider.GroupName: string;
begin
  Result := 'Demo';
end;

function TDemoSettingsPageProvider.CreatePage(AOwner: TComponent): TControl;
var
  LPanel: TPanel;
  LLbl: TLabel;
  LEdit: TEdit;
begin
  LPanel := TPanel.Create(AOwner);
  LPanel.BevelOuter := bvNone;

  LLbl := TLabel.Create(LPanel);
  LLbl.Parent := LPanel;
  LLbl.Top := 16;
  LLbl.Left := 16;
  LLbl.Caption := 'Demo display name:';

  LEdit := TEdit.Create(LPanel);
  LEdit.Parent := LPanel;
  LEdit.Top := 36;
  LEdit.Left := 16;
  LEdit.Width := 320;
  LEdit.Text := 'Hello DeepShell';
  LEdit.Name := 'edDemoName';

  Result := LPanel;
end;

procedure TDemoSettingsPageProvider.Apply;
begin
  // Persist to your store here.
end;

procedure TDemoSettingsPageProvider.Cancel;
begin
  // Discard pending state.
end;

procedure TDemoSettingsPageProvider.RestoreDefaults;
begin
  // Reset values for this page only.
end;

end.
