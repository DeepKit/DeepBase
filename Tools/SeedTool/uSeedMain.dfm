object frmSeedMain: TfrmSeedMain
  Left = 0
  Top = 0
  Caption = #38450#31735#25913#25773#31181#24037#20855
  ClientHeight = 720
  ClientWidth = 850
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Size = 9
  Position = poScreenCenter
  OnCreate = FormCreate
  TextHeight = 15
  object pnlTop: TPanel
    Left = 0
    Top = 0
    Width = 850
    Height = 50
    Align = alTop
    BevelOuter = bvNone
    Color = 3355443
    ParentBackground = False
    TabOrder = 0
    object lblTitle: TLabel
      AlignWithMargins = True
      Left = 20
      Top = 10
      Width = 810
      Height = 30
      Margins.Left = 20
      Margins.Top = 10
      Margins.Right = 20
      Margins.Bottom = 10
      Align = alClient
      Caption = #22270#20687#36164#28304#21152#23494#25773#31181#24037#20855
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWhite
      Font.Height = -18
      Font.Name = 'Segoe UI'
      Font.Size = 14
      Font.Style = [fsBold]
      ParentFont = False
    end
  end
  object pnlCenter: TPanel
    Left = 0
    Top = 50
    Width = 850
    Height = 530
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 1
    object gbDatabase: TGroupBox
      AlignWithMargins = True
      Left = 10
      Top = 10
      Width = 830
      Height = 55
      Margins.Left = 10
      Margins.Top = 10
      Margins.Right = 10
      Margins.Bottom = 5
      Align = alTop
      Caption = ' '#25968#25454#24211#36335#24452' '
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -13
      Font.Name = 'Segoe UI'
      Font.Size = 10
      Font.Style = [fsBold]
      ParentFont = False
      TabOrder = 0
      object edtDbPath: TEdit
        Left = 13
        Top = 22
        Width = 710
        Height = 23
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -12
        Font.Name = 'Segoe UI'
        Font.Size = 9
        Font.Style = []
        ParentFont = False
        TabOrder = 0
      end
      object btnSelectDb: TBitBtn
        Left = 733
        Top = 20
        Width = 85
        Height = 26
        Caption = #27983#35272'...'
        TabOrder = 1
        OnClick = btnSelectDbClick
      end
    end
    object gbConfig: TGroupBox
      AlignWithMargins = True
      Left = 10
      Top = 75
      Width = 830
      Height = 100
      Margins.Left = 10
      Margins.Top = 5
      Margins.Right = 10
      Margins.Bottom = 5
      Align = alTop
      Caption = ' '#21152#23494#37197#32622' '
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -13
      Font.Name = 'Segoe UI'
      Font.Size = 10
      Font.Style = [fsBold]
      ParentFont = False
      TabOrder = 1
      object lblEncKey: TLabel
        Left = 13
        Top = 25
        Width = 78
        Height = 15
        Caption = #21152#23494#23494#38053' (Key):'  
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -12
        Font.Name = 'Segoe UI'
        Font.Size = 9
        Font.Style = []
        ParentFont = False
      end
      object lblSalt: TLabel
        Left = 13
        Top = 55
        Width = 25
        Height = 15
        Caption = 'Salt:'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -12
        Font.Name = 'Segoe UI'
        Font.Size = 9
        Font.Style = []
        ParentFont = False
      end
      object lblKdfIter: TLabel
        Left = 430
        Top = 55
        Width = 74
        Height = 15
        Caption = 'KDF '#36845#20195#27425#25968':'  
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -12
        Font.Name = 'Segoe UI'
        Font.Size = 9
        Font.Style = []
        ParentFont = False
      end
      object edtEncKey: TEdit
        Left = 100
        Top = 22
        Width = 400
        Height = 23
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -12
        Font.Name = 'Segoe UI'
        Font.Size = 9
        Font.Style = []
        ParentFont = False
        PasswordChar = '*'
        TabOrder = 0
        TextHint = #35831#36755#20837#21152#23494#23494#38053' ('#33267#23569'8'#20301')'
      end
      object edtSalt: TEdit
        Left = 100
        Top = 52
        Width = 300
        Height = 23
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -12
        Font.Name = 'Segoe UI'
        Font.Size = 9
        Font.Style = []
        ParentFont = False
        TabOrder = 1
        Text = 'MoveC_Salt_v1'
      end
      object edtKdfIterations: TEdit
        Left = 520
        Top = 52
        Width = 80
        Height = 23
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -12
        Font.Name = 'Segoe UI'
        Font.Size = 9
        Font.Style = []
        ParentFont = False
        TabOrder = 2
        Text = '10000'
      end
      object chkEnableHMAC: TCheckBox
        Left = 640
        Top = 54
        Width = 100
        Height = 17
        Caption = #21551#29992' HMAC'
        Checked = True
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -12
        Font.Name = 'Segoe UI'
        Font.Size = 9
        Font.Style = []
        ParentFont = False
        State = cbChecked
        TabOrder = 3
      end
      object chkShowKey: TCheckBox
        Left = 520
        Top = 24
        Width = 80
        Height = 17
        Caption = #26174#31034#23494#38053
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -12
        Font.Name = 'Segoe UI'
        Font.Size = 9
        Font.Style = []
        ParentFont = False
        TabOrder = 4
        OnClick = chkShowKeyClick
      end
    end
    object pcMain: TPageControl
      AlignWithMargins = True
      Left = 10
      Top = 185
      Width = 830
      Height = 335
      Margins.Left = 10
      Margins.Top = 5
      Margins.Right = 10
      Margins.Bottom = 10
      Align = alClient
      ActivePage = tsImages
      TabOrder = 2
      OnChange = pcMainChange
      object tsImages: TTabSheet
        Caption = #22270#20687#25991#20214
        object lblImageCount: TLabel
          AlignWithMargins = True
          Left = 13
          Top = 282
          Width = 796
          Height = 15
          Margins.Left = 13
          Margins.Top = 5
          Margins.Right = 13
          Margins.Bottom = 10
          Align = alBottom
          Caption = #24050#28155#21152' 0 '#20010#22270#20687
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clGray
          Font.Height = -12
          Font.Name = 'Segoe UI'
          Font.Size = 9
          Font.Style = []
          ParentFont = False
        end
        object lstImages: TListBox
          AlignWithMargins = True
          Left = 13
          Top = 8
          Width = 696
          Height = 264
          Margins.Left = 13
          Margins.Top = 8
          Margins.Right = 0
          Margins.Bottom = 5
          Align = alClient
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clWindowText
          Font.Height = -12
          Font.Name = 'Consolas'
          Font.Size = 9
          Font.Style = []
          ItemHeight = 14
          ParentFont = False
          TabOrder = 0
          OnClick = lstImagesClick
        end
        object pnlImageButtons: TPanel
          Left = 709
          Top = 0
          Width = 113
          Height = 277
          Align = alRight
          BevelOuter = bvNone
          TabOrder = 1
          object btnAddImage: TBitBtn
            Left = 10
            Top = 10
            Width = 95
            Height = 28
            Caption = #28155#21152#22270#20687
            TabOrder = 0
            OnClick = btnAddImageClick
          end
          object btnSelectFolder: TBitBtn
            Left = 10
            Top = 45
            Width = 95
            Height = 28
            Caption = #36873#25321#25991#20214#22841
            TabOrder = 1
            OnClick = btnSelectFolderClick
          end
          object btnRemoveImage: TBitBtn
            Left = 10
            Top = 90
            Width = 95
            Height = 28
            Caption = #31227#38500#36873#20013
            TabOrder = 2
            OnClick = btnRemoveImageClick
          end
        object btnClearAll: TBitBtn
          Left = 10
          Top = 125
          Width = 95
          Height = 28
          Caption = #28165#31354#25152#26377
          TabOrder = 3
          OnClick = btnClearAllClick
        end
        object btnLoadFromDb: TBitBtn
          Left = 10
          Top = 180
          Width = 95
          Height = 28
          Caption = #20174#25968#25454#24211#21152#36733
          TabOrder = 4
          OnClick = btnLoadFromDbClick
        end
      end
    end
    object tsTexts: TTabSheet
        Caption = #25991#23383#37197#32622
        ImageIndex = 1
        object pnlTextEditor: TPanel
          Left = 0
          Top = 0
          Width = 822
          Height = 307
          Align = alClient
          BevelOuter = bvNone
          TabOrder = 0
          object lblTextHint: TLabel
            Left = 13
            Top = 8
            Width = 380
            Height = 15
            Caption = #36873#25321#22270#20687#21518#21487#32534#36753#23545#24212#30340#22320#22336#25991#26412#21644#25551#36848#20449#24687'('#20851#20110#25105'/'#32593#31449#31561')'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = clGray
            Font.Height = -12
            Font.Name = 'Segoe UI'
            Font.Size = 9
            Font.Style = []
            ParentFont = False
          end
          object lblCurrentImage: TLabel
            Left = 13
            Top = 35
            Width = 68
            Height = 15
            Caption = #24403#21069#22270#20687#65306
            Font.Charset = DEFAULT_CHARSET
            Font.Color = clWindowText
            Font.Height = -12
            Font.Name = 'Segoe UI'
            Font.Size = 9
            Font.Style = [fsBold]
            ParentFont = False
          end
          object lblCurrentImageKey: TLabel
            Left = 90
            Top = 35
            Width = 60
            Height = 15
            Caption = #26410#36873#25321
            Font.Charset = DEFAULT_CHARSET
            Font.Color = clBlue
            Font.Height = -12
            Font.Name = 'Segoe UI'
            Font.Size = 9
            Font.Style = []
            ParentFont = False
          end
          object lblAddressText: TLabel
            Left = 13
            Top = 65
            Width = 128
            Height = 15
            Caption = #22320#22336#25991#26412' (address_text):'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = clWindowText
            Font.Height = -12
            Font.Name = 'Segoe UI'
            Font.Size = 9
            Font.Style = []
            ParentFont = False
          end
          object lblDescription: TLabel
            Left = 13
            Top = 115
            Width = 119
            Height = 15
            Caption = #25551#36848' (description):'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = clWindowText
            Font.Height = -12
            Font.Name = 'Segoe UI'
            Font.Size = 9
            Font.Style = []
            ParentFont = False
          end
          object edtAddressText: TEdit
            Left = 13
            Top = 85
            Width = 600
            Height = 23
            Font.Charset = DEFAULT_CHARSET
            Font.Color = clWindowText
            Font.Height = -12
            Font.Name = 'Segoe UI'
            Font.Size = 9
            Font.Style = []
            ParentFont = False
            TabOrder = 0
            TextHint = #22914': bc1qxxx... '#25110' www.heyue.fyi'
            OnChange = edtAddressTextChange
          end
          object memoDescription: TMemo
            Left = 13
            Top = 135
            Width = 600
            Height = 100
            Font.Charset = DEFAULT_CHARSET
            Font.Color = clWindowText
            Font.Height = -12
            Font.Name = 'Segoe UI'
            Font.Size = 9
            Font.Style = []
            ParentFont = False
            ScrollBars = ssVertical
            TabOrder = 1
            OnChange = memoDescriptionChange
          end
          object btnSaveText: TBitBtn
            Left = 630
            Top = 85
            Width = 100
            Height = 28
            Caption = #20445#23384#25991#26412
            Enabled = False
            TabOrder = 2
            OnClick = btnSaveTextClick
          end
          object cboImageSelect: TComboBox
            Left = 200
            Top = 32
            Width = 250
            Height = 23
            Style = csDropDownList
            Font.Charset = DEFAULT_CHARSET
            Font.Color = clWindowText
            Font.Height = -12
            Font.Name = 'Segoe UI'
            Font.Size = 9
            Font.Style = []
            ParentFont = False
            TabOrder = 3
            OnChange = cboImageSelectChange
          end
          object chkEnabled: TCheckBox
            Left = 630
            Top = 135
            Width = 160
            Height = 17
            Caption = '启用（在 About 中显示）'
            Checked = True
            State = cbChecked
            TabOrder = 4
            OnClick = chkEnabledClick
          end
        end
      end
    end
  end
  object pnlBottom: TPanel
    Left = 0
    Top = 580
    Width = 850
    Height = 140
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 2
    object memoLog: TMemo
      AlignWithMargins = True
      Left = 10
      Top = 5
      Width = 830
      Height = 90
      Margins.Left = 10
      Margins.Top = 5
      Margins.Right = 10
      Margins.Bottom = 5
      Align = alClient
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -11
      Font.Name = 'Consolas'
      Font.Size = 8
      Font.Style = []
      ParentFont = False
      ReadOnly = True
      ScrollBars = ssVertical
      TabOrder = 0
    end
    object btnSeed: TBitBtn
      Left = 530
      Top = 105
      Width = 150
      Height = 30
      Caption = #24320#22987#25773#31181
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -13
      Font.Name = 'Segoe UI'
      Font.Size = 10
      Font.Style = [fsBold]
      ParentFont = False
      TabOrder = 1
      OnClick = btnSeedClick
    end
    object btnClose: TBitBtn
      Left = 700
      Top = 105
      Width = 120
      Height = 30
      Caption = #20851#38381
      TabOrder = 2
      OnClick = btnCloseClick
    end
  end
  object OpenDialog: TOpenDialog
    Left = 760
    Top = 8
  end
  object SaveDialog: TSaveDialog
    DefaultExt = 'db'
    Filter = 'SQLite '#25968#25454#24211'|*.db|'#25152#26377#25991#20214'|*.*'
    Options = [ofOverwritePrompt, ofHideReadOnly, ofEnableSizing]
    Title = #36873#25321#25968#25454#24211#25991#20214
    Left = 800
    Top = 8
  end
end
