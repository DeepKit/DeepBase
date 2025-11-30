object WaitForm: TWaitForm
  Left = 0
  Top = 0
  BorderStyle = bsNone
  Caption = 'Please Wait...'
  ClientHeight = 120
  ClientWidth = 300
  Color = clWhite
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  FormStyle = fsStayOnTop
  OldCreateOrder = False
  Position = poOwnerFormCenter
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 15
  object pnlContent: TPanel
    Left = 0
    Top = 0
    Width = 300
    Height = 120
    Align = alClient
    BevelOuter = bvNone
    ParentBackground = False
    TabOrder = 0
    object lblMessage: TLabel
      Left = 20
      Top = 75
      Width = 260
      Height = 17
      Alignment = taCenter
      AutoSize = False
      Caption = 'Loading...'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -13
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
    end
    object ActivityIndicator1: TActivityIndicator
      Left = 130
      Top = 25
      IndicatorSize = aisLarge
    end
  end
end
