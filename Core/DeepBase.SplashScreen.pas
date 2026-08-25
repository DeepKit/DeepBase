{ ============================================================================
  DeepBase.SplashScreen - Splash Screen Support
  
  Version: 1.0
  Description: Provides a simple splash screen with optional progress bar,
               status text, and fade animation. Works without VCL Forms unit
               dependency in the main project.
  Thread Safety: Call from main thread only.
  Platform: Windows (VCL only - not available in FMX applications)
  ============================================================================ }

unit DeepBase.SplashScreen;

{$IFDEF FMX}
  {$MESSAGE FATAL 'DeepBase.SplashScreen is VCL-only. For FMX, implement your own splash screen using FMX.Forms.'}
{$ENDIF}

interface

uses
  System.SysUtils,
  System.Classes,
  System.UITypes,
  System.Math,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.ExtCtrls,
  Vcl.StdCtrls,
  Vcl.ComCtrls,
  Vcl.Imaging.jpeg,
  Vcl.Imaging.pngimage,
  Winapi.Windows;

type
  /// <summary>
  /// Splash screen options
  /// </summary>
  TSplashOptions = record
    ShowProgress: Boolean;
    ShowStatus: Boolean;
    FadeIn: Boolean;
    FadeOut: Boolean;
    FadeDuration: Integer; // milliseconds
    StayOnTop: Boolean;
    AutoClose: Boolean;
    AutoCloseDelay: Integer; // milliseconds
    StatusFont: TFont;
    ProgressHeight: Integer;
    
    class function Default: TSplashOptions; static;
  end;

  /// <summary>
  /// Splash screen form
  /// </summary>
  TSplashForm = class(TForm)
  private
    FImage: TImage;
    FProgressBar: TProgressBar;
    FStatusLabel: TLabel;
    FOptions: TSplashOptions;
    FFadeTimer: TTimer;
    FCurrentAlpha: Byte;
    FFading: Boolean;
    FFadeDirection: Integer; // 1 = fade in, -1 = fade out
    FCloseAfterFade: Boolean;
    
    procedure SetupForm;
    procedure LoadImage(const FileName: string);
    procedure OnFadeTimer(Sender: TObject);
    procedure StartFadeIn;
    procedure StartFadeOut(CloseAfter: Boolean);
    
  protected
    procedure CreateParams(var Params: TCreateParams); override;
    
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    
    procedure ShowSplash(const ImageFile: string; const Options: TSplashOptions);
    procedure SetProgress(Value: Integer);
    procedure SetStatus(const Text: string);
    procedure HideSplash;
  end;

  /// <summary>
  /// Static splash screen helper
  /// </summary>
  TSplashScreen = class
  private class var
    FSplashForm: TSplashForm;
    
  public
    /// <summary>
    /// Show splash screen with image
    /// </summary>
    class procedure Show(const ImageFile: string); overload;
    class procedure Show(const ImageFile: string; const Options: TSplashOptions); overload;
    
    /// <summary>
    /// Update progress bar (0-100)
    /// </summary>
    class procedure SetProgress(Value: Integer);
    
    /// <summary>
    /// Update status text
    /// </summary>
    class procedure SetStatus(const Text: string);
    
    /// <summary>
    /// Hide and close splash screen
    /// </summary>
    class procedure Hide;
    
    /// <summary>
    /// Check if splash screen is visible
    /// </summary>
    class function IsVisible: Boolean;
    
    /// <summary>
    /// Process pending messages (call during long operations)
    /// </summary>
    class procedure ProcessMessages;
  end;

implementation

{ TSplashOptions }

class function TSplashOptions.Default: TSplashOptions;
begin
  Result.ShowProgress := True;
  Result.ShowStatus := True;
  Result.FadeIn := True;
  Result.FadeOut := True;
  Result.FadeDuration := 300;
  Result.StayOnTop := True;
  Result.AutoClose := False;
  Result.AutoCloseDelay := 3000;
  Result.StatusFont := nil;
  Result.ProgressHeight := 6;
