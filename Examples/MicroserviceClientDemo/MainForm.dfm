object MainForm: TMainForm
  Left = 0
  Top = 0
  Caption = 'UniBase Microservice Client Demo'
  ClientHeight = 600
  ClientWidth = 800
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 15
  object pnlTop: TPanel
    Left = 0
    Top = 0
    Width = 800
    Height = 73
    Align = alTop
    TabOrder = 0
    object lblBaseUrl: TLabel
      Left = 16
      Top = 16
      Width = 52
      Height = 15
      Caption = 'Base URL:'
    end
    object lblToken: TLabel
      Left = 16
      Top = 44
      Width = 72
      Height = 15
      Caption = 'Bearer Token:'
    end
    object edtBaseUrl: TEdit
      Left = 96
      Top = 13
      Width = 377
      Height = 23
      TabOrder = 0
      Text = 'https://jsonplaceholder.typicode.com'
    end
    object btnConnect: TButton
      Left = 488
      Top = 11
      Width = 89
      Height = 25
      Caption = 'Connect'
      TabOrder = 1
      OnClick = btnConnectClick
    end
    object edtToken: TEdit
      Left = 96
      Top = 41
      Width = 377
      Height = 23
      TabOrder = 2
    end
  end
  object PageControl1: TPageControl
    Left = 0
    Top = 73
    Width = 800
    Height = 177
    ActivePage = tsBasicOps
    Align = alTop
    TabOrder = 1
    object tsBasicOps: TTabSheet
      Caption = 'Basic Operations'
      object pnlBasicOps: TPanel
        Left = 0
        Top = 0
        Width = 792
        Height = 147
        Align = alClient
        TabOrder = 0
        object lblUserId: TLabel
          Left = 16
          Top = 16
          Width = 42
          Height = 15
          Caption = 'User ID:'
        end
        object edtUserId: TEdit
          Left = 72
          Top = 13
          Width = 57
          Height = 23
          TabOrder = 0
          Text = '1'
        end
        object btnGetUser: TButton
          Left = 144
          Top = 11
          Width = 89
          Height = 25
          Caption = 'GET User'
          TabOrder = 1
          OnClick = btnGetUserClick
        end
        object btnGetUsers: TButton
          Left = 248
          Top = 11
          Width = 89
          Height = 25
          Caption = 'GET All Users'
          TabOrder = 2
          OnClick = btnGetUsersClick
        end
        object btnCreateUser: TButton
          Left = 144
          Top = 48
          Width = 89
          Height = 25
          Caption = 'POST User'
          TabOrder = 3
          OnClick = btnCreateUserClick
        end
        object btnUpdateUser: TButton
          Left = 248
          Top = 48
          Width = 89
          Height = 25
          Caption = 'PUT User'
          TabOrder = 4
          OnClick = btnUpdateUserClick
        end
        object btnDeleteUser: TButton
          Left = 352
          Top = 48
          Width = 89
          Height = 25
          Caption = 'DELETE User'
          TabOrder = 5
          OnClick = btnDeleteUserClick
        end
      end
    end
    object tsCircuitBreaker: TTabSheet
      Caption = 'Circuit Breaker'
      ImageIndex = 1
      object pnlCircuitBreaker: TPanel
        Left = 0
        Top = 0
        Width = 792
        Height = 147
        Align = alClient
        TabOrder = 0
        object lblCBStatus: TLabel
          Left = 16
          Top = 16
          Width = 122
          Height = 15
          Caption = 'Circuit Breaker Status:'
        end
        object lblCBState: TLabel
          Left = 16
          Top = 40
          Width = 78
          Height = 15
          Caption = 'Not connected'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clNavy
          Font.Height = -12
          Font.Name = 'Segoe UI'
          Font.Style = [fsBold]
          ParentFont = False
        end
        object btnCBTest: TButton
          Left = 16
          Top = 72
          Width = 169
          Height = 25
          Caption = 'Test Circuit Breaker'
          TabOrder = 0
          OnClick = btnCBTestClick
        end
        object btnCBReset: TButton
          Left = 200
          Top = 72
          Width = 121
          Height = 25
          Caption = 'Reset Circuit'
          TabOrder = 1
          OnClick = btnCBResetClick
        end
      end
    end
    object tsServiceDiscovery: TTabSheet
      Caption = 'Service Discovery'
      ImageIndex = 2
      object pnlServiceDiscovery: TPanel
        Left = 0
        Top = 0
        Width = 792
        Height = 147
        Align = alClient
        TabOrder = 0
        object lblServiceName: TLabel
          Left = 16
          Top = 16
          Width = 76
          Height = 15
          Caption = 'Service Name:'
        end
        object lblServiceUrl: TLabel
          Left = 16
          Top = 48
          Width = 66
          Height = 15
          Caption = 'Service URL:'
        end
        object edtServiceName: TEdit
          Left = 104
          Top = 13
          Width = 153
          Height = 23
          TabOrder = 0
          Text = 'user-service'
        end
        object edtServiceUrl: TEdit
          Left = 104
          Top = 45
          Width = 153
          Height = 23
          TabOrder = 1
          Text = 'http://localhost:8080'
        end
        object btnRegisterService: TButton
          Left = 272
          Top = 11
          Width = 121
          Height = 25
          Caption = 'Register Service'
          TabOrder = 2
          OnClick = btnRegisterServiceClick
        end
        object btnGetEndpoint: TButton
          Left = 272
          Top = 43
          Width = 121
          Height = 25
          Caption = 'Get Endpoint'
          TabOrder = 3
          OnClick = btnGetEndpointClick
        end
      end
    end
  end
  object memoLog: TMemo
    Left = 0
    Top = 250
    Width = 800
    Height = 331
    Align = alClient
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -11
    Font.Name = 'Consolas'
    Font.Style = []
    ParentFont = False
    ScrollBars = ssVertical
    TabOrder = 2
  end
  object StatusBar1: TStatusBar
    Left = 0
    Top = 581
    Width = 800
    Height = 19
    Panels = <
      item
        Width = 400
      end
      item
        Width = 200
      end>
  end
end
