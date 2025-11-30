object CategoryTreeForm: TCategoryTreeForm
  Left = 0
  Top = 0
  Caption = #20998#31867#31649#29702
  ClientHeight = 400
  ClientWidth = 600
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
  object pnlLeft: TPanel
    Left = 0
    Top = 0
    Width = 250
    Height = 400
    Align = alLeft
    BevelOuter = bvNone
    TabOrder = 0
    object tvCategories: TTreeView
      Left = 0
      Top = 0
      Width = 250
      Height = 400
      Align = alClient
      Indent = 19
      TabOrder = 0
      OnChange = tvCategoriesChange
    end
  end
  object pnlRight: TPanel
    Left = 250
    Top = 0
    Width = 350
    Height = 400
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 1
    object lblName: TLabel
      Left = 16
      Top = 16
      Width = 52
      Height = 15
      Caption = #20998#31867#21517#31216':'
    end
    object lblDescription: TLabel
      Left = 16
      Top = 80
      Width = 28
      Height = 15
      Caption = #25551#36848':'
    end
    object lblParent: TLabel
      Left = 16
      Top = 48
      Width = 40
      Height = 15
      Caption = #29238#20998#31867':'
    end
    object edtName: TEdit
      Left = 80
      Top = 12
      Width = 250
      Height = 23
      TabOrder = 0
    end
    object mmoDescription: TMemo
      Left = 80
      Top = 76
      Width = 250
      Height = 100
      TabOrder = 2
    end
    object cmbParent: TComboBox
      Left = 80
      Top = 44
      Width = 250
      Height = 23
      Style = csDropDownList
      TabOrder = 1
    end
    object pnlButtons: TPanel
      Left = 0
      Top = 340
      Width = 350
      Height = 60
      Align = alBottom
      BevelOuter = bvNone
      TabOrder = 3
      object btnAdd: TButton
        Left = 16
        Top = 16
        Width = 75
        Height = 28
        Caption = #26032#24314
        TabOrder = 0
        OnClick = btnAddClick
      end
      object btnSave: TButton
        Left = 100
        Top = 16
        Width = 75
        Height = 28
        Caption = #20445#23384
        TabOrder = 1
        OnClick = btnSaveClick
      end
      object btnDelete: TButton
        Left = 184
        Top = 16
        Width = 75
        Height = 28
        Caption = #21024#38500
        TabOrder = 2
        OnClick = btnDeleteClick
      end
      object btnClose: TButton
        Left = 268
        Top = 16
        Width = 75
        Height = 28
        Caption = #20851#38381
        TabOrder = 3
        OnClick = btnCloseClick
      end
    end
  end
end
