object fraBackupWizard: TfraBackupWizard
  Left = 0
  Top = 0
  Width = 850
  Height = 600
  TabOrder = 0
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
      Width = 116
      Height = 15
      Caption = 'Backup/Restore Wizard'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
    end
    object btnCreateBackup: TButton
      Left = 450
      Top = 8
      Width = 100
      Height = 25
      Caption = 'Create Backup'
      TabOrder = 0
      OnClick = btnCreateBackupClick
    end
    object btnRestoreBackup: TButton
      Left = 560
      Top = 8
      Width = 100
      Height = 25
      Caption = 'Restore'
      Enabled = False
      TabOrder = 1
      OnClick = btnRestoreBackupClick
    end
    object btnDeleteBackup: TButton
      Left = 670
      Top = 8
      Width = 80
      Height = 25
      Caption = 'Delete'
      Enabled = False
      TabOrder = 2
      OnClick = btnDeleteBackupClick
    end
    object btnRefresh: TButton
      Left = 760
      Top = 8
      Width = 80
      Height = 25
      Caption = 'Refresh'
      TabOrder = 3
      OnClick = btnRefreshClick
    end
  end
  object pnlMain: TPanel
    Left = 0
    Top = 41
    Width = 550
    Height = 500
    Align = alLeft
    BevelOuter = bvNone
    TabOrder = 1
    object lblBackups: TLabel
      Left = 8
      Top = 4
      Width = 89
      Height = 15
      Caption = 'Available Backups:'
    end
    object lvBackups: TListView
      Left = 0
      Top = 24
      Width = 550
      Height = 476
      Align = alBottom
      Anchors = [akLeft, akTop, akRight, akBottom]
      Columns = <>
      HideSelection = False
      ReadOnly = True
      RowSelect = True
      TabOrder = 0
      ViewStyle = vsReport
      OnSelectItem = lvBackupsSelectItem
    end
  end
  object pnlDetails: TPanel
    Left = 550
    Top = 41
    Width = 300
    Height = 500
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 2
    object lblDetailsTitle: TLabel
      Left = 16
      Top = 8
      Width = 79
      Height = 15
      Caption = 'Backup Details:'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
    end
    object lblFileName: TLabel
      Left = 16
      Top = 40
      Width = 28
      Height = 15
      Caption = 'File:'
    end
    object lblFileNameValue: TLabel
      Left = 80
      Top = 40
      Width = 4
      Height = 15
      Caption = '-'
    end
    object lblCreated: TLabel
      Left = 16
      Top = 65
      Width = 45
      Height = 15
      Caption = 'Created:'
    end
    object lblCreatedValue: TLabel
      Left = 80
      Top = 65
      Width = 4
      Height = 15
      Caption = '-'
    end
    object lblSize: TLabel
      Left = 16
      Top = 90
      Width = 23
      Height = 15
      Caption = 'Size:'
    end
    object lblSizeValue: TLabel
      Left = 80
      Top = 90
      Width = 4
      Height = 15
      Caption = '-'
    end
    object lblDescription: TLabel
      Left = 16
      Top = 125
      Width = 113
      Height = 15
      Caption = 'Description (optional):'
    end
    object mmoDescription: TMemo
      Left = 16
      Top = 145
      Width = 268
      Height = 100
      ScrollBars = ssVertical
      TabOrder = 0
    end
    object chkCompress: TCheckBox
      Left = 16
      Top = 260
      Width = 200
      Height = 17
      Caption = 'Compress backup (ZIP)'
      Checked = True
      State = cbChecked
      TabOrder = 1
    end
  end
  object pnlStatus: TPanel
    Left = 0
    Top = 541
    Width = 850
    Height = 59
    Align = alBottom
    BevelOuter = bvNone
    Color = clWhite
    ParentBackground = False
    TabOrder = 3
    object lblStatus: TLabel
      Left = 8
      Top = 8
      Width = 3
      Height = 15
    end
    object prgProgress: TProgressBar
      Left = 8
      Top = 30
      Width = 830
      Height = 20
      TabOrder = 0
      Visible = False
    end
  end
end
