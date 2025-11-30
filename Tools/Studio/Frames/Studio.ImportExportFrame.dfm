object fraImportExport: TfraImportExport
  Left = 0
  Top = 0
  Width = 900
  Height = 650
  TabOrder = 0
  object pnlToolbar: TPanel
    Left = 0
    Top = 0
    Width = 900
    Height = 41
    Align = alTop
    BevelOuter = bvNone
    Color = clWhite
    ParentBackground = False
    TabOrder = 0
    object lblTitle: TLabel
      Left = 12
      Top = 12
      Width = 119
      Height = 15
      Caption = 'Data Import / Export'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
    end
  end
  object pnlMain: TPanel
    Left = 0
    Top = 41
    Width = 900
    Height = 609
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 1
    object pgcMain: TPageControl
      Left = 0
      Top = 0
      Width = 900
      Height = 609
      ActivePage = tabExport
      Align = alClient
      TabOrder = 0
      object tabExport: TTabSheet
        Caption = 'Export'
        object pnlExportLeft: TPanel
          Left = 0
          Top = 0
          Width = 400
          Height = 579
          Align = alLeft
          BevelOuter = bvNone
          TabOrder = 0
          object lblExportTables: TLabel
            Left = 8
            Top = 8
            Width = 125
            Height = 15
            Caption = 'Select Tables to Export:'
          end
          object lvExportTables: TListView
            Left = 8
            Top = 28
            Width = 384
            Height = 543
            Checkboxes = True
            Columns = <>
            HideSelection = False
            MultiSelect = True
            ReadOnly = True
            RowSelect = True
            TabOrder = 0
            ViewStyle = vsReport
          end
        end
        object pnlExportRight: TPanel
          Left = 400
          Top = 0
          Width = 492
          Height = 579
          Align = alClient
          BevelOuter = bvNone
          TabOrder = 1
          object lblExportFormat: TLabel
            Left = 16
            Top = 8
            Width = 74
            Height = 15
            Caption = 'Export Format:'
          end
          object lblExportPath: TLabel
            Left = 16
            Top = 90
            Width = 61
            Height = 15
            Caption = 'Export Path:'
          end
          object lblExportStatus: TLabel
            Left = 16
            Top = 200
            Width = 3
            Height = 15
          end
          object cboExportFormat: TComboBox
            Left = 16
            Top = 28
            Width = 300
            Height = 23
            Style = csDropDownList
            TabOrder = 0
          end
          object chkExportHeaders: TCheckBox
            Left = 16
            Top = 60
            Width = 180
            Height = 17
            Caption = 'Include header row'
            Checked = True
            State = cbChecked
            TabOrder = 1
          end
          object chkExportSelected: TCheckBox
            Left = 200
            Top = 60
            Width = 180
            Height = 17
            Caption = 'Export selected rows only'
            TabOrder = 2
            Visible = False
          end
          object edtExportPath: TEdit
            Left = 16
            Top = 110
            Width = 300
            Height = 23
            TabOrder = 3
          end
          object btnExportBrowse: TButton
            Left = 322
            Top = 110
            Width = 75
            Height = 23
            Caption = 'Browse...'
            TabOrder = 4
            OnClick = btnExportBrowseClick
          end
          object btnExport: TButton
            Left = 16
            Top = 150
            Width = 120
            Height = 30
            Caption = 'Export'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = clWindowText
            Font.Height = -12
            Font.Name = 'Segoe UI'
            Font.Style = [fsBold]
            ParentFont = False
            TabOrder = 5
            OnClick = btnExportClick
          end
          object prgExport: TProgressBar
            Left = 16
            Top = 220
            Width = 380
            Height = 17
            TabOrder = 6
            Visible = False
          end
        end
      end
      object tabImport: TTabSheet
        Caption = 'Import'
        ImageIndex = 1
        object pnlImportTop: TPanel
          Left = 0
          Top = 0
          Width = 892
          Height = 130
          Align = alTop
          BevelOuter = bvNone
          TabOrder = 0
          object lblImportFile: TLabel
            Left = 16
            Top = 12
            Width = 56
            Height = 15
            Caption = 'Import File:'
          end
          object lblImportFormat: TLabel
            Left = 16
            Top = 60
            Width = 41
            Height = 15
            Caption = 'Format:'
          end
          object lblTargetTable: TLabel
            Left = 250
            Top = 60
            Width = 63
            Height = 15
            Caption = 'Target Table:'
          end
          object edtImportFile: TEdit
            Left = 16
            Top = 30
            Width = 400
            Height = 23
            TabOrder = 0
            OnChange = edtImportFileChange
          end
          object btnImportBrowse: TButton
            Left = 422
            Top = 30
            Width = 75
            Height = 23
            Caption = 'Browse...'
            TabOrder = 1
            OnClick = btnImportBrowseClick
          end
          object cboImportFormat: TComboBox
            Left = 16
            Top = 78
            Width = 200
            Height = 23
            Style = csDropDownList
            TabOrder = 2
            OnChange = cboImportFormatChange
          end
          object cboTargetTable: TComboBox
            Left = 250
            Top = 78
            Width = 200
            Height = 23
            Style = csDropDownList
            TabOrder = 3
          end
          object chkCreateTable: TCheckBox
            Left = 480
            Top = 60
            Width = 200
            Height = 17
            Caption = 'Create table if not exists'
            TabOrder = 4
            Visible = False
          end
          object chkTruncateFirst: TCheckBox
            Left = 480
            Top = 82
            Width = 200
            Height = 17
            Caption = 'Truncate table before import'
            TabOrder = 5
          end
        end
        object pnlImportPreview: TPanel
          Left = 0
          Top = 130
          Width = 892
          Height = 340
          Align = alClient
          BevelOuter = bvNone
          TabOrder = 1
          object lblPreview: TLabel
            Left = 16
            Top = 8
            Width = 46
            Height = 15
            Caption = 'Preview:'
          end
          object sgPreview: TStringGrid
            Left = 16
            Top = 28
            Width = 860
            Height = 300
            ColCount = 6
            DefaultColWidth = 120
            FixedCols = 0
            Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goColSizing]
            TabOrder = 0
          end
        end
        object pnlImportBottom: TPanel
          Left = 0
          Top = 470
          Width = 892
          Height = 109
          Align = alBottom
          BevelOuter = bvNone
          TabOrder = 2
          object lblImportStatus: TLabel
            Left = 16
            Top = 50
            Width = 3
            Height = 15
          end
          object btnImport: TButton
            Left = 16
            Top = 10
            Width = 120
            Height = 30
            Caption = 'Import'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = clWindowText
            Font.Height = -12
            Font.Name = 'Segoe UI'
            Font.Style = [fsBold]
            ParentFont = False
            TabOrder = 0
            OnClick = btnImportClick
          end
          object prgImport: TProgressBar
            Left = 16
            Top = 70
            Width = 500
            Height = 17
            TabOrder = 1
            Visible = False
          end
        end
      end
    end
  end
  object dlgSave: TSaveDialog
    Filter = 'CSV Files (*.csv)|*.csv|All Files (*.*)|*.*'
    Options = [ofOverwritePrompt, ofHideReadOnly, ofEnableSizing]
    Left = 700
    Top = 8
  end
  object dlgOpen: TOpenDialog
    Filter = 'All Supported|*.csv;*.json;*.xml|CSV Files (*.csv)|*.csv|JSON Files (*.json)|*.json|XML Files (*.xml)|*.xml|All Files (*.*)|*.*'
    Options = [ofHideReadOnly, ofFileMustExist, ofEnableSizing]
    Left = 760
    Top = 8
  end
end
