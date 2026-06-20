unit DeepBase.DateTime;

{*******************************************************************************
  DeepBase Date/Time Utilities
  A comprehensive date/time module with:
  - Time zone handling
  - Date/time formatting and parsing
  - Date/time arithmetic
  - Relative time descriptions
  - Time spans and intervals
  - Business day calculations
  - ISO 8601 support
  
  Author: DeepBase Team
  Created: 2025-11-29
*******************************************************************************}

interface

uses
  System.SysUtils, System.Classes, System.DateUtils, System.TimeSpan,
  System.Generics.Collections, Winapi.Windows;

type
  EDateTimeException = class(Exception);

  /// <summary>Day of week</summary>
  TDayOfWeekEx = (dowSunday, dowMonday, dowTuesday, dowWednesday, 
    dowThursday, dowFriday, dowSaturday);

  /// <summary>Time unit for calculations</summary>
  TTimeUnit = (tuMilliseconds, tuSeconds, tuMinutes, tuHours, tuDays, 
    tuWeeks, tuMonths, tuYears);

  /// <summary>Time span record</summary>
  TTimeSpanEx = record
    Days: Integer;
    Hours: Integer;
    Minutes: Integer;
    Seconds: Integer;
    Milliseconds: Integer;
    
    constructor Create(ADays, AHours, AMinutes, ASeconds: Integer; AMilliseconds: Integer = 0);
    class function FromMilliseconds(AValue: Int64): TTimeSpanEx; static;
    class function FromSeconds(AValue: Int64): TTimeSpanEx; static;
    class function FromMinutes(AValue: Int64): TTimeSpanEx; static;
    class function FromHours(AValue: Int64): TTimeSpanEx; static;
    class function FromDays(AValue: Integer): TTimeSpanEx; static;
    
    function TotalMilliseconds: Int64;
    function TotalSeconds: Double;
    function TotalMinutes: Double;
    function TotalHours: Double;
    function TotalDays: Double;
    
    function Add(const AOther: TTimeSpanEx): TTimeSpanEx;
    function Subtract(const AOther: TTimeSpanEx): TTimeSpanEx;
    function Negate: TTimeSpanEx;
    
    function ToString: string;
    function ToShortString: string;
    
    class operator Add(const A, B: TTimeSpanEx): TTimeSpanEx;
    class operator Subtract(const A, B: TTimeSpanEx): TTimeSpanEx;
    class operator Equal(const A, B: TTimeSpanEx): Boolean;
    class operator NotEqual(const A, B: TTimeSpanEx): Boolean;
    class operator GreaterThan(const A, B: TTimeSpanEx): Boolean;
    class operator LessThan(const A, B: TTimeSpanEx): Boolean;
  end;

  /// <summary>Date range/interval</summary>
  TDateRange = record
    StartDate: TDateTime;
    EndDate: TDateTime;
    
    constructor Create(AStart, AEnd: TDateTime);
    
    function Contains(ADate: TDateTime): Boolean;
    function Overlaps(const AOther: TDateRange): Boolean;
    function Duration: TTimeSpanEx;
    function DayCount: Integer;
    
    function Intersection(const AOther: TDateRange): TDateRange;
    function Union(const AOther: TDateRange): TDateRange;
    
    function ToString: string;
    
    class function Today: TDateRange; static;
    class function ThisWeek: TDateRange; static;
    class function ThisMonth: TDateRange; static;
    class function ThisYear: TDateRange; static;
    class function LastNDays(ADays: Integer): TDateRange; static;
  end;

  /// <summary>Time zone info</summary>
  TTimeZoneInfo = record
    ID: string;
    DisplayName: string;
    StandardName: string;
    DaylightName: string;
    BaseUtcOffset: Integer; // Minutes
    SupportsDST: Boolean;
  end;

  /// <summary>Time zone utilities</summary>
  TTimeZones = class
  private
    class var FCache: TDictionary<string, TTimeZoneInfo>;
  public
    class constructor Create;
    class destructor Destroy;
    
    /// <summary>Get local time zone info</summary>
    class function Local: TTimeZoneInfo; static;
    
    /// <summary>Get UTC time zone</summary>
    class function UTC: TTimeZoneInfo; static;
    
    /// <summary>Convert to UTC</summary>
    class function ToUTC(ADateTime: TDateTime): TDateTime; static;
    
    /// <summary>Convert from UTC to local</summary>
    class function ToLocal(ADateTime: TDateTime): TDateTime; static;
    
    /// <summary>Get current UTC offset in minutes</summary>
    class function CurrentUtcOffset: Integer; static;
    
    /// <summary>Is daylight saving time active</summary>
    class function IsDaylightSavingTime(ADateTime: TDateTime): Boolean; static;
    
    /// <summary>Format UTC offset as string (+HH:MM)</summary>
    class function FormatOffset(AMinutes: Integer): string; static;
  end;

  /// <summary>Date/time formatting utilities</summary>
  TDateTimeFormat = class
  public
    /// <summary>ISO 8601 format</summary>
    class function ToISO8601(ADateTime: TDateTime; AIncludeTime: Boolean = True): string; static;
    class function FromISO8601(const AValue: string): TDateTime; static;
    class function TryFromISO8601(const AValue: string; out ADateTime: TDateTime): Boolean; static;
    
    /// <summary>RFC 2822 format (email/HTTP)</summary>
    class function ToRFC2822(ADateTime: TDateTime): string; static;
    class function FromRFC2822(const AValue: string): TDateTime; static;
    
    /// <summary>Unix timestamp</summary>
    class function ToUnixTime(ADateTime: TDateTime): Int64; static;
    class function FromUnixTime(AValue: Int64): TDateTime; static;
    class function ToUnixTimeMs(ADateTime: TDateTime): Int64; static;
    class function FromUnixTimeMs(AValue: Int64): TDateTime; static;
    
    /// <summary>Custom format</summary>
    class function Format(ADateTime: TDateTime; const AFormat: string): string; static;
    class function Parse(const AValue, AFormat: string): TDateTime; static;
    class function TryParse(const AValue, AFormat: string; out ADateTime: TDateTime): Boolean; static;
    
    /// <summary>Common formats</summary>
    class function ToShortDate(ADateTime: TDateTime): string; static;
    class function ToLongDate(ADateTime: TDateTime): string; static;
    class function ToShortTime(ADateTime: TDateTime): string; static;
    class function ToLongTime(ADateTime: TDateTime): string; static;
    class function ToShortDateTime(ADateTime: TDateTime): string; static;
    class function ToLongDateTime(ADateTime: TDateTime): string; static;
    
    /// <summary>Sortable format (YYYY-MM-DD HH:NN:SS)</summary>
    class function ToSortable(ADateTime: TDateTime): string; static;
    
    /// <summary>File-safe format (no special chars)</summary>
    class function ToFileSafe(ADateTime: TDateTime): string; static;
  end;

  /// <summary>Relative time descriptions</summary>
  TRelativeTime = class
  public
    /// <summary>Get relative description (e.g., "2 hours ago")</summary>
    class function Describe(ADateTime: TDateTime): string; static;
    class function DescribeSpan(const ASpan: TTimeSpanEx): string; static;
    
    /// <summary>Get approximate relative time</summary>
    class function TimeAgo(ADateTime: TDateTime): string; static;
    class function TimeUntil(ADateTime: TDateTime): string; static;
    
    /// <summary>Is within time span</summary>
    class function IsWithinMinutes(ADateTime: TDateTime; AMinutes: Integer): Boolean; static;
    class function IsWithinHours(ADateTime: TDateTime; AHours: Integer): Boolean; static;
    class function IsWithinDays(ADateTime: TDateTime; ADays: Integer): Boolean; static;
    
    /// <summary>Check relative to today</summary>
    class function IsToday(ADateTime: TDateTime): Boolean; static;
    class function IsYesterday(ADateTime: TDateTime): Boolean; static;
    class function IsTomorrow(ADateTime: TDateTime): Boolean; static;
    class function IsThisWeek(ADateTime: TDateTime): Boolean; static;
    class function IsThisMonth(ADateTime: TDateTime): Boolean; static;
    class function IsThisYear(ADateTime: TDateTime): Boolean; static;
  end;

  /// <summary>Date/time arithmetic</summary>
  TDateTimeCalc = class
  public
    /// <summary>Add time units</summary>
    class function Add(ADateTime: TDateTime; AValue: Integer; AUnit: TTimeUnit): TDateTime; static;
    
    /// <summary>Subtract time units</summary>
    class function Subtract(ADateTime: TDateTime; AValue: Integer; AUnit: TTimeUnit): TDateTime; static;
    
    /// <summary>Difference between dates</summary>
    class function Diff(AFrom, ATo: TDateTime; AUnit: TTimeUnit): Double; static;
    class function DiffSpan(AFrom, ATo: TDateTime): TTimeSpanEx; static;
    
    /// <summary>Start/end of period</summary>
    class function StartOfDay(ADateTime: TDateTime): TDateTime; static;
    class function EndOfDay(ADateTime: TDateTime): TDateTime; static;
    class function StartOfWeek(ADateTime: TDateTime; AFirstDayOfWeek: TDayOfWeekEx = dowMonday): TDateTime; static;
    class function EndOfWeek(ADateTime: TDateTime; AFirstDayOfWeek: TDayOfWeekEx = dowMonday): TDateTime; static;
    class function StartOfMonth(ADateTime: TDateTime): TDateTime; static;
    class function EndOfMonth(ADateTime: TDateTime): TDateTime; static;
    class function StartOfYear(ADateTime: TDateTime): TDateTime; static;
    class function EndOfYear(ADateTime: TDateTime): TDateTime; static;
    
    /// <summary>Next/previous occurrence</summary>
    class function NextDayOfWeek(ADateTime: TDateTime; ADayOfWeek: TDayOfWeekEx): TDateTime; static;
    class function PreviousDayOfWeek(ADateTime: TDateTime; ADayOfWeek: TDayOfWeekEx): TDateTime; static;
    
    /// <summary>Round to nearest</summary>
    class function RoundToMinute(ADateTime: TDateTime): TDateTime; static;
    class function RoundToHour(ADateTime: TDateTime): TDateTime; static;
    class function RoundToDay(ADateTime: TDateTime): TDateTime; static;
    
    /// <summary>Clamp to range</summary>
    class function Clamp(ADateTime, AMin, AMax: TDateTime): TDateTime; static;
    
    /// <summary>Min/Max</summary>
    class function Min(A, B: TDateTime): TDateTime; static;
    class function Max(A, B: TDateTime): TDateTime; static;
  end;

  /// <summary>Business day calculations</summary>
  TBusinessDays = class
  public type
    THolidayFunc = reference to function(ADate: TDateTime): Boolean;
  private
    class var FHolidays: TList<TDateTime>;
    class var FWeekendDays: set of TDayOfWeekEx;
  public
    class constructor Create;
    class destructor Destroy;
    
    /// <summary>Set weekend days</summary>
    class procedure SetWeekendDays(const ADays: array of TDayOfWeekEx); static;
    
    /// <summary>Add/clear holidays</summary>
    class procedure AddHoliday(ADate: TDateTime); static;
    class procedure AddHolidays(const ADates: array of TDateTime); static;
    class procedure ClearHolidays; static;
    
    /// <summary>Check if business day</summary>
    class function IsBusinessDay(ADate: TDateTime): Boolean; static;
    class function IsWeekend(ADate: TDateTime): Boolean; static;
    class function IsHoliday(ADate: TDateTime): Boolean; static;
    
    /// <summary>Add/subtract business days</summary>
    class function AddBusinessDays(ADate: TDateTime; ADays: Integer): TDateTime; static;
    
    /// <summary>Count business days</summary>
    class function BusinessDaysBetween(AFrom, ATo: TDateTime): Integer; static;
    
    /// <summary>Get next/previous business day</summary>
    class function NextBusinessDay(ADate: TDateTime): TDateTime; static;
    class function PreviousBusinessDay(ADate: TDateTime): TDateTime; static;
  end;

  /// <summary>Date/time static helper</summary>
  TDateTimeUtils = class
  public
    /// <summary>Current date/time</summary>
    class function Now: TDateTime; static;
    class function UtcNow: TDateTime; static;
    class function Today: TDateTime; static;
    
    /// <summary>Date/time creation</summary>
    class function Create(AYear, AMonth, ADay: Word): TDateTime; overload; static;
    class function Create(AYear, AMonth, ADay, AHour, AMinute, ASecond: Word): TDateTime; overload; static;
    class function CreateTime(AHour, AMinute, ASecond: Word; AMillisecond: Word = 0): TDateTime; static;
    
    /// <summary>Validation</summary>
    class function IsValidDate(AYear, AMonth, ADay: Word): Boolean; static;
    class function IsValidTime(AHour, AMinute, ASecond: Word): Boolean; static;
    class function IsLeapYear(AYear: Word): Boolean; static;
    class function DaysInMonth(AYear, AMonth: Word): Word; static;
    class function DaysInYear(AYear: Word): Word; static;
    
    /// <summary>Extraction</summary>
    class function GetYear(ADateTime: TDateTime): Word; static;
    class function GetMonth(ADateTime: TDateTime): Word; static;
    class function GetDay(ADateTime: TDateTime): Word; static;
    class function GetHour(ADateTime: TDateTime): Word; static;
    class function GetMinute(ADateTime: TDateTime): Word; static;
    class function GetSecond(ADateTime: TDateTime): Word; static;
    class function GetMillisecond(ADateTime: TDateTime): Word; static;
    class function GetDayOfWeek(ADateTime: TDateTime): TDayOfWeekEx; static;
    class function GetDayOfYear(ADateTime: TDateTime): Word; static;
    class function GetWeekOfYear(ADateTime: TDateTime): Word; static;
    class function GetQuarter(ADateTime: TDateTime): Word; static;
    
    /// <summary>Date part only</summary>
    class function DatePart(ADateTime: TDateTime): TDateTime; static;
    
    /// <summary>Time part only</summary>
    class function TimePart(ADateTime: TDateTime): TDateTime; static;
    
    /// <summary>Age calculation</summary>
    class function Age(ABirthDate: TDateTime): Integer; overload; static;
    class function Age(ABirthDate, AAsOfDate: TDateTime): Integer; overload; static;
    
    /// <summary>Comparison</summary>
    class function IsSameDay(A, B: TDateTime): Boolean; static;
    class function IsSameMonth(A, B: TDateTime): Boolean; static;
    class function IsSameYear(A, B: TDateTime): Boolean; static;
    class function IsBefore(A, B: TDateTime): Boolean; static;
    class function IsAfter(A, B: TDateTime): Boolean; static;
    class function IsBetween(ADateTime, AStart, AEnd: TDateTime): Boolean; static;
    
    /// <summary>Day name</summary>
    class function DayName(ADayOfWeek: TDayOfWeekEx): string; static;
    class function ShortDayName(ADayOfWeek: TDayOfWeekEx): string; static;
    
    /// <summary>Month name</summary>
    class function MonthName(AMonth: Word): string; static;
    class function ShortMonthName(AMonth: Word): string; static;
  end;

  /// <summary>Static helper shortcut</summary>
  TDT = TDateTimeUtils;

