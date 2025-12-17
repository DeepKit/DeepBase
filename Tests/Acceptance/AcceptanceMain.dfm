object frmAcceptanceMain: TfrmAcceptanceMain
  Left = 0
  Top = 0
  Caption = 'UniBase 可视化验收测试工具'
  ClientHeight = 600
  ClientWidth = 1000
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 13
  object pnlTop: TPanel
    Left = 0
    Top = 0
    Width = 1000
    Height = 60
    Align = alTop
    BevelOuter = bvNone
    Color = 2829099
    ParentBackground = False
    TabOrder = 0
    object lblTitle: TLabel
      Left = 16
      Top = 16
      Width = 300
      Height = 28
      Caption = 'UniBase 可视化验收测试'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWhite
      Font.Height = -20
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
    end
  end
  object pnlLeft: TPanel
    Left = 0
    Top = 60
    Width = 250
    Height = 540
    Align = alLeft
    BevelOuter = bvNone
    TabOrder = 1
    object tvPhases: TTreeView
      Left = 0
      Top = 0
      Width = 250
      Height = 540
      Align = alClient
      Indent = 19
      TabOrder = 0
      OnClick = tvPhasesClick
    end
  end
  object pnlRight: TPanel
    Left = 250
    Top = 60
    Width = 750
    Height = 540
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 2
    object splitter1: TSplitter
      Left = 0
      Top = 350
      Width = 750
      Height = 3
      Cursor = crVSplit
      Align = alBottom
    end
    object pnlButtons: TPanel
      Left = 0
      Top = 0
      Width = 750
      Height = 50
      Align = alTop
      BevelOuter = bvNone
      TabOrder = 0
      object btnRunPhase: TButton
        Left = 8
        Top = 8
        Width = 100
        Height = 35
        Caption = '运行当前阶段'
        TabOrder = 0
        OnClick = btnRunPhaseClick
      end
      object btnRunAll: TButton
        Left = 114
        Top = 8
        Width = 100
        Height = 35
        Caption = '运行所有阶段'
        TabOrder = 1
        OnClick = btnRunAllClick
      end
      object btnReport: TButton
        Left = 220
        Top = 8
        Width = 80
        Height = 35
        Caption = '生成报告'
        TabOrder = 2
        OnClick = btnReportClick
      end
      object btnMarkPass: TButton
        Left = 306
        Top = 8
        Width = 80
        Height = 35
        Caption = '标记通过'
        Enabled = False
        TabOrder = 3
        OnClick = btnMarkPassClick
      end
      object btnMarkFail: TButton
        Left = 392
        Top = 8
        Width = 80
        Height = 35
        Caption = '标记失败'
        Enabled = False
        TabOrder = 4
        OnClick = btnMarkFailClick
      end
    end
    object lvTests: TListView
      Left = 0
      Top = 80
      Width = 750
      Height = 270
      Align = alClient
      Columns = <>
      TabOrder = 1
      ViewStyle = vsReport
      OnSelectItem = lvTestsSelectItem
    end
    object pnlLog: TPanel
      Left = 0
      Top = 353
      Width = 750
      Height = 187
      Align = alBottom
      BevelOuter = bvNone
      TabOrder = 2
      object mmoLog: TMemo
        Left = 0
        Top = 0
        Width = 750
        Height = 187
        Align = alClient
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -11
        Font.Name = 'Consolas'
        Font.Style = []
        ParentFont = False
        ReadOnly = True
        ScrollBars = ssVertical
        TabOrder = 0
      end
    end
    object pnlProgress: TPanel
      Left = 0
      Top = 50
      Width = 750
      Height = 30
      Align = alTop
      BevelOuter = bvNone
      TabOrder = 3
      object lblProgress: TLabel
        Left = 220
        Top = 8
        Width = 80
        Height = 13
        Caption = '总体进度: 0%'
      end
      object pbProgress: TProgressBar
        Left = 8
        Top = 4
        Width = 200
        Height = 20
        TabOrder = 0
      end
    end
    object pnlStatus: TPanel
      Left = 0
      Top = 540
      Width = 750
      Height = 0
      Align = alBottom
      BevelOuter = bvNone
      TabOrder = 4
      object lblStatus: TLabel
        Left = 8
        Top = 4
        Width = 100
        Height = 13
        Caption = '准备就绪'
      end
    end
  end
end
