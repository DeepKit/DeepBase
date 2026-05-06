unit UniBase.FMX.AboutFrame;

{
  UniBase FMX AboutFrame - FireMonkey 版关于/打赏页面组件

  功能:
  - 6 个标准 Tab 页 (公众号/微信/支付宝/BTC/USDT/关于我)
  - 从 SQLite 数据库安全加载图片 (HMAC 签名验证)
  - BTC/USDT 地址复制功能
  - 机器码显示
  - 根据 enabled 字段动态显示/隐藏 Tab

  使用方法:
    var Frame := TFMXAboutFrame.Create(Self);
    Frame.Parent := SomeContainer;
    Frame.DatabasePath := 'AppConfig.db';
    Frame.Initialize;
}

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  System.Hash, System.IOUtils,
  UniBase.AntiTamper,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs,
  FMX.TabControl, FMX.Objects, FMX.StdCtrls, FMX.Controls.Presentation,
  FMX.Layouts, FMX.Clipboard, FMX.Platform,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Param, FireDAC.Stan.Error,
  FireDAC.DatS, FireDAC.Phys.Intf, FireDAC.DApt.Intf, FireDAC.Stan.Async,
  FireDAC.DApt, FireDAC.UI.Intf, FireDAC.FMXUI.Wait, FireDAC.Stan.Def,
  FireDAC.Stan.Pool, FireDAC.Phys, FireDAC.Phys.SQLite, FireDAC.Phys.SQLiteDef,
  FireDAC.Comp.Client, FireDAC.Comp.DataSet, Data.DB;