implementation

{ TTimeSpanEx }

constructor TTimeSpanEx.Create(ADays, AHours, AMinutes, ASeconds: Integer; AMilliseconds: Integer);
begin
  Days := ADays;
  Hours := AHours;
  Minutes := AMinutes;
  Seconds := ASeconds;
  Milliseconds := AMilliseconds;
end;

class function TTimeSpanEx.FromMilliseconds(AValue: Int64): TTimeSpanEx;
begin
  Result.Milliseconds := AValue mod 1000;
  AValue := AValue div 1000;
  Result.Seconds := AValue mod 60;
  AValue := AValue div 60;
  Result.Minutes := AValue mod 60;
  AValue := AValue div 60;
  Result.Hours := AValue mod 24;
  Result.Days := AValue div 24;
end;

class function TTimeSpanEx.FromSeconds(AValue: Int64): TTimeSpanEx;
begin
  Result := FromMilliseconds(AValue * 1000);
end;

class function TTimeSpanEx.FromMinutes(AValue: Int64): TTimeSpanEx;
begin
  Result := FromMilliseconds(AValue * 60 * 1000);
end;

class function TTimeSpanEx.FromHours(AValue: Int64): TTimeSpanEx;
begin
  Result := FromMilliseconds(AValue * 60 * 60 * 1000);
