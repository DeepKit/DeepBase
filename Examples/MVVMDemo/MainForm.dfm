object frmMain: TfrmMain
  Left = 0
  Top = 0
  BorderStyle = bsSingle
  Caption = 'MVVM Demo - Login Form'
  ClientHeight = 380
  ClientWidth = 400
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnClose = FormClose
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnShow = FormShow
  TextHeight = 15
  object pnlLogin: TPanel
    Left = 0
    Top = 0
    Width = 400
    Height = 380
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 0
    object lblTitle: TLabel
      Left = 24
      Top = 24
      Width = 352
      Height = 32
      Alignment = taCenter
      AutoSize = False
      Caption = 'MVVM Login Demo'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -21
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
    end
    object lblUsername: TLabel
      Left = 24
      Top = 80
      Width = 57
      Height = 15
      Caption = 'Username:'
    end
    object lblPassword: TLabel
      Left = 24
      Top = 152
      Width = 53
      Height = 15
      Caption = 'Password:'
    end
    object lblMessage: TLabel
      Left = 24
      Top = 280
      Width = 352
      Height = 30
      Alignment = taCenter
      AutoSize = False
      Caption = 'Please enter your credentials'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clGray
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      WordWrap = True
    end
    object lblUsernameError: TLabel
      Left = 24
      Top = 128
      Width = 352
      Height = 15
      AutoSize = False
      Caption = 'Username is required'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clRed
      Font.Height = -11
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      Visible = False
    end
    object lblPasswordError: TLabel
      Left = 24
      Top = 200
      Width = 352
      Height = 15
      AutoSize = False
      Caption = 'Password is required'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clRed
      Font.Height = -11
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      Visible = False
    end
    object edtUsername: TEdit
      Left = 24
      Top = 100
      Width = 352
      Height = 23
      TabOrder = 0
      OnChange = edtUsernameChange
    end
    object edtPassword: TEdit
      Left = 24
      Top = 172
      Width = 352
      Height = 23
      PasswordChar = '*'
      TabOrder = 1
      OnChange = edtPasswordChange
    end
    object chkRememberMe: TCheckBox
      Left = 24
      Top = 224
      Width = 120
      Height = 17
      Caption = 'Remember me'
      TabOrder = 2
      OnClick = chkRememberMeClick
    end
    object btnLogin: TButton
      Left = 24
      Top = 320
      Width = 170
      Height = 40
      Caption = 'Login'
      Default = True
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -13
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
      TabOrder = 3
      OnClick = btnLoginClick
    end
    object btnCancel: TButton
      Left = 206
      Top = 320
      Width = 170
      Height = 40
      Caption = 'Cancel'
      Enabled = False
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -13
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      TabOrder = 4
      OnClick = btnCancelClick
    end
    object pnlBusy: TPanel
      Left = 24
      Top = 248
      Width = 352
      Height = 28
      BevelOuter = bvNone
      TabOrder = 5
      Visible = False
      object lblBusy: TLabel
        Left = 0
        Top = 0
        Width = 352
        Height = 15
        Align = alTop
        Alignment = taCenter
        Caption = 'Connecting...'
        ExplicitWidth = 71
      end
      object pbProgress: TProgressBar
        Left = 0
        Top = 15
        Width = 352
        Height = 13
        Align = alClient
        Style = pbstMarquee
        TabOrder = 0
      end
    end
  end
  object pnlSuccess: TPanel
    Left = 0
    Top = 0
    Width = 400
    Height = 380
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 1
    Visible = False
    object lblWelcome: TLabel
      Left = 24
      Top = 120
      Width = 352
      Height = 60
      Alignment = taCenter
      AutoSize = False
      Caption = 'Welcome!'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clGreen
      Font.Height = -27
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
      WordWrap = True
    end
    object btnLogout: TButton
      Left = 115
      Top = 220
      Width = 170
      Height = 40
      Caption = 'Logout'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -13
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      TabOrder = 0
      OnClick = btnLogoutClick
    end
  end
end
