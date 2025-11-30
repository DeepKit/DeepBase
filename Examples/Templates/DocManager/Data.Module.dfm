object DataModule1: TDataModule1
  OnCreate = DataModuleCreate
  OnDestroy = DataModuleDestroy
  Height = 240
  Width = 320
  object FDConnection1: TFDConnection
    LoginPrompt = False
    Left = 56
    Top = 24
  end
  object FDPhysSQLiteDriverLink1: TFDPhysSQLiteDriverLink
    Left = 56
    Top = 88
  end
  object qryDocuments: TFDQuery
    Connection = FDConnection1
    Left = 152
    Top = 24
  end
  object qryCategories: TFDQuery
    Connection = FDConnection1
    Left = 152
    Top = 88
  end
  object qryTags: TFDQuery
    Connection = FDConnection1
    Left = 152
    Top = 152
  end
end