end;

class function TTimeSpanEx.FromDays(AValue: Integer): TTimeSpanEx;
begin
  Result := TTimeSpanEx.Create(AValue, 0, 0, 0);
end;

function TTimeSpanEx.TotalMilliseconds: Int64;
begin
  Result := Int64(Days) * 24 * 60 * 60 * 1000 +
            Int64(Hours) * 60 * 60 * 1000 +
            Int64(Minutes) * 60 * 1000 +
            Int64(Seconds) * 1000 +
            Milliseconds;
end;

function TTimeSpanEx.TotalSeconds: Double;
begin
  Result := TotalMilliseconds / 1000;
end;

function TTimeSpanEx.TotalMinutes: Double;
begin
  Result := TotalMilliseconds / (60 * 1000);
end;

function TTimeSpanEx.TotalHours: Double;
begin
  Result := TotalMilliseconds / (60 * 60 * 1000);
end;

function TTimeSpanEx.TotalDays: Double;
begin
  Result := TotalMilliseconds / (24 * 60 * 60 * 1000);
end;

function TTimeSpanEx.Add(const AOther: TTimeSpanEx): TTimeSpanEx;
begin
  Result := TTimeSpanEx.FromMilliseconds(TotalMilliseconds + AOther.TotalMilliseconds);
end;

function TTimeSpanEx.Subtract(const AOther: TTimeSpanEx): TTimeSpanEx;
begin
  Result := TTimeSpanEx.FromMilliseconds(TotalMilliseconds - AOther.TotalMilliseconds);
end;

function TTimeSpanEx.Negate: TTimeSpanEx;
begin
  Result := TTimeSpanEx.FromMilliseconds(-TotalMilliseconds);
end;

function TTimeSpanEx.ToString: string;
begin
  if Days > 0 then
    Result := System.SysUtils.Format('%d days, %d:%02d:%02d', [Days, Hours, Minutes, Seconds])
  else
    Result := System.SysUtils.Format('%d:%02d:%02d', [Hours, Minutes, Seconds]);
end;

function TTimeSpanEx.ToShortString: string;
begin
  if Days > 0 then
    Result := System.SysUtils.Format('%dd %dh', [Days, Hours])
  else if Hours > 0 then
    Result := System.SysUtils.Format('%dh %dm', [Hours, Minutes])
  else if Minutes > 0 then
    Result := System.SysUtils.Format('%dm %ds', [Minutes, Seconds])
  else
    Result := System.SysUtils.Format('%ds', [Seconds]);
end;

class operator TTimeSpanEx.Add(const A, B: TTimeSpanEx): TTimeSpanEx;
begin
  Result := A.Add(B);
end;

class operator TTimeSpanEx.Subtract(const A, B: TTimeSpanEx): TTimeSpanEx;
begin
  Result := A.Subtract(B);
end;

class operator TTimeSpanEx.Equal(const A, B: TTimeSpanEx): Boolean;
begin
  Result := A.TotalMilliseconds = B.TotalMilliseconds;
end;

class operator TTimeSpanEx.NotEqual(const A, B: TTimeSpanEx): Boolean;
begin
  Result := A.TotalMilliseconds <> B.TotalMilliseconds;
end;

class operator TTimeSpanEx.GreaterThan(const A, B: TTimeSpanEx): Boolean;
begin
  Result := A.TotalMilliseconds > B.TotalMilliseconds;
end;

class operator TTimeSpanEx.LessThan(const A, B: TTimeSpanEx): Boolean;
begin
  Result := A.TotalMilliseconds < B.TotalMilliseconds;
