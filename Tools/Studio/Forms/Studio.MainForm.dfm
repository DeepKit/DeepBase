object frmStudioMain: TfrmStudioMain
  Left = 0
  Top = 0
  Caption = 'UniBase Studio'
  ClientHeight = 700
  ClientWidth = 1000
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  TextHeight = 15
  object splSplitter: TSplitter
    Left = 200
    Top = 41
    Height = 659
    ExplicitLeft = 208
    ExplicitTop = 40
    ExplicitHeight = 100
  end
  object pnlTop: TPanel
    Left = 0
    Top = 0
    Width = 1000
    Height = 41
    Align = alTop
    BevelOuter = bvNone
    Color = clWhite
    ParentBackground = False
    TabOrder = 0
    ExplicitWidth = 994
    object lblTitle: TLabel
      Left = 16
      Top = 10
      Width = 116
      Height = 21
      Caption = 'UniBase Studio'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -16
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
    end
    object lblCurrentDB: TLabel
      Left = 290
      Top = 12
      Width = 79
      Height = 15
      Caption = 'No DB Opened'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clGrayText
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
    end
    object btnOpenDB: TButton
      Left = 150
      Top = 8
      Width = 120
      Height = 25
      Caption = 'Open Database...'
      TabOrder = 0
      OnClick = btnOpenDBClick
    end
  end
  object pnlNav: TPanel
    Left = 0
    Top = 41
    Width = 200
    Height = 659
    Align = alLeft
    BevelOuter = bvNone
    Color = clWhite
    ParentBackground = False
    TabOrder = 1
    ExplicitHeight = 642
    object catNav: TCategoryButtons
      Left = 0
      Top = 0
      Width = 200
      Height = 659
      Align = alClient
      BevelInner = bvNone
      BevelOuter = bvNone
      BorderStyle = bsNone
      ButtonFlow = cbfVertical
      ButtonHeight = 40
      ButtonWidth = 200
      Categories = <>
      RegularButtonColor = clWhite
      SelectedButtonColor = 15790320
      TabOrder = 0
      OnButtonClicked = catNavButtonClicked
      ExplicitHeight = 642
    end
  end
  object pnlClient: TPanel
    Left = 203
    Top = 41
    Width = 797
    Height = 659
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 2
    ExplicitWidth = 791
    ExplicitHeight = 642
    object cardPanel: TCardPanel
      Left = 0
      Top = 0
      Width = 797
      Height = 659
      Align = alClient
      ActiveCard = cardConfig
      BevelOuter = bvNone
      TabOrder = 0
      ExplicitWidth = 791
      ExplicitHeight = 642
      object cardConfig: TCard
        Left = 0
        Top = 0
        Width = 797
        Height = 659
        Caption = 'Configuration'
        CardIndex = 0
        TabOrder = 0
        ExplicitWidth = 791
        ExplicitHeight = 642
      end
      object cardLog: TCard
        Left = 0
        Top = 0
        Width = 797
        Height = 659
        Caption = 'Logs'
        CardIndex = 1
        TabOrder = 1
      end
      object cardHotkey: TCard
        Left = 0
        Top = 0
        Width = 797
        Height = 659
        Caption = 'Hotkeys'
        CardIndex = 2
        TabOrder = 2
      end
      object cardTheme: TCard
        Left = 0
        Top = 0
        Width = 797
        Height = 659
        Caption = 'Themes'
        CardIndex = 3
        TabOrder = 3
      end
      object cardSQL: TCard
        Left = 0
        Top = 0
        Width = 797
        Height = 659
        Caption = 'SQL Query'
        CardIndex = 4
        TabOrder = 4
      end
      object cardQueries: TCard
        Left = 0
        Top = 0
        Width = 797
        Height = 659
        Caption = 'Queries'
        CardIndex = 5
        TabOrder = 5
      end
      object cardSchema: TCard
        Left = 0
        Top = 0
        Width = 797
        Height = 659
        Caption = 'Schema'
        CardIndex = 6
        TabOrder = 6
      end
      object cardBackup: TCard
        Left = 0
        Top = 0
        Width = 797
        Height = 659
        Caption = 'Backup'
        CardIndex = 7
        TabOrder = 7
      end
      object cardImportExport: TCard
        Left = 0
        Top = 0
        Width = 797
        Height = 659
        Caption = 'Import/Export'
        CardIndex = 8
        TabOrder = 8
      end
      object cardProfile: TCard
        Left = 0
        Top = 0
        Width = 797
        Height = 659
        Caption = 'Profiler'
        CardIndex = 9
        TabOrder = 9
      end
      object cardLLM: TCard
        Left = 0
        Top = 0
        Width = 797
        Height = 659
        Caption = 'LLM Manager'
        CardIndex = 10
        TabOrder = 10
      end
      object cardPromptTemplate: TCard
        Left = 0
        Top = 0
        Width = 797
        Height = 659
        Caption = 'Prompt Templates'
        CardIndex = 11
        TabOrder = 11
      end
    end
  end
  object dlgOpenDB: TOpenDialog
    Filter = 'SQLite Database (*.db)|*.db|All Files (*.*)|*.*'
    Options = [ofHideReadOnly, ofFileMustExist, ofEnableSizing]
    Left = 344
    Top = 8
  end
end
