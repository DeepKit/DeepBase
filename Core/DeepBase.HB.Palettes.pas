{ ============================================================================
  DeepBase.HB.Palettes - Framework-Agnostic Built-in 10 Theme Palettes Registration

  Version: 1.0 (Delphi 13.1 on Win64 / Cross-Platform RTL)
  Description: Registers 10 built-in theme JSONs into THbTheme registry.
               Pure RTL, shared across VCL and FMX.
  ============================================================================ }

unit DeepBase.HB.Palettes;

interface

uses
  System.SysUtils,
  System.Classes,
  DeepBase.HB.Core;

procedure RegisterBuiltInThemes;

implementation

const
  JSON_HUANJIN_GOLD =
    '{' +
    '  "id": "huanjin-gold",' +
    '  "name": "暖金",' +
    '  "nameEn": "Warm Gold",' +
    '  "description": "唤金默认 · 温暖生意感",' +
    '  "isDark": false,' +
    '  "surface": {' +
    '    "surface": "#FFFDF8",' +
    '    "surfaceAlt": "#FFF6E6",' +
    '    "border": "#EBDFC8",' +
    '    "soft": "#FDF0DA",' +
    '    "sunken": "#F5EFE6",' +
    '    "elevation1": "#1A000000",' +
    '    "elevation2": "#26000000",' +
    '    "elevation3": "#33000000"' +
    '  },' +
    '  "ink": {' +
    '    "ink": "#292524",' +
    '    "inkMuted": "#8A8175",' +
    '    "fontScale": 1.0' +
    '  },' +
    '  "brand": {' +
    '    "primary": "#D97706",' +
    '    "primaryHover": "#B45309",' +
    '    "primaryPressed": "#92400E",' +
    '    "onPrimary": "#FFFFFF",' +
    '    "heroGradFrom": "#78350F",' +
    '    "heroGradTo": "#F59E0B",' +
    '    "focusRing": "#D97706"' +
    '  },' +
    '  "status": {' +
    '    "success": "#059669",' +
    '    "successSoft": "#ECFDF5",' +
    '    "warning": "#D97706",' +
    '    "warningSoft": "#FEF9C3",' +
    '    "danger": "#DC2626",' +
    '    "dangerSoft": "#FEF2F2",' +
    '    "info": "#2563EB",' +
    '    "infoSoft": "#EFF6FF"' +
    '  },' +
    '  "shape": {' +
    '    "radiusS": 6.0,' +
    '    "radiusM": 12.0,' +
    '    "radiusL": 20.0,' +
    '    "pillRatio": 0.5,' +
    '    "borderWidth": 1.0' +
    '  },' +
    '  "typography": {' +
    '    "fontFamily": "Microsoft YaHei UI",' +
    '    "sizeXS": 11.0,' +
    '    "sizeS": 12.5,' +
    '    "sizeM": 14.0,' +
    '    "sizeL": 17.0,' +
    '    "sizeXL": 22.0,' +
    '    "sizeXXL": 34.0,' +
    '    "weightBold": 700' +
    '  },' +
    '  "space": {' +
    '    "spaceXS": 4.0,' +
    '    "spaceS": 8.0,' +
    '    "spaceM": 14.0,' +
    '    "spaceL": 22.0,' +
    '    "spaceXL": 32.0' +
    '  },' +
    '  "motion": {' +
    '    "durFast": 120,' +
    '    "durNorm": 220,' +
    '    "durSlow": 380,' +
    '    "easeMode": "EaseOut"' +
    '  },' +
    '  "density": {' +
    '    "rowHeightScale": 1.0' +
    '  }' +
    '}';

  JSON_HUANJIN_NIGHT =
    '{' +
    '  "id": "huanjin-night",' +
    '  "name": "夜金·暗",' +
    '  "nameEn": "Ink Gold Dark",' +
    '  "description": "唤金暗色 · 沉浸低反光",' +
    '  "inherits": "huanjin-gold",' +
    '  "isDark": true,' +
    '  "surface": {' +
    '    "surface": "#1C1917",' +
    '    "surfaceAlt": "#292524",' +
    '    "border": "#44403C",' +
    '    "soft": "#302B27",' +
    '    "sunken": "#141210",' +
    '    "elevation1": "#33000000",' +
    '    "elevation2": "#4D000000",' +
    '    "elevation3": "#66000000"' +
    '  },' +
    '  "ink": {' +
    '    "ink": "#F5F5F4",' +
    '    "inkMuted": "#A8A29E"' +
    '  },' +
    '  "brand": {' +
    '    "primary": "#F59E0B",' +
    '    "primaryHover": "#FBBF24",' +
    '    "primaryPressed": "#D97706",' +
    '    "onPrimary": "#1C1917",' +
    '    "heroGradFrom": "#451A03",' +
    '    "heroGradTo": "#B45309",' +
    '    "focusRing": "#F59E0B"' +
    '  },' +
    '  "status": {' +
    '    "success": "#10B981",' +
    '    "successSoft": "#064E3B",' +
    '    "warning": "#F59E0B",' +
    '    "warningSoft": "#78350F",' +
    '    "danger": "#EF4444",' +
    '    "dangerSoft": "#7F1D1D",' +
    '    "info": "#3B82F6",' +
    '    "infoSoft": "#1E3A8A"' +
    '  }' +
    '}';

  JSON_DEEPARW_INDIGO =
    '{' +
    '  "id": "deeparw-indigo",' +
    '  "name": "数脉·靛",' +
    '  "nameEn": "Tech Indigo",' +
    '  "description": "科技商务 · 数据密集型应用",' +
    '  "isDark": false,' +
    '  "surface": {' +
    '    "surface": "#F8FAFC",' +
    '    "surfaceAlt": "#F1F5F9",' +
    '    "border": "#CBD5E1",' +
    '    "soft": "#E2E8F0",' +
    '    "sunken": "#E2E8F0",' +
    '    "elevation1": "#1A0F172A",' +
    '    "elevation2": "#260F172A",' +
    '    "elevation3": "#330F172A"' +
    '  },' +
    '  "ink": {' +
    '    "ink": "#0F172A",' +
    '    "inkMuted": "#64748B",' +
    '    "fontScale": 1.0' +
    '  },' +
    '  "brand": {' +
    '    "primary": "#4F46E5",' +
    '    "primaryHover": "#4338CA",' +
    '    "primaryPressed": "#3730A3",' +
    '    "onPrimary": "#FFFFFF",' +
    '    "heroGradFrom": "#312E81",' +
    '    "heroGradTo": "#6366F1",' +
    '    "focusRing": "#4F46E5"' +
    '  },' +
    '  "status": {' +
    '    "success": "#059669",' +
    '    "successSoft": "#ECFDF5",' +
    '    "warning": "#D97706",' +
    '    "warningSoft": "#FEF9C3",' +
    '    "danger": "#DC2626",' +
    '    "dangerSoft": "#FEF2F2",' +
    '    "info": "#4F46E5",' +
    '    "infoSoft": "#EEF2FF"' +
    '  }' +
    '}';

  JSON_ADMIN_GRAPHITE =
    '{' +
    '  "id": "admin-graphite",' +
    '  "name": "玄石·极",' +
    '  "nameEn": "Obsidian",' +
    '  "description": "中台后台 · 极客与中台管理",' +
    '  "isDark": true,' +
    '  "surface": {' +
    '    "surface": "#0F172A",' +
    '    "surfaceAlt": "#1E293B",' +
    '    "border": "#334155",' +
    '    "soft": "#1E293B",' +
    '    "sunken": "#020617",' +
    '    "elevation1": "#33000000",' +
    '    "elevation2": "#4D000000",' +
    '    "elevation3": "#66000000"' +
    '  },' +
    '  "ink": {' +
    '    "ink": "#F8FAFC",' +
    '    "inkMuted": "#94A3B8"' +
    '  },' +
    '  "brand": {' +
    '    "primary": "#38BDF8",' +
    '    "primaryHover": "#7DD3FC",' +
    '    "primaryPressed": "#0284C7",' +
    '    "onPrimary": "#0F172A",' +
    '    "heroGradFrom": "#0C4A6E",' +
    '    "heroGradTo": "#0284C7",' +
    '    "focusRing": "#38BDF8"' +
    '  },' +
    '  "status": {' +
    '    "success": "#34D399",' +
    '    "successSoft": "#064E3B",' +
    '    "warning": "#FBBF24",' +
    '    "warningSoft": "#78350F",' +
    '    "danger": "#F87171",' +
    '    "dangerSoft": "#7F1D1D",' +
    '    "info": "#38BDF8",' +
    '    "infoSoft": "#0C4A6E"' +
    '  }' +
    '}';

  JSON_JADE_EMERALD =
    '{' +
    '  "id": "jade-emerald",' +
    '  "name": "翠微·碧",' +
    '  "nameEn": "Emerald",' +
    '  "description": "生机健康 · 医疗与生机应用",' +
    '  "isDark": false,' +
    '  "surface": {' +
    '    "surface": "#F0FDF4",' +
    '    "surfaceAlt": "#DCFCE7",' +
    '    "border": "#BBF7D0",' +
    '    "soft": "#DCFCE7",' +
    '    "sunken": "#D1FAE5",' +
    '    "elevation1": "#1A064E3B",' +
    '    "elevation2": "#26064E3B",' +
    '    "elevation3": "#33064E3B"' +
    '  },' +
    '  "ink": {' +
    '    "ink": "#064E3B",' +
    '    "inkMuted": "#047857"' +
    '  },' +
    '  "brand": {' +
    '    "primary": "#059669",' +
    '    "primaryHover": "#047857",' +
    '    "primaryPressed": "#065F46",' +
    '    "onPrimary": "#FFFFFF",' +
    '    "heroGradFrom": "#064E3B",' +
    '    "heroGradTo": "#10B981",' +
    '    "focusRing": "#059669"' +
    '  }' +
    '}';

  JSON_ROSE_CLAY =
    '{' +
    '  "id": "rose-clay",' +
    '  "name": "赤陶·暮",' +
    '  "nameEn": "Rose Clay",' +
    '  "description": "温暖消费 · 美妆与消费美学",' +
    '  "isDark": false,' +
    '  "surface": {' +
    '    "surface": "#FFF1F2",' +
    '    "surfaceAlt": "#FFE4E6",' +
    '    "border": "#FECDD3",' +
    '    "soft": "#FFE4E6",' +
    '    "sunken": "#FCE7F3",' +
    '    "elevation1": "#1A881337",' +
    '    "elevation2": "#26881337",' +
    '    "elevation3": "#33881337"' +
    '  },' +
    '  "ink": {' +
    '    "ink": "#4C0519",' +
    '    "inkMuted": "#9F1239"' +
    '  },' +
    '  "brand": {' +
    '    "primary": "#E11D48",' +
    '    "primaryHover": "#BE123C",' +
    '    "primaryPressed": "#9F1239",' +
    '    "onPrimary": "#FFFFFF",' +
    '    "heroGradFrom": "#881337",' +
    '    "heroGradTo": "#FB7185",' +
    '    "focusRing": "#E11D48"' +
    '  }' +
    '}';

  JSON_FROST_CONTRAST =
    '{' +
    '  "id": "frost-contrast",' +
    '  "name": "凝霜·素",' +
    '  "nameEn": "Frost Contrast",' +
    '  "description": "高对比可读 · 户外强光与无障碍",' +
    '  "isDark": false,' +
    '  "surface": {' +
    '    "surface": "#FFFFFF",' +
    '    "surfaceAlt": "#F8FAFC",' +
    '    "border": "#94A3B8",' +
    '    "soft": "#F1F5F9",' +
    '    "sunken": "#E2E8F0",' +
    '    "elevation1": "#26000000",' +
    '    "elevation2": "#3F000000",' +
    '    "elevation3": "#59000000"' +
    '  },' +
    '  "ink": {' +
    '    "ink": "#000000",' +
    '    "inkMuted": "#475569"' +
    '  },' +
    '  "brand": {' +
    '    "primary": "#0284C7",' +
    '    "primaryHover": "#0369A1",' +
    '    "primaryPressed": "#075985",' +
    '    "onPrimary": "#FFFFFF",' +
    '    "heroGradFrom": "#075985",' +
    '    "heroGradTo": "#38BDF8",' +
    '    "focusRing": "#0284C7"' +
    '  }' +
    '}';

  JSON_OCEAN_DEEP =
    '{' +
    '  "id": "ocean-deep",' +
    '  "name": "沧海·蓝",' +
    '  "nameEn": "Ocean Deep",' +
    '  "description": "企业稳健 · 金融与企业应用",' +
    '  "isDark": true,' +
    '  "surface": {' +
    '    "surface": "#0C1322",' +
    '    "surfaceAlt": "#172338",' +
    '    "border": "#233857",' +
    '    "soft": "#1A2840",' +
    '    "sunken": "#070B14",' +
    '    "elevation1": "#33000000",' +
    '    "elevation2": "#4D000000",' +
    '    "elevation3": "#66000000"' +
    '  },' +
    '  "ink": {' +
    '    "ink": "#F0F6FC",' +
    '    "inkMuted": "#8B949E"' +
    '  },' +
    '  "brand": {' +
    '    "primary": "#58A6FF",' +
    '    "primaryHover": "#79B8FF",' +
    '    "primaryPressed": "#388BFD",' +
    '    "onPrimary": "#0C1322",' +
    '    "heroGradFrom": "#1F3B64",' +
    '    "heroGradTo": "#58A6FF",' +
    '    "focusRing": "#58A6FF"' +
    '  }' +
    '}';

  JSON_VIOLET_DUSK =
    '{' +
    '  "id": "violet-dusk",' +
    '  "name": "紫暮·夜",' +
    '  "nameEn": "Violet Dusk",' +
    '  "description": "典雅智能 · AI 创作与尊贵暗色",' +
    '  "isDark": true,' +
    '  "surface": {' +
    '    "surface": "#171226",' +
    '    "surfaceAlt": "#251C3D",' +
    '    "border": "#3E3063",' +
    '    "soft": "#2D224A",' +
    '    "sunken": "#0E0A17",' +
    '    "elevation1": "#33000000",' +
    '    "elevation2": "#4D000000",' +
    '    "elevation3": "#66000000"' +
    '  },' +
    '  "ink": {' +
    '    "ink": "#F5F3FF",' +
    '    "inkMuted": "#A78BFA"' +
    '  },' +
    '  "brand": {' +
    '    "primary": "#C084FC",' +
    '    "primaryHover": "#D8B4FE",' +
    '    "primaryPressed": "#A855F7",' +
    '    "onPrimary": "#171226",' +
    '    "heroGradFrom": "#581C87",' +
    '    "heroGradTo": "#C084FC",' +
    '    "focusRing": "#C084FC"' +
    '  }' +
    '}';

  JSON_TEA_GREEN =
    '{' +
    '  "id": "tea-green",' +
    '  "name": "茶青·韵",' +
    '  "nameEn": "Tea Green",' +
    '  "description": "自然雅致 · 国风与文化社区",' +
    '  "isDark": false,' +
    '  "surface": {' +
    '    "surface": "#F7F8F5",' +
    '    "surfaceAlt": "#EDF0E9",' +
    '    "border": "#D2D8CB",' +
    '    "soft": "#E3E7DE",' +
    '    "sunken": "#DDE3D7",' +
    '    "elevation1": "#1A2B3322",' +
    '    "elevation2": "#262B3322",' +
    '    "elevation3": "#332B3322"' +
    '  },' +
    '  "ink": {' +
    '    "ink": "#2D3728",' +
    '    "inkMuted": "#687560"' +
    '  },' +
    '  "brand": {' +
    '    "primary": "#5A7848",' +
    '    "primaryHover": "#496339",' +
    '    "primaryPressed": "#3A502D",' +
    '    "onPrimary": "#FFFFFF",' +
    '    "heroGradFrom": "#3A502D",' +
    '    "heroGradTo": "#7B9C65",' +
    '    "focusRing": "#5A7848"' +
    '  }' +
    '}';

procedure RegisterBuiltInThemes;
begin
  THbTheme.RegisterThemeFromJson(JSON_HUANJIN_GOLD);
  THbTheme.RegisterThemeFromJson(JSON_HUANJIN_NIGHT);
  THbTheme.RegisterThemeFromJson(JSON_DEEPARW_INDIGO);
  THbTheme.RegisterThemeFromJson(JSON_ADMIN_GRAPHITE);
  THbTheme.RegisterThemeFromJson(JSON_JADE_EMERALD);
  THbTheme.RegisterThemeFromJson(JSON_ROSE_CLAY);
  THbTheme.RegisterThemeFromJson(JSON_FROST_CONTRAST);
  THbTheme.RegisterThemeFromJson(JSON_OCEAN_DEEP);
  THbTheme.RegisterThemeFromJson(JSON_VIOLET_DUSK);
  THbTheme.RegisterThemeFromJson(JSON_TEA_GREEN);
end;

initialization
  RegisterBuiltInThemes;

end.
