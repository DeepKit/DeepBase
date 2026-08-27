program hbtheme_fmx_gallery;

uses
  System.StartUpCopy,
  FMX.Forms,
  Gallery.FMXMainForm in 'Gallery.FMXMainForm.pas' {FMXGalleryMainForm},
  DeepBase.HB.Core in '..\..\Core\DeepBase.HB.Core.pas',
  DeepBase.HB.Palettes in '..\..\Core\DeepBase.HB.Palettes.pas',
  DeepBase.FMX.HB.Theme in '..\..\FMX\DeepBase.FMX.HB.Theme.pas',
  DeepBase.FMX.HB.Palettes in '..\..\FMX\DeepBase.FMX.HB.Palettes.pas',
  DeepBase.FMX.HB.Controls in '..\..\FMX\DeepBase.FMX.HB.Controls.pas',
  DeepBase.FMX.HB.Cards in '..\..\FMX\DeepBase.FMX.HB.Cards.pas';

begin
  Application.Initialize;
  Application.CreateForm(TFMXGalleryMainForm, FMXGalleryMainForm);
  Application.Run;
end.
