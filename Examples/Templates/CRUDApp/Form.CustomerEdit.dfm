object CustomerEditForm: TCustomerEditForm
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'Customer'
  ClientHeight = 380
  ClientWidth = 450
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poMainFormCenter
  OnCreate = FormCreate
  OnShow = FormShow
  TextHeight = 15
  object PnlBottom: TPanel
    Left = 0
    Top = 339
    Width = 450
    Height = 41
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 0
    object BtnOK: TButton
      Left = 280
      Top = 8
      Width = 75
      Height = 25
      Caption = 'OK'
      Default = True
      TabOrder = 0
      OnClick = BtnOKClick
    end
    object BtnCancel: TButton
      Left = 361
      Top = 8
      Width = 75
      Height = 25
      Cancel = True
      Caption = 'Cancel'
      ModalResult = 2
      TabOrder = 1
    end
  end
  object PageControl: TPageControl
    Left = 0
    Top = 0
    Width = 450
    Height = 339
    ActivePage = TabBasic
    Align = alClient
    TabOrder = 1
    object TabBasic: TTabSheet
      Caption = 'Basic Info'
      object LblFirstName: TLabel
        Left = 16
        Top = 19
        Width = 62
        Height = 15
        Caption = 'First Name:'
      end
      object LblLastName: TLabel
        Left = 16
        Top = 51
        Width = 60
        Height = 15
        Caption = 'Last Name:'
      end
      object LblEmail: TLabel
        Left = 16
        Top = 83
        Width = 32
        Height = 15
        Caption = 'Email:'
      end
      object LblPhone: TLabel
        Left = 16
        Top = 115
        Width = 38
        Height = 15
        Caption = 'Phone:'
      end
      object LblStatus: TLabel
        Left = 16
        Top = 147
        Width = 36
        Height = 15
        Caption = 'Status:'
      end
      object LblCreatedAt: TLabel
        Left = 16
        Top = 227
        Width = 58
        Height = 15
        Caption = 'Created at:'
      end
      object LblCreatedAtValue: TLabel
        Left = 120
        Top = 227
        Width = 4
        Height = 15
        Caption = '-'
      end
      object LblUpdatedAt: TLabel
        Left = 16
        Top = 251
        Width = 62
        Height = 15
        Caption = 'Updated at:'
      end
      object LblUpdatedAtValue: TLabel
        Left = 120
        Top = 251
        Width = 4
        Height = 15
        Caption = '-'
      end
      object EdtFirstName: TEdit
        Left = 120
        Top = 16
        Width = 297
        Height = 23
        TabOrder = 0
      end
      object EdtLastName: TEdit
        Left = 120
        Top = 48
        Width = 297
        Height = 23
        TabOrder = 1
      end
      object EdtEmail: TEdit
        Left = 120
        Top = 80
        Width = 297
        Height = 23
        TabOrder = 2
      end
      object EdtPhone: TEdit
        Left = 120
        Top = 112
        Width = 201
        Height = 23
        TabOrder = 3
      end
      object CmbStatus: TComboBox
        Left = 120
        Top = 144
        Width = 145
        Height = 23
        Style = csDropDownList
        TabOrder = 4
      end
    end
    object TabAddress: TTabSheet
      Caption = 'Address'
      ImageIndex = 1
      object LblAddress: TLabel
        Left = 16
        Top = 19
        Width = 45
        Height = 15
        Caption = 'Address:'
      end
      object LblCity: TLabel
        Left = 16
        Top = 51
        Width = 24
        Height = 15
        Caption = 'City:'
      end
      object LblCountry: TLabel
        Left = 16
        Top = 83
        Width = 47
        Height = 15
        Caption = 'Country:'
      end
      object LblPostalCode: TLabel
        Left = 16
        Top = 115
        Width = 66
        Height = 15
        Caption = 'Postal Code:'
      end
      object EdtAddress: TEdit
        Left = 120
        Top = 16
        Width = 297
        Height = 23
        TabOrder = 0
      end
      object EdtCity: TEdit
        Left = 120
        Top = 48
        Width = 201
        Height = 23
        TabOrder = 1
      end
      object EdtCountry: TEdit
        Left = 120
        Top = 80
        Width = 201
        Height = 23
        TabOrder = 2
      end
      object EdtPostalCode: TEdit
        Left = 120
        Top = 112
        Width = 121
        Height = 23
        TabOrder = 3
      end
    end
    object TabNotes: TTabSheet
      Caption = 'Notes'
      ImageIndex = 2
      object LblNotes: TLabel
        Left = 16
        Top = 11
        Width = 34
        Height = 15
        Caption = 'Notes:'
      end
      object MemoNotes: TMemo
        Left = 16
        Top = 32
        Width = 401
        Height = 257
        ScrollBars = ssVertical
        TabOrder = 0
      end
    end
  end
end
