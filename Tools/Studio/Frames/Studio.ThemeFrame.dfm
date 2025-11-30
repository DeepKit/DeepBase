object fraTheme: TfraTheme
  Left = 0
  Top = 0
  Width = 750
  Height = 500
  TabOrder = 0
  object splSplitter: TSplitter
    Left = 300
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
    object lblTitle: TLabel
      Left = 12
      Top = 12
      Width = 82
      Height = 15
      Caption = 'Theme Settings'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
    end
    object btnApply: TButton
      Left = 620
      Top = 8
      Width = 120
      Height = 25
      Caption = 'Apply Theme'
      TabOrder = 0
      OnClick = btnApplyClick
    end
  end
  object pnlLeft: TPanel
    Left = 0
    Top = 41
    Width = 300
    Height = 430
    Align = alLeft
    BevelOuter = bvNone
    TabOrder = 1
    object lblThemes: TLabel
      Left = 8
      Top = 4
      Width = 94
      Height = 15
      Caption = 'Available Themes:'
    end
    object lvThemes: TListView
      Left = 0
      Top = 24
      Width = 300
      Height = 406
      Align = alBottom
      Anchors = [akLeft, akTop, akRight, akBottom]
      Columns = <>
      HideSelection = False
      ReadOnly = True
      RowSelect = True
      TabOrder = 0
      ViewStyle = vsReport
      OnDblClick = lvThemesDblClick
      OnSelectItem = lvThemesSelectItem
    end
  end
  object pnlRight: TPanel
    Left = 303
    Top = 41
    Width = 447
    Height = 430
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 2
    object pnlPreviewHeader: TPanel
      Left = 0
      Top = 0
      Width = 447
      Height = 30
      Align = alTop
      BevelOuter = bvNone
      Color = clWhite
      ParentBackground = False
      TabOrder = 0
      object lblPreview: TLabel
        Left = 8
        Top = 8
        Width = 46
        Height = 15
        Caption = 'Preview:'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -12
        Font.Name = 'Segoe UI'
        Font.Style = [fsBold]
        ParentFont = False
      end
    end
    object pnlPreviewContent: TPanel
      Left = 0
      Top = 30
      Width = 447
      Height = 400
      Align = alClient
      BevelOuter = bvNone
      TabOrder = 1
      object grpSampleControls: TGroupBox
        Left = 16
        Top = 16
        Width = 400
        Height = 350
        Caption = 'Sample Controls'
        TabOrder = 0
        object lblSampleLabel: TLabel
          Left = 16
          Top = 30
          Width = 94
          Height = 15
          Caption = 'This is a TLabel:'
        end
        object edtSampleEdit: TEdit
          Left = 16
          Top = 55
          Width = 200
          Height = 23
          TabOrder = 0
          Text = 'Sample Edit Text'
        end
        object btnSampleButton: TButton
          Left = 230
          Top = 53
          Width = 120
          Height = 27
          Caption = 'Sample Button'
          TabOrder = 1
        end
        object chkSampleCheck: TCheckBox
          Left = 16
          Top = 95
          Width = 150
          Height = 17
          Caption = 'Sample CheckBox'
          TabOrder = 2
        end
        object cboSampleCombo: TComboBox
          Left = 180
          Top = 93
          Width = 170
          Height = 23
          Style = csDropDownList
          TabOrder = 3
        end
        object prgSampleProgress: TProgressBar
          Left = 16
          Top = 135
          Width = 334
          Height = 20
          TabOrder = 4
        end
        object trkSampleTrack: TTrackBar
          Left = 12
          Top = 170
          Width = 338
          Height = 30
          Max = 10
          TabOrder = 5
        end
        object rdoSample1: TRadioButton
          Left = 16
          Top = 215
          Width = 120
          Height = 17
          Caption = 'Radio Option 1'
          TabOrder = 6
        end
        object rdoSample2: TRadioButton
          Left = 150
          Top = 215
          Width = 120
          Height = 17
          Caption = 'Radio Option 2'
          TabOrder = 7
        end
      end
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
