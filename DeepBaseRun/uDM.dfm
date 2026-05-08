object DM: TDM
  OldCreateOrder = False
  OnCreate = DataModuleCreate
  Height = 150
  Width = 300
  object FDConnection: TFDConnection
    Params.Strings = (
      'DriverID=SQLite')
    Connected = False
    LoginPrompt = False
    Left = 40
    Top = 40
  end
end
