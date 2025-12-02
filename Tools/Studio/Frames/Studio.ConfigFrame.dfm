object fraConfig: TfraConfig
  Left = 0
  Top = 0
  Width = 700
  Height = 450
  TabOrder = 0
  object pnlToolbar: TPanel
    Left = 0
    Top = 0
    Width = 700
    Height = 41
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object lblCategory: TLabel
      Left = 8
      Top = 12
      Width = 50
      Height = 13
      Caption = 'Category:'
    end
    object lblSearch: TLabel
      Left = 215
      Top = 12
      Width = 40
      Height = 13
      Caption = 'Search:'
    end
    object cmbCategory: TComboBox
      Left = 64
      Top = 8
      Width = 130
      Height = 21
      Style = csDropDownList
      TabOrder = 0
      OnChange = cmbCategoryChange
    end
    object edtSearch: TEdit
      Left = 260
      Top = 8
      Width = 120
      Height = 21
      TabOrder = 1
      OnChange = edtSearchChange
    end
    object btnRefresh: TButton
      Left = 395
      Top = 8
      Width = 65
      Height = 25
      Caption = 'Refresh'
      TabOrder = 2
      OnClick = btnRefreshClick
    end
    object btnAdd: TButton
      Left = 466
      Top = 8
      Width = 65
      Height = 25
      Caption = 'Add'
      TabOrder = 3
      OnClick = btnAddClick
    end
    object btnDelete: TButton
      Left = 537
      Top = 8
      Width = 65
      Height = 25
      Caption = 'Delete'
      TabOrder = 4
      OnClick = btnDeleteClick
    end
    object btnSave: TButton
      Left = 608
      Top = 8
      Width = 65
      Height = 25
      Caption = 'Save'
      TabOrder = 5
      OnClick = btnSaveClick
    end
  end
  object pnlMain: TPanel
    Left = 0
    Top = 41
    Width = 700
    Height = 384
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 1
    object sgConfig: TStringGrid
      Left = 0
      Top = 0
      Width = 700
      Height = 359
      Align = alClient
      ColCount = 4
      DefaultRowHeight = 20
      FixedCols = 0
      Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goColSizing, goRowSelect, goEditing]
      TabOrder = 0
      OnSelectCell = sgConfigSelectCell
      OnSetEditText = sgConfigSetEditText
      ColWidths = (
        180
        200
        80
        200)
    end
    object StatusBar: TStatusBar
      Left = 0
      Top = 359
      Width = 700
      Height = 25
      Panels = <
        item
          Width = 150
        end
        item
          Width = 200
        end
        item
          Width = 100
        end>
    end
  end
end