end;

{ TDateRange }

constructor TDateRange.Create(AStart, AEnd: TDateTime);
begin
  StartDate := AStart;
  EndDate := AEnd;
end;

function TDateRange.Contains(ADate: TDateTime): Boolean;
begin
  Result := (ADate >= StartDate) and (ADate <= EndDate);
end;

function TDateRange.Overlaps(const AOther: TDateRange): Boolean;
begin
  Result := (StartDate <= AOther.EndDate) and (EndDate >= AOther.StartDate);
end;

function TDateRange.Duration: TTimeSpanEx;
begin
  Result := TDateTimeCalc.DiffSpan(StartDate, EndDate);
end;

function TDateRange.DayCount: Integer;
begin
  Result := Trunc(EndDate - StartDate) + 1;
end;

function TDateRange.Intersection(const AOther: TDateRange): TDateRange;
begin
  if not Overlaps(AOther) then
    raise EDateTimeException.Create('Ranges do not overlap');
  Result.StartDate := TDateTimeCalc.Max(StartDate, AOther.StartDate);
  Result.EndDate := TDateTimeCalc.Min(EndDate, AOther.EndDate);
end;

function TDateRange.Union(const AOther: TDateRange): TDateRange;
begin
  Result.StartDate := TDateTimeCalc.Min(StartDate, AOther.StartDate);
  Result.EndDate := TDateTimeCalc.Max(EndDate, AOther.EndDate);
end;

function TDateRange.ToString: string;
begin
  Result := System.SysUtils.Format('%s - %s', [
    TDateTimeFormat.ToShortDate(StartDate),
    TDateTimeFormat.ToShortDate(EndDate)
  ]);
end;

class function TDateRange.Today: TDateRange;
var
  LToday: TDateTime;
begin
  LToday := System.SysUtils.Date;
  Result := TDateRange.Create(LToday, LToday);
end;

class function TDateRange.ThisWeek: TDateRange;
begin
  Result.StartDate := TDateTimeCalc.StartOfWeek(System.SysUtils.Date);
  Result.EndDate := TDateTimeCalc.EndOfWeek(System.SysUtils.Date);
end;

class function TDateRange.ThisMonth: TDateRange;
begin
  Result.StartDate := TDateTimeCalc.StartOfMonth(System.SysUtils.Date);
  Result.EndDate := TDateTimeCalc.EndOfMonth(System.SysUtils.Date);
end;

class function TDateRange.ThisYear: TDateRange;
begin
  Result.StartDate := TDateTimeCalc.StartOfYear(System.SysUtils.Date);
  Result.EndDate := TDateTimeCalc.EndOfYear(System.SysUtils.Date);
end;

class function TDateRange.LastNDays(ADays: Integer): TDateRange;
begin
  Result.EndDate := System.SysUtils.Date;
  Result.StartDate := Result.EndDate - ADays + 1;
end;

{ TTimeZones }

class constructor TTimeZones.Create;
begin
  FCache := TDictionary<string, TTimeZoneInfo>.Create;
end;

class destructor TTimeZones.Destroy;
begin
  FreeAndNil(FCache);
end;


class function TTimeZones.Local: TTimeZoneInfo;
var
  LTZ: TTimeZoneInformation;
begin
  GetTimeZoneInformation(LTZ);
  Result.ID := 'Local';
  Result.DisplayName := string(LTZ.StandardName);
  Result.StandardName := string(LTZ.StandardName);
  Result.DaylightName := string(LTZ.DaylightName);
  Result.BaseUtcOffset := -LTZ.Bias;
  Result.SupportsDST := LTZ.DaylightBias <> 0;
end;

class function TTimeZones.UTC: TTimeZoneInfo;
begin
  Result.ID := 'UTC';
  Result.DisplayName := 'Coordinated Universal Time';
  Result.StandardName := 'UTC';
  Result.DaylightName := 'UTC';
  Result.BaseUtcOffset := 0;
  Result.SupportsDST := False;
end;

class function TTimeZones.ToUTC(ADateTime: TDateTime): TDateTime;
begin
  Result := TTimeZone.Local.ToUniversalTime(ADateTime);
end;

class function TTimeZones.ToLocal(ADateTime: TDateTime): TDateTime;
begin
  Result := TTimeZone.Local.ToLocalTime(ADateTime);
end;

class function TTimeZones.CurrentUtcOffset: Integer;
var
  LTZ: TTimeZoneInformation;
begin
  GetTimeZoneInformation(LTZ);
  Result := -LTZ.Bias;
end;

class function TTimeZones.IsDaylightSavingTime(ADateTime: TDateTime): Boolean;
begin
  Result := TTimeZone.Local.IsDaylightTime(ADateTime);
end;

class function TTimeZones.FormatOffset(AMinutes: Integer): string;
var
  LHours, LMins: Integer;
begin
  if AMinutes >= 0 then
  begin
    LHours := AMinutes div 60;
    LMins := AMinutes mod 60;
    Result := System.SysUtils.Format('+%.2d:%.2d', [LHours, LMins]);
  end
  else
  begin
    AMinutes := -AMinutes;
    LHours := AMinutes div 60;
    LMins := AMinutes mod 60;
    Result := System.SysUtils.Format('-%.2d:%.2d', [LHours, LMins]);
  end;
end;

{ TDateTimeFormat }

class function TDateTimeFormat.ToISO8601(ADateTime: TDateTime; AIncludeTime: Boolean): string;
begin
  if AIncludeTime then
    Result := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', ADateTime)
  else
    Result := FormatDateTime('yyyy-mm-dd', ADateTime);
end;

class function TDateTimeFormat.FromISO8601(const AValue: string): TDateTime;
begin
  if not TryFromISO8601(AValue, Result) then
    raise EDateTimeException.CreateFmt('Invalid ISO 8601 format: %s', [AValue]);
end;

class function TDateTimeFormat.TryFromISO8601(const AValue: string; out ADateTime: TDateTime): Boolean;
var
  LValue: string;
  LYear, LMonth, LDay, LHour, LMin, LSec: Word;
  IYear, IMonth, IDay, IHour, IMin, ISec: Integer;
