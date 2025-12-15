object MainForm: TMainForm
  Left = 0
  Top = 0
  Caption = 'UniBase 用户认证演示 (VCL)'
  ClientHeight = 650
  ClientWidth = 880
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Microsoft YaHei UI'
  Font.Style = []
  Position = poScreenCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 17
  object PanelTop: TPanel
    Left = 0
    Top = 0
    Width = 880
    Height = 80
    Align = alTop
    BevelOuter = bvNone
    Color = 15066597
    ParentBackground = False
    TabOrder = 0
    object LblTitle: TLabel
      Left = 20
      Top = 10
      Width = 280
      Height = 24
      Caption = 'UniBase 用户认证演示'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -18
      Font.Name = 'Microsoft YaHei UI'
      Font.Style = [fsBold]
      ParentFont = False
    end
    object LblStatus: TLabel
      Left = 20
      Top = 45
      Width = 56
      Height = 17
      Caption = '未连接'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clGray
      Font.Height = -12
      Font.Name = 'Microsoft YaHei UI'
      Font.Style = []
      ParentFont = False
    end
    object BtnLogin: TButton
      Left = 550
      Top = 25
      Width = 90
      Height = 32
      Caption = '登录'
      Enabled = False
      TabOrder = 0
      OnClick = BtnLoginClick
    end
    object BtnRegister: TButton
      Left = 650
      Top = 25
      Width = 90
      Height = 32
      Caption = '注册'
      Enabled = False
      TabOrder = 1
      OnClick = BtnRegisterClick
    end
    object BtnLogout: TButton
      Left = 750
      Top = 25
      Width = 90
      Height = 32
      Caption = '登出'
      Enabled = False
      TabOrder = 2
      OnClick = BtnLogoutClick
    end
  end
  object PanelConfig: TPanel
    Left = 0
    Top = 80
    Width = 880
    Height = 50
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 1
    object LblServer: TLabel
      Left = 20
      Top = 15
      Width = 84
      Height = 17
      Caption = '服务器地址:'
    end
    object EdtServer: TEdit
      Left = 110
      Top = 12
      Width = 380
      Height = 25
      TabOrder = 0
      Text = 'https://dev.aipexbase.com/api'
    end
    object BtnConnect: TButton
      Left = 500
      Top = 10
      Width = 90
      Height = 30
      Caption = '连接'
      TabOrder = 1
      OnClick = BtnConnectClick
    end
  end
  object PageControl: TPageControl
    Left = 0
    Top = 130
    Width = 880
    Height = 520
    ActivePage = TabProfile
    Align = alClient
    Enabled = False
    TabOrder = 2
    OnChange = PageControlChange
    object TabProfile: TTabSheet
      Caption = '用户信息'
    end
    object TabBalance: TTabSheet
      Caption = '余额充值'
      ImageIndex = 1
    end
    object TabUsage: TTabSheet
      Caption = '用量统计'
      ImageIndex = 2
    end
    object TabBilling: TTabSheet
      Caption = '账单发票'
      ImageIndex = 3
    end
  end
end