end;

{ TSplashForm }

constructor TSplashForm.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  
  FOptions := TSplashOptions.Default;
  FFading := False;
  FCurrentAlpha := 255;
  FCloseAfterFade := False;
  
  SetupForm;
end;

destructor TSplashForm.Destroy;
begin
  if Assigned(FFadeTimer) then
    FreeAndNil(FFadeTimer);
  inherited;
end;

procedure TSplashForm.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  // Layered window for alpha transparency
  Params.ExStyle := Params.ExStyle or WS_EX_LAYERED;
end;

procedure TSplashForm.SetupForm;
begin
  // Form properties
  BorderStyle := bsNone;
  Position := poScreenCenter;
  Color := clWhite;
  
  // Image
  FImage := TImage.Create(Self);
  FImage.Parent := Self;
  FImage.Align := alClient;
  FImage.Stretch := True;
  FImage.Proportional := True;
  FImage.Center := True;
  
  // Progress bar
  FProgressBar := TProgressBar.Create(Self);
  FProgressBar.Parent := Self;
  FProgressBar.Align := alBottom;
  FProgressBar.Height := 6;
  FProgressBar.Min := 0;
  FProgressBar.Max := 100;
  FProgressBar.Position := 0;
  FProgressBar.Visible := False;
  
  // Status label
  FStatusLabel := TLabel.Create(Self);
  FStatusLabel.Parent := Self;
  FStatusLabel.Align := alBottom;
  FStatusLabel.Alignment := taCenter;
  FStatusLabel.Font.Size := 10;
  FStatusLabel.Font.Color := clGray;
  FStatusLabel.Height := 24;
  FStatusLabel.Visible := False;
  
  // Fade timer
  FFadeTimer := TTimer.Create(Self);
  FFadeTimer.Enabled := False;
  FFadeTimer.Interval := 15; // ~60 FPS
  FFadeTimer.OnTimer := OnFadeTimer;
end;

procedure TSplashForm.LoadImage(const FileName: string);
var
  Ext: string;
begin
  if not FileExists(FileName) then
    Exit;
    
  Ext := LowerCase(ExtractFileExt(FileName));
  
  try
    FImage.Picture.LoadFromFile(FileName);
    
    // Resize form to image size (with max limits)
    ClientWidth := Min(FImage.Picture.Width, Screen.Width - 100);
    ClientHeight := Min(FImage.Picture.Height, Screen.Height - 100);
    
    // Re-center
    Left := (Screen.Width - Width) div 2;
    Top := (Screen.Height - Height) div 2;
  except
    on E: Exception do
      {$IFDEF DEBUG}
      OutputDebugString(PChar('DeepBase.SplashScreen: LoadImage failed: ' + E.Message));
      {$ENDIF}
  end;
end;

procedure TSplashForm.ShowSplash(const ImageFile: string; const Options: TSplashOptions);
begin
  FOptions := Options;
  
  // Load image
  LoadImage(ImageFile);
  
  // Configure components
  FProgressBar.Visible := Options.ShowProgress;
  FProgressBar.Height := Options.ProgressHeight;
  
  FStatusLabel.Visible := Options.ShowStatus;
  if Assigned(Options.StatusFont) then
    FStatusLabel.Font.Assign(Options.StatusFont);
  
  // Stay on top
  if Options.StayOnTop then
    FormStyle := fsStayOnTop
  else
    FormStyle := fsNormal;
  
  // Show with fade
  if Options.FadeIn then
  begin
    FCurrentAlpha := 0;
    SetLayeredWindowAttributes(Handle, 0, 0, LWA_ALPHA);
    Show;
    StartFadeIn;
  end
  else
  begin
    FCurrentAlpha := 255;
    SetLayeredWindowAttributes(Handle, 0, 255, LWA_ALPHA);
    Show;
  end;
  
  Application.ProcessMessages;
