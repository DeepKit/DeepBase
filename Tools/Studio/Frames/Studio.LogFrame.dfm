object fraLog: TfraLog
  Left = 0
  Top = 0
  Width = 600
  Height = 400
  TabOrder = 0
  object pnlToolbar: TPanel
    Left = 0
    Top = 0
    Width = 600
    Height = 41
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object btnRefresh: TButton
      Left = 8
      Top = 8
      Width = 75
      Height = 25
      Caption = 'Refresh'
      TabOrder = 0
      OnClick = btnRefreshClick
    end
    object btnClear: TButton
      Left = 89
      Top = 8
      Width = 75
      Height = 25
      Caption = 'Clear'
      TabOrder = 1
      OnClick = btnClearClick
    end
  end
  object pnlLog: TPanel
    Left = 0
    Top = 41
    Width = 600
    Height = 359
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 1
    object lvLogs: TListView
      Left = 0
      Top = 0
      Width = 600
      Height = 359
      Align = alClient
      Columns = <
        item
          Caption = 'Time'
          Width = 140
        end
        item
          Caption = 'Level'
          Width = 60
        end
        item
          Caption = 'Source'
          Width = 100
        end
        item
          Caption = 'Message'
          Width = 400
        end>
      GridLines = True
      ReadOnly = True
      RowSelect = True
      TabOrder = 0
      ViewStyle = vsReport
    end
  end
end
