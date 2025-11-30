object frmMain: TfrmMain
  Left = 0
  Top = 0
  Caption = 'UniBase Phase 1 Demo (VCL Controls)'
  ClientHeight = 600
  ClientWidth = 900
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 15
  object pnlLeft: TPanel
    Left = 0
    Top = 0
    Width = 250
    Height = 600
    Align = alLeft
    BevelOuter = bvNone
    ParentBackground = False
    TabOrder = 0
    object pnlSettings: TPanel
      Left = 0
      Top = 0
      Width = 250
      Height = 200
      Align = alTop
      BevelOuter = bvNone
      TabOrder = 0
      object lblLanguage: TI18nLabel
        Left = 16
        Top = 16
        Width = 53
        Height = 15
        Caption = 'Language'
        TextKey = 'Language'
  object FDGUIxWaitCursor1: TFDGUIxWaitCursor
    Provider = 'Forms'
    Left = 840
    Top = 16
  end
end
      object lblTheme: TI18nLabel
        Left = 16
        Top = 72
        Width = 38
        Height = 15
        Caption = 'Theme'
        TextKey = 'Theme'
      end
      object cboLanguage: TLanguageComboBox
        Left = 16
        Top = 37
        Width = 217
        Height = 23
        TabOrder = 0
      end
      object cboTheme: TThemeComboBox
        Left = 16
        Top = 93
        Width = 217
        Height = 23
        TabOrder = 1
      end
    end
    object pnlConfig: TPanel
      Left = 0
      Top = 200
      Width = 250
      Height = 400
      Align = alClient
      BevelOuter = bvNone
      TabOrder = 1
      object lblTestConfig: TI18nLabel
        Left = 16
        Top = 16
        Width = 60
        Height = 15
        Caption = 'Test Config'
        TextKey = 'Test Config'
      end
      object edtTestConfig: TConfigEdit
        Left = 16
        Top = 37
        Width = 217
        Height = 23
        TabOrder = 0
        Text = ''
        ConfigKey = 'Demo.TestString'
        DefaultValue = 'Hello'
      end
      object chkAutoSave: TConfigCheckBox
        Left = 16
        Top = 80
        Width = 217
        Height = 17
        Caption = 'Auto Save'
        TabOrder = 1
        ConfigKey = 'App.AutoSaveDemo'
      end
      object btnTestLog: TI18nButton
        Left = 16
        Top = 120
        Width = 217
        Height = 25
        Caption = 'Add Log'
        TabOrder = 2
        OnClick = btnTestLogClick
        TextKey = 'Add Log'
      end
    end
  end
  object splSplitter: TSplitter
    Left = 250
    Top = 0
    Height = 600
    ExplicitLeft = 256
    ExplicitTop = 288
    ExplicitHeight = 100
  end
  object pnlRight: TPanel
    Left = 253
    Top = 0
    Width = 647
    Height = 600
    Align = alClient
    BevelOuter = bvNone
    ParentBackground = False
    TabOrder = 1
    object pnlLog: TPanel
      Left = 0
      Top = 0
      Width = 647
      Height = 600
      Align = alClient
      BevelOuter = bvNone
      Caption = 'Log'
      TabOrder = 0
      object LogListView1: TLogListView
        Left = 0
        Top = 0
        Width = 647
        Height = 600
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
          end
          item
            Caption = 'Thread'
            Width = 60
          end>
        GridLines = True
        OwnerData = True
        ReadOnly = True
        RowSelect = True
        TabOrder = 0
        ViewStyle = vsReport
      end
    end
  end