end;

procedure TSplashForm.SetProgress(Value: Integer);
begin
  if Value < 0 then Value := 0;
  if Value > 100 then Value := 100;
  FProgressBar.Position := Value;
  Application.ProcessMessages;
end;

procedure TSplashForm.SetStatus(const Text: string);
begin
  FStatusLabel.Caption := Text;
  Application.ProcessMessages;
end;

procedure TSplashForm.HideSplash;
begin
  if FOptions.FadeOut and Visible then
  begin
    StartFadeOut(True);
  end
  else
  begin
    Hide;
  end;
end;

procedure TSplashForm.StartFadeIn;
begin
  FFading := True;
  FFadeDirection := 1;
  FCloseAfterFade := False;
  FFadeTimer.Enabled := True;
end;

procedure TSplashForm.StartFadeOut(CloseAfter: Boolean);
begin
  FFading := True;
  FFadeDirection := -1;
  FCloseAfterFade := CloseAfter;
  FFadeTimer.Enabled := True;
end;

procedure TSplashForm.OnFadeTimer(Sender: TObject);
var
  Step: Integer;
begin
  // Calculate step based on duration
  Step := (255 * Integer(FFadeTimer.Interval)) div FOptions.FadeDuration;
  if Step < 5 then Step := 5;
  
  if FFadeDirection > 0 then
  begin
    // Fade in
    FCurrentAlpha := Min(255, FCurrentAlpha + Step);
    SetLayeredWindowAttributes(Handle, 0, FCurrentAlpha, LWA_ALPHA);
    
    if FCurrentAlpha >= 255 then
    begin
      FFadeTimer.Enabled := False;
      FFading := False;
      
      // Auto close?
      if FOptions.AutoClose then
      begin
        Sleep(FOptions.AutoCloseDelay);
        HideSplash;
      end;
    end;
  end
  else
  begin
    // Fade out
    if FCurrentAlpha > Step then
      FCurrentAlpha := FCurrentAlpha - Step
    else
      FCurrentAlpha := 0;
      
    SetLayeredWindowAttributes(Handle, 0, FCurrentAlpha, LWA_ALPHA);
    
    if FCurrentAlpha <= 0 then
    begin
      FFadeTimer.Enabled := False;
      FFading := False;
      
      if FCloseAfterFade then
        Hide;
    end;
  end;
end;

{ TSplashScreen }

class procedure TSplashScreen.Show(const ImageFile: string);
begin
  Show(ImageFile, TSplashOptions.Default);
end;

class procedure TSplashScreen.Show(const ImageFile: string; const Options: TSplashOptions);
begin
  // Create splash form if needed
  if FSplashForm = nil then
    FSplashForm := TSplashForm.Create(nil);
    
  FSplashForm.ShowSplash(ImageFile, Options);
end;

class procedure TSplashScreen.SetProgress(Value: Integer);
begin
  if Assigned(FSplashForm) and FSplashForm.Visible then
    FSplashForm.SetProgress(Value);
end;

class procedure TSplashScreen.SetStatus(const Text: string);
begin
  if Assigned(FSplashForm) and FSplashForm.Visible then
    FSplashForm.SetStatus(Text);
end;

class procedure TSplashScreen.Hide;
begin
  if Assigned(FSplashForm) then
  begin
    FSplashForm.HideSplash;
    // Don't free immediately - let fade complete
    Application.ProcessMessages;
  end;
end;

class function TSplashScreen.IsVisible: Boolean;
begin
  Result := Assigned(FSplashForm) and FSplashForm.Visible;
end;

class procedure TSplashScreen.ProcessMessages;
begin
  Application.ProcessMessages;
end;

initialization

finalization
  if Assigned(TSplashScreen.FSplashForm) then
    FreeAndNil(TSplashScreen.FSplashForm);

end.
