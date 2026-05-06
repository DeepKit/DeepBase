object LLMSettingsFrame: TLLMSettingsFrame
  Left = 0
  Top = 0
  Width = 900
  Height = 600
  TabOrder = 0
  object PgSettings: TPageControl
    Left = 0
    Top = 0
    Width = 900
    Height = 600
    ActivePage = TabProviders
    Align = alClient
    TabOrder = 0
    object TabProviders: TTabSheet
      Caption = 'Providers'
      object LbProviders: TListBox
        Left = 12
        Top = 12
        Width = 180
        Height = 480
        ItemHeight = 13
        TabOrder = 0
        OnClick = LbProvidersClick
      end
      object BtnAddProvider: TButton
        Left = 12
        Top = 500
        Width = 84
        Height = 28
        Caption = 'Add'
        TabOrder = 1
        OnClick = BtnAddProviderClick
      end
      object BtnDeleteProvider: TButton
        Left = 108
        Top = 500
        Width = 84
        Height = 28
        Caption = 'Delete'
        TabOrder = 2
        OnClick = BtnDeleteProviderClick
      end
      object LblProviderName: TLabel
        Left = 220
        Top = 16
        Width = 76
        Height = 13
        Caption = 'Provider Name'
      end
      object EdtProviderName: TEdit
        Left = 340
        Top = 12
        Width = 300
        Height = 21
        TabOrder = 3
      end
      object LblEndpoint: TLabel
        Left = 220
        Top = 48
        Width = 44
        Height = 13
        Caption = 'Endpoint'
      end
      object EdtEndpoint: TEdit
        Left = 340
        Top = 44
        Width = 420
        Height = 21
        TabOrder = 4
      end
      object LblApiKey: TLabel
        Left = 220
        Top = 80
        Width = 38
        Height = 13
        Caption = 'API Key'
      end
      object EdtApiKey: TEdit
        Left = 340
        Top = 76
        Width = 420
        Height = 21
        PasswordChar = '*'
        TabOrder = 5
      end
      object LblApiFormat: TLabel
        Left = 220
        Top = 112
        Width = 52
        Height = 13
        Caption = 'API Format'
      end
      object CmbApiFormat: TComboBox
        Left = 340
        Top = 108
        Width = 160
        Height = 21
        Style = csDropDownList
        ItemIndex = 0
        TabOrder = 6
        Text = 'openai'
        Items.Strings = (
          'openai'
          'anthropic')
      end
      object BtnSaveProvider: TButton
        Left = 340
        Top = 144
        Width = 120
        Height = 28
        Caption = 'Save Provider'
        TabOrder = 7
        OnClick = BtnSaveProviderClick
      end
      object BtnFetchModels: TButton
        Left = 476
        Top = 144
        Width = 120
        Height = 28
        Caption = 'Models'
        TabOrder = 8
        OnClick = BtnFetchModelsClick
      end
      object LblProviderModels: TLabel
        Left = 220
        Top = 196
        Width = 36
        Height = 13
        Caption = 'Models'
      end
      object LbProviderModels: TListBox
        Left = 220
        Top = 216
        Width = 540
        Height = 276
        ItemHeight = 13
        TabOrder = 9
      end
    end
    object TabTiers: TTabSheet
      Caption = 'Tiers'
      ImageIndex = 1
      object LblTierProvider: TLabel
        Left = 12
        Top = 16
        Width = 40
        Height = 13
        Caption = 'Provider'
      end
      object CmbTierProvider: TComboBox
        Left = 84
        Top = 12
        Width = 220
        Height = 21
        Style = csDropDownList
        TabOrder = 0
        OnChange = CmbTierProviderChange
      end
      object BtnRefreshModels: TButton
        Left = 320
        Top = 10
        Width = 120
        Height = 26
        Caption = 'Refresh Models'
        TabOrder = 1
        OnClick = BtnRefreshModelsClick
      end
      object LblAllModels: TLabel
        Left = 12
        Top = 52
        Width = 50
        Height = 13
        Caption = 'All Models'
      end
      object LbAllModels: TListBox
        Left = 12
        Top = 72
        Width = 220
        Height = 360
        ItemHeight = 13
        TabOrder = 2
      end
      object BtnToSmart: TButton
        Left = 248
        Top = 96
        Width = 74
        Height = 25
        Caption = 'Smart >'
        TabOrder = 3
        OnClick = BtnToSmartClick
      end
      object BtnFromSmart: TButton
        Left = 248
        Top = 128
        Width = 74
        Height = 25
        Caption = '< Smart'
        TabOrder = 4
        OnClick = BtnFromSmartClick
      end
      object BtnToBalanced: TButton
        Left = 248
        Top = 224
        Width = 74
        Height = 25
        Caption = 'Balanced >'
        TabOrder = 5
        OnClick = BtnToBalancedClick
      end
      object BtnFromBalanced: TButton
        Left = 248
        Top = 256
        Width = 74
        Height = 25
        Caption = '< Balanced'
        TabOrder = 6
        OnClick = BtnFromBalancedClick
      end
      object BtnToFast: TButton
        Left = 248
        Top = 352
        Width = 74
        Height = 25
        Caption = 'Fast >'
        TabOrder = 7
        OnClick = BtnToFastClick
      end
      object BtnFromFast: TButton
        Left = 248
        Top = 384
        Width = 74
        Height = 25
        Caption = '< Fast'
        TabOrder = 8
        OnClick = BtnFromFastClick
      end
      object LblSmartTitle: TLabel
        Left = 340
        Top = 52
        Width = 28
        Height = 13
        Caption = 'Smart'
      end
      object LbSmart: TListBox
        Left = 340
        Top = 72
        Width = 380
        Height = 100
        ItemHeight = 13
        TabOrder = 9
        OnMouseDown = TierListMouseDown
      end
      object BtnSmartUp: TButton
        Left = 732
        Top = 72
        Width = 48
        Height = 25
        Caption = 'Up'
        TabOrder = 10
        OnClick = BtnSmartUpClick
      end
      object BtnSmartDown: TButton
        Left = 732
        Top = 104
        Width = 48
        Height = 25
        Caption = 'Down'
        TabOrder = 11
        OnClick = BtnSmartDownClick
      end
      object LblBalancedTitle: TLabel
        Left = 340
        Top = 188
        Width = 43
        Height = 13
        Caption = 'Balanced'
      end
      object LbBalanced: TListBox
        Left = 340
        Top = 208
        Width = 380
        Height = 100
        ItemHeight = 13
        TabOrder = 12
        OnMouseDown = TierListMouseDown
      end
      object BtnBalancedUp: TButton
        Left = 732
        Top = 208
        Width = 48
        Height = 25
        Caption = 'Up'
        TabOrder = 13
        OnClick = BtnBalancedUpClick
      end
      object BtnBalancedDown: TButton
        Left = 732
        Top = 240
        Width = 48
        Height = 25
        Caption = 'Down'
        TabOrder = 14
        OnClick = BtnBalancedDownClick
      end
      object LblFastTitle: TLabel
        Left = 340
        Top = 324
        Width = 20
        Height = 13
        Caption = 'Fast'
      end
      object LbFast: TListBox
        Left = 340
        Top = 344
        Width = 380
        Height = 100
        ItemHeight = 13
        TabOrder = 15
        OnMouseDown = TierListMouseDown
      end
      object BtnFastUp: TButton
        Left = 732
        Top = 344
        Width = 48
        Height = 25
        Caption = 'Up'
        TabOrder = 16
        OnClick = BtnFastUpClick
      end
      object BtnFastDown: TButton
        Left = 732
        Top = 376
        Width = 48
        Height = 25
        Caption = 'Down'
        TabOrder = 17
        OnClick = BtnFastDownClick
      end
    end
    object TabTest: TTabSheet
      Caption = 'Test'
      ImageIndex = 2
      object LblTestProvider: TLabel
        Left = 12
        Top = 16
        Width = 40
        Height = 13
        Caption = 'Provider'
      end
      object LbTestProviders: TListBox
        Left = 12
        Top = 36
        Width = 180
        Height = 180
        ItemHeight = 13
        TabOrder = 0
        OnClick = LbTestProvidersClick
      end
      object LblTestModel: TLabel
        Left = 212
        Top = 16
        Width = 29
        Height = 13
        Caption = 'Model'
      end
      object LbTestModels: TListBox
        Left = 212
        Top = 36
        Width = 260
        Height = 180
        ItemHeight = 13
        TabOrder = 1
      end
      object LblTestPrompt: TLabel
        Left = 492
        Top = 16
        Width = 34
        Height = 13
        Caption = 'Prompt'
      end
      object MemTestPrompt: TMemo
        Left = 492
        Top = 36
        Width = 340
        Height = 100
        Lines.Strings = (
          '你是什么模型？')
        TabOrder = 2
      end
      object BtnTest: TButton
        Left = 492
        Top = 148
        Width = 100
        Height = 28
        Caption = 'Test'
        TabOrder = 3
        OnClick = BtnTestClick
      end
      object LblElapsed: TLabel
        Left = 608
        Top = 156
        Width = 3
        Height = 13
      end
      object MemTestResponse: TMemo
        Left = 12
        Top = 236
        Width = 820
        Height = 260
        ReadOnly = True
        ScrollBars = ssVertical
        TabOrder = 4
      end
    end
  end
  object PopupTier: TPopupMenu
    Left = 808
    Top = 528
    object MnuPrimary: TMenuItem
      Caption = 'Primary'
      OnClick = MnuPrimaryClick
    end
    object MnuFallback: TMenuItem
      Caption = 'Fallback'
      OnClick = MnuFallbackClick
    end
    object MnuDisabled: TMenuItem
      Caption = 'Disabled'
      OnClick = MnuDisabledClick
    end
  end
end
