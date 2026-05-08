object frmMain: TfrmMain
  Left = 0
  Top = 0
  Caption = 'DeepBase DataBinding Demo'
  ClientHeight = 560
  ClientWidth = 800
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  DesignSize = (
    800
    560)
  TextHeight = 15
  object pnlTop: TPanel
    Left = 0
    Top = 0
    Width = 800
    Height = 280
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object grpModel: TGroupBox
      Left = 8
      Top = 8
      Width = 280
      Height = 265
      Caption = 'Model (Direct Edit)'
      TabOrder = 0
      object lblFirstName: TLabel
        Left = 16
        Top = 28
        Width = 60
        Height = 15
        Caption = 'First Name:'
      end
      object lblLastName: TLabel
        Left = 16
        Top = 60
        Width = 59
        Height = 15
        Caption = 'Last Name:'
      end
      object lblAge: TLabel
        Left = 16
        Top = 92
        Width = 24
        Height = 15
        Caption = 'Age:'
      end
      object lblEmail: TLabel
        Left = 16
        Top = 124
        Width = 32
        Height = 15
        Caption = 'Email:'
      end
      object edtFirstName: TEdit
        Left = 100
        Top = 25
        Width = 160
        Height = 23
        TabOrder = 0
        OnChange = edtFirstNameChange
      end
      object edtLastName: TEdit
        Left = 100
        Top = 57
        Width = 160
        Height = 23
        TabOrder = 1
        OnChange = edtLastNameChange
      end
      object edtAge: TEdit
        Left = 100
        Top = 89
        Width = 80
        Height = 23
        TabOrder = 2
        OnChange = edtAgeChange
      end
      object edtEmail: TEdit
        Left = 100
        Top = 121
        Width = 160
        Height = 23
        TabOrder = 3
        OnChange = edtEmailChange
      end
      object chkActive: TCheckBox
        Left = 16
        Top = 156
        Width = 97
        Height = 17
        Caption = 'Active'
        TabOrder = 4
        OnClick = chkActiveClick
      end
      object btnUpdateModel: TButton
        Left = 16
        Top = 192
        Width = 120
        Height = 25
        Caption = 'Update Model'
        TabOrder = 5
        OnClick = btnUpdateModelClick
      end
      object btnResetModel: TButton
        Left = 144
        Top = 192
        Width = 120
        Height = 25
        Caption = 'Reset Model'
        TabOrder = 6
        OnClick = btnResetModelClick
      end
    end
    object grpBindings: TGroupBox
      Left = 296
      Top = 8
      Width = 280
      Height = 265
      Caption = 'Bound Controls'
      TabOrder = 1
      object lblBoundFirstName: TLabel
        Left = 16
        Top = 28
        Width = 106
        Height = 15
        Caption = 'FirstName (TwoWay):'
      end
      object lblBoundLastName: TLabel
        Left = 16
        Top = 60
        Width = 105
        Height = 15
        Caption = 'LastName (TwoWay):'
      end
      object lblBoundFullName: TLabel
        Left = 16
        Top = 92
        Width = 106
        Height = 15
        Caption = 'FullName (OneWay):'
      end
      object lblBoundAge: TLabel
        Left = 16
        Top = 124
        Width = 135
        Height = 15
        Caption = 'Age (OneWay+Converter):'
      end
      object lblBoundActive: TLabel
        Left = 16
        Top = 156
        Width = 105
        Height = 15
        Caption = 'Active (Yes/No Text):'
      end
      object edtBoundFirstName: TEdit
        Left = 160
        Top = 25
        Width = 100
        Height = 23
        TabOrder = 0
        OnChange = edtBoundFirstNameChange
      end
      object edtBoundLastName: TEdit
        Left = 160
        Top = 57
        Width = 100
        Height = 23
        TabOrder = 1
        OnChange = edtBoundLastNameChange
      end
      object edtBoundFullName: TEdit
        Left = 160
        Top = 89
        Width = 100
        Height = 23
        Color = clBtnFace
        ReadOnly = True
        TabOrder = 2
      end
      object edtBoundAge: TEdit
        Left = 160
        Top = 121
        Width = 100
        Height = 23
        Color = clBtnFace
        ReadOnly = True
        TabOrder = 3
      end
      object edtBoundActive: TEdit
        Left = 160
        Top = 153
        Width = 100
        Height = 23
        Color = clBtnFace
        ReadOnly = True
        TabOrder = 4
      end
      object chkBoundActive: TCheckBox
        Left = 16
        Top = 192
        Width = 145
        Height = 17
        Caption = 'Active (TwoWay)'
        TabOrder = 5
        OnClick = chkBoundActiveClick
      end
    end
    object grpInfo: TGroupBox
      Left = 584
      Top = 8
      Width = 208
      Height = 265
      Caption = 'Info'
      TabOrder = 2
      object mmoInfo: TMemo
        Left = 8
        Top = 20
        Width = 192
        Height = 237
        BorderStyle = bsNone
        Color = clBtnFace
        Lines.Strings = (
          '')
        ReadOnly = True
        TabOrder = 0
      end
    end
  end
  object pnlStatus: TPanel
    Left = 0
    Top = 280
    Width = 800
    Height = 33
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 1
    object lblModelStatus: TLabel
      Left = 8
      Top = 8
      Width = 75
      Height = 15
      Caption = 'Model Status:'
    end
  end
  object mmoLog: TMemo
    Left = 8
    Top = 319
    Width = 784
    Height = 233
    Anchors = [akLeft, akTop, akRight, akBottom]
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -11
    Font.Name = 'Consolas'
    Font.Style = []
    ParentFont = False
    ScrollBars = ssVertical
    TabOrder = 2
  end
end
