object fraSchemaViewer: TfraSchemaViewer
  Left = 0
  Top = 0
  Width = 850
  Height = 600
  TabOrder = 0
  object splMain: TSplitter
    Left = 250
    Top = 41
    Height = 530
    ExplicitLeft = 168
    ExplicitTop = 40
    ExplicitHeight = 100
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
    object lblTitle: TLabel
      Left = 12
      Top = 12
      Width = 82
      Height = 15
      Caption = 'Schema Viewer'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
    end
    object btnRefresh: TButton
      Left = 730
      Top = 8
      Width = 100
      Height = 25
      Caption = 'Refresh'
      TabOrder = 0
      OnClick = btnRefreshClick
    end
  end
  object pnlLeft: TPanel
    Left = 0
    Top = 41
    Width = 250
    Height = 530
    Align = alLeft
    BevelOuter = bvNone
    TabOrder = 1
    object lblTables: TLabel
      Left = 8
      Top = 4
      Width = 38
      Height = 15
      Caption = 'Tables:'
    end
    object tvSchema: TTreeView
      Left = 0
      Top = 24
      Width = 250
      Height = 506
      Align = alBottom
      Anchors = [akLeft, akTop, akRight, akBottom]
      Indent = 19
      TabOrder = 0
      OnChange = tvSchemaChange
    end
  end
  object pnlRight: TPanel
    Left = 253
    Top = 41
    Width = 597
    Height = 530
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 2
    object pgcDetails: TPageControl
      Left = 0
      Top = 0
      Width = 597
      Height = 530
      ActivePage = tabColumns
      Align = alClient
      TabOrder = 0
      object tabColumns: TTabSheet
        Caption = 'Columns'
        object grdColumns: TStringGrid
          Left = 0
          Top = 0
          Width = 589
          Height = 500
          Align = alClient
          ColCount = 5
          DefaultRowHeight = 22
          FixedCols = 0
          RowCount = 2
          Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goRowSelect, goColSizing, goThumbTracking]
          TabOrder = 0
          ColWidths = (
            150
            120
            70
            100
            80)
        end
      end
      object tabIndexes: TTabSheet
        Caption = 'Indexes'
        ImageIndex = 1
        object grdIndexes: TStringGrid
          Left = 0
          Top = 0
          Width = 589
          Height = 500
          Align = alClient
          ColCount = 3
          DefaultRowHeight = 22
          FixedCols = 0
          RowCount = 2
          Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goRowSelect, goColSizing, goThumbTracking]
          TabOrder = 0
          ColWidths = (
            200
            60
            250)
        end
      end
      object tabForeignKeys: TTabSheet
        Caption = 'Foreign Keys'
        ImageIndex = 2
        object grdForeignKeys: TStringGrid
          Left = 0
          Top = 0
          Width = 589
          Height = 500
          Align = alClient
          ColCount = 6
          DefaultRowHeight = 22
          FixedCols = 0
          RowCount = 2
          Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goRowSelect, goColSizing, goThumbTracking]
          TabOrder = 0
          ColWidths = (
            120
            100
            100
            100
            80
            80)
        end
      end
      object tabDDL: TTabSheet
        Caption = 'DDL'
        ImageIndex = 3
        object mmoDDL: TMemo
          Left = 0
          Top = 0
          Width = 589
          Height = 500
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
          WordWrap = False
        end
      end
    end
  end
  object pnlStatus: TPanel
    Left = 0
    Top = 571
    Width = 850
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
