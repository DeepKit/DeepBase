object fraLog: TfraLog
  Left = 0
  Top = 0
  Width = 800
  Height = 500
  TabOrder = 0
  object pnlToolbar: TPanel
    Left = 0
    Top = 0
    Width = 800
    Height = 41
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object lblLevel: TLabel
      Left = 8
      Top = 12
      Width = 31
      Height = 13
      Caption = 'Level:'
    end
    object lblSearch: TLabel
      Left = 200
      Top = 12
      Width = 40
      Height = 13
      Caption = 'Search:'
    end
    object cmbLevel: TComboBox
      Left = 48
      Top = 8
      Width = 90
      Height = 21
      Style = csDropDownList
      ItemIndex = 0
      TabOrder = 0
      Text = 'All'
      OnChange = cmbLevelChange
      Items.Strings = (
        'All'
        'DEBUG'
        'INFO'
        'WARN'
        'ERROR'
        'FATAL')
    end
    object edtSearch: TEdit
      Left = 248
      Top = 8
      Width = 150
      Height = 21
      TabOrder = 1
      OnChange = edtSearchChange
    end
    object btnRefresh: TButton
      Left = 410
      Top = 8
      Width = 70
      Height = 25
      Caption = 'Refresh'
      TabOrder = 2
      OnClick = btnRefreshClick
    end
    object btnExport: TButton
      Left = 486
      Top = 8
      Width = 70
      Height = 25
      Caption = 'Export'
      TabOrder = 3
      OnClick = btnExportClick
    end
    object btnClear: TButton
      Left = 562
      Top = 8
      Width = 70
      Height = 25
      Caption = 'Clear'
      TabOrder = 4
      OnClick = btnClearClick
    end
    object chkAutoRefresh: TCheckBox
      Left = 648
      Top = 10
      Width = 90
      Height = 17
      Caption = 'Auto Refresh'
      TabOrder = 5
      OnClick = chkAutoRefreshClick
    end
  end
  object pnlLog: TPanel
    Left = 0
    Top = 41
    Width = 800
    Height = 434
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 1
    object lvLogs: TListView
      Left = 0
      Top = 0
      Width = 800
      Height = 409
      Align = alClient
      Columns = <
        item
          Caption = 'Time'
          Width = 150
        end
        item
          Caption = 'Level'
          Width = 60
        end
        item
          Caption = 'Source'
          Width = 120
        end
        item
          Caption = 'Message'
          Width = 450
        end>
      GridLines = True
      ReadOnly = True
      RowSelect = True
      TabOrder = 0
      ViewStyle = vsReport
      OnDblClick = lvLogsDblClick
    end
    object StatusBar: TStatusBar
      Left = 0
      Top = 409
      Width = 800
      Height = 25
      Panels = <
        item
          Width = 150
        end
        item
          Width = 200
        end
        item
          Width = 50
        end>
    end
  end
  object tmrAutoRefresh: TTimer
    Enabled = False
    Interval = 3000
    OnTimer = tmrAutoRefreshTimer
    Left = 760
    Top = 8
  end
  object dlgSave: TSaveDialog
    DefaultExt = 'csv'
    Filter = 'CSV Files (*.csv)|*.csv|Text Files (*.txt)|*.txt|All Files (*.*)|*.*'
    Left = 728
    Top = 8
  end
end