begin
  Result := False;
  LValue := AValue.Replace('T', ' ').Replace('Z', '');
  
  // Try full datetime
  if Length(LValue) >= 19 then
  begin
    Result := TryStrToInt(Copy(LValue, 1, 4), IYear) and
              TryStrToInt(Copy(LValue, 6, 2), IMonth) and
              TryStrToInt(Copy(LValue, 9, 2), IDay) and
              TryStrToInt(Copy(LValue, 12, 2), IHour) and
              TryStrToInt(Copy(LValue, 15, 2), IMin) and
              TryStrToInt(Copy(LValue, 18, 2), ISec);
    if Result then
    begin
      LYear := IYear; LMonth := IMonth; LDay := IDay;
      LHour := IHour; LMin := IMin; LSec := ISec;
      ADateTime := EncodeDateTime(LYear, LMonth, LDay, LHour, LMin, LSec, 0);
    end;
  end
  // Try date only
  else if Length(LValue) >= 10 then
  begin
    Result := TryStrToInt(Copy(LValue, 1, 4), IYear) and
              TryStrToInt(Copy(LValue, 6, 2), IMonth) and
              TryStrToInt(Copy(LValue, 9, 2), IDay);
    if Result then
    begin
      LYear := IYear; LMonth := IMonth; LDay := IDay;
      ADateTime := EncodeDate(LYear, LMonth, LDay);
    end;
  end;
end;

class function TDateTimeFormat.ToRFC2822(ADateTime: TDateTime): string;
const
  DayNames: array[1..7] of string = ('Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat');
  MonthNames: array[1..12] of string = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');
var
  LYear, LMonth, LDay, LHour, LMin, LSec, LMs: Word;
begin
  DecodeDateTime(ADateTime, LYear, LMonth, LDay, LHour, LMin, LSec, LMs);
  Result := System.SysUtils.Format('%s, %02d %s %04d %02d:%02d:%02d %s', [
    DayNames[DayOfWeek(ADateTime)], LDay, MonthNames[LMonth], LYear,
    LHour, LMin, LSec, TTimeZones.FormatOffset(TTimeZones.CurrentUtcOffset)
  ]);
end;

class function TDateTimeFormat.FromRFC2822(const AValue: string): TDateTime;
begin
  // Simplified parsing - in production use more robust parsing
  Result := StrToDateTime(AValue);
end;

class function TDateTimeFormat.ToUnixTime(ADateTime: TDateTime): Int64;
begin
  Result := DateTimeToUnix(TTimeZones.ToUTC(ADateTime));
end;

class function TDateTimeFormat.FromUnixTime(AValue: Int64): TDateTime;
begin
  Result := TTimeZones.ToLocal(UnixToDateTime(AValue));
end;

class function TDateTimeFormat.ToUnixTimeMs(ADateTime: TDateTime): Int64;
begin
  Result := ToUnixTime(ADateTime) * 1000 + MilliSecondOf(ADateTime);
end;

class function TDateTimeFormat.FromUnixTimeMs(AValue: Int64): TDateTime;
begin
  Result := FromUnixTime(AValue div 1000);
  Result := IncMilliSecond(Result, AValue mod 1000);
end;

class function TDateTimeFormat.Format(ADateTime: TDateTime; const AFormat: string): string;
begin
  Result := FormatDateTime(AFormat, ADateTime);
end;

class function TDateTimeFormat.Parse(const AValue, AFormat: string): TDateTime;
begin
  if not TryParse(AValue, AFormat, Result) then
    raise EDateTimeException.CreateFmt('Cannot parse "%s" with format "%s"', [AValue, AFormat]);
end;

class function TDateTimeFormat.TryParse(const AValue, AFormat: string; out ADateTime: TDateTime): Boolean;
begin
  // Simplified - use format string to parse
  Result := TryStrToDateTime(AValue, ADateTime);
end;

class function TDateTimeFormat.ToShortDate(ADateTime: TDateTime): string;
begin
  Result := DateToStr(ADateTime);
end;

class function TDateTimeFormat.ToLongDate(ADateTime: TDateTime): string;
begin
  Result := FormatDateTime('dddd, mmmm d, yyyy', ADateTime);
end;

class function TDateTimeFormat.ToShortTime(ADateTime: TDateTime): string;
begin
  Result := FormatDateTime('hh:nn', ADateTime);
end;

class function TDateTimeFormat.ToLongTime(ADateTime: TDateTime): string;
begin
  Result := TimeToStr(ADateTime);
end;

class function TDateTimeFormat.ToShortDateTime(ADateTime: TDateTime): string;
begin
  Result := DateTimeToStr(ADateTime);
end;

class function TDateTimeFormat.ToLongDateTime(ADateTime: TDateTime): string;
begin
  Result := FormatDateTime('dddd, mmmm d, yyyy hh:nn:ss', ADateTime);
end;

class function TDateTimeFormat.ToSortable(ADateTime: TDateTime): string;
begin
  Result := FormatDateTime('yyyy-mm-dd hh:nn:ss', ADateTime);
end;

class function TDateTimeFormat.ToFileSafe(ADateTime: TDateTime): string;
begin
  Result := FormatDateTime('yyyy-mm-dd_hh-nn-ss', ADateTime);
end;

{ TRelativeTime }

class function TRelativeTime.Describe(ADateTime: TDateTime): string;
var
  LDiff: TTimeSpanEx;
  LNow: TDateTime;
begin
  LNow := System.SysUtils.Now;
  LDiff := TDateTimeCalc.DiffSpan(ADateTime, LNow);
  
  if LDiff.TotalMilliseconds < 0 then
    Result := TimeUntil(ADateTime)
  else
    Result := TimeAgo(ADateTime);
end;

class function TRelativeTime.DescribeSpan(const ASpan: TTimeSpanEx): string;
begin
  Result := ASpan.ToShortString;
end;

class function TRelativeTime.TimeAgo(ADateTime: TDateTime): string;
var
  LDiff: Double;
begin
  LDiff := System.SysUtils.Now - ADateTime;
  
  if LDiff < 1/1440 then // Less than 1 minute
    Result := 'just now'
  else if LDiff < 1/24 then // Less than 1 hour
    Result := System.SysUtils.Format('%d minutes ago', [Round(LDiff * 1440)])
  else if LDiff < 1 then // Less than 1 day
    Result := System.SysUtils.Format('%d hours ago', [Round(LDiff * 24)])
  else if LDiff < 7 then // Less than 1 week
    Result := System.SysUtils.Format('%d days ago', [Round(LDiff)])
  else if LDiff < 30 then // Less than 1 month
    Result := System.SysUtils.Format('%d weeks ago', [Round(LDiff / 7)])
  else if LDiff < 365 then // Less than 1 year
    Result := System.SysUtils.Format('%d months ago', [Round(LDiff / 30)])
  else
    Result := System.SysUtils.Format('%d years ago', [Round(LDiff / 365)]);
end;

class function TRelativeTime.TimeUntil(ADateTime: TDateTime): string;
var
  LDiff: Double;