type
  /// <summary>
  /// FMX 版 AboutFrame - 关于/打赏页面组件
  /// </summary>
  TFMXAboutFrame = class(TFrame)
  private
    // 数据库
    FConnection: TFDConnection;
    FQuery: TFDQuery;
    FTable: TFDTable;
    FDatabasePath: string;

    // UI 控件
    FTabControl: TTabControl;
    FTabOfficialGzh: TTabItem;
    FTabWechat: TTabItem;
    FTabAlipay: TTabItem;
    FTabBTC: TTabItem;
    FTabUSDT: TTabItem;
    FTabAboutMe: TTabItem;

    // 图片控件
    FImgOfficialGzh: TImage;
    FImgWechat: TImage;
    FImgAlipay: TImage;
    FImgBTC: TImage;
    FImgUSDT: TImage;
    FImgAboutMe: TImage;

    // 标签控件
    FLblOfficialGzhTip: TLabel;
    FLblWechatTip: TLabel;
    FLblAlipayTip: TLabel;
    FLblBTCTip: TLabel;
    FLblBTCAddress: TLabel;
    FLblUSDTTip: TLabel;
    FLblUSDTAddress: TLabel;
    FLblAboutMeTip: TLabel;
    FLblMachineCode: TLabel;
    FLblMachineCodeValue: TLabel;

    // 按钮控件
    FBtnCopyBTC: TButton;
    FBtnCopyUSDT: TButton;

    // 地址数据
    FBTCAddress: string;
    FUSDTAddress: string;

    // 内部方法
    procedure CreateUIControls;
    procedure CreateTabPage(var Tab: TTabItem; var Img: TImage; var LblTip: TLabel;
      const TabText, TipText: string);
    procedure CreateAddressTab(var Tab: TTabItem; var Img: TImage;
      var LblTip, LblAddress: TLabel; var BtnCopy: TButton;
      const TabText, TipText: string; OnCopyClick: TNotifyEvent);
    procedure CreateAboutMeTab;
    procedure ConnectDatabase;
    procedure LoadAllImages;
    procedure LoadSecureImage(const ImageKey: string; TargetImage: TImage);
    procedure UpdateTabVisibility;
    function GenerateMachineCode: string;
    procedure CopyToClipboard(const Text: string);
    procedure BtnCopyBTCClick(Sender: TObject);
    procedure BtnCopyUSDTClick(Sender: TObject);
    procedure LblMachineCodeValueClick(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    /// <summary>初始化组件并加载数据</summary>
    procedure Initialize;

    /// <summary>数据库路径</summary>
    property DatabasePath: string read FDatabasePath write FDatabasePath;
  end;

implementation

{$R *.fmx}

const
  // 标准 ImageKey
  KEY_OFFICIAL_GZH = 'official_gzh';
  KEY_WECHAT = 'wechat';
  KEY_ALIPAY = 'alipay';
  KEY_BTC = 'btc';
  KEY_USDT = 'usdt';
  KEY_ABOUTME = 'aboutme';

  // 默认提示文本
  TIP_OFFICIAL_GZH = '扫码关注公众号获取解锁码';
  TIP_WECHAT = '微信扫码打赏';
  TIP_ALIPAY = '支付宝扫码打赏';
  TIP_BTC = 'BTC 打赏';
  TIP_USDT = 'USDT (TRC20) 打赏';
  TIP_ABOUTME = '关于开发者';

constructor TFMXAboutFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  // 创建数据库连接
  FConnection := TFDConnection.Create(Self);
  FConnection.DriverName := 'SQLite';
  FConnection.LoginPrompt := False;

  FQuery := TFDQuery.Create(Self);
  FQuery.Connection := FConnection;

  FTable := TFDTable.Create(Self);
  FTable.Connection := FConnection;
  FTable.TableName := 'aboutMeImages';

  // 创建 UI 控件
  CreateUIControls;
end;

destructor TFMXAboutFrame.Destroy;
begin
  if Assigned(FTable) and FTable.Active then
    FTable.Active := False;
  if FConnection.Connected then
    FConnection.Connected := False;
  inherited;
end;

procedure TFMXAboutFrame.CreateUIControls;
begin
  // 创建 TabControl
  FTabControl := TTabControl.Create(Self);
  FTabControl.Parent := Self;
  FTabControl.Align := TAlignLayout.Client;
  FTabControl.TabPosition := TTabPosition.Top;

  // 创建各个 Tab 页
  CreateTabPage(FTabOfficialGzh, FImgOfficialGzh, FLblOfficialGzhTip, '公众号', TIP_OFFICIAL_GZH);
  CreateTabPage(FTabWechat, FImgWechat, FLblWechatTip, '微信', TIP_WECHAT);
  CreateTabPage(FTabAlipay, FImgAlipay, FLblAlipayTip, '支付宝', TIP_ALIPAY);
  CreateAddressTab(FTabBTC, FImgBTC, FLblBTCTip, FLblBTCAddress, FBtnCopyBTC, 'BTC', TIP_BTC, BtnCopyBTCClick);
  CreateAddressTab(FTabUSDT, FImgUSDT, FLblUSDTTip, FLblUSDTAddress, FBtnCopyUSDT, 'USDT', TIP_USDT, BtnCopyUSDTClick);
  CreateAboutMeTab;
end;

procedure TFMXAboutFrame.CreateTabPage(var Tab: TTabItem; var Img: TImage; var LblTip: TLabel;
  const TabText, TipText: string);
var
  Layout: TLayout;
begin
  Tab := TTabItem.Create(FTabControl);
  Tab.Parent := FTabControl;
  Tab.Text := TabText;

  Layout := TLayout.Create(Tab);
  Layout.Parent := Tab;
  Layout.Align := TAlignLayout.Client;

  // 提示标签
  LblTip := TLabel.Create(Layout);
  LblTip.Parent := Layout;
  LblTip.Align := TAlignLayout.Top;
  LblTip.Height := 40;
  LblTip.Text := TipText;
  LblTip.TextSettings.HorzAlign := TTextAlign.Center;
  LblTip.Margins.Top := 10;

  // 图片
  Img := TImage.Create(Layout);
  Img.Parent := Layout;
  Img.Align := TAlignLayout.Client;
  Img.Margins.Left := 20;
  Img.Margins.Right := 20;
  Img.Margins.Top := 10;
  Img.Margins.Bottom := 20;
  Img.WrapMode := TImageWrapMode.Fit;
end;

procedure TFMXAboutFrame.CreateAddressTab(var Tab: TTabItem; var Img: TImage;
  var LblTip, LblAddress: TLabel; var BtnCopy: TButton;
  const TabText, TipText: string; OnCopyClick: TNotifyEvent);
var
  Layout: TLayout;
  BottomLayout: TLayout;
begin
  Tab := TTabItem.Create(FTabControl);
  Tab.Parent := FTabControl;
  Tab.Text := TabText;

  Layout := TLayout.Create(Tab);
  Layout.Parent := Tab;
  Layout.Align := TAlignLayout.Client;

  // 提示标签
  LblTip := TLabel.Create(Layout);
  LblTip.Parent := Layout;
  LblTip.Align := TAlignLayout.Top;
  LblTip.Height := 40;
  LblTip.Text := TipText;
  LblTip.TextSettings.HorzAlign := TTextAlign.Center;
  LblTip.Margins.Top := 10;

  // 底部布局 (地址 + 复制按钮)
  BottomLayout := TLayout.Create(Layout);
  BottomLayout.Parent := Layout;
  BottomLayout.Align := TAlignLayout.Bottom;
  BottomLayout.Height := 80;

  // 地址标签
  LblAddress := TLabel.Create(BottomLayout);
  LblAddress.Parent := BottomLayout;
  LblAddress.Align := TAlignLayout.Top;
  LblAddress.Height := 30;
  LblAddress.Text := '';
  LblAddress.TextSettings.HorzAlign := TTextAlign.Center;
  LblAddress.TextSettings.Font.Size := 10;
  LblAddress.Margins.Left := 10;
  LblAddress.Margins.Right := 10;

  // 复制按钮
  BtnCopy := TButton.Create(BottomLayout);
  BtnCopy.Parent := BottomLayout;
  BtnCopy.Align := TAlignLayout.Bottom;
  BtnCopy.Height := 35;
  BtnCopy.Text := '复制地址';
  BtnCopy.Margins.Left := 80;
  BtnCopy.Margins.Right := 80;
  BtnCopy.Margins.Bottom := 10;
  BtnCopy.OnClick := OnCopyClick;

  // 图片
  Img := TImage.Create(Layout);
  Img.Parent := Layout;
  Img.Align := TAlignLayout.Client;
  Img.Margins.Left := 20;
  Img.Margins.Right := 20;
  Img.Margins.Top := 10;
  Img.Margins.Bottom := 10;
  Img.WrapMode := TImageWrapMode.Fit;
end;

procedure TFMXAboutFrame.CreateAboutMeTab;
var
  Layout: TLayout;
  BottomLayout: TLayout;
begin
  FTabAboutMe := TTabItem.Create(FTabControl);
  FTabAboutMe.Parent := FTabControl;
  FTabAboutMe.Text := '关于我';

  Layout := TLayout.Create(FTabAboutMe);
  Layout.Parent := FTabAboutMe;
  Layout.Align := TAlignLayout.Client;

  // 提示标签
  FLblAboutMeTip := TLabel.Create(Layout);
  FLblAboutMeTip.Parent := Layout;
  FLblAboutMeTip.Align := TAlignLayout.Top;
  FLblAboutMeTip.Height := 40;
  FLblAboutMeTip.Text := TIP_ABOUTME;
  FLblAboutMeTip.TextSettings.HorzAlign := TTextAlign.Center;
  FLblAboutMeTip.Margins.Top := 10;

  // 底部布局 (机器码)
  BottomLayout := TLayout.Create(Layout);
  BottomLayout.Parent := Layout;
  BottomLayout.Align := TAlignLayout.Bottom;
  BottomLayout.Height := 60;

  // 机器码标签
  FLblMachineCode := TLabel.Create(BottomLayout);
  FLblMachineCode.Parent := BottomLayout;
  FLblMachineCode.Align := TAlignLayout.Top;
  FLblMachineCode.Height := 20;
  FLblMachineCode.Text := '机器码:';
  FLblMachineCode.TextSettings.HorzAlign := TTextAlign.Center;

  // 机器码值
  FLblMachineCodeValue := TLabel.Create(BottomLayout);
  FLblMachineCodeValue.Parent := BottomLayout;
  FLblMachineCodeValue.Align := TAlignLayout.Client;
  FLblMachineCodeValue.Text := '';
  FLblMachineCodeValue.TextSettings.HorzAlign := TTextAlign.Center;
  FLblMachineCodeValue.TextSettings.Font.Size := 10;
  FLblMachineCodeValue.Cursor := crHandPoint;
  FLblMachineCodeValue.HitTest := True;
  FLblMachineCodeValue.OnClick := LblMachineCodeValueClick;

  // 图片
  FImgAboutMe := TImage.Create(Layout);
  FImgAboutMe.Parent := Layout;
  FImgAboutMe.Align := TAlignLayout.Client;
  FImgAboutMe.Margins.Left := 20;
  FImgAboutMe.Margins.Right := 20;
  FImgAboutMe.Margins.Top := 10;
  FImgAboutMe.Margins.Bottom := 10;
  FImgAboutMe.WrapMode := TImageWrapMode.Fit;
end;

procedure TFMXAboutFrame.Initialize;
begin
  ConnectDatabase;
  UpdateTabVisibility;
  LoadAllImages;

  // 生成并显示机器码
  FLblMachineCodeValue.Text := GenerateMachineCode;
end;

procedure TFMXAboutFrame.ConnectDatabase;
begin
  if FDatabasePath = '' then
    FDatabasePath := System.IOUtils.TPath.Combine(
      System.IOUtils.TPath.GetDirectoryName(ParamStr(0)), 'AppConfig.db');

  if not System.IOUtils.TFile.Exists(FDatabasePath) then
    Exit;

  FConnection.Params.Database := FDatabasePath;
  FConnection.Connected := True;

  // 确保表存在（与 UniBase.AntiTamper / SeedTool 协议一致）
  FQuery.SQL.Text :=
    'CREATE TABLE IF NOT EXISTS aboutMeImages (' +
    '  id INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  image_key TEXT NOT NULL UNIQUE,' +
    '  image_data BLOB NOT NULL,' +
    '  address_text TEXT,' +
    '  description TEXT,' +
    '  enabled INTEGER NOT NULL DEFAULT 1,' +
    '  sha256_hash TEXT NOT NULL,' +
    '  hmac_sha256 TEXT NOT NULL,' +
    '  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,' +
    '  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP' +
    ')';
  FQuery.ExecSQL;

  // 兼容旧表：尽力补齐关键字段（忽略重复/失败）
  try
    FQuery.SQL.Text := 'ALTER TABLE aboutMeImages ADD COLUMN sha256_hash TEXT';
    FQuery.ExecSQL;
  except
  end;
  try
    FQuery.SQL.Text := 'ALTER TABLE aboutMeImages ADD COLUMN hmac_sha256 TEXT';
    FQuery.ExecSQL;
  except
  end;
  try
    FQuery.SQL.Text := 'ALTER TABLE aboutMeImages ADD COLUMN enabled INTEGER NOT NULL DEFAULT 1';
    FQuery.ExecSQL;
  except
  end;
  try
    FQuery.SQL.Text := 'ALTER TABLE aboutMeImages ADD COLUMN description TEXT';
    FQuery.ExecSQL;
  except
  end;

  // 打开表，供 Locate/读取使用
  if not FTable.Active then
    FTable.Active := True;
end;

procedure TFMXAboutFrame.UpdateTabVisibility;

  function IsKeyEnabled(const Key: string): Boolean;
  begin
    Result := True; // 默认显示
    if not FConnection.Connected then Exit;

    try
      FQuery.SQL.Text := 'SELECT enabled FROM aboutMeImages WHERE image_key = :key';
      FQuery.ParamByName('key').AsString := Key;
      FQuery.Open;
      try
        if not FQuery.Eof then
          Result := FQuery.FieldByName('enabled').AsInteger <> 0;
      finally
        FQuery.Close;
      end;
    except
      // 忽略错误，默认显示
    end;
  end;

begin
  FTabOfficialGzh.Visible := IsKeyEnabled(KEY_OFFICIAL_GZH);
  FTabWechat.Visible := IsKeyEnabled(KEY_WECHAT);
  FTabAlipay.Visible := IsKeyEnabled(KEY_ALIPAY);
  FTabBTC.Visible := IsKeyEnabled(KEY_BTC);
  FTabUSDT.Visible := IsKeyEnabled(KEY_USDT);
  FTabAboutMe.Visible := IsKeyEnabled(KEY_ABOUTME);
end;

procedure TFMXAboutFrame.LoadAllImages;
begin
  // 清空地址显示
  FBTCAddress := '';
  FUSDTAddress := '';
  if Assigned(FLblBTCAddress) then
    FLblBTCAddress.Text := '';
  if Assigned(FLblUSDTAddress) then
    FLblUSDTAddress.Text := '';

  LoadSecureImage(KEY_OFFICIAL_GZH, FImgOfficialGzh);
  LoadSecureImage(KEY_WECHAT, FImgWechat);
  LoadSecureImage(KEY_ALIPAY, FImgAlipay);
  LoadSecureImage(KEY_BTC, FImgBTC);
  LoadSecureImage(KEY_USDT, FImgUSDT);
  LoadSecureImage(KEY_ABOUTME, FImgAboutMe);
end;

procedure TFMXAboutFrame.LoadSecureImage(const ImageKey: string; TargetImage: TImage);
var
  DecryptedData: TBytes;
  AddressText: string;
  Stream: TBytesStream;
begin
  if not Assigned(TargetImage) then Exit;
  if not Assigned(FTable) or not FTable.Active then Exit;

  try
    AddressText := '';
    if TAntiTamperPackage.LoadSecureImageBytes(FTable, ImageKey, DecryptedData, AddressText) then
    begin
      // 加载图像（解密后的原始图像字节）
      if Length(DecryptedData) > 0 then
      begin
        Stream := TBytesStream.Create(DecryptedData);
        try
          try
            TargetImage.Bitmap.LoadFromStream(Stream);
          except
            // 忽略图像解码错误
          end;
        finally
          Stream.Free;
        end;
      end;

      // BTC/USDT 地址文本
      if SameText(ImageKey, KEY_BTC) then
      begin
        FBTCAddress := AddressText;
        if Assigned(FLblBTCAddress) then
          FLblBTCAddress.Text := FBTCAddress;
      end
      else if SameText(ImageKey, KEY_USDT) then
      begin
        FUSDTAddress := AddressText;
        if Assigned(FLblUSDTAddress) then
          FLblUSDTAddress.Text := FUSDTAddress;
      end;
    end;
  except
    // 忽略加载错误
  end;
end;

function TFMXAboutFrame.GenerateMachineCode: string;
var
  Info: string;
begin
  {$IFDEF MSWINDOWS}
  Info := GetEnvironmentVariable('COMPUTERNAME') + '|' +
          GetEnvironmentVariable('USERNAME') + '|' +
          GetEnvironmentVariable('PROCESSOR_IDENTIFIER');
  {$ELSE}
  Info := 'UniBase_' + DateTimeToStr(Now);
  {$ENDIF}

  Result := Copy(THashSHA2.GetHashString(Info, THashSHA2.TSHA2Version.SHA256), 1, 16);
end;

procedure TFMXAboutFrame.CopyToClipboard(const Text: string);
var
  ClipboardService: IFMXClipboardService;
begin
  if TPlatformServices.Current.SupportsPlatformService(IFMXClipboardService, ClipboardService) then
    ClipboardService.SetClipboard(Text);
end;

procedure TFMXAboutFrame.BtnCopyBTCClick(Sender: TObject);
begin
  if FBTCAddress <> '' then
  begin
    CopyToClipboard(FBTCAddress);
    ShowMessage('BTC 地址已复制到剪贴板');
  end;
end;

procedure TFMXAboutFrame.BtnCopyUSDTClick(Sender: TObject);
begin
  if FUSDTAddress <> '' then
  begin
    CopyToClipboard(FUSDTAddress);
    ShowMessage('USDT 地址已复制到剪贴板');
  end;
end;

procedure TFMXAboutFrame.LblMachineCodeValueClick(Sender: TObject);
begin
  if FLblMachineCodeValue.Text <> '' then
  begin
    CopyToClipboard(FLblMachineCodeValue.Text);
    ShowMessage('机器码已复制到剪贴板');
  end;
end;

end.
