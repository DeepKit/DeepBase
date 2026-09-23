object MainForm: TMainForm
  Left = 0
  Top = 0
  Caption = 'Data Analyzer Template'
  ClientHeight = 561
  ClientWidth = 782
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  OnCreate = FormCreate
  Position = poScreenCenter
  TextHeight = 15
  object pnlTop: TPanel
    Left = 0
    Top = 0
    Width = 782
    Height = 49
    Align = alTop
    TabOrder = 0
    object btnAnalyze: TButton
      Left = 8
      Top = 12
      Width = 120
      Height = 25
      Caption = 'Analyze'
      TabOrder = 0
      OnClick = btnAnalyzeClick
    end
    object btnChart: TButton
      Left = 136
      Top = 12
      Width = 120
      Height = 25
      Caption = 'Chart'
      TabOrder = 1
      OnClick = btnChartClick
    end
    object btnReport: TButton
      Left = 264
      Top = 12
      Width = 120
      Height = 25
      Caption = 'Report'
      TabOrder = 2
      OnClick = btnReportClick
    end
  end
  object mmoResult: TMemo
    Left = 0
    Top = 49
    Width = 782
    Height = 512
    Align = alClient
    Font.Name = 'Consolas'
    ReadOnly = True
    ScrollBars = ssBoth
    TabOrder = 1
  end
end
