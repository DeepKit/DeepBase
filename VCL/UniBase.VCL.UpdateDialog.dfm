object UpdateDialog: TUpdateDialog
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu]
  BorderStyle = bsDialog
  Caption = 'Software Update'
  ClientHeight = 300
  ClientWidth = 400
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  OldCreateOrder = False
  Position = poOwnerFormCenter
  OnClose = FormClose
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 15
  object lblTitle: TLabel
    Left = 20
    Top = 20
    Width = 154
    Height = 21
    Caption = 'New Version Available'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -16
    Font.Name = 'Segoe UI'
    Font.Style = [fsBold]
    ParentFont = False
  end
  object lblVersion: TLabel
    Left = 20
    Top = 50
    Width = 85
    Height = 15
    Caption = 'Version 1.0.0 -> 1.1.0'
  end
  object mmoChangelog: TMemo
    Left = 20
    Top = 80
    Width = 360
    Height = 120
    ReadOnly = True
    ScrollBars = ssVertical
    TabOrder = 0
  end
  object pbDownload: TProgressBar
    Left = 20
    Top = 215
    Width = 360
    Height = 17
    TabOrder = 1
    Visible = False
  end
  object btnUpdate: TButton
    Left = 224
    Top = 250
    Width = 75
    Height = 25
    Caption = 'Update'
    Default = True
    TabOrder = 2
    OnClick = btnUpdateClick
  end
  object btnCancel: TButton
    Left = 305
    Top = 250
    Width = 75
    Height = 25
    Cancel = True
    Caption = 'Cancel'
    TabOrder = 3
    OnClick = btnCancelClick
  end
end