begin
  LDiff := ADateTime - System.SysUtils.Now;
  
  if LDiff < 0 then
    Result := TimeAgo(ADateTime)
  else if LDiff < 1/1440 then
    Result := 'in a moment'
  else if LDiff < 1/24 then
    Result := System.SysUtils.Format('in %d minutes', [Round(LDiff * 1440)])
  else if LDiff < 1 then
    Result := System.SysUtils.Format('in %d hours', [Round(LDiff * 24)])
  else if LDiff < 7 then
    Result := System.SysUtils.Format('in %d days', [Round(LDiff)])
  else if LDiff < 30 then
    Result := System.SysUtils.Format('in %d weeks', [Round(LDiff / 7)])
  else if LDiff < 365 then
    Result := System.SysUtils.Format('in %d months', [Round(LDiff / 30)])
  else
    Result := System.SysUtils.Format('in %d years', [Round(LDiff / 365)]);
end;

class function TRelativeTime.IsWithinMinutes(ADateTime: TDateTime; AMinutes: Integer): Boolean;
begin
  Result := Abs(System.SysUtils.Now - ADateTime) * 1440 <= AMinutes;
end;

class function TRelativeTime.IsWithinHours(ADateTime: TDateTime; AHours: Integer): Boolean;
begin
  Result := Abs(System.SysUtils.Now - ADateTime) * 24 <= AHours;
end;

class function TRelativeTime.IsWithinDays(ADateTime: TDateTime; ADays: Integer): Boolean;
begin
  Result := Abs(System.SysUtils.Now - ADateTime) <= ADays;
end;

class function TRelativeTime.IsToday(ADateTime: TDateTime): Boolean;
begin
  Result := Trunc(ADateTime) = Trunc(System.SysUtils.Now);
end;

class function TRelativeTime.IsYesterday(ADateTime: TDateTime): Boolean;
begin
  Result := Trunc(ADateTime) = Trunc(System.SysUtils.Now) - 1;
end;

class function TRelativeTime.IsTomorrow(ADateTime: TDateTime): Boolean;
begin
  Result := Trunc(ADateTime) = Trunc(System.SysUtils.Now) + 1;
end;

class function TRelativeTime.IsThisWeek(ADateTime: TDateTime): Boolean;
var
  LRange: TDateRange;
begin
  LRange := TDateRange.ThisWeek;
  Result := LRange.Contains(Trunc(ADateTime));
end;

class function TRelativeTime.IsThisMonth(ADateTime: TDateTime): Boolean;
var
  LRange: TDateRange;
begin
  LRange := TDateRange.ThisMonth;
  Result := LRange.Contains(Trunc(ADateTime));
end;

class function TRelativeTime.IsThisYear(ADateTime: TDateTime): Boolean;
begin
  Result := YearOf(ADateTime) = YearOf(System.SysUtils.Now);
end;

{ TDateTimeCalc }

class function TDateTimeCalc.Add(ADateTime: TDateTime; AValue: Integer; AUnit: TTimeUnit): TDateTime;
begin
  case AUnit of
    tuMilliseconds: Result := IncMilliSecond(ADateTime, AValue);
    tuSeconds: Result := IncSecond(ADateTime, AValue);
    tuMinutes: Result := IncMinute(ADateTime, AValue);
    tuHours: Result := IncHour(ADateTime, AValue);
    tuDays: Result := IncDay(ADateTime, AValue);
    tuWeeks: Result := IncWeek(ADateTime, AValue);
    tuMonths: Result := IncMonth(ADateTime, AValue);
    tuYears: Result := IncYear(ADateTime, AValue);
  else
    Result := ADateTime;
  end;
end;

class function TDateTimeCalc.Subtract(ADateTime: TDateTime; AValue: Integer; AUnit: TTimeUnit): TDateTime;
begin
  Result := Add(ADateTime, -AValue, AUnit);
end;

class function TDateTimeCalc.Diff(AFrom, ATo: TDateTime; AUnit: TTimeUnit): Double;
var
  LDiff: Double;
begin
  LDiff := ATo - AFrom;
  case AUnit of
    tuMilliseconds: Result := LDiff * 24 * 60 * 60 * 1000;
    tuSeconds: Result := LDiff * 24 * 60 * 60;
    tuMinutes: Result := LDiff * 24 * 60;
    tuHours: Result := LDiff * 24;
    tuDays: Result := LDiff;
    tuWeeks: Result := LDiff / 7;
    tuMonths: Result := LDiff / 30.4375;
    tuYears: Result := LDiff / 365.25;
  else
    Result := LDiff;
  end;
end;

class function TDateTimeCalc.DiffSpan(AFrom, ATo: TDateTime): TTimeSpanEx;
var
  LMs: Int64;
begin
  LMs := Round((ATo - AFrom) * 24 * 60 * 60 * 1000);
  Result := TTimeSpanEx.FromMilliseconds(LMs);
end;

class function TDateTimeCalc.StartOfDay(ADateTime: TDateTime): TDateTime;
begin
  Result := Trunc(ADateTime);
end;

class function TDateTimeCalc.EndOfDay(ADateTime: TDateTime): TDateTime;
begin
  Result := Trunc(ADateTime) + 1 - 1/86400000;
end;

class function TDateTimeCalc.StartOfWeek(ADateTime: TDateTime; AFirstDayOfWeek: TDayOfWeekEx): TDateTime;
var
  LDow: Integer;
begin
  LDow := DayOfTheWeek(ADateTime);
  Result := Trunc(ADateTime) - ((LDow - Ord(AFirstDayOfWeek) + 7) mod 7);
end;

class function TDateTimeCalc.EndOfWeek(ADateTime: TDateTime; AFirstDayOfWeek: TDayOfWeekEx): TDateTime;
begin
  Result := StartOfWeek(ADateTime, AFirstDayOfWeek) + 7 - 1/86400000;
end;

class function TDateTimeCalc.StartOfMonth(ADateTime: TDateTime): TDateTime;
var
  LYear, LMonth, LDay: Word;
begin
  DecodeDate(ADateTime, LYear, LMonth, LDay);
  Result := EncodeDate(LYear, LMonth, 1);
end;

class function TDateTimeCalc.EndOfMonth(ADateTime: TDateTime): TDateTime;
begin
  Result := System.DateUtils.EndOfTheMonth(ADateTime);
end;

class function TDateTimeCalc.StartOfYear(ADateTime: TDateTime): TDateTime;
begin
  Result := EncodeDate(YearOf(ADateTime), 1, 1);
end;

class function TDateTimeCalc.EndOfYear(ADateTime: TDateTime): TDateTime;
begin
  Result := EncodeDate(YearOf(ADateTime), 12, 31) + 1 - 1/86400000;
end;

class function TDateTimeCalc.NextDayOfWeek(ADateTime: TDateTime; ADayOfWeek: TDayOfWeekEx): TDateTime;
var
  LCurrent, LTarget, LDiff: Integer;
