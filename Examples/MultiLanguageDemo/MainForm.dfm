object frmMain: TfrmMain
  Left = 0
  Top = 0
  Caption = 'MultiLanguage Demo'
  ClientHeight = 480
  ClientWidth = 640
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 15
  object PanelTop: TPanel
    Left = 0
    Top = 0
    Width = 640
    Height = 50
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object LabelTitle: TLabel
      Left = 16
      Top = 16
      Width = 180
      Height = 20
      Caption = 'DeepBase i18n Demo'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -15
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
    end
    object LabelLanguage: TLabel
      Left = 400
      Top = 18
      Width = 58
      Height = 15
      Caption = 'Language:'
    end
    object ComboLanguage: TComboBox
      Left = 468
      Top = 14
      Width = 156
      Height = 23
      Style = csDropDownList
      TabOrder = 0
      OnChange = ComboLanguageChange
    end
  end
  object PageControl1: TPageControl
    Left = 0
    Top = 50
    Width = 640
    Height = 430
    ActivePage = TabBasic
    Align = alClient
    TabOrder = 1
    object TabBasic: TTabSheet
      Caption = 'Basic T()'
      object LabelWelcome: TLabel
        Left = 16
        Top = 16
        Width = 60
        Height = 20
        Caption = 'Welcome!'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -15
        Font.Name = 'Segoe UI'
        Font.Style = [fsBold]
        ParentFont = False
      end
      object LabelTranslateDemo: TLabel
        Left = 16
        Top = 48
        Width = 308
        Height = 15
        Caption = 'Enter a translation key (e.g. Hello, Save, Cancel, Settings):'
      end
      object LabelResult: TLabel
        Left = 16
        Top = 112
        Width = 38
        Height = 15
        Caption = 'Result:'
      end
      object EditInput: TEdit
        Left = 16
        Top = 72
        Width = 200
        Height = 23
        TabOrder = 0
        Text = 'Hello'
      end
      object ButtonTranslate: TButton
        Left = 224
        Top = 70
        Width = 90
        Height = 27
        Caption = 'Translate'
        TabOrder = 1
        OnClick = ButtonTranslateClick
      end
      object MemoLog: TMemo
        Left = 16
        Top = 144
        Width = 593
        Height = 241
        ReadOnly = True
        ScrollBars = ssVertical
        TabOrder = 2
      end
    end
    object TabFormatted: TTabSheet
      Caption = 'TFmt()'
      ImageIndex = 1
      object LabelFmtDemo: TLabel
        Left = 16
        Top = 16
        Width = 340
        Height = 15
        Caption = 'TFmt() translates and formats strings with arguments:'
      end
      object LabelName: TLabel
        Left = 16
        Top = 48
        Width = 38
        Height = 15
        Caption = 'Name:'
      end
      object LabelAge: TLabel
        Left = 16
        Top = 80
        Width = 24
        Height = 15
        Caption = 'Age:'
      end
      object LabelFmtResult: TLabel
        Left = 16
        Top = 152
        Width = 38
        Height = 20
        Caption = 'Result'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clNavy
        Font.Height = -15
        Font.Name = 'Segoe UI'
        Font.Style = [fsBold]
        ParentFont = False
      end
      object EditName: TEdit
        Left = 72
        Top = 44
        Width = 150
        Height = 23
        TabOrder = 0
        Text = 'Alice'
      end
      object EditAge: TEdit
        Left = 72
        Top = 76
        Width = 60
        Height = 23
        TabOrder = 1
        Text = '25'
      end
      object ButtonFormat: TButton
        Left = 16
        Top = 112
        Width = 90
        Height = 27
        Caption = 'Format'
        TabOrder = 2
        OnClick = ButtonFormatClick
      end
    end
    object TabPlural: TTabSheet
      Caption = 'TN() Plural'
      ImageIndex = 2
      object LabelPluralDemo: TLabel
        Left = 16
        Top = 16
        Width = 285
        Height = 15
        Caption = 'TN() handles singular/plural forms automatically:'
      end
      object LabelCount: TLabel
        Left = 16
        Top = 48
        Width = 38
        Height = 15
        Caption = 'Count:'
      end
      object LabelPluralResult: TLabel
        Left = 16
        Top = 120
        Width = 38
        Height = 20
        Caption = 'Result'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clNavy
        Font.Height = -15
        Font.Name = 'Segoe UI'
        Font.Style = [fsBold]
        ParentFont = False
      end
      object EditCount: TEdit
        Left = 72
        Top = 44
        Width = 60
        Height = 23
        TabOrder = 0
        Text = '1'
      end
      object ButtonPlural: TButton
        Left = 16
        Top = 80
        Width = 90
        Height = 27
        Caption = 'Test Plural'
        TabOrder = 1
        OnClick = ButtonPluralClick
      end
    end
    object TabControls: TTabSheet
      Caption = 'I18n Controls'
      ImageIndex = 3
      object LabelControlsNote: TLabel
        Left = 16
        Top = 16
        Width = 430
        Height = 15
        Caption = 'TI18nLabel and TI18nButton auto-update when language changes:'
      end
      object GroupI18nControls: TGroupBox
        Left = 16
        Top = 48
        Width = 400
        Height = 200
        Caption = 'I18n-Aware Controls'
        TabOrder = 0
        object I18nLabel1: TI18nLabel
          Left = 24
          Top = 32
          Width = 60
          Height = 15
          Caption = 'Open File'
          I18nKey = 'Open File'
        end
        object I18nLabel2: TI18nLabel
          Left = 24
          Top = 60
          Width = 45
          Height = 15
          Caption = 'Settings'
          I18nKey = 'Settings'
        end
        object I18nButton1: TI18nButton
          Left = 24
          Top = 100
          Width = 100
          Height = 30
          Caption = 'Save'
          TabOrder = 0
          I18nKey = 'Save'
          OnClick = I18nButton1Click
        end
        object I18nButton2: TI18nButton
          Left = 140
          Top = 100
          Width = 100
          Height = 30
          Caption = 'Cancel'
          TabOrder = 1
          I18nKey = 'Cancel'
          OnClick = I18nButton2Click
        end
      end
    end
  end
end
