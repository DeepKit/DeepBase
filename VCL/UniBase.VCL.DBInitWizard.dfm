object DBInitWizard: TDBInitWizard
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu, biMinimize]
  BorderStyle = bsDialog
  Caption = 'UniBase Initialization Wizard'
  ClientHeight = 350
  ClientWidth = 500
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
  object pnlBottom: TPanel
    Left = 0
    Top = 310
    Width = 500
    Height = 40
    Align = alBottom
    BevelOuter = bvNone
    ParentBackground = False
    TabOrder = 0
    object btnBack: TButton
      Left = 240
      Top = 8
      Width = 75
      Height = 25
      Caption = '< Back'
      Enabled = False
      TabOrder = 0
      OnClick = btnBackClick
    end
    object btnNext: TButton
      Left = 321
      Top = 8
      Width = 75
      Height = 25
      Caption = 'Next >'
      Default = True
      TabOrder = 1
      OnClick = btnNextClick
    end
    object btnCancel: TButton
      Left = 410
      Top = 8
      Width = 75
      Height = 25
      Cancel = True
      Caption = 'Cancel'
      TabOrder = 2
      OnClick = btnCancelClick
    end
  end
  object pnlClient: TPanel
    Left = 0
    Top = 0
    Width = 500
    Height = 310
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 1
    object pcWizard: TPageControl
      Left = 0
      Top = 0
      Width = 500
      Height = 310
      ActivePage = tsWelcome
      Align = alClient
      Style = tsFlatButtons
      TabOrder = 0
      object tsWelcome: TTabSheet
        Caption = 'Welcome'
        TabVisible = False
        object lblWelcomeTitle: TLabel
          Left = 20
          Top = 30
          Width = 226
          Height = 21
          Caption = 'Welcome to UniBase Setup'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clWindowText
          Font.Height = -16
          Font.Name = 'Segoe UI'
          Font.Style = [fsBold]
          ParentFont = False
        end
        object lblWelcomeText: TLabel
          Left = 20
          Top = 70
          Width = 440
          Height = 60
          AutoSize = False
          Caption = 
            'This wizard will guide you through the initialization of the app' +
            'lication database and environment.'#13#10#13#10'Click "Next" to continue.'
          WordWrap = True
        end
      end
      object tsPath: TTabSheet
        Caption = 'Database Path'
        TabVisible = False
        object lblPathTitle: TLabel
          Left = 20
          Top = 20
          Width = 168
          Height = 21
          Caption = 'Select Database Path'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clWindowText
          Font.Height = -16
          Font.Name = 'Segoe UI'
          Font.Style = [fsBold]
          ParentFont = False
        end
        object lblPathInfo: TLabel
          Left = 20
          Top = 55
          Width = 440
          Height = 30
          AutoSize = False
          Caption = 'Choose where to store the application configuration and data.'
          WordWrap = True
        end
        object edtPath: TEdit
          Left = 20
          Top = 95
          Width = 360
          Height = 23
          TabOrder = 0
          Text = ''
        end
        object btnBrowse: TButton
          Left = 386
          Top = 94
          Width = 75
          Height = 25
          Caption = 'Browse...'
          TabOrder = 1
          OnClick = btnBrowseClick
        end
        object radDefault: TRadioButton
          Left = 20
          Top = 135
          Width = 400
          Height = 17
          Caption = 'Use Default (AppData/UniBase)'
          Checked = True
          TabOrder = 2
          TabStop = True
          OnClick = radDefaultClick
        end
        object radCustom: TRadioButton
          Left = 20
          Top = 158
          Width = 400
          Height = 17
          Caption = 'Use Custom Path'
          TabOrder = 3
          OnClick = radCustomClick
        end
      end
      object tsFinish: TTabSheet
        Caption = 'Finish'
        TabVisible = False
        object lblFinishTitle: TLabel
          Left = 20
          Top = 30
          Width = 102
          Height = 21
          Caption = 'Ready to Init'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clWindowText
          Font.Height = -16
          Font.Name = 'Segoe UI'
          Font.Style = [fsBold]
          ParentFont = False
        end
        object lblFinishText: TLabel
          Left = 20
          Top = 70
          Width = 440
          Height = 60
          AutoSize = False
          Caption = 
            'The wizard is ready to initialize the database at the selected l' +
            'ocation.'#13#10#13#10'Click "Finish" to complete the setup.'
          WordWrap = True
        end
      end
    end
  end
  object dlgBrowseFolder: TFileOpenDialog
    FavoriteLinks = <>
    FileTypes = <>
    Options = [fdoPickFolders, fdoPathMustExist]
    Left = 432
    Top = 24
  end
end
