object DocumentEditForm: TDocumentEditForm
  Left = 0
  Top = 0
  Caption = #25991#26723#32534#36753
  ClientHeight = 550
  ClientWidth = 800
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poMainFormCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  TextHeight = 15
  object splRight: TSplitter
    Left = 597
    Top = 90
    Height = 370
    Align = alRight
    ExplicitLeft = 520
    ExplicitTop = 168
    ExplicitHeight = 100
  end
  object pnlTop: TPanel
    Left = 0
    Top = 0
    Width = 800
    Height = 90
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object lblTitle: TLabel
      Left = 16
      Top = 12
      Width = 28
      Height = 15
      Caption = #26631#39064':'
    end
    object lblCategory: TLabel
      Left = 16
      Top = 44
      Width = 28
      Height = 15
      Caption = #20998#31867':'
    end
    object lblTags: TLabel
      Left = 300
      Top = 44
      Width = 28
      Height = 15
      Caption = #26631#31614':'
    end
    object edtTitle: TEdit
      Left = 56
      Top = 8
      Width = 700
      Height = 23
      TabOrder = 0
      OnChange = edtTitleChange
    end
    object cmbCategory: TComboBox
      Left = 56
      Top = 40
      Width = 220
      Height = 23
      Style = csDropDownList
      TabOrder = 1
    end
    object edtTags: TEdit
      Left = 340
      Top = 40
      Width = 416
      Height = 23
      TabOrder = 2
      TextHint = #22810#20010#26631#31614#29992#36887#21495#25110#31354#26684#20998#38548
    end
  end
  object pnlContent: TPanel
    Left = 0
    Top = 90
    Width = 597
    Height = 370
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 1
    object mmoContent: TMemo
      Left = 0
      Top = 0
      Width = 597
      Height = 370
      Align = alClient
      ScrollBars = ssBoth
      TabOrder = 0
      OnChange = mmoContentChange
    end
  end
  object pnlBottom: TPanel
    Left = 0
    Top = 460
    Width = 800
    Height = 90
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 2
    object lblAttachments: TLabel
      Left = 16
      Top = 8
      Width = 28
      Height = 15
      Caption = #38468#20214':'
    end
    object btnSave: TButton
      Left = 608
      Top = 55
      Width = 85
      Height = 28
      Caption = #20445#23384'(&S)'
      Default = True
      TabOrder = 0
      OnClick = btnSaveClick
    end
    object btnCancel: TButton
      Left = 700
      Top = 55
      Width = 85
      Height = 28
      Cancel = True
      Caption = #21462#28040
      TabOrder = 1
      OnClick = btnCancelClick
    end
    object btnAttach: TButton
      Left = 56
      Top = 4
      Width = 75
      Height = 25
      Caption = #28155#21152'...'
      TabOrder = 2
      OnClick = btnAttachClick
    end
    object lvAttachments: TListView
      Left = 140
      Top = 4
      Width = 450
      Height = 45
      Columns = <>
      TabOrder = 3
      ViewStyle = vsReport
    end
  end
  object pnlRight: TPanel
    Left = 600
    Top = 90
    Width = 200
    Height = 370
    Align = alRight
    BevelOuter = bvNone
    TabOrder = 3
    object lblVersions: TLabel
      Left = 8
      Top = 4
      Width = 52
      Height = 15
      Caption = #29256#26412#21382#21490':'
    end
    object lvVersions: TListView
      Left = 0
      Top = 24
      Width = 200
      Height = 346
      Align = alBottom
      Columns = <>
      TabOrder = 0
      ViewStyle = vsReport
      OnDblClick = lvVersionsDblClick
    end
  end
end
