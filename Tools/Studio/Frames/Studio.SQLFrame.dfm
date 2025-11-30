object fraSQLEditor: TfraSQLEditor
  Left = 0
  Top = 0
  Width = 850
  Height = 600
  TabOrder = 0
  object splMain: TSplitter
    Left = 0
    Top = 241
    Width = 850
    Height = 5
    Cursor = crVSplit
    Align = alTop
    ExplicitTop = 200
    ExplicitWidth = 750
  end
  object pnlToolbar: TPanel
    Left = 0
    Top = 0
    Width = 850
    Height = 41
    Align = alTop
    BevelOuter = bvNone
    Color = clWhite
    ParentBackground = False
    TabOrder = 0
    object lblStatus: TLabel
      Left = 320
      Top = 12
      Width = 3
      Height = 15
    end
    object btnExecute: TButton
      Left = 12
      Top = 8
      Width = 100
      Height = 25
      Caption = 'Execute (F5)'
      TabOrder = 0
      OnClick = btnExecuteClick
    end
    object btnClear: TButton
      Left = 120
      Top = 8
      Width = 80
      Height = 25
      Caption = 'Clear'
      TabOrder = 1
      OnClick = btnClearClick
    end
    object btnExportCSV: TButton
      Left = 210
      Top = 8
      Width = 90
      Height = 25
      Caption = 'Export CSV'
      TabOrder = 2
      OnClick = btnExportCSVClick
    end
  end
  object pnlEditor: TPanel
    Left = 0
    Top = 41
    Width = 850
    Height = 200
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 1
    object lblSQL: TLabel
      Left = 8
      Top = 4
      Width = 62
      Height = 15
      Caption = 'SQL Query:'
    end
    object mmoSQL: TMemo
      Left = 0
      Top = 24
      Width = 850
      Height = 176
      Align = alBottom
      Anchors = [akLeft, akTop, akRight, akBottom]
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -15
      Font.Name = 'Consolas'
      Font.Style = []
      ParentFont = False
      ScrollBars = ssBoth
      TabOrder = 0
      WantTabs = True
      OnKeyDown = mmoSQLKeyDown
    end
  end
  object pnlResults: TPanel
    Left = 0
    Top = 246
    Width = 850
    Height = 354
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 2
    object pnlResultsHeader: TPanel
      Left = 0
      Top = 0
      Width = 850
      Height = 30
      Align = alTop
      BevelOuter = bvNone
      Color = clWhite
      ParentBackground = False
      TabOrder = 0
      object lblResults: TLabel
        Left = 8
        Top = 8
        Width = 42
        Height = 15
        Caption = 'Results:'
      end
      object lblLimit: TLabel
        Left = 700
        Top = 8
        Width = 53
        Height = 15
        Caption = 'Row Limit:'
      end
      object cboResultLimit: TComboBox
        Left = 760
        Top = 5
        Width = 80
        Height = 23
        Style = csDropDownList
        TabOrder = 0
      end
    end
    object pgcResults: TPageControl
      Left = 0
      Top = 30
      Width = 850
      Height = 324
      ActivePage = tabGrid
      Align = alClient
      TabOrder = 1
      object tabGrid: TTabSheet
        Caption = 'Results'
        object grdResults: TStringGrid
          Left = 0
          Top = 0
          Width = 842
          Height = 294
          Align = alClient
          ColCount = 1
          DefaultRowHeight = 22
          FixedCols = 0
          RowCount = 2
          Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goRowSelect, goColSizing, goThumbTracking]
          TabOrder = 0
        end
      end
      object tabMessages: TTabSheet
        Caption = 'Messages'
        ImageIndex = 1
        object mmoMessages: TMemo
          Left = 0
          Top = 0
          Width = 842
          Height = 294
          Align = alClient
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clWindowText
          Font.Height = -13
          Font.Name = 'Consolas'
          Font.Style = []
          ParentFont = False
          ReadOnly = True
          ScrollBars = ssBoth
          TabOrder = 0
        end
      end
      object tabHistory: TTabSheet
        Caption = 'History'
        ImageIndex = 2
        object lvHistory: TListView
          Left = 0
          Top = 0
          Width = 842
          Height = 294
          Align = alClient
          Columns = <>
          HideSelection = False
          ReadOnly = True
          RowSelect = True
          TabOrder = 0
          ViewStyle = vsReport
          OnDblClick = lvHistoryDblClick
        end
      end
    end
  end
end
