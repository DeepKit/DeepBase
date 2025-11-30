object fraProfiler: TfraProfiler
  Left = 0
  Top = 0
  Width = 900
  Height = 650
  TabOrder = 0
  object pnlToolbar: TPanel
    Left = 0
    Top = 0
    Width = 900
    Height = 41
    Align = alTop
    BevelOuter = bvNone
    Color = clWhite
    ParentBackground = False
    TabOrder = 0
    object lblTitle: TLabel
      Left = 12
      Top = 12
      Width = 109
      Height = 15
      Caption = 'Performance Profiler'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
    end
    object btnRefresh: TButton
      Left = 700
      Top = 8
      Width = 80
      Height = 25
      Caption = 'Refresh'
      TabOrder = 0
      OnClick = btnRefreshClick
    end
    object btnAnalyze: TButton
      Left = 790
      Top = 8
      Width = 100
      Height = 25
      Caption = 'Run ANALYZE'
      TabOrder = 1
      OnClick = btnAnalyzeClick
    end
  end
  object pnlMain: TPanel
    Left = 0
    Top = 41
    Width = 900
    Height = 559
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 1
    object pgcMain: TPageControl
      Left = 0
      Top = 0
      Width = 900
      Height = 559
      ActivePage = tabStats
      Align = alClient
      TabOrder = 0
      object tabStats: TTabSheet
        Caption = 'Table Statistics'
        object lvStats: TListView
          Left = 0
          Top = 0
          Width = 892
          Height = 489
          Align = alClient
          Columns = <>
          HideSelection = False
          ReadOnly = True
          RowSelect = True
          TabOrder = 0
          ViewStyle = vsReport
        end
        object pnlStatsFooter: TPanel
          Left = 0
          Top = 489
          Width = 892
          Height = 40
          Align = alBottom
          BevelOuter = bvNone
          TabOrder = 1
          object lblTotalRows: TLabel
            Left = 16
            Top = 12
            Width = 60
            Height = 15
            Caption = 'Total Rows:'
          end
          object lblTotalSize: TLabel
            Left = 200
            Top = 12
            Width = 75
            Height = 15
            Caption = 'Estimated Size:'
          end
        end
      end
      object tabQueryPlan: TTabSheet
        Caption = 'Query Plan'
        ImageIndex = 1
        object pnlQueryTop: TPanel
          Left = 0
          Top = 0
          Width = 892
          Height = 200
          Align = alTop
          BevelOuter = bvNone
          TabOrder = 0
          object lblQuery: TLabel
            Left = 8
            Top = 8
            Width = 156
            Height = 15
            Caption = 'Enter SQL query to analyze:'
          end
          object mmoQuery: TMemo
            Left = 8
            Top = 28
            Width = 780
            Height = 160
            Font.Charset = DEFAULT_CHARSET
            Font.Color = clWindowText
            Font.Height = -13
            Font.Name = 'Consolas'
            Font.Style = []
            ParentFont = False
            ScrollBars = ssBoth
            TabOrder = 0
            WordWrap = False
          end
          object btnExplain: TButton
            Left = 800
            Top = 28
            Width = 80
            Height = 30
            Caption = 'Explain'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = clWindowText
            Font.Height = -12
            Font.Name = 'Segoe UI'
            Font.Style = [fsBold]
            ParentFont = False
            TabOrder = 1
            OnClick = btnExplainClick
          end
        end
        object pnlQueryBottom: TPanel
          Left = 0
          Top = 200
          Width = 892
          Height = 329
          Align = alClient
          BevelOuter = bvNone
          TabOrder = 1
          object lblPlan: TLabel
            Left = 8
            Top = 8
            Width = 62
            Height = 15
            Caption = 'Query Plan:'
          end
          object mmoExplain: TMemo
            Left = 8
            Top = 28
            Width = 876
            Height = 293
            Anchors = [akLeft, akTop, akRight, akBottom]
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
      object tabIndexes: TTabSheet
        Caption = 'Indexes'
        ImageIndex = 2
        object lvIndexes: TListView
          Left = 0
          Top = 0
          Width = 892
          Height = 489
          Align = alClient
          Columns = <>
          HideSelection = False
          ReadOnly = True
          RowSelect = True
          TabOrder = 0
          ViewStyle = vsReport
        end
        object pnlIndexFooter: TPanel
          Left = 0
          Top = 489
          Width = 892
          Height = 40
          Align = alBottom
          BevelOuter = bvNone
          TabOrder = 1
          object lblIndexCount: TLabel
            Left = 16
            Top = 12
            Width = 73
            Height = 15
            Caption = 'Total Indexes:'
          end
        end
      end
      object tabSuggestions: TTabSheet
        Caption = 'Suggestions'
        ImageIndex = 3
        object mmoSuggestions: TMemo
          Left = 0
          Top = 0
          Width = 892
          Height = 529
          Align = alClient
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clWindowText
          Font.Height = -13
          Font.Name = 'Segoe UI'
          Font.Style = []
          ParentFont = False
          ReadOnly = True
          ScrollBars = ssVertical
          TabOrder = 0
        end
      end
    end
  end
  object pnlStatus: TPanel
    Left = 0
    Top = 600
    Width = 900
    Height = 50
    Align = alBottom
    BevelOuter = bvNone
    Color = clWhite
    ParentBackground = False
    TabOrder = 2
    object lblStatus: TLabel
      Left = 12
      Top = 8
      Width = 3
      Height = 15
    end
    object prgProgress: TProgressBar
      Left = 12
      Top = 28
      Width = 876
      Height = 17
      TabOrder = 0
      Visible = False
    end
  end
end
