object MainForm: TMainForm
  Left = 0
  Top = 0
  Caption = 'Customer Management - CRUD Template'
  ClientHeight = 500
  ClientWidth = 800
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Menu = MainMenu
  Position = poScreenCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnShow = FormShow
  TextHeight = 15
  object PnlTop: TPanel
    Left = 0
    Top = 0
    Width = 800
    Height = 49
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object LblSearch: TLabel
      Left = 8
      Top = 16
      Width = 39
      Height = 15
      Caption = 'Search:'
    end
    object LblStatus: TLabel
      Left = 360
      Top = 16
      Width = 35
      Height = 15
      Caption = 'Status:'
    end
    object EdtSearch: TEdit
      Left = 56
      Top = 13
      Width = 201
      Height = 23
      TabOrder = 0
      OnChange = EdtSearchChange
    end
    object BtnSearch: TButton
      Left = 263
      Top = 12
      Width = 75
      Height = 25
      Caption = 'Search'
      TabOrder = 1
      OnClick = ActRefreshExecute
    end
    object CmbStatus: TComboBox
      Left = 401
      Top = 13
      Width = 121
      Height = 23
      Style = csDropDownList
      TabOrder = 2
      OnChange = CmbStatusChange
    end
  end
  object PnlBottom: TPanel
    Left = 0
    Top = 430
    Width = 800
    Height = 41
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 1
    object BtnAdd: TButton
      Left = 8
      Top = 8
      Width = 75
      Height = 25
      Action = ActAdd
      TabOrder = 0
    end
    object BtnEdit: TButton
      Left = 89
      Top = 8
      Width = 75
      Height = 25
      Action = ActEdit
      TabOrder = 1
    end
    object BtnDelete: TButton
      Left = 170
      Top = 8
      Width = 75
      Height = 25
      Action = ActDelete
      TabOrder = 2
    end
    object BtnRefresh: TButton
      Left = 717
      Top = 8
      Width = 75
      Height = 25
      Action = ActRefresh
      TabOrder = 3
    end
  end
  object StatusBar: TStatusBar
    Left = 0
    Top = 471
    Width = 800
    Height = 29
    Panels = <
      item
        Width = 150
      end
      item
        Width = 150
      end
      item
        Width = 150
      end>
  end
  object GridCustomers: TStringGrid
    Left = 0
    Top = 49
    Width = 800
    Height = 381
    Align = alClient
    ColCount = 6
    DefaultRowHeight = 22
    FixedCols = 0
    Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goRangeSelect, goRowSelect, goColSizing]
    TabOrder = 3
    OnDblClick = GridCustomersDblClick
    OnSelectCell = GridCustomersSelectCell
    ColWidths = (
      0
      180
      200
      120
      120
      80)
  end
  object MainMenu: TMainMenu
    Left = 680
    Top = 8
    object MnuFile: TMenuItem
      Caption = '&File'
      object MnuFileExit: TMenuItem
        Action = ActExit
      end
    end
    object MnuEdit: TMenuItem
      Caption = '&Edit'
      object MnuEditAdd: TMenuItem
        Action = ActAdd
      end
      object MnuEditEdit: TMenuItem
        Action = ActEdit
      end
      object MnuEditDelete: TMenuItem
        Action = ActDelete
      end
      object N1: TMenuItem
        Caption = '-'
      end
      object MnuEditRefresh: TMenuItem
        Action = ActRefresh
      end
    end
    object MnuHelp: TMenuItem
      Caption = '&Help'
      object MnuHelpAbout: TMenuItem
        Caption = '&About...'
        OnClick = MnuHelpAboutClick
      end
    end
  end
  object ActionList: TActionList
    Left = 744
    Top = 8
    object ActAdd: TAction
      Caption = '&Add'
      ShortCut = 45
      OnExecute = ActAddExecute
    end
    object ActEdit: TAction
      Caption = '&Edit'
      ShortCut = 16397
      OnExecute = ActEditExecute
    end
    object ActDelete: TAction
      Caption = '&Delete'
      ShortCut = 46
      OnExecute = ActDeleteExecute
    end
    object ActRefresh: TAction
      Caption = '&Refresh'
      ShortCut = 116
      OnExecute = ActRefreshExecute
    end
    object ActExit: TAction
      Caption = 'E&xit'
      ShortCut = 32883
      OnExecute = ActExitExecute
    end
  end
end
