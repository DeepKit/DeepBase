# UniBase FMX Platform Demo

Cross-platform demonstration of UniBase FMX controls and platform abstraction layer.

## Features Demonstrated

### 1. Platform Tab
Displays comprehensive platform information:
- Current platform (Windows, macOS, Android, iOS, Linux)
- Device type (Desktop, Phone, Tablet)
- Platform detection flags
- Screen information (resolution, scale, orientation)
- System paths (Documents, Cache, Temp, AppData)

### 2. Theme Tab
Dark/Light theme switching:
- Toggle between light and dark modes
- Follow system theme preference
- Color scheme preview (Primary, Background, Surface, Error)
- Automatic color adaptation

### 3. ListView Tab
Enhanced ListView with mobile features:
- **Pull-to-Refresh**: Pull down to refresh content
- **Infinite Scrolling**: Automatically load more items when scrolling near bottom
- **Search/Filter**: Type to filter items in real-time
- **Empty State**: Custom empty view when no items match

### 4. Form Controls Tab
Material Design style form inputs:
- **TUniMaterialEdit**: Floating label input with validation
- **TUniStarRating**: Interactive star rating control
- **TUniChipInput**: Tag/chip input with add/remove

## Components Used

### UniBase.FMX.Platform
- `TUniPlatformAdapter` - Platform detection singleton
- `Platform()` - Global accessor function
- Platform-specific path utilities
- Screen metrics and safe area handling

### UniBase.FMX.Theme
- `TUniFMXTheme` - Theme manager singleton
- `Theme()` - Global accessor function
- Light/Dark color schemes
- System theme detection

### UniBase.FMX.ListView
- `TUniListView` - Enhanced ListView
- Pull-to-refresh support
- Infinite scrolling
- Search/filter capabilities
- Empty state view

### UniBase.FMX.FormControls
- `TUniMaterialEdit` - Material Design text input
- `TUniSearchComboBox` - Filterable ComboBox
- `TUniLabeledSwitch` - Switch with label
- `TUniChipInput` - Tag input control
- `TUniStarRating` - Star rating control
- `TUniFormValidator` - Form validation manager

## Building

1. Open `FMXPlatformDemo.dpr` in RAD Studio
2. Select target platform:
   - Windows 32-bit/64-bit
   - macOS (ARM64/Intel)
   - Android 32-bit/64-bit
   - iOS Device/Simulator
   - Linux 64-bit
3. Build and Run

## Platform-Specific Notes

### Windows
- Full feature support
- System dark mode detection from Registry

### macOS
- Requires code signing for distribution
- System theme detection via NSAppearance

### Android
- Minimum API level 21 (Android 5.0)
- Safe area handling for notch displays
- Material Design native feel

### iOS
- Minimum iOS 12
- Safe area handling for notch/Dynamic Island
- Native iOS look and feel

### Linux
- GTK3 backend
- Limited theme detection

## Usage Examples

### Platform Detection
```pascal
uses UniBase.FMX.Platform;

if Platform.IsMobile then
begin
  // Mobile-specific layout
  ListViewItemHeight := 60;
end
else
begin
  // Desktop layout
  ListViewItemHeight := 44;
end;
```

### Theme Switching
```pascal
uses UniBase.FMX.Theme;

// Follow system preference
Theme.FollowSystemTheme;

// Or set explicitly
Theme.SetDarkMode;

// Get current colors
var BgColor := Theme.CurrentColors.Background;
```

### Enhanced ListView
```pascal
uses UniBase.FMX.ListView;

var LV := TUniListView.Create(Self);
LV.PullToRefresh := True;
LV.InfiniteScroll := True;
LV.OnRefresh := HandleRefresh;
LV.OnLoadMore := HandleLoadMore;
```

### Form Validation
```pascal
uses UniBase.FMX.FormControls;

var EmailEdit := TUniMaterialEdit.Create(Self);
EmailEdit.LabelText := 'Email';
EmailEdit.Required := True;
EmailEdit.AddValidator(TUniMaterialEdit.EmailValidator);

if EmailEdit.Validate then
  // Process form
```

## License

Part of the UniBase Framework - see main project LICENSE.
