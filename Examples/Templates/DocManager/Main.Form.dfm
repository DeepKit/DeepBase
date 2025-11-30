object MainForm: TMainForm
  Left = 0
  Top = 0
  Caption = 'Document Manager'
  ClientHeight = 600
  ClientWidth = 1000
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Menu = MainMenu1
  Position = poScreenCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnShow = FormShow
  TextHeight = 15
  object splLeft: TSplitter
    Left = 200
    Top = 29
    Height = 548
    ExplicitLeft = 192
    ExplicitTop = 168
    ExplicitHeight = 100
  end
  object splRight: TSplitter
    Left = 600
    Top = 29
    Height = 548
    ExplicitLeft = 632
    ExplicitTop = 168
    ExplicitHeight = 100
  end
  object pnlLeft: TPanel
    Left = 0
    Top = 29
    Width = 200
    Height = 548
    Align = alLeft
    BevelOuter = bvNone
    TabOrder = 0
    object tvCategories: TTreeView
      Left = 0
      Top = 0
      Width = 200
      Height = 548
      Align = alClient
      Indent = 19
      TabOrder = 0
      OnChange = tvCategoriesChange
    end
  end
  object pnlCenter: TPanel
    Left = 203
    Top = 29
    Width = 397
    Height = 548
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 1
    object pnlSearch: TPanel
      Left = 0
      Top = 0
      Width = 397
      Height = 35
      Align = alTop
      BevelOuter = bvNone
      TabOrder = 0
      object edtSearch: TEdit
        Left = 8
        Top = 6
        Width = 300
        Height = 23
        TabOrder = 0
        OnKeyPress = edtSearchKeyPress
      end
      object btnSearch: TButton
        Left = 316
        Top = 4
        Width = 75
        Height = 25
        Action = actSearch
        TabOrder = 1
      end
    end
    object lvDocuments: TListView
      Left = 0
      Top = 35
      Width = 397
      Height = 513
      Align = alClient
      Columns = <>
      PopupMenu = PopupMenu1
      TabOrder = 1
      ViewStyle = vsReport
      OnDblClick = lvDocumentsDblClick
      OnSelectItem = lvDocumentsSelectItem
    end
  end
  object pnlRight: TPanel
    Left = 603
    Top = 29
    Width = 397
    Height = 548
    Align = alRight
    BevelOuter = bvNone
    TabOrder = 2
    object pnlPreview: TPanel
      Left = 0
      Top = 0
      Width = 397
      Height = 548
      Align = alClient
      BevelOuter = bvNone
      TabOrder = 0
      object pnlPreviewTop: TPanel
        Left = 0
        Top = 0
        Width = 397
        Height = 40
        Align = alTop
        BevelOuter = bvNone
        TabOrder = 0
        object lblTitle: TLabel
          Left = 8
          Top = 12
          Width = 381
          Height = 17
          AutoSize = False
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clWindowText
          Font.Height = -14
          Font.Name = 'Segoe UI'
          Font.Style = [fsBold]
          ParentFont = False
        end
      end
      object mmoPreview: TMemo
        Left = 0
        Top = 40
        Width = 397
        Height = 508
        Align = alClient
        ReadOnly = True
        ScrollBars = ssVertical
        TabOrder = 1
      end
    end
  end
  object ToolBar1: TToolBar
    Left = 0
    Top = 0
    Width = 1000
    Height = 29
    Caption = 'ToolBar1'
    TabOrder = 3
    object tbNew: TToolButton
      Left = 0
      Top = 0
      Action = actNew
    end
    object tbOpen: TToolButton
      Left = 23
      Top = 0
      Action = actOpen
    end
    object tbSave: TToolButton
      Left = 46
      Top = 0
      Action = actSave
    end
    object tbSep1: TToolButton
      Left = 69
      Top = 0
      Width = 8
      Caption = 'tbSep1'
      Style = tbsSeparator
    end
    object tbDelete: TToolButton
      Left = 77
      Top = 0
      Action = actDelete
    end
    object tbRefresh: TToolButton
      Left = 100
      Top = 0
      Action = actRefresh
    end
  end
  object StatusBar1: TStatusBar
    Left = 0
    Top = 577
    Width = 1000
    Height = 23
    Panels = <
      item
        Width = 200
      end
      item
        Width = 200
      end>
  end
  object MainMenu1: TMainMenu
    Left = 448
    Top = 152
    object mnuFile: TMenuItem
      Caption = #25991#20214'(&F)'
      object mnuNew: TMenuItem
        Action = actNew
      end
      object mnuOpen: TMenuItem
        Action = actOpen
      end
      object mnuSave: TMenuItem
        Action = actSave
      end
      object mnuSep1: TMenuItem
        Caption = '-'
      end
      object mnuImport: TMenuItem
        Caption = #23548#20837'...'
      end
      object mnuExport: TMenuItem
        Caption = #23548#20986'...'
      end
      object mnuSep2: TMenuItem
        Caption = '-'
      end
      object mnuExit: TMenuItem
        Caption = #36864#20986'(&X)'
        OnClick = mnuExitClick
      end
    end
    object mnuEdit: TMenuItem
      Caption = #32534#36753'(&E)'
      object mnuCut: TMenuItem
        Caption = #21098#20999
        ShortCut = 16472
      end
      object mnuCopy: TMenuItem
        Caption = #22797#21046
        ShortCut = 16451
      end
      object mnuPaste: TMenuItem
        Caption = #31896#36148
        ShortCut = 16470
      end
      object mnuDelete: TMenuItem
        Action = actDelete
      end
    end
    object mnuView: TMenuItem
      Caption = #26597#30475'(&V)'
      object mnuRefresh: TMenuItem
        Action = actRefresh
      end
    end
    object mnuHelp: TMenuItem
      Caption = #24110#21161'(&H)'
      object mnuAbout: TMenuItem
        Caption = #20851#20110'...'
        OnClick = mnuAboutClick
      end
    end
  end
  object ActionList1: TActionList
    Left = 448
    Top = 216
    object actNew: TAction
      Caption = #26032#24314
      ShortCut = 16462
      OnExecute = actNewExecute
    end
    object actOpen: TAction
      Caption = #25171#24320
      ShortCut = 16463
      OnExecute = actOpenExecute
    end
    object actSave: TAction
      Caption = #20445#23384
      ShortCut = 16467
      OnExecute = actSaveExecute
    end
    object actDelete: TAction
      Caption = #21024#38500
      ShortCut = 46
      OnExecute = actDeleteExecute
    end
    object actRefresh: TAction
      Caption = #21047#26032
      ShortCut = 116
      OnExecute = actRefreshExecute
    end
    object actSearch: TAction
      Caption = #25628#32034
      OnExecute = actSearchExecute
    end
  end
  object PopupMenu1: TPopupMenu
    Left = 448
    Top = 280
    object pmnuOpen: TMenuItem
      Action = actOpen
    end
    object pmnuDelete: TMenuItem
      Action = actDelete
    end
    object pmnuSep1: TMenuItem
      Caption = '-'
    end
    object pmnuRefresh: TMenuItem
      Action = actRefresh
    end
  end
end