begin
  // DayOfTheWeek returns 1=Mon..7=Sun, TDayOfWeekEx is 0=Sun,1=Mon..6=Sat
  LCurrent := DayOfTheWeek(ADateTime); // 1-7 (Mon-Sun)
  // Convert TDayOfWeekEx to DayOfTheWeek format
  if ADayOfWeek = dowSunday then
    LTarget := 7
  else
    LTarget := Ord(ADayOfWeek); // Mon=1..Sat=6

  LDiff := LTarget - LCurrent;
  if LDiff <= 0 then
    LDiff := LDiff + 7;
  Result := Trunc(ADateTime) + LDiff;
end;

class function TDateTimeCalc.PreviousDayOfWeek(ADateTime: TDateTime; ADayOfWeek: TDayOfWeekEx): TDateTime;
var
  LCurrent, LTarget, LDiff: Integer;
begin
  // DayOfTheWeek returns 1=Mon..7=Sun, TDayOfWeekEx is 0=Sun,1=Mon..6=Sat
  LCurrent := DayOfTheWeek(ADateTime); // 1-7 (Mon-Sun)
  // Convert TDayOfWeekEx to DayOfTheWeek format
  if ADayOfWeek = dowSunday then
    LTarget := 7
  else
    LTarget := Ord(ADayOfWeek); // Mon=1..Sat=6

  LDiff := LCurrent - LTarget;
  if LDiff <= 0 then
    LDiff := LDiff + 7;
  Result := Trunc(ADateTime) - LDiff;
end;

class function TDateTimeCalc.RoundToMinute(ADateTime: TDateTime): TDateTime;
var
  LYear, LMonth, LDay, LHour, LMin, LSec, LMs: Word;
begin
  DecodeDateTime(ADateTime, LYear, LMonth, LDay, LHour, LMin, LSec, LMs);
  if LSec >= 30 then
    Inc(LMin);
  Result := EncodeDateTime(LYear, LMonth, LDay, LHour, LMin, 0, 0);
end;

class function TDateTimeCalc.RoundToHour(ADateTime: TDateTime): TDateTime;
var
  LYear, LMonth, LDay, LHour, LMin, LSec, LMs: Word;
begin
  DecodeDateTime(ADateTime, LYear, LMonth, LDay, LHour, LMin, LSec, LMs);
  if LMin >= 30 then
    Inc(LHour);
  Result := EncodeDateTime(LYear, LMonth, LDay, LHour, 0, 0, 0);
end;

class function TDateTimeCalc.RoundToDay(ADateTime: TDateTime): TDateTime;
begin
  if Frac(ADateTime) >= 0.5 then
    Result := Trunc(ADateTime) + 1
  else
    Result := Trunc(ADateTime);
end;

class function TDateTimeCalc.Clamp(ADateTime, AMin, AMax: TDateTime): TDateTime;
begin
  if ADateTime < AMin then
    Result := AMin
  else if ADateTime > AMax then
    Result := AMax
  else
    Result := ADateTime;
end;

class function TDateTimeCalc.Min(A, B: TDateTime): TDateTime;
begin
  if A < B then
    Result := A
  else
    Result := B;
end;

class function TDateTimeCalc.Max(A, B: TDateTime): TDateTime;
begin
  if A > B then
    Result := A
  else
    Result := B;
end;

{ TBusinessDays }

class constructor TBusinessDays.Create;
begin
  FHolidays := TList<TDateTime>.Create;
  FWeekendDays := [dowSaturday, dowSunday];
end;

class destructor TBusinessDays.Destroy;
begin
  FreeAndNil(FHolidays);
end;

class procedure TBusinessDays.SetWeekendDays(const ADays: array of TDayOfWeekEx);
var
  LDay: TDayOfWeekEx;
begin
  FWeekendDays := [];
  for LDay in ADays do
    Include(FWeekendDays, LDay);
end;

class procedure TBusinessDays.AddHoliday(ADate: TDateTime);
begin
  if not FHolidays.Contains(Trunc(ADate)) then
    FHolidays.Add(Trunc(ADate));
end;

class procedure TBusinessDays.AddHolidays(const ADates: array of TDateTime);
var
  LDate: TDateTime;
begin
  for LDate in ADates do
    AddHoliday(LDate);
end;

class procedure TBusinessDays.ClearHolidays;
begin
  FHolidays.Clear;
end;

class function TBusinessDays.IsBusinessDay(ADate: TDateTime): Boolean;
begin
  Result := not IsWeekend(ADate) and not IsHoliday(ADate);
end;

class function TBusinessDays.IsWeekend(ADate: TDateTime): Boolean;
var
  LDow: TDayOfWeekEx;
begin
  LDow := TDayOfWeekEx((DayOfTheWeek(ADate) mod 7));
  Result := LDow in FWeekendDays;
end;

class function TBusinessDays.IsHoliday(ADate: TDateTime): Boolean;
begin
  Result := FHolidays.Contains(Trunc(ADate));
end;

class function TBusinessDays.AddBusinessDays(ADate: TDateTime; ADays: Integer): TDateTime;
var
  LDirection: Integer;
begin
  Result := Trunc(ADate);
  if ADays = 0 then
    Exit;
    
  if ADays > 0 then
    LDirection := 1
  else
  begin
    LDirection := -1;
    ADays := -ADays;
  end;
  
  while ADays > 0 do
  begin
    Result := Result + LDirection;
    if IsBusinessDay(Result) then
      Dec(ADays);
  end;
end;

class function TBusinessDays.BusinessDaysBetween(AFrom, ATo: TDateTime): Integer;
var
  LCurrent: TDateTime;
  LDirection: Integer;
begin
  Result := 0;
  LCurrent := Trunc(AFrom);
  
  if AFrom <= ATo then
    LDirection := 1
  else
    LDirection := -1;
    
  while (LDirection > 0) and (LCurrent < Trunc(ATo)) or
        (LDirection < 0) and (LCurrent > Trunc(ATo)) do
  begin
    LCurrent := LCurrent + LDirection;
    if IsBusinessDay(LCurrent) then
      Inc(Result);
  end;
  
  if LDirection < 0 then
    Result := -Result;
end;

class function TBusinessDays.NextBusinessDay(ADate: TDateTime): TDateTime;
begin
  Result := Trunc(ADate) + 1;
  while not IsBusinessDay(Result) do
    Result := Result + 1;
end;

class function TBusinessDays.PreviousBusinessDay(ADate: TDateTime): TDateTime;
begin
  Result := Trunc(ADate) - 1;
  while not IsBusinessDay(Result) do
    Result := Result - 1;
end;

{ TDateTimeUtils }

class function TDateTimeUtils.Now: TDateTime;
begin
  Result := System.SysUtils.Now;
