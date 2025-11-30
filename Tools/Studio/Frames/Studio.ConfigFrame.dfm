object fraConfig: TfraConfig
  Left = 0
  Top = 0
  Width = 451
  Height = 304
  TabOrder = 0
  object pnlToolbar: TPanel
    Left = 0
    Top = 0
    Width = 451
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
    object btnAdd: TButton
      Left = 89
      Top = 8
      Width = 75
      Height = 25
      Caption = 'Add Key'
      TabOrder = 1
      OnClick = btnAddClick
    end
    object btnDelete: TButton
      Left = 170
      Top = 8
      Width = 75
      Height = 25
      Caption = 'Delete'
      TabOrder = 2
      OnClick = btnDeleteClick
    end
  end
  object vleConfig: TValueListEditor
    Left = 0
    Top = 41
    Width = 451
    Height = 263
    Align = alClient
    TabOrder = 1
    TitleCaptions.Strings = (
      'Key'
      'Value')
    OnStringsChange = vleConfigStringsChange
    ColWidths = (
      150
      295)
  end
end
