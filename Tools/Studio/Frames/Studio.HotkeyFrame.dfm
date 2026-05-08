object fraHotkey: TfraHotkey
  Left = 0
  Top = 0
  Width = 750
  Height = 500
  TabOrder = 0
  object splSplitter: TSplitter
    Left = 170
    Top = 41
    Height = 430
    ExplicitLeft = 168
    ExplicitTop = 40
    ExplicitHeight = 100
  end
  object pnlToolbar: TPanel
    Left = 0
    Top = 0
    Width = 750
    Height = 41
    Align = alTop
    BevelOuter = bvNone
    Color = clWhite
    ParentBackground = False
    TabOrder = 0
    object lblSearch: TLabel
      Left = 12
      Top = 12
      Width = 40
      Height = 15
      Caption = 'Search:'
    end
    object edtSearch: TEdit
      Left = 60
      Top = 9
      Width = 160
      Height = 23
      TabOrder = 0
      OnChange = edtSearchChange
    end
    object btnResetAll: TButton
      Left = 620
      Top = 8
      Width = 120
      Height = 25
      Caption = 'Reset All'
      TabOrder = 1
      OnClick = btnResetAllClick
    end
    object btnResetSelected: TButton
      Left = 490
      Top = 8
      Width = 120
      Height = 25
      Caption = 'Reset Selected'
      TabOrder = 2
      OnClick = btnResetSelectedClick
    end
    object btnImport: TButton
      Left = 360
      Top = 8
      Width = 120
      Height = 25
      Caption = 'Import...'
      TabOrder = 3
      OnClick = btnImportClick
    end
    object btnExport: TButton
      Left = 230
      Top = 8
      Width = 120
      Height = 25
      Caption = 'Export...'
      TabOrder = 4
      OnClick = btnExportClick
    end
  end
  object pnlLeft: TPanel
    Left = 0
    Top = 41
    Width = 170
    Height = 430
    Align = alLeft
    BevelOuter = bvNone
    TabOrder = 1
    object lblCategories: TLabel
      Left = 8
      Top = 4
      Width = 60
      Height = 15
      Caption = 'Categories:'
    end
    object lstCategories: TListBox
      Left = 0
      Top = 24
      Width = 170
      Height = 406
      Align = alBottom
      Anchors = [akLeft, akTop, akRight, akBottom]
      ItemHeight = 15
      TabOrder = 0
      OnClick = lstCategoriesClick
    end
  end
  object pnlRight: TPanel
    Left = 173
    Top = 41
    Width = 577
    Height = 430
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 2
    object grdHotkeys: TStringGrid
      Left = 0
      Top = 0
      Width = 577
      Height = 430
      Align = alClient
      ColCount = 4
      DefaultRowHeight = 22
      FixedCols = 0
      RowCount = 2
      Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goRowSelect, goThumbTracking]
      TabOrder = 0
      OnDblClick = grdHotkeysDblClick
      OnDrawCell = grdHotkeysDrawCell
      OnKeyDown = grdHotkeysKeyDown
      OnSelectCell = grdHotkeysSelectCell
      ColWidths = (
        150
        120
        120
        250)
    end
  end
  object pnlStatus: TPanel
    Left = 0
    Top = 471
    Width = 750
    Height = 29
    Align = alBottom
    BevelOuter = bvNone
    Color = clWhite
    ParentBackground = False
    TabOrder = 3
    object lblStatus: TLabel
      Left = 8
      Top = 7
      Width = 3
      Height = 15
    end
  end
end
