# UniBase Plugin Example

This example demonstrates how to create a plugin for the UniBase framework.

## Files

- `SamplePlugin.pas` - Plugin implementation
- `SamplePluginPkg.dpk` - BPL package project

## Building the Plugin

1. Open `SamplePluginPkg.dpk` in RAD Studio
2. Build the package (Ctrl+F9)
3. The output `SamplePluginPkg.bpl` will be created

## Installing the Plugin

Copy `SamplePluginPkg.bpl` to your application's `Plugins` directory:

```
MyApp/
├── MyApp.exe
├── config.db
└── Plugins/
    └── SamplePluginPkg.bpl
```

The plugin will be automatically loaded when the application starts.

## Plugin Features Demonstrated

### IUniBasePlugin (Required)
- `GetPluginInfo` - Returns plugin metadata (GUID, name, version, etc.)
- `Initialize` - Called when plugin is loaded
- `Finalize` - Called before plugin is unloaded
- `GetState` - Returns current plugin state

### IUniBasePluginUI (Optional)
- `GetMenuItems` - Provides menu items to add to host application
- `GetToolbarItems` - Provides toolbar buttons
- `GetSettingsPage` - Provides a settings UI frame
- `OnMenuClick` / `OnToolbarClick` - Handle user interactions

### IUniBasePluginEvents (Optional)
- `OnLanguageChanged` - Notified when UI language changes
- `OnThemeChanged` - Notified when theme changes
- `OnConfigChanged` - Notified when config values change

## Plugin Context

The plugin receives an `IUniBasePluginContext` that provides:

```pascal
// Get/Set configuration
Context.GetConfig('Key', 'DefaultValue');
Context.SetConfig('Key', 'Value');

// Translation
Context.Translate('Hello'); // Uses current language

// Logging
Context.Log('Message', 1); // 0=Debug, 1=Info, 2=Warn, 3=Error

// Paths
Context.GetRootPath;        // Application root directory
Context.GetPluginDataPath;  // Plugin-specific data directory
```

## Best Practices

1. **Use TUniBasePluginBase** - Provides default implementations and state management
2. **Handle nil Context** - Context may be nil if PluginManager doesn't provide one
3. **Save state in Finalize** - Use Context.SetConfig to persist data
4. **Use unique GUIDs** - Each plugin must have a unique GUID
5. **Specify MinUniBaseVersion** - Ensure compatibility with framework version
6. **Handle exceptions** - Don't let exceptions propagate to the host
