object frmMain: TfrmMain
  Left = 0
  Top = 0
  Caption = #21160#24577#26597#35810#21442#25968#37197#32622#34920
  ClientHeight = 543
  ClientWidth = 998
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnCreate = FormCreate
  OnShow = FormShow
  TextHeight = 15
  object Panel1: TPanel
    Left = 0
    Top = 0
    Width = 998
    Height = 41
    Align = alTop
    TabOrder = 0
    ExplicitWidth = 992
    DesignSize = (
      998
      41)
    object Label1: TLabel
      Left = 16
      Top = 13
      Width = 52
      Height = 15
      Caption = #36807#31243#34920#65306
    end
    object DBNavigator1: TDBNavigator
      Left = 74
      Top = 6
      Width = 240
      Height = 25
      DataSource = dsQueries
      TabOrder = 0
    end
    object btnClose: TButton
      Left = 898
      Top = 10
      Width = 75
      Height = 25
      Anchors = [akTop, akRight]
      Caption = 'btnClose'
      TabOrder = 1
      OnClick = btnCloseClick
      ExplicitLeft = 892
    end
    object CboBoxDatabase: TComboBox
      Left = 376
      Top = 10
      Width = 161
      Height = 23
      TabOrder = 2
      Text = 'CboBoxDatabase'
      Visible = False
      OnChange = CboBoxDatabaseChange
    end
    object cboBoxTables: TComboBox
      Left = 570
      Top = 10
      Width = 142
      Height = 23
      TabOrder = 3
      Text = 'ComboBox1'
      OnChange = cboBoxTablesChange
    end
    object btnShowCurrRec: TButton
      Left = 793
      Top = 10
      Width = 88
      Height = 25
      Anchors = [akTop, akRight]
      Caption = #26174#31034#24403#21069#35760#24405
      TabOrder = 4
      OnClick = btnShowCurrRecClick
      ExplicitLeft = 787
    end
    object sEdtFieldsNum: TSpinEdit
      Left = 720
      Top = 8
      Width = 67
      Height = 24
      MaxValue = 30
      MinValue = 1
      TabOrder = 5
      Value = 6
    end
    object DBEdit2: TDBEdit
      Left = 320
      Top = 9
      Width = 244
      Height = 23
      DataField = 'proc_name'
      DataSource = dsQueries
      TabOrder = 6
    end
  end
  object Panel2: TPanel
    Left = 0
    Top = 41
    Width = 998
    Height = 442
    Align = alClient
    TabOrder = 1
    ExplicitWidth = 992
    ExplicitHeight = 425
    object Splitter1: TSplitter
      Left = 994
      Top = 242
      Height = 199
      Align = alRight
      ExplicitLeft = 584
      ExplicitTop = 424
      ExplicitHeight = 100
    end
    object Splitter6: TSplitter
      Left = 541
      Top = 242
      Height = 199
      Align = alRight
      ExplicitLeft = 376
      ExplicitTop = 280
      ExplicitHeight = 100
    end
    object Panel4: TPanel
      Left = 1
      Top = 201
      Width = 996
      Height = 41
      Align = alTop
      BevelInner = bvLowered
      TabOrder = 0
      ExplicitWidth = 990
      DesignSize = (
        996
        41)
      object Label2: TLabel
        Left = 15
        Top = 15
        Width = 52
        Height = 15
        Caption = #21442#25968#34920#65306
      end
      object edtSearch: TEdit
        Left = 344
        Top = 12
        Width = 304
        Height = 23
        Anchors = [akTop, akRight]
        TabOrder = 0
        ExplicitLeft = 338
      end
      object btnSearch: TButton
        Left = 735
        Top = 10
        Width = 75
        Height = 25
        Anchors = [akTop, akRight]
        Caption = 'btnSearch'
        TabOrder = 1
        OnClick = btnSearchClick
        ExplicitLeft = 729
      end
      object btnGenSql: TButton
        Left = 816
        Top = 10
        Width = 75
        Height = 25
        Anchors = [akTop, akRight]
        Caption = 'btnGenSql'
        TabOrder = 2
        OnClick = btnGenSqlClick
        ExplicitLeft = 810
      end
      object btnExecQry: TButton
        Left = 897
        Top = 10
        Width = 75
        Height = 25
        Anchors = [akTop, akRight]
        Caption = 'btnExec'
        TabOrder = 3
        OnClick = btnExecQryClick
        ExplicitLeft = 891
      end
      object DBNavigator2: TDBNavigator
        Left = 73
        Top = 11
        Width = 240
        Height = 25
        DataSource = dsParams
        TabOrder = 4
      end
      object cBoxParams: TCheckBox
        Left = 654
        Top = 15
        Width = 75
        Height = 17
        Caption = #22635#20805#21442#25968
        TabOrder = 5
      end
    end
    object Panel5: TPanel
      Left = 1
      Top = 1
      Width = 996
      Height = 200
      Align = alTop
      TabOrder = 1
      ExplicitWidth = 990
      object Splitter2: TSplitter
        Left = 609
        Top = 1
        Width = 6
        Height = 198
        Align = alRight
        ExplicitLeft = -5
      end
      object Splitter3: TSplitter
        Left = 603
        Top = 1
        Width = 6
        Height = 198
        Align = alRight
        ExplicitLeft = -5
      end
      object Splitter4: TSplitter
        Left = 122
        Top = 1
        Width = 6
        Height = 198
        ExplicitLeft = 134
        ExplicitTop = 5
      end
      object dbgQueries: TDBGrid
        Left = 128
        Top = 1
        Width = 475
        Height = 198
        Align = alClient
        DataSource = dsQueries
        TabOrder = 0
        TitleFont.Charset = DEFAULT_CHARSET
        TitleFont.Color = clWindowText
        TitleFont.Height = -12
        TitleFont.Name = 'Segoe UI'
        TitleFont.Style = []
        Columns = <
          item
            Expanded = False
            FieldName = 'proc_name'
            Width = 200
            Visible = True
          end
          item
            Expanded = False
            FieldName = 'category'
            Width = 120
            Visible = True
          end
          item
            Expanded = False
            FieldName = 'table_name'
            Width = 120
            Visible = True
          end
          item
            Expanded = False
            FieldName = 'run_type'
            PickList.Strings = (
              'select'
              'insert'
              'update'
              'delete')
            Width = 120
            Visible = True
          end
          item
            Expanded = False
            FieldName = 'order_by'
            Visible = True
          end
          item
            Expanded = False
            FieldName = 'limits'
            Visible = True
          end>
      end
      object dbgQry: TDBGrid
        Left = 615
        Top = 1
        Width = 380
        Height = 198
        Align = alRight
        DataSource = dsQry
        TabOrder = 1
        TitleFont.Charset = DEFAULT_CHARSET
        TitleFont.Color = clWindowText
        TitleFont.Height = -12
        TitleFont.Name = 'Segoe UI'
        TitleFont.Style = []
        Visible = False
      end
      object ListBoxFields: TListBox
        Left = 1
        Top = 1
        Width = 121
        Height = 198
        Align = alLeft
        ItemHeight = 15
        TabOrder = 2
      end
    end
    object Panel6: TPanel
      Left = 544
      Top = 242
      Width = 450
      Height = 199
      Align = alRight
      TabOrder = 2
      ExplicitLeft = 538
      ExplicitHeight = 182
      object Splitter5: TSplitter
        Left = 1
        Top = 89
        Width = 448
        Height = 3
        Cursor = crVSplit
        Align = alTop
        ExplicitTop = 65
        ExplicitWidth = 44
      end
      object meoSql: TMemo
        Left = 1
        Top = 1
        Width = 448
        Height = 88
        Align = alTop
        ScrollBars = ssVertical
        TabOrder = 0
      end
      object DBMemo1: TDBMemo
        Left = 1
        Top = 92
        Width = 448
        Height = 106
        Align = alClient
        DataField = 'memo'
        DataSource = dsQueries
        TabOrder = 1
        ExplicitHeight = 89
      end
    end
    object Panel7: TPanel
      Left = 1
      Top = 242
      Width = 540
      Height = 199
      Align = alClient
      TabOrder = 3
      ExplicitWidth = 534
      ExplicitHeight = 182
      object dbgParams: TDBGrid
        Left = 1
        Top = 1
        Width = 538
        Height = 167
        Align = alClient
        DataSource = dsParams
        TabOrder = 0
        TitleFont.Charset = DEFAULT_CHARSET
        TitleFont.Color = clWindowText
        TitleFont.Height = -12
        TitleFont.Name = 'Segoe UI'
        TitleFont.Style = []
        Columns = <
          item
            Expanded = False
            FieldName = 'proc_name'
            ReadOnly = True
            Width = 32
            Visible = True
          end
          item
            Expanded = False
            FieldName = 'para_order'
            Width = 24
            Visible = True
          end
          item
            Expanded = False
            FieldName = 'para_name'
            Width = 48
            Visible = True
          end
          item
            Expanded = False
            FieldName = 'para_type'
            PickList.Strings = (
              'string'
              'integer'
              'float'
              'date'
              'boolean')
            Width = 48
            Visible = True
          end
          item
            Expanded = False
            FieldName = 'and_or'
            Width = 32
            Visible = True
          end
          item
            Expanded = False
            FieldName = 'is_where'
            Width = 32
            Visible = True
          end
          item
            Expanded = False
            FieldName = 'para_value'
            Width = 80
            Visible = True
          end>
      end
      object Panel8: TPanel
        Left = 1
        Top = 168
        Width = 538
        Height = 30
        Align = alBottom
        BevelInner = bvLowered
        TabOrder = 1
        ExplicitTop = 151
        ExplicitWidth = 532
        object Label3: TLabel
          AlignWithMargins = True
          Left = 5
          Top = 8
          Width = 91
          Height = 17
          Margins.Top = 6
          Align = alLeft
          Alignment = taCenter
          BiDiMode = bdLeftToRight
          Caption = #22635#20805#20020#26102#21442#25968#65306
          ParentBiDiMode = False
          ExplicitHeight = 15
        end
        object edtParams: TEdit
          AlignWithMargins = True
          Left = 102
          Top = 5
          Width = 431
          Height = 20
          Align = alClient
          TabOrder = 0
          Text = 'name'#65306#24352#19977'|||address'#65306#21271#20140#24066#26397#38451#21306'|||age'#65306'25|||user_id:2|||title:'#25105#26159#19968#22836#29482
          ExplicitWidth = 425
          ExplicitHeight = 23
        end
      end
    end
  end
  object Panel3: TPanel
    Left = 0
    Top = 483
    Width = 998
    Height = 41
    Align = alBottom
    TabOrder = 2
    ExplicitTop = 466
    ExplicitWidth = 992
  end
  object StatusBar1: TStatusBar
    Left = 0
    Top = 524
    Width = 998
    Height = 19
    Panels = <
      item
        Width = 120
      end
      item
        Width = 360
      end
      item
        Alignment = taRightJustify
        Width = 120
      end>
    ExplicitTop = 507
    ExplicitWidth = 992
  end
  object dsParams: TDataSource
    DataSet = tblParams
    Left = 672
    Top = 185
  end
  object dsQueries: TDataSource
    DataSet = tblQueries
    Left = 576
    Top = 193
  end
  object aQry: TADOQuery
    Connection = Conn
    Parameters = <>
    SQL.Strings = (
      
        'INSERT INTO texts (user_id, share_link, no, title, video_url, st' +
        'atus) VALUES (2, NULL, NULL, '#39#25105#26159#19968#22836#29482#39', NULL, '#39#24050#32463#20998#20139#31561#24453#19979#36733#39')'#11
      ''
      '')
    Left = 408
    Top = 89
  end
  object dsQry: TDataSource
    DataSet = aQry
    Left = 416
    Top = 185
  end
  object tblQueries: TADOTable
    Connection = Conn
    CursorType = ctStatic
    IndexFieldNames = 'proc_name'
    TableName = 'queries'
    Left = 576
    Top = 97
  end
  object tblParams: TADOTable
    Connection = Conn
    CursorType = ctStatic
    AfterInsert = tblParamsAfterInsert
    BeforePost = tblParamsBeforePost
    IndexFieldNames = 'proc_name;para_order'
    MasterFields = 'proc_name'
    MasterSource = dsQueries
    TableName = 'query_parameters'
    Left = 664
    Top = 97
  end
  object Conn: TADOConnection
    ConnectionString = 
      'Provider=MSDASQL.1;Persist Security Info=False;Extended Properti' +
      'es="DSN=PostgreSQL30;DATABASE=chat_ais;SERVER=113.45.178.1;PORT=' +
      '5432;UID=fuyi01;SSLmode=disable;ReadOnly=0;Protocol=7.4;FakeOidI' +
      'ndex=0;ShowOidColumn=0;RowVersioning=0;ShowSystemTables=0;Fetch=' +
      '100;UnknownSizes=0;MaxVarcharSize=255;MaxLongVarcharSize=8190;De' +
      'bug=0;CommLog=0;UseDeclareFetch=0;TextAsLongVarchar=1;UnknownsAs' +
      'LongVarchar=0;BoolsAsChar=1;Parse=0;ExtraSysTablePrefixes=;LFCon' +
      'version=1;UpdatableCursors=1;TrueIsMinus1=0;BI=0;ByteaAsLongVarB' +
      'inary=1;UseServerSidePrepare=1;LowerCaseIdentifier=0;D6=-101;Opt' +
      'ionalErrors=0;FetchRefcursors=0;XaOpt=1"'
    LoginPrompt = False
    Provider = 'MSDASQL.1'
    Left = 249
    Top = 130
  end
end
