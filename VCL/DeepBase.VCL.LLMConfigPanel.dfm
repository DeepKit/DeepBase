object LLMConfigPanel: TLLMConfigPanel
  Left = 0
  Top = 0
  Width = 680
  Height = 560
  TabOrder = 0
  object Splitter1: TSplitter
    Left = 0
    Top = 161
    Width = 600
    Height = 3
    Cursor = crVSplit
    Align = alTop
    ExplicitTop = 153
    ExplicitWidth = 451
  end
  object pnlConfig: TPanel
    Left = 0
    Top = 0
    Width = 600
    Height = 161
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object grpConfig: TGroupBox
      Left = 8
      Top = 4
      Width = 585
      Height = 150
      Anchors = [akLeft, akTop, akRight]
      Caption = 'LLM Configuration'
      TabOrder = 0
      object lblProvider: TLabel
        Left = 16
        Top = 24
        Width = 47
        Height = 15
        Caption = 'Provider:'
      end
      object lblApiUrl: TLabel
        Left = 16
        Top = 56
        Width = 46
        Height = 15
        Caption = 'API URL:'
      end
      object lblApiKey: TLabel
        Left = 16
        Top = 88
        Width = 43
        Height = 15
        Caption = 'API Key:'
      end
      object lblModel: TLabel
        Left = 288
        Top = 24
        Width = 37
        Height = 15
        Caption = 'Model:'
      end
      object cboProvider: TComboBox
        Left = 72
        Top = 21
        Width = 145
        Height = 23
        Style = csDropDownList
        TabOrder = 0
        Items.Strings = (
          'OpenAI'
          'Azure'
          'Anthropic'
          'LiteLLM'
          'Ollama')
      end
      object edtApiUrl: TEdit
        Left = 72
        Top = 53
        Width = 497
        Height = 23
        Anchors = [akLeft, akTop, akRight]
        TabOrder = 1
      end
      object edtApiKey: TEdit
        Left = 72
        Top = 85
        Width = 497
        Height = 23
        Anchors = [akLeft, akTop, akRight]
        PasswordChar = '*'
        TabOrder = 2
      end
      object edtModel: TEdit
        Left = 336
        Top = 21
        Width = 233
        Height = 23
        Anchors = [akLeft, akTop, akRight]
        TabOrder = 3
      end
      object btnSave: TButton
        Left = 72
        Top = 116
        Width = 75
        Height = 25
        Caption = 'Save'
        TabOrder = 4
        OnClick = btnSaveClick
      end
      object btnTest: TButton
        Left = 160
        Top = 116
        Width = 105
        Height = 25
        Caption = 'Test Connection'
        TabOrder = 5
        OnClick = btnTestClick
      end
    end
  end
  object pnlHistory: TPanel
    Left = 0
    Top = 164
    Width = 600
    Height = 236
    Align = alClient
    BevelOuter = bvNone
    Caption = 'History'
    TabOrder = 1
    object lvHistory: TListView
      Left = 0
      Top = 0
      Width = 600
      Height = 236
      Align = alClient
      Columns = <
        item
          Caption = 'Time'
          Width = 130
        end
        item
          Caption = 'Prompt'
          Width = 200
        end
        item
          Caption = 'Cost ($)'
          Width = 60
        end
        item
          Caption = 'Status'
          Width = 70
        end
        item
          Caption = 'Duration'
          Width = 70
        end>
      GridLines = True
      OwnerData = True
      ReadOnly = True
      RowSelect = True
      TabOrder = 0
      ViewStyle = vsReport
      OnData = lvHistoryData
    end
  end
end