end;

class function TDateTimeUtils.UtcNow: TDateTime;
begin
  Result := TTimeZones.ToUTC(System.SysUtils.Now);
end;

class function TDateTimeUtils.Today: TDateTime;
begin
  Result := System.SysUtils.Date;
end;

class function TDateTimeUtils.Create(AYear, AMonth, ADay: Word): TDateTime;
begin
  Result := EncodeDate(AYear, AMonth, ADay);
end;

class function TDateTimeUtils.Create(AYear, AMonth, ADay, AHour, AMinute, ASecond: Word): TDateTime;
begin
  Result := EncodeDateTime(AYear, AMonth, ADay, AHour, AMinute, ASecond, 0);
end;

class function TDateTimeUtils.CreateTime(AHour, AMinute, ASecond: Word; AMillisecond: Word): TDateTime;
begin
  Result := EncodeTime(AHour, AMinute, ASecond, AMillisecond);
end;

class function TDateTimeUtils.IsValidDate(AYear, AMonth, ADay: Word): Boolean;
begin
  Result := (AMonth >= 1) and (AMonth <= 12) and
            (ADay >= 1) and (ADay <= DaysInMonth(AYear, AMonth));
end;

class function TDateTimeUtils.IsValidTime(AHour, AMinute, ASecond: Word): Boolean;
begin
  Result := (AHour <= 23) and (AMinute <= 59) and (ASecond <= 59);
end;

class function TDateTimeUtils.IsLeapYear(AYear: Word): Boolean;
begin
  Result := System.SysUtils.IsLeapYear(AYear);
end;

class function TDateTimeUtils.DaysInMonth(AYear, AMonth: Word): Word;
begin
  Result := System.DateUtils.DaysInAMonth(AYear, AMonth);
end;

class function TDateTimeUtils.DaysInYear(AYear: Word): Word;
begin
  if IsLeapYear(AYear) then
    Result := 366
  else
    Result := 365;
end;

class function TDateTimeUtils.GetYear(ADateTime: TDateTime): Word;
begin
  Result := YearOf(ADateTime);
end;

class function TDateTimeUtils.GetMonth(ADateTime: TDateTime): Word;
begin
  Result := MonthOf(ADateTime);
end;

class function TDateTimeUtils.GetDay(ADateTime: TDateTime): Word;
begin
  Result := DayOf(ADateTime);
end;

class function TDateTimeUtils.GetHour(ADateTime: TDateTime): Word;
begin
  Result := HourOf(ADateTime);
end;

class function TDateTimeUtils.GetMinute(ADateTime: TDateTime): Word;
begin
  Result := MinuteOf(ADateTime);
end;

class function TDateTimeUtils.GetSecond(ADateTime: TDateTime): Word;
begin
  Result := SecondOf(ADateTime);
end;

class function TDateTimeUtils.GetMillisecond(ADateTime: TDateTime): Word;
begin
  Result := MilliSecondOf(ADateTime);
end;

class function TDateTimeUtils.GetDayOfWeek(ADateTime: TDateTime): TDayOfWeekEx;
begin
  Result := TDayOfWeekEx((DayOfTheWeek(ADateTime) mod 7));
end;

class function TDateTimeUtils.GetDayOfYear(ADateTime: TDateTime): Word;
begin
  Result := DayOfTheYear(ADateTime);
end;

class function TDateTimeUtils.GetWeekOfYear(ADateTime: TDateTime): Word;
begin
  Result := WeekOfTheYear(ADateTime);
end;

class function TDateTimeUtils.GetQuarter(ADateTime: TDateTime): Word;
begin
  Result := ((MonthOf(ADateTime) - 1) div 3) + 1;
end;

class function TDateTimeUtils.DatePart(ADateTime: TDateTime): TDateTime;
begin
  Result := Trunc(ADateTime);
end;

class function TDateTimeUtils.TimePart(ADateTime: TDateTime): TDateTime;
begin
  Result := Frac(ADateTime);
end;

class function TDateTimeUtils.Age(ABirthDate: TDateTime): Integer;
begin
  Result := Age(ABirthDate, System.SysUtils.Date);
end;

class function TDateTimeUtils.Age(ABirthDate, AAsOfDate: TDateTime): Integer;
var
  LBirthYear, LBirthMonth, LBirthDay: Word;
  LAsOfYear, LAsOfMonth, LAsOfDay: Word;
begin
  DecodeDate(ABirthDate, LBirthYear, LBirthMonth, LBirthDay);
  DecodeDate(AAsOfDate, LAsOfYear, LAsOfMonth, LAsOfDay);
  
  Result := LAsOfYear - LBirthYear;
  if (LAsOfMonth < LBirthMonth) or 
     ((LAsOfMonth = LBirthMonth) and (LAsOfDay < LBirthDay)) then
    Dec(Result);
end;

class function TDateTimeUtils.IsSameDay(A, B: TDateTime): Boolean;
begin
  Result := Trunc(A) = Trunc(B);
end;

class function TDateTimeUtils.IsSameMonth(A, B: TDateTime): Boolean;
begin
  Result := (YearOf(A) = YearOf(B)) and (MonthOf(A) = MonthOf(B));
end;

class function TDateTimeUtils.IsSameYear(A, B: TDateTime): Boolean;
begin
  Result := YearOf(A) = YearOf(B);
end;

class function TDateTimeUtils.IsBefore(A, B: TDateTime): Boolean;
begin
  Result := A < B;
end;

class function TDateTimeUtils.IsAfter(A, B: TDateTime): Boolean;
begin
  Result := A > B;
end;

class function TDateTimeUtils.IsBetween(ADateTime, AStart, AEnd: TDateTime): Boolean;
begin
  Result := (ADateTime >= AStart) and (ADateTime <= AEnd);
end;

class function TDateTimeUtils.DayName(ADayOfWeek: TDayOfWeekEx): string;
const
  Names: array[TDayOfWeekEx] of string = (
    'Sunday', 'Monday', 'Tuesday', 'Wednesday', 
    'Thursday', 'Friday', 'Saturday');
begin
  Result := Names[ADayOfWeek];
end;

class function TDateTimeUtils.ShortDayName(ADayOfWeek: TDayOfWeekEx): string;
const
  Names: array[TDayOfWeekEx] of string = (
    'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat');
begin
  Result := Names[ADayOfWeek];
end;

class function TDateTimeUtils.MonthName(AMonth: Word): string;
const
  Names: array[1..12] of string = (
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December');
begin
  Result := Names[AMonth];
end;

class function TDateTimeUtils.ShortMonthName(AMonth: Word): string;
const
  Names: array[1..12] of string = (
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');
begin
  Result := Names[AMonth];
end;

end.
