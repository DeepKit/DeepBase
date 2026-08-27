program hbtheme_gallery;

uses
  Vcl.Forms,
  Gallery.MainForm in 'Gallery.MainForm.pas' {GalleryMainForm},
  DeepBase.VCL.HB.Theme in '..\..\VCL\DeepBase.VCL.HB.Theme.pas',
  DeepBase.VCL.HB.Palettes in '..\..\VCL\DeepBase.VCL.HB.Palettes.pas',
  DeepBase.VCL.HB.Controls in '..\..\VCL\DeepBase.VCL.HB.Controls.pas',
  DeepBase.VCL.HB.Cards in '..\..\VCL\DeepBase.VCL.HB.Cards.pas';

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TGalleryMainForm, GalleryMainForm);
  Application.Run;
end.
