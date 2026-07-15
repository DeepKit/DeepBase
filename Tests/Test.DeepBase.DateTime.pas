/// <summary>
/// Unit tests for DeepBase.DateTime module
/// Tests: TTimeSpanEx, TDateRange, TTimeZones, TDateTimeFormat,
///        TRelativeTime, TDateTimeCalc, TBusinessDays, TDateTimeUtils
/// </summary>
unit Test.DeepBase.DateTime;

interface

uses
  System.SysUtils,
  System.DateUtils,
  DUnitX.TestFramework,
  DeepBase.DateTime;

type
  /// <summary>
  /// Tests for TTimeSpanEx
  /// </summary>
  [TestFixture]
  TTimeSpanExTests = class
  public
    [Test]
    procedure Test_Create;
    [Test]
    procedure Test_FromMilliseconds;
    [Test]
    procedure Test_FromSeconds;
    [Test]
    procedure Test_FromMinutes;
    [Test]
    procedure Test_FromHours;
    [Test]
    procedure Test_FromDays;
    [Test]
    procedure Test_TotalMilliseconds;
    [Test]
    procedure Test_TotalSeconds;
    [Test]
    procedure Test_TotalMinutes;
    [Test]
    procedure Test_TotalHours;
    [Test]
    procedure Test_TotalDays;
    [Test]
    procedure Test_Add;
    [Test]
    procedure Test_Subtract;
    [Test]
    procedure Test_Negate;
    [Test]
    procedure Test_ToString;
    [Test]
    procedure Test_ToShortString;
    [Test]
    procedure Test_OperatorAdd;
    [Test]
    procedure Test_OperatorSubtract;
    [Test]
    procedure Test_OperatorEqual;
    [Test]
    procedure Test_OperatorNotEqual;
    [Test]
    procedure Test_OperatorGreaterThan;
    [Test]
    procedure Test_OperatorLessThan;
  end;

  /// <summary>
  /// Tests for TDateRange
  /// </summary>
  [TestFixture]
  TDateRangeTests = class
  public
    [Test]
    procedure Test_Create;
    [Test]
    procedure Test_Contains_True;
    [Test]
    procedure Test_Contains_False;
    [Test]
    procedure Test_Overlaps_True;
    [Test]
    procedure Test_Overlaps_False;
    [Test]
    procedure Test_Duration;
    [Test]
    procedure Test_DayCount;
    [Test]
    procedure Test_Intersection;
    [Test]
    procedure Test_Union;
    [Test]
    procedure Test_ToString;
    [Test]
    procedure Test_Today;
    [Test]
    procedure Test_ThisWeek;
    [Test]
    procedure Test_ThisMonth;
    [Test]
    procedure Test_ThisYear;
    [Test]
    procedure Test_LastNDays;
  end;

  /// <summary>
  /// Tests for TTimeZones
  /// </summary>
  [TestFixture]
  TTimeZonesTests = class
  public
    [Test]
    procedure Test_Local;
    [Test]
    procedure Test_UTC;
    [Test]
    procedure Test_ToUTC;
    [Test]
    procedure Test_ToLocal;
    [Test]
    procedure Test_CurrentUtcOffset;
    [Test]
    procedure Test_FormatOffset_Positive;
    [Test]
    procedure Test_FormatOffset_Negative;
    [Test]
    procedure Test_FormatOffset_Zero;
  end;

  /// <summary>
  /// Tests for TDateTimeFormat
  /// </summary>
  [TestFixture]
  TDateTimeFormatTests = class
  public
    [Test]
    procedure Test_ToISO8601_WithTime;
    [Test]
    procedure Test_ToISO8601_DateOnly;
    [Test]
    procedure Test_FromISO8601;
    [Test]
    procedure Test_TryFromISO8601_Valid;
    [Test]
    procedure Test_TryFromISO8601_Invalid;
    [Test]
    procedure Test_ToUnixTime;
    [Test]
    procedure Test_FromUnixTime;
    [Test]
    procedure Test_ToUnixTimeMs;
    [Test]
    procedure Test_FromUnixTimeMs;
    [Test]
    procedure Test_Format;
    [Test]
    procedure Test_Parse;
    [Test]
    procedure Test_TryParse_Valid;
    [Test]
    procedure Test_TryParse_Invalid;
    [Test]
    procedure Test_ToShortDate;
    [Test]
    procedure Test_ToLongDate;
    [Test]
    procedure Test_ToShortTime;
    [Test]
    procedure Test_ToLongTime;
    [Test]
    procedure Test_ToSortable;
    [Test]
    procedure Test_ToFileSafe;
    [Test]
    procedure Test_FromRFC2822_SameUtcDifferentOffset;
    [Test]
    procedure Test_FromRFC2822_TwoDigitYear;
    [Test]
    procedure Test_FromRFC2822_CommentsAndWhitespace;
    [Test]
    procedure Test_FromRFC2822_RoundTrip_PreservesUtcEquivalent;
    [Test]
    procedure Test_FromRFC2822_MilitaryLetterZ;
    [Test]
    procedure Test_FromRFC2822_NamedTimezone_EST;
    [Test]
    procedure Test_FromRFC2822_NoTimezone_TreatedAsLocal;
  end;

  /// <summary>
  /// Tests for TRelativeTime
  /// </summary>
  [TestFixture]
  TRelativeTimeTests = class
  public
    [Test]
    procedure Test_Describe;
    [Test]
    procedure Test_DescribeSpan;
    [Test]
    procedure Test_TimeAgo;
    [Test]
    procedure Test_TimeUntil;
    [Test]
    procedure Test_IsWithinMinutes;
    [Test]
    procedure Test_IsWithinHours;
    [Test]
    procedure Test_IsWithinDays;
    [Test]
    procedure Test_IsToday;
    [Test]
    procedure Test_IsYesterday;
    [Test]
    procedure Test_IsTomorrow;
    [Test]
    procedure Test_IsThisWeek;
    [Test]
    procedure Test_IsThisMonth;
    [Test]
    procedure Test_IsThisYear;
  end;

  /// <summary>
  /// Tests for TDateTimeCalc
  /// </summary>
  [TestFixture]
  TDateTimeCalcTests = class
  public
    [Test]
    procedure Test_Add_Days;
    [Test]
    procedure Test_Add_Months;
    [Test]
    procedure Test_Add_Years;
    [Test]
    procedure Test_Subtract_Days;
    [Test]
    procedure Test_Diff_Days;
    [Test]
    procedure Test_DiffSpan;
    [Test]
    procedure Test_DiffCalendarMonths_SameMonth;
    [Test]
    procedure Test_DiffCalendarMonths_WholeMonths;
    [Test]
    procedure Test_DiffCalendarMonths_PartialMonth;
    [Test]
    procedure Test_DiffCalendarMonths_Jan31_Feb28;
    [Test]
    procedure Test_DiffCalendarMonths_Feb28_Mar31;
    [Test]
    procedure Test_DiffCalendarMonths_LeapYear;
    [Test]
    procedure Test_DiffCalendarMonths_Negative;
    [Test]
    procedure Test_DiffCalendarYears_WholeYears;
    [Test]
    procedure Test_DiffCalendarYears_PartialYear;
    [Test]
    procedure Test_StartOfDay;
    [Test]
    procedure Test_EndOfDay;
    [Test]
    procedure Test_StartOfWeek;
    [Test]
    procedure Test_EndOfWeek;
    [Test]
    procedure Test_StartOfMonth;
    [Test]
    procedure Test_EndOfMonth;
    [Test]
    procedure Test_StartOfYear;
    [Test]
    procedure Test_EndOfYear;
    [Test]
    procedure Test_NextDayOfWeek;
    [Test]
    procedure Test_PreviousDayOfWeek;
    [Test]
    procedure Test_RoundToMinute;
    [Test]
    procedure Test_RoundToHour;
    [Test]
    procedure Test_Clamp;
    [Test]
    procedure Test_Min;
    [Test]
    procedure Test_Max;
  end;

  /// <summary>
  /// Tests for TBusinessDays
  /// </summary>
  [TestFixture]
  TBusinessDaysTests = class
  public
    [Setup]
    procedure Setup;

    [Test]
    procedure Test_IsWeekend_Saturday;
    [Test]
    procedure Test_IsWeekend_Sunday;
    [Test]
    procedure Test_IsWeekend_Weekday;
    [Test]
    procedure Test_IsBusinessDay;
    [Test]
    procedure Test_AddHoliday;
    [Test]
    procedure Test_IsHoliday;
    [Test]
    procedure Test_AddBusinessDays;
    [Test]
    procedure Test_AddBusinessDays_ZeroDays_SnapsToBusinessDay;
    [Test]
    procedure Test_BusinessDaysBetween;
    [Test]
    procedure Test_NextBusinessDay;
    [Test]
    procedure Test_PreviousBusinessDay;
  end;

  /// <summary>
  /// Tests for TDateTimeUtils
  /// </summary>
  [TestFixture]
  TDateTimeUtilsTests = class
  public
    [Test]
    procedure Test_Now;
    [Test]
    procedure Test_UtcNow;
    [Test]
    procedure Test_Today;
    [Test]
    procedure Test_Create_Date;
    [Test]
    procedure Test_Create_DateTime;
    [Test]
    procedure Test_CreateTime;
    [Test]
    procedure Test_IsValidDate_True;
    [Test]
    procedure Test_IsValidDate_False;
    [Test]
    procedure Test_IsValidTime_True;
    [Test]
    procedure Test_IsValidTime_False;
    [Test]
    procedure Test_IsLeapYear;
    [Test]
    procedure Test_DaysInMonth;
    [Test]
    procedure Test_DaysInYear;
    [Test]
    procedure Test_GetYear;
    [Test]
    procedure Test_GetMonth;
    [Test]
    procedure Test_GetDay;
    [Test]
    procedure Test_GetHour;
    [Test]
    procedure Test_GetMinute;
    [Test]
    procedure Test_GetSecond;
    [Test]
    procedure Test_GetDayOfWeek;
    [Test]
    procedure Test_GetDayOfYear;
    [Test]
    procedure Test_GetWeekOfYear;
    [Test]
    procedure Test_GetQuarter;
    [Test]
    procedure Test_DatePart;
    [Test]
    procedure Test_TimePart;
    [Test]
    procedure Test_Age;
    [Test]
    procedure Test_IsSameDay;
    [Test]
    procedure Test_IsSameMonth;
    [Test]
    procedure Test_IsSameYear;
    [Test]
    procedure Test_IsBefore;
    [Test]
    procedure Test_IsAfter;
    [Test]
    procedure Test_IsBetween;
    [Test]
    procedure Test_DayName;
    [Test]
    procedure Test_MonthName;
  end;

implementation

// ============================================================================
// TTimeSpanExTests
// ============================================================================

procedure TTimeSpanExTests.Test_Create;
var
  Span: TTimeSpanEx;
begin
  Span := TTimeSpanEx.Create(1, 2, 30, 45, 500);
  Assert.AreEqual(1, Span.Days);
  Assert.AreEqual(2, Span.Hours);
  Assert.AreEqual(30, Span.Minutes);
  Assert.AreEqual(45, Span.Seconds);
  Assert.AreEqual(500, Span.Milliseconds);
end;

procedure TTimeSpanExTests.Test_FromMilliseconds;
var
  Span: TTimeSpanEx;
begin
  Span := TTimeSpanEx.FromMilliseconds(90061500); // 1d 1h 1m 1s 500ms
  Assert.AreEqual(1, Span.Days);
  Assert.AreEqual(1, Span.Hours);
  Assert.AreEqual(1, Span.Minutes);
  Assert.AreEqual(1, Span.Seconds);
  Assert.AreEqual(500, Span.Milliseconds);
end;

procedure TTimeSpanExTests.Test_FromSeconds;
var
  Span: TTimeSpanEx;
begin
  Span := TTimeSpanEx.FromSeconds(3661); // 1h 1m 1s
  Assert.AreEqual(1, Span.Hours);
  Assert.AreEqual(1, Span.Minutes);
  Assert.AreEqual(1, Span.Seconds);
end;

procedure TTimeSpanExTests.Test_FromMinutes;
var
  Span: TTimeSpanEx;
begin
  Span := TTimeSpanEx.FromMinutes(90); // 1h 30m
  Assert.AreEqual(1, Span.Hours);
  Assert.AreEqual(30, Span.Minutes);
end;

procedure TTimeSpanExTests.Test_FromHours;
var
  Span: TTimeSpanEx;
begin
  Span := TTimeSpanEx.FromHours(25); // 1d 1h
  Assert.AreEqual(1, Span.Days);
  Assert.AreEqual(1, Span.Hours);
end;

procedure TTimeSpanExTests.Test_FromDays;
var
  Span: TTimeSpanEx;
begin
  Span := TTimeSpanEx.FromDays(5);
  Assert.AreEqual(5, Span.Days);
  Assert.AreEqual(0, Span.Hours);
end;

procedure TTimeSpanExTests.Test_TotalMilliseconds;
var
  Span: TTimeSpanEx;
begin
  Span := TTimeSpanEx.Create(0, 1, 0, 0); // 1 hour
  Assert.AreEqual(Int64(3600000), Span.TotalMilliseconds);
end;

procedure TTimeSpanExTests.Test_TotalSeconds;
var
  Span: TTimeSpanEx;
begin
  Span := TTimeSpanEx.Create(0, 1, 0, 0);
  Assert.AreEqual(3600.0, Span.TotalSeconds, 0.001);
end;

procedure TTimeSpanExTests.Test_TotalMinutes;
var
  Span: TTimeSpanEx;
begin
  Span := TTimeSpanEx.Create(0, 1, 30, 0);
  Assert.AreEqual(90.0, Span.TotalMinutes, 0.001);
end;

procedure TTimeSpanExTests.Test_TotalHours;
var
  Span: TTimeSpanEx;
begin
  Span := TTimeSpanEx.Create(1, 12, 0, 0);
  Assert.AreEqual(36.0, Span.TotalHours, 0.001);
end;

procedure TTimeSpanExTests.Test_TotalDays;
var
  Span: TTimeSpanEx;
begin
  Span := TTimeSpanEx.Create(2, 12, 0, 0);
  Assert.AreEqual(2.5, Span.TotalDays, 0.001);
end;

procedure TTimeSpanExTests.Test_Add;
var
  A, B, R: TTimeSpanEx;
begin
  A := TTimeSpanEx.Create(1, 0, 0, 0);
  B := TTimeSpanEx.Create(0, 12, 0, 0);
  R := A.Add(B);
  Assert.AreEqual(1, R.Days);
  Assert.AreEqual(12, R.Hours);
end;

procedure TTimeSpanExTests.Test_Subtract;
var
  A, B, R: TTimeSpanEx;
begin
  A := TTimeSpanEx.Create(2, 0, 0, 0);
  B := TTimeSpanEx.Create(1, 0, 0, 0);
  R := A.Subtract(B);
  Assert.AreEqual(1, R.Days);
end;

procedure TTimeSpanExTests.Test_Negate;
var
  Span, Neg: TTimeSpanEx;
begin
  Span := TTimeSpanEx.Create(1, 2, 3, 4);
  Neg := Span.Negate;
  Assert.AreEqual(-Span.TotalMilliseconds, Neg.TotalMilliseconds);
end;

procedure TTimeSpanExTests.Test_ToString;
var
  Span: TTimeSpanEx;
  S: string;
begin
  Span := TTimeSpanEx.Create(1, 2, 30, 45);
  S := Span.ToString;
  Assert.IsNotEmpty(S);
end;

procedure TTimeSpanExTests.Test_ToShortString;
var
  Span: TTimeSpanEx;
  S: string;
begin
  Span := TTimeSpanEx.Create(0, 2, 30, 0);
  S := Span.ToShortString;
  Assert.IsNotEmpty(S);
end;

procedure TTimeSpanExTests.Test_OperatorAdd;
var
  A, B, R: TTimeSpanEx;
begin
  A := TTimeSpanEx.FromHours(10);
  B := TTimeSpanEx.FromHours(5);
  R := A + B;
  Assert.AreEqual(15.0, R.TotalHours, 0.001);
end;

procedure TTimeSpanExTests.Test_OperatorSubtract;
var
  A, B, R: TTimeSpanEx;
begin
  A := TTimeSpanEx.FromHours(10);
  B := TTimeSpanEx.FromHours(3);
  R := A - B;
  Assert.AreEqual(7.0, R.TotalHours, 0.001);
end;

procedure TTimeSpanExTests.Test_OperatorEqual;
var
  A, B: TTimeSpanEx;
begin
  A := TTimeSpanEx.FromMinutes(60);
  B := TTimeSpanEx.FromHours(1);
  Assert.IsTrue(A = B);
end;

procedure TTimeSpanExTests.Test_OperatorNotEqual;
var
  A, B: TTimeSpanEx;
begin
  A := TTimeSpanEx.FromMinutes(60);
  B := TTimeSpanEx.FromMinutes(30);
  Assert.IsTrue(A <> B);
end;

procedure TTimeSpanExTests.Test_OperatorGreaterThan;
var
  A, B: TTimeSpanEx;
begin
  A := TTimeSpanEx.FromHours(2);
  B := TTimeSpanEx.FromHours(1);
  Assert.IsTrue(A > B);
end;

procedure TTimeSpanExTests.Test_OperatorLessThan;
var
  A, B: TTimeSpanEx;
begin
  A := TTimeSpanEx.FromHours(1);
  B := TTimeSpanEx.FromHours(2);
  Assert.IsTrue(A < B);
end;

// ============================================================================
// TDateRangeTests
// ============================================================================

procedure TDateRangeTests.Test_Create;
var
  R: TDateRange;
begin
  R := TDateRange.Create(EncodeDate(2024, 1, 1), EncodeDate(2024, 12, 31));
  Assert.AreEqual(EncodeDate(2024, 1, 1), R.StartDate);
  Assert.AreEqual(EncodeDate(2024, 12, 31), R.EndDate);
end;

procedure TDateRangeTests.Test_Contains_True;
var
  R: TDateRange;
begin
  R := TDateRange.Create(EncodeDate(2024, 1, 1), EncodeDate(2024, 12, 31));
  Assert.IsTrue(R.Contains(EncodeDate(2024, 6, 15)));
end;

procedure TDateRangeTests.Test_Contains_False;
var
  R: TDateRange;
begin
  R := TDateRange.Create(EncodeDate(2024, 1, 1), EncodeDate(2024, 12, 31));
  Assert.IsFalse(R.Contains(EncodeDate(2023, 6, 15)));
end;

procedure TDateRangeTests.Test_Overlaps_True;
var
  R1, R2: TDateRange;
begin
  R1 := TDateRange.Create(EncodeDate(2024, 1, 1), EncodeDate(2024, 6, 30));
  R2 := TDateRange.Create(EncodeDate(2024, 5, 1), EncodeDate(2024, 12, 31));
  Assert.IsTrue(R1.Overlaps(R2));
end;

procedure TDateRangeTests.Test_Overlaps_False;
var
  R1, R2: TDateRange;
begin
  R1 := TDateRange.Create(EncodeDate(2024, 1, 1), EncodeDate(2024, 3, 31));
  R2 := TDateRange.Create(EncodeDate(2024, 7, 1), EncodeDate(2024, 12, 31));
  Assert.IsFalse(R1.Overlaps(R2));
end;

procedure TDateRangeTests.Test_Duration;
var
  R: TDateRange;
  D: TTimeSpanEx;
begin
  R := TDateRange.Create(EncodeDate(2024, 1, 1), EncodeDate(2024, 1, 11));
  D := R.Duration;
  Assert.AreEqual(10, D.Days);
end;

procedure TDateRangeTests.Test_DayCount;
var
  R: TDateRange;
begin
  R := TDateRange.Create(EncodeDate(2024, 1, 1), EncodeDate(2024, 1, 31));
  Assert.AreEqual(31, R.DayCount);  // Includes both start and end dates
end;

procedure TDateRangeTests.Test_Intersection;
var
  R1, R2, I: TDateRange;
begin
  R1 := TDateRange.Create(EncodeDate(2024, 1, 1), EncodeDate(2024, 6, 30));
  R2 := TDateRange.Create(EncodeDate(2024, 3, 1), EncodeDate(2024, 9, 30));
  I := R1.Intersection(R2);
  Assert.AreEqual(EncodeDate(2024, 3, 1), I.StartDate);
  Assert.AreEqual(EncodeDate(2024, 6, 30), I.EndDate);
end;

procedure TDateRangeTests.Test_Union;
var
  R1, R2, U: TDateRange;
begin
  R1 := TDateRange.Create(EncodeDate(2024, 1, 1), EncodeDate(2024, 6, 30));
  R2 := TDateRange.Create(EncodeDate(2024, 3, 1), EncodeDate(2024, 9, 30));
  U := R1.Union(R2);
  Assert.AreEqual(EncodeDate(2024, 1, 1), U.StartDate);
  Assert.AreEqual(EncodeDate(2024, 9, 30), U.EndDate);
end;

procedure TDateRangeTests.Test_ToString;
var
  R: TDateRange;
begin
  R := TDateRange.Create(EncodeDate(2024, 1, 1), EncodeDate(2024, 12, 31));
  Assert.IsNotEmpty(R.ToString);
end;

procedure TDateRangeTests.Test_Today;
var
  R: TDateRange;
begin
  R := TDateRange.Today;
  Assert.IsTrue(R.Contains(System.SysUtils.Date));
  Assert.AreEqual(1, R.DayCount);  // Today is 1 day (same start and end)
end;

procedure TDateRangeTests.Test_ThisWeek;
var
  R: TDateRange;
begin
  R := TDateRange.ThisWeek;
  Assert.IsTrue(R.Contains(System.SysUtils.Date));
end;

procedure TDateRangeTests.Test_ThisMonth;
var
  R: TDateRange;
begin
  R := TDateRange.ThisMonth;
  Assert.IsTrue(R.Contains(System.SysUtils.Date));
end;

procedure TDateRangeTests.Test_ThisYear;
var
  R: TDateRange;
begin
  R := TDateRange.ThisYear;
  Assert.IsTrue(R.Contains(System.SysUtils.Date));
end;

procedure TDateRangeTests.Test_LastNDays;
var
  R: TDateRange;
begin
  R := TDateRange.LastNDays(7);
  Assert.AreEqual(7, R.DayCount);  // 7 days including today
  Assert.IsTrue(R.Contains(System.SysUtils.Date));
end;

// ============================================================================
// TTimeZonesTests
// ============================================================================

procedure TTimeZonesTests.Test_Local;
var
  Info: TTimeZoneInfo;
begin
  Info := TTimeZones.Local;
  Assert.IsNotEmpty(Info.DisplayName);
end;

procedure TTimeZonesTests.Test_UTC;
var
  Info: TTimeZoneInfo;
begin
  Info := TTimeZones.UTC;
  Assert.AreEqual(0, Info.BaseUtcOffset);
end;

procedure TTimeZonesTests.Test_ToUTC;
var
  Local, UTC: TDateTime;
begin
  Local := Now;
  UTC := TTimeZones.ToUTC(Local);
  // UTC should be different from local (unless in UTC zone)
  Assert.IsTrue(Abs(Local - UTC) < 1); // Within 24 hours
end;

procedure TTimeZonesTests.Test_ToLocal;
var
  UTC, Local: TDateTime;
begin
  UTC := TTimeZones.ToUTC(Now);
  Local := TTimeZones.ToLocal(UTC);
  // Round-trip should return close to original
  Assert.IsTrue(Abs(Now - Local) < 1/86400); // Within 1 second
end;

procedure TTimeZonesTests.Test_CurrentUtcOffset;
var
  Offset: Integer;
begin
  Offset := TTimeZones.CurrentUtcOffset;
  // Offset should be reasonable (-720 to +840 minutes)
  Assert.IsTrue((Offset >= -720) and (Offset <= 840));
end;

procedure TTimeZonesTests.Test_FormatOffset_Positive;
var
  S: string;
begin
  S := TTimeZones.FormatOffset(480); // +8 hours
  Assert.AreEqual('+08:00', S);
end;

procedure TTimeZonesTests.Test_FormatOffset_Negative;
var
  S: string;
begin
  S := TTimeZones.FormatOffset(-300); // -5 hours
  Assert.AreEqual('-05:00', S);
end;

procedure TTimeZonesTests.Test_FormatOffset_Zero;
var
  S: string;
begin
  S := TTimeZones.FormatOffset(0);
  Assert.AreEqual('+00:00', S);
end;

// ============================================================================
// TDateTimeFormatTests
// ============================================================================

procedure TDateTimeFormatTests.Test_ToISO8601_WithTime;
var
  DT: TDateTime;
  S: string;
begin
  DT := EncodeDate(2024, 6, 15) + EncodeTime(14, 30, 0, 0);
  S := TDateTimeFormat.ToISO8601(DT, True);
  Assert.IsTrue(S.Contains('2024-06-15'));
  Assert.IsTrue(S.Contains('14:30'));
end;

procedure TDateTimeFormatTests.Test_ToISO8601_DateOnly;
var
  DT: TDateTime;
  S: string;
begin
  DT := EncodeDate(2024, 6, 15);
  S := TDateTimeFormat.ToISO8601(DT, False);
  Assert.AreEqual('2024-06-15', S);
end;

procedure TDateTimeFormatTests.Test_FromISO8601;
var
  DT: TDateTime;
begin
  DT := TDateTimeFormat.FromISO8601('2024-06-15T14:30:00');
  Assert.AreEqual(2024, YearOf(DT));
  Assert.AreEqual(6, MonthOf(DT));
  Assert.AreEqual(15, DayOf(DT));
end;

procedure TDateTimeFormatTests.Test_TryFromISO8601_Valid;
var
  DT: TDateTime;
begin
  Assert.IsTrue(TDateTimeFormat.TryFromISO8601('2024-06-15', DT));
  Assert.AreEqual(2024, YearOf(DT));
end;

procedure TDateTimeFormatTests.Test_TryFromISO8601_Invalid;
var
  DT: TDateTime;
begin
  Assert.IsFalse(TDateTimeFormat.TryFromISO8601('invalid', DT));
end;

procedure TDateTimeFormatTests.Test_ToUnixTime;
var
  DT: TDateTime;
  Unix: Int64;
begin
  DT := EncodeDate(2024, 1, 1);
  Unix := TDateTimeFormat.ToUnixTime(DT);
  Assert.IsTrue(Unix > 0);
end;

procedure TDateTimeFormatTests.Test_FromUnixTime;
var
  DT: TDateTime;
begin
  DT := TDateTimeFormat.FromUnixTime(1704067200); // 2024-01-01 00:00:00 UTC
  Assert.AreEqual(2024, YearOf(DT));
end;

procedure TDateTimeFormatTests.Test_ToUnixTimeMs;
var
  DT: TDateTime;
  UnixMs: Int64;
begin
  DT := EncodeDate(2024, 1, 1);
  UnixMs := TDateTimeFormat.ToUnixTimeMs(DT);
  Assert.IsTrue(UnixMs > 1000000000000);
end;

procedure TDateTimeFormatTests.Test_FromUnixTimeMs;
var
  DT: TDateTime;
begin
  DT := TDateTimeFormat.FromUnixTimeMs(1704067200000);
  Assert.AreEqual(2024, YearOf(DT));
end;

procedure TDateTimeFormatTests.Test_Format;
var
  DT: TDateTime;
  S: string;
begin
  DT := EncodeDate(2024, 6, 15);
  S := TDateTimeFormat.Format(DT, 'yyyy/mm/dd');
  Assert.AreEqual('2024/06/15', S);
end;

procedure TDateTimeFormatTests.Test_Parse;
var
  DT: TDateTime;
begin
  DT := TDateTimeFormat.Parse('2024/06/15', 'yyyy/mm/dd');
  Assert.AreEqual(2024, YearOf(DT));
  Assert.AreEqual(6, MonthOf(DT));
  Assert.AreEqual(15, DayOf(DT));
end;

procedure TDateTimeFormatTests.Test_TryParse_Valid;
var
  DT: TDateTime;
begin
  // TryParse currently uses TryStrToDateTime which uses system locale format
  // This test verifies the function works with parseable date strings
  Assert.IsTrue(TDateTimeFormat.TryParse(DateToStr(EncodeDate(2024, 6, 15)), 'yyyy-mm-dd', DT));
end;

procedure TDateTimeFormatTests.Test_TryParse_Invalid;
var
  DT: TDateTime;
begin
  Assert.IsFalse(TDateTimeFormat.TryParse('invalid', 'yyyy-mm-dd', DT));
end;

procedure TDateTimeFormatTests.Test_ToShortDate;
var
  S: string;
begin
  S := TDateTimeFormat.ToShortDate(EncodeDate(2024, 6, 15));
  Assert.IsNotEmpty(S);
end;

procedure TDateTimeFormatTests.Test_ToLongDate;
var
  S: string;
begin
  S := TDateTimeFormat.ToLongDate(EncodeDate(2024, 6, 15));
  Assert.IsNotEmpty(S);
end;

procedure TDateTimeFormatTests.Test_ToShortTime;
var
  S: string;
begin
  S := TDateTimeFormat.ToShortTime(EncodeTime(14, 30, 0, 0));
  Assert.IsNotEmpty(S);
end;

procedure TDateTimeFormatTests.Test_ToLongTime;
var
  S: string;
begin
  S := TDateTimeFormat.ToLongTime(EncodeTime(14, 30, 45, 0));
  Assert.IsNotEmpty(S);
end;

procedure TDateTimeFormatTests.Test_ToSortable;
var
  S: string;
begin
  S := TDateTimeFormat.ToSortable(EncodeDate(2024, 6, 15) + EncodeTime(14, 30, 0, 0));
  Assert.IsTrue(S.StartsWith('2024-06-15'));
end;

procedure TDateTimeFormatTests.Test_ToFileSafe;
var
  S: string;
begin
  S := TDateTimeFormat.ToFileSafe(Now);
  Assert.IsFalse(S.Contains(':'));
  Assert.IsFalse(S.Contains('/'));
end;

procedure TDateTimeFormatTests.Test_FromRFC2822_SameUtcDifferentOffset;
var
  Parsed1, Parsed2: TDateTime;
begin
  // "Fri, 21 Jun 2024 12:00:00 +0000" and "Fri, 21 Jun 2024 07:00:00 -0500"
  // represent the same UTC instant (12:00 UTC). Both should yield the same
  // local TDateTime regardless of the machine's timezone.
  Parsed1 := TDateTimeFormat.FromRFC2822('Fri, 21 Jun 2024 12:00:00 +0000');
  Parsed2 := TDateTimeFormat.FromRFC2822('Fri, 21 Jun 2024 07:00:00 -0500');
  Assert.AreEqual(0.0, Parsed2 - Parsed1, 1 / 86400,
    'Same UTC instant via different offsets must map to the same local time');
end;

procedure TDateTimeFormatTests.Test_FromRFC2822_TwoDigitYear;
var
  Parsed1999, Parsed2001: TDateTime;
begin
  // 2-digit year: RFC 2822 §4.3 rule — 00..49 → 2000..2049; 50..99 → 1950..1999.
  // Compare against explicit 4-digit-year parses to make the test timezone-agnostic.
  Parsed1999 := TDateTimeFormat.FromRFC2822('21 Jun 99 12:00:00 +0000');
  Assert.AreEqual(
    TDateTimeFormat.FromRFC2822('21 Jun 1999 12:00:00 +0000'),
    Parsed1999, 1 / 86400,
    'Two-digit year 99 must expand to 1999');

  Parsed2001 := TDateTimeFormat.FromRFC2822('21 Jun 01 12:00:00 +0000');
  Assert.AreEqual(
    TDateTimeFormat.FromRFC2822('21 Jun 2001 12:00:00 +0000'),
    Parsed2001, 1 / 86400,
    'Two-digit year 01 must expand to 2001');
end;

procedure TDateTimeFormatTests.Test_FromRFC2822_CommentsAndWhitespace;
var
  WithComment, Without: TDateTime;
begin
  // RFC 2822 allows CFWS (comments and folding whitespace) anywhere between tokens.
  WithComment := TDateTimeFormat.FromRFC2822(
    'Fri, 21 Jun 2024 12:00:00 +0000 (a comment)');
  Without    := TDateTimeFormat.FromRFC2822(
    'Fri, 21 Jun 2024 12:00:00 +0000');
  Assert.AreEqual(0.0, WithComment - Without, 1 / 86400,
    'Trailing comment must not change the parsed value');
end;

procedure TDateTimeFormatTests.Test_FromRFC2822_RoundTrip_PreservesUtcEquivalent;
var
  DT, Parsed: TDateTime;
  UtcOriginal, UtcParsed: TDateTime;
begin
  // Round-trip: ToRFC2822 serializes using the local offset; FromRFC2822 must
  // recover the same UTC-equivalent instant even though the string is in local time.
  DT := EncodeDate(2024, 6, 21) + EncodeTime(14, 30, 45, 0);
  Parsed := TDateTimeFormat.FromRFC2822(TDateTimeFormat.ToRFC2822(DT));

  // Normalize both sides to UTC to remove local-timezone dependence.
  UtcOriginal := TTimeZones.ToUTC(DT);
  UtcParsed   := TTimeZones.ToUTC(Parsed);
  Assert.AreEqual(0.0, UtcParsed - UtcOriginal, 1 / 86400,
    'Round-trip ToRFC2822 -> FromRFC2822 must preserve the UTC instant');
end;

procedure TDateTimeFormatTests.Test_FromRFC2822_MilitaryLetterZ;
var
  Zulu, PlusZero: TDateTime;
begin
  // Military 'Z' is UTC — must behave identically to "+0000".
  Zulu    := TDateTimeFormat.FromRFC2822('Fri, 21 Jun 2024 12:00:00 Z');
  PlusZero := TDateTimeFormat.FromRFC2822('Fri, 21 Jun 2024 12:00:00 +0000');
  Assert.AreEqual(0.0, Zulu - PlusZero, 1 / 86400,
    'Military letter Z must equal +0000');
end;

procedure TDateTimeFormatTests.Test_FromRFC2822_NamedTimezone_EST;
var
  Named, Numeric: TDateTime;
begin
  // EST = -0500 per RFC 2822 §4.3.
  Named  := TDateTimeFormat.FromRFC2822('Fri, 21 Jun 2024 12:00:00 EST');
  Numeric := TDateTimeFormat.FromRFC2822('Fri, 21 Jun 2024 12:00:00 -0500');
  Assert.AreEqual(0.0, Named - Numeric, 1 / 86400,
    'EST must equal -0500');
end;

procedure TDateTimeFormatTests.Test_FromRFC2822_NoTimezone_TreatedAsLocal;
var
  ParsedNoZone, ParsedLocal: TDateTime;
  LocalOffsetStr: string;
begin
  // When no timezone is present, the parser treats the wall-clock as local.
  // Compare against an explicit parse using the machine's current offset.
  ParsedNoZone := TDateTimeFormat.FromRFC2822('Fri, 21 Jun 2024 12:00:00');
  LocalOffsetStr := TTimeZones.FormatOffset(TTimeZones.CurrentUtcOffset);
  ParsedLocal  := TDateTimeFormat.FromRFC2822(
    'Fri, 21 Jun 2024 12:00:00 ' + LocalOffsetStr);
  Assert.AreEqual(0.0, ParsedNoZone - ParsedLocal, 1 / 86400,
    'No-timezone input must equal the same time tagged with the local offset');
end;

// ============================================================================
// TRelativeTimeTests
// ============================================================================

procedure TRelativeTimeTests.Test_Describe;
var
  S: string;
begin
  S := TRelativeTime.Describe(Now - 1/24); // 1 hour ago
  Assert.IsNotEmpty(S);
end;

procedure TRelativeTimeTests.Test_DescribeSpan;
var
  Span: TTimeSpanEx;
  S: string;
begin
  Span := TTimeSpanEx.FromHours(2);
  S := TRelativeTime.DescribeSpan(Span);
  Assert.IsNotEmpty(S);
end;

procedure TRelativeTimeTests.Test_TimeAgo;
var
  S: string;
begin
  S := TRelativeTime.TimeAgo(Now - 1); // Yesterday
  Assert.IsNotEmpty(S);
end;

procedure TRelativeTimeTests.Test_TimeUntil;
var
  S: string;
begin
  S := TRelativeTime.TimeUntil(Now + 1); // Tomorrow
  Assert.IsNotEmpty(S);
end;

procedure TRelativeTimeTests.Test_IsWithinMinutes;
begin
  Assert.IsTrue(TRelativeTime.IsWithinMinutes(Now - 1/(24*60), 5));
  Assert.IsFalse(TRelativeTime.IsWithinMinutes(Now - 1/24, 5));
end;

procedure TRelativeTimeTests.Test_IsWithinHours;
begin
  Assert.IsTrue(TRelativeTime.IsWithinHours(Now - 1/48, 2));
  Assert.IsFalse(TRelativeTime.IsWithinHours(Now - 1, 2));
end;

procedure TRelativeTimeTests.Test_IsWithinDays;
begin
  Assert.IsTrue(TRelativeTime.IsWithinDays(Now - 2, 5));
  Assert.IsFalse(TRelativeTime.IsWithinDays(Now - 10, 5));
end;

procedure TRelativeTimeTests.Test_IsToday;
begin
  Assert.IsTrue(TRelativeTime.IsToday(Now));
  Assert.IsFalse(TRelativeTime.IsToday(Now - 1));
end;

procedure TRelativeTimeTests.Test_IsYesterday;
begin
  Assert.IsTrue(TRelativeTime.IsYesterday(Now - 1));
  Assert.IsFalse(TRelativeTime.IsYesterday(Now));
end;

procedure TRelativeTimeTests.Test_IsTomorrow;
begin
  Assert.IsTrue(TRelativeTime.IsTomorrow(Now + 1));
  Assert.IsFalse(TRelativeTime.IsTomorrow(Now));
end;

procedure TRelativeTimeTests.Test_IsThisWeek;
begin
  Assert.IsTrue(TRelativeTime.IsThisWeek(Now));
end;

procedure TRelativeTimeTests.Test_IsThisMonth;
begin
  Assert.IsTrue(TRelativeTime.IsThisMonth(Now));
end;

procedure TRelativeTimeTests.Test_IsThisYear;
begin
  Assert.IsTrue(TRelativeTime.IsThisYear(Now));
  Assert.IsFalse(TRelativeTime.IsThisYear(EncodeDate(YearOf(Now) - 1, 1, 1)));
end;

// ============================================================================
// TDateTimeCalcTests
// ============================================================================

procedure TDateTimeCalcTests.Test_Add_Days;
var
  D1, D2: TDateTime;
begin
  D1 := EncodeDate(2024, 1, 1);
  D2 := TDateTimeCalc.Add(D1, 10, tuDays);
  Assert.AreEqual(EncodeDate(2024, 1, 11), D2);
end;

procedure TDateTimeCalcTests.Test_Add_Months;
var
  D1, D2: TDateTime;
begin
  D1 := EncodeDate(2024, 1, 15);
  D2 := TDateTimeCalc.Add(D1, 2, tuMonths);
  Assert.AreEqual(3, MonthOf(D2));
end;

procedure TDateTimeCalcTests.Test_Add_Years;
var
  D1, D2: TDateTime;
begin
  D1 := EncodeDate(2024, 1, 15);
  D2 := TDateTimeCalc.Add(D1, 1, tuYears);
  Assert.AreEqual(2025, YearOf(D2));
end;

procedure TDateTimeCalcTests.Test_Subtract_Days;
var
  D1, D2: TDateTime;
begin
  D1 := EncodeDate(2024, 1, 15);
  D2 := TDateTimeCalc.Subtract(D1, 10, tuDays);
  Assert.AreEqual(EncodeDate(2024, 1, 5), D2);
end;

procedure TDateTimeCalcTests.Test_Diff_Days;
var
  Diff: Double;
begin
  Diff := TDateTimeCalc.Diff(EncodeDate(2024, 1, 1), EncodeDate(2024, 1, 11), tuDays);
  Assert.AreEqual(10.0, Diff, 0.001);
end;

procedure TDateTimeCalcTests.Test_DiffSpan;
var
  Span: TTimeSpanEx;
begin
  Span := TDateTimeCalc.DiffSpan(EncodeDate(2024, 1, 1), EncodeDate(2024, 1, 6));
  Assert.AreEqual(5, Span.Days);
end;

procedure TDateTimeCalcTests.Test_DiffCalendarMonths_SameMonth;
begin
  // Same date: 0 months.
  Assert.AreEqual(0.0, TDateTimeCalc.DiffCalendarMonths(EncodeDate(2024, 3, 15), EncodeDate(2024, 3, 15)), 0.001);
  // Same month, earlier -> later: partial fraction within one month.
  Assert.AreEqual(0.3, TDateTimeCalc.DiffCalendarMonths(EncodeDate(2024, 3, 1), EncodeDate(2024, 3, 10)), 0.05);
end;

procedure TDateTimeCalcTests.Test_DiffCalendarMonths_WholeMonths;
begin
  // Jan 15 -> Feb 15 is exactly 1 month.
  Assert.AreEqual(1.0, TDateTimeCalc.DiffCalendarMonths(EncodeDate(2024, 1, 15), EncodeDate(2024, 2, 15)), 0.001);
  // Jan 15 2024 -> Apr 15 2024 is 3 months.
  Assert.AreEqual(3.0, TDateTimeCalc.DiffCalendarMonths(EncodeDate(2024, 1, 15), EncodeDate(2024, 4, 15)), 0.001);
  // Cross-year: Nov 2023 -> Feb 2024 = 3 months.
  Assert.AreEqual(3.0, TDateTimeCalc.DiffCalendarMonths(EncodeDate(2023, 11, 1), EncodeDate(2024, 2, 1)), 0.001);
end;

procedure TDateTimeCalcTests.Test_DiffCalendarMonths_PartialMonth;
begin
  // Jan 1 -> Jan 16 = 15/31 ~ 0.484
  Assert.AreEqual(15 / 31, TDateTimeCalc.DiffCalendarMonths(EncodeDate(2024, 1, 1), EncodeDate(2024, 1, 16)), 0.01);
  // Jan 31 -> Feb 1 = 1/31 ~ 0.032 (fractional part of one month).
  Assert.AreEqual(1 / 31, TDateTimeCalc.DiffCalendarMonths(EncodeDate(2024, 1, 31), EncodeDate(2024, 2, 1)), 0.01);
end;

procedure TDateTimeCalcTests.Test_DiffCalendarMonths_Jan31_Feb28;
begin
  // Jan 31 -> Feb 28: whole=0 (day 28 < 31), fraction = (28-31+31)/31 = 28/31 ~ 0.903.
  Assert.AreEqual(28 / 31, TDateTimeCalc.DiffCalendarMonths(EncodeDate(2024, 1, 31), EncodeDate(2024, 2, 28)), 0.01);
end;

procedure TDateTimeCalcTests.Test_DiffCalendarMonths_Feb28_Mar31;
begin
  // Feb 28 -> Mar 31: 1 month + 3/28 = ~1.107 (from-month is Feb, 28 days).
  Assert.AreEqual(1 + 3 / 28, TDateTimeCalc.DiffCalendarMonths(EncodeDate(2024, 2, 28), EncodeDate(2024, 3, 31)), 0.01);
end;

procedure TDateTimeCalcTests.Test_DiffCalendarMonths_LeapYear;
begin
  // Feb 28 2024 -> Feb 29 2024 = 1/29 of Feb ~ 0.034 (leap year).
  Assert.AreEqual(1 / 29, TDateTimeCalc.DiffCalendarMonths(EncodeDate(2024, 2, 28), EncodeDate(2024, 2, 29)), 0.01);
  // Feb 29 2024 -> Mar 29 2024 = exactly 1 month.
  Assert.AreEqual(1.0, TDateTimeCalc.DiffCalendarMonths(EncodeDate(2024, 2, 29), EncodeDate(2024, 3, 29)), 0.001);
  // Non-leap year: Feb 28 2023 -> Mar 28 2023 = exactly 1 month.
  Assert.AreEqual(1.0, TDateTimeCalc.DiffCalendarMonths(EncodeDate(2023, 2, 28), EncodeDate(2023, 3, 28)), 0.001);
end;

procedure TDateTimeCalcTests.Test_DiffCalendarMonths_Negative;
begin
  // AFrom > ATo -> negative result.
  Assert.AreEqual(-1.0, TDateTimeCalc.DiffCalendarMonths(EncodeDate(2024, 3, 15), EncodeDate(2024, 2, 15)), 0.001);
  Assert.AreEqual(-3.0, TDateTimeCalc.DiffCalendarMonths(EncodeDate(2024, 4, 15), EncodeDate(2024, 1, 15)), 0.001);
end;

procedure TDateTimeCalcTests.Test_DiffCalendarYears_WholeYears;
begin
  // Exactly 2 years.
  Assert.AreEqual(2.0, TDateTimeCalc.DiffCalendarYears(EncodeDate(2022, 6, 15), EncodeDate(2024, 6, 15)), 0.001);
end;

procedure TDateTimeCalcTests.Test_DiffCalendarYears_PartialYear;
begin
  // Jan 1 2023 -> Jul 1 2024 = 1.5 years (6/12).
  Assert.AreEqual(1.5, TDateTimeCalc.DiffCalendarYears(EncodeDate(2023, 1, 1), EncodeDate(2024, 7, 1)), 0.05);
  // Feb 28 2024 -> Feb 28 2025 = 1 year exactly.
  Assert.AreEqual(1.0, TDateTimeCalc.DiffCalendarYears(EncodeDate(2024, 2, 28), EncodeDate(2025, 2, 28)), 0.01);
end;

procedure TDateTimeCalcTests.Test_StartOfDay;
var
  DT, Start: TDateTime;
begin
  DT := EncodeDate(2024, 6, 15) + EncodeTime(14, 30, 45, 500);
  Start := TDateTimeCalc.StartOfDay(DT);
  Assert.AreEqual(0, HourOf(Start));
  Assert.AreEqual(0, MinuteOf(Start));
end;

procedure TDateTimeCalcTests.Test_EndOfDay;
var
  DT, EndD: TDateTime;
begin
  DT := EncodeDate(2024, 6, 15) + EncodeTime(14, 30, 0, 0);
  EndD := TDateTimeCalc.EndOfDay(DT);
  Assert.AreEqual(23, HourOf(EndD));
  Assert.AreEqual(59, MinuteOf(EndD));
end;

procedure TDateTimeCalcTests.Test_StartOfWeek;
var
  DT, Start: TDateTime;
begin
  DT := EncodeDate(2024, 6, 19); // Wednesday
  Start := TDateTimeCalc.StartOfWeek(DT, dowMonday);
  Assert.AreEqual(17, DayOf(Start)); // Monday
end;

procedure TDateTimeCalcTests.Test_EndOfWeek;
var
  DT, EndW: TDateTime;
begin
  DT := EncodeDate(2024, 6, 19); // Wednesday
  EndW := TDateTimeCalc.EndOfWeek(DT, dowMonday);
  Assert.AreEqual(23, DayOf(EndW)); // Sunday
end;

procedure TDateTimeCalcTests.Test_StartOfMonth;
var
  DT, Start: TDateTime;
begin
  DT := EncodeDate(2024, 6, 15);
  Start := TDateTimeCalc.StartOfMonth(DT);
  Assert.AreEqual(1, DayOf(Start));
end;

procedure TDateTimeCalcTests.Test_EndOfMonth;
var
  DT, EndM: TDateTime;
begin
  DT := EncodeDate(2024, 6, 15);
  EndM := TDateTimeCalc.EndOfMonth(DT);
  Assert.AreEqual(30, DayOf(EndM));
end;

procedure TDateTimeCalcTests.Test_StartOfYear;
var
  DT, Start: TDateTime;
begin
  DT := EncodeDate(2024, 6, 15);
  Start := TDateTimeCalc.StartOfYear(DT);
  Assert.AreEqual(1, MonthOf(Start));
  Assert.AreEqual(1, DayOf(Start));
end;

procedure TDateTimeCalcTests.Test_EndOfYear;
var
  DT, EndY: TDateTime;
begin
  DT := EncodeDate(2024, 6, 15);
  EndY := TDateTimeCalc.EndOfYear(DT);
  Assert.AreEqual(12, MonthOf(EndY));
  Assert.AreEqual(31, DayOf(EndY));
end;

procedure TDateTimeCalcTests.Test_NextDayOfWeek;
var
  DT, Next: TDateTime;
begin
  DT := EncodeDate(2024, 6, 19); // Wednesday
  Next := TDateTimeCalc.NextDayOfWeek(DT, dowFriday);
  Assert.AreEqual(21, DayOf(Next));
end;

procedure TDateTimeCalcTests.Test_PreviousDayOfWeek;
var
  DT, Prev: TDateTime;
begin
  DT := EncodeDate(2024, 6, 19); // Wednesday
  Prev := TDateTimeCalc.PreviousDayOfWeek(DT, dowMonday);
  Assert.AreEqual(17, DayOf(Prev));
end;

procedure TDateTimeCalcTests.Test_RoundToMinute;
var
  DT, Rounded: TDateTime;
begin
  DT := EncodeDate(2024, 6, 15) + EncodeTime(14, 30, 45, 0);
  Rounded := TDateTimeCalc.RoundToMinute(DT);
  Assert.AreEqual(0, SecondOf(Rounded));
end;

procedure TDateTimeCalcTests.Test_RoundToHour;
var
  DT, Rounded: TDateTime;
begin
  DT := EncodeDate(2024, 6, 15) + EncodeTime(14, 30, 45, 0);
  Rounded := TDateTimeCalc.RoundToHour(DT);
  Assert.AreEqual(0, MinuteOf(Rounded));
  Assert.AreEqual(0, SecondOf(Rounded));
end;

procedure TDateTimeCalcTests.Test_Clamp;
var
  Result: TDateTime;
begin
  Result := TDateTimeCalc.Clamp(
    EncodeDate(2024, 7, 1),
    EncodeDate(2024, 1, 1),
    EncodeDate(2024, 6, 30)
  );
  Assert.AreEqual(EncodeDate(2024, 6, 30), Result);
end;

procedure TDateTimeCalcTests.Test_Min;
var
  Result: TDateTime;
begin
  Result := TDateTimeCalc.Min(EncodeDate(2024, 1, 1), EncodeDate(2024, 6, 1));
  Assert.AreEqual(EncodeDate(2024, 1, 1), Result);
end;

procedure TDateTimeCalcTests.Test_Max;
var
  Result: TDateTime;
begin
  Result := TDateTimeCalc.Max(EncodeDate(2024, 1, 1), EncodeDate(2024, 6, 1));
  Assert.AreEqual(EncodeDate(2024, 6, 1), Result);
end;

// ============================================================================
// TBusinessDaysTests
// ============================================================================

procedure TBusinessDaysTests.Setup;
begin
  TBusinessDays.ClearHolidays;
  TBusinessDays.SetWeekendDays([dowSaturday, dowSunday]);
end;

procedure TBusinessDaysTests.Test_IsWeekend_Saturday;
begin
  Assert.IsTrue(TBusinessDays.IsWeekend(EncodeDate(2024, 6, 15))); // Saturday
end;

procedure TBusinessDaysTests.Test_IsWeekend_Sunday;
begin
  Assert.IsTrue(TBusinessDays.IsWeekend(EncodeDate(2024, 6, 16))); // Sunday
end;

procedure TBusinessDaysTests.Test_IsWeekend_Weekday;
begin
  Assert.IsFalse(TBusinessDays.IsWeekend(EncodeDate(2024, 6, 17))); // Monday
end;

procedure TBusinessDaysTests.Test_IsBusinessDay;
begin
  Assert.IsTrue(TBusinessDays.IsBusinessDay(EncodeDate(2024, 6, 17))); // Monday
  Assert.IsFalse(TBusinessDays.IsBusinessDay(EncodeDate(2024, 6, 15))); // Saturday
end;

procedure TBusinessDaysTests.Test_AddHoliday;
begin
  TBusinessDays.AddHoliday(EncodeDate(2024, 12, 25));
  Assert.IsTrue(TBusinessDays.IsHoliday(EncodeDate(2024, 12, 25)));
end;

procedure TBusinessDaysTests.Test_IsHoliday;
begin
  TBusinessDays.AddHoliday(EncodeDate(2024, 1, 1));
  Assert.IsTrue(TBusinessDays.IsHoliday(EncodeDate(2024, 1, 1)));
  Assert.IsFalse(TBusinessDays.IsHoliday(EncodeDate(2024, 1, 2)));
end;

procedure TBusinessDaysTests.Test_AddBusinessDays;
var
  Start, Expected: TDateTime;
begin
  Start := EncodeDate(2024, 6, 17); // Monday
  Expected := TBusinessDays.AddBusinessDays(Start, 5);
  Assert.AreEqual(EncodeDate(2024, 6, 24), Expected); // Next Monday
end;

procedure TBusinessDaysTests.Test_AddBusinessDays_ZeroDays_SnapsToBusinessDay;
var
  Sat, Mon, Expected: TDateTime;
begin
  // 2024-06-15 is Saturday, 2024-06-16 is Sunday, 2024-06-17 is Monday.
  Sat := EncodeDate(2024, 6, 15);
  Expected := TBusinessDays.AddBusinessDays(Sat, 0);
  Assert.AreEqual(EncodeDate(2024, 6, 17), Expected,
    'ADays=0 on Saturday must snap to Monday');
  Assert.IsTrue(TBusinessDays.IsBusinessDay(Expected),
    'result must itself be a business day');

  // Sunday also snaps to Monday.
  Expected := TBusinessDays.AddBusinessDays(EncodeDate(2024, 6, 16), 0);
  Assert.AreEqual(EncodeDate(2024, 6, 17), Expected,
    'ADays=0 on Sunday must snap to Monday');

  // A weekday with ADays=0 returns the same date.
  Mon := EncodeDate(2024, 6, 17);
  Expected := TBusinessDays.AddBusinessDays(Mon, 0);
  Assert.AreEqual(Mon, Expected,
    'ADays=0 on Monday must return Monday');

  // With a holiday on Monday, Saturday ADays=0 must skip to Tuesday.
  TBusinessDays.AddHoliday(EncodeDate(2024, 6, 17));
  try
    Expected := TBusinessDays.AddBusinessDays(Sat, 0);
    Assert.AreEqual(EncodeDate(2024, 6, 18), Expected,
      'ADays=0 on Saturday with Monday holiday must snap to Tuesday');
  finally
    TBusinessDays.ClearHolidays;
  end;
end;

procedure TBusinessDaysTests.Test_BusinessDaysBetween;
var
  Count: Integer;
begin
  Count := TBusinessDays.BusinessDaysBetween(
    EncodeDate(2024, 6, 17), // Monday
    EncodeDate(2024, 6, 21)  // Friday
  );
  Assert.AreEqual(4, Count);
end;

procedure TBusinessDaysTests.Test_NextBusinessDay;
var
  Result: TDateTime;
begin
  Result := TBusinessDays.NextBusinessDay(EncodeDate(2024, 6, 14)); // Friday
  Assert.AreEqual(EncodeDate(2024, 6, 17), Result); // Monday
end;

procedure TBusinessDaysTests.Test_PreviousBusinessDay;
var
  Result: TDateTime;
begin
  Result := TBusinessDays.PreviousBusinessDay(EncodeDate(2024, 6, 17)); // Monday
  Assert.AreEqual(EncodeDate(2024, 6, 14), Result); // Friday
end;

// ============================================================================
// TDateTimeUtilsTests
// ============================================================================

procedure TDateTimeUtilsTests.Test_Now;
var
  DT: TDateTime;
begin
  DT := TDateTimeUtils.Now;
  Assert.IsTrue(Abs(DT - System.SysUtils.Now) < 1/86400); // Within 1 second
end;

procedure TDateTimeUtilsTests.Test_UtcNow;
var
  DT: TDateTime;
begin
  DT := TDateTimeUtils.UtcNow;
  Assert.IsTrue(DT > 0);
end;

procedure TDateTimeUtilsTests.Test_Today;
var
  DT: TDateTime;
begin
  DT := TDateTimeUtils.Today;
  Assert.AreEqual(System.SysUtils.Date, DT);
end;

procedure TDateTimeUtilsTests.Test_Create_Date;
var
  DT: TDateTime;
begin
  DT := TDateTimeUtils.Create(2024, 6, 15);
  Assert.AreEqual(EncodeDate(2024, 6, 15), DT);
end;

procedure TDateTimeUtilsTests.Test_Create_DateTime;
var
  DT: TDateTime;
begin
  DT := TDateTimeUtils.Create(2024, 6, 15, 14, 30, 0);
  Assert.AreEqual(2024, YearOf(DT));
  Assert.AreEqual(14, HourOf(DT));
end;

procedure TDateTimeUtilsTests.Test_CreateTime;
var
  DT: TDateTime;
begin
  DT := TDateTimeUtils.CreateTime(14, 30, 45);
  Assert.AreEqual(14, HourOf(DT));
  Assert.AreEqual(30, MinuteOf(DT));
  Assert.AreEqual(45, SecondOf(DT));
end;

procedure TDateTimeUtilsTests.Test_IsValidDate_True;
begin
  Assert.IsTrue(TDateTimeUtils.IsValidDate(2024, 6, 15));
end;

procedure TDateTimeUtilsTests.Test_IsValidDate_False;
begin
  Assert.IsFalse(TDateTimeUtils.IsValidDate(2024, 13, 1)); // Invalid month
  Assert.IsFalse(TDateTimeUtils.IsValidDate(2024, 2, 30)); // Invalid day
end;

procedure TDateTimeUtilsTests.Test_IsValidTime_True;
begin
  Assert.IsTrue(TDateTimeUtils.IsValidTime(14, 30, 45));
end;

procedure TDateTimeUtilsTests.Test_IsValidTime_False;
begin
  Assert.IsFalse(TDateTimeUtils.IsValidTime(25, 0, 0)); // Invalid hour
  Assert.IsFalse(TDateTimeUtils.IsValidTime(14, 61, 0)); // Invalid minute
end;

procedure TDateTimeUtilsTests.Test_IsLeapYear;
begin
  Assert.IsTrue(TDateTimeUtils.IsLeapYear(2024));
  Assert.IsFalse(TDateTimeUtils.IsLeapYear(2023));
  Assert.IsFalse(TDateTimeUtils.IsLeapYear(1900));
  Assert.IsTrue(TDateTimeUtils.IsLeapYear(2000));
end;

procedure TDateTimeUtilsTests.Test_DaysInMonth;
begin
  Assert.AreEqual(Word(31), TDateTimeUtils.DaysInMonth(2024, 1));
  Assert.AreEqual(Word(29), TDateTimeUtils.DaysInMonth(2024, 2)); // Leap year
  Assert.AreEqual(Word(28), TDateTimeUtils.DaysInMonth(2023, 2));
  Assert.AreEqual(Word(30), TDateTimeUtils.DaysInMonth(2024, 6));
end;

procedure TDateTimeUtilsTests.Test_DaysInYear;
begin
  Assert.AreEqual(Word(366), TDateTimeUtils.DaysInYear(2024));
  Assert.AreEqual(Word(365), TDateTimeUtils.DaysInYear(2023));
end;

procedure TDateTimeUtilsTests.Test_GetYear;
begin
  Assert.AreEqual(Word(2024), TDateTimeUtils.GetYear(EncodeDate(2024, 6, 15)));
end;

procedure TDateTimeUtilsTests.Test_GetMonth;
begin
  Assert.AreEqual(Word(6), TDateTimeUtils.GetMonth(EncodeDate(2024, 6, 15)));
end;

procedure TDateTimeUtilsTests.Test_GetDay;
begin
  Assert.AreEqual(Word(15), TDateTimeUtils.GetDay(EncodeDate(2024, 6, 15)));
end;

procedure TDateTimeUtilsTests.Test_GetHour;
begin
  Assert.AreEqual(Word(14), TDateTimeUtils.GetHour(EncodeTime(14, 30, 0, 0)));
end;

procedure TDateTimeUtilsTests.Test_GetMinute;
begin
  Assert.AreEqual(Word(30), TDateTimeUtils.GetMinute(EncodeTime(14, 30, 0, 0)));
end;

procedure TDateTimeUtilsTests.Test_GetSecond;
begin
  Assert.AreEqual(Word(45), TDateTimeUtils.GetSecond(EncodeTime(14, 30, 45, 0)));
end;

procedure TDateTimeUtilsTests.Test_GetDayOfWeek;
var
  DOW: TDayOfWeekEx;
begin
  DOW := TDateTimeUtils.GetDayOfWeek(EncodeDate(2024, 6, 17)); // Monday
  Assert.AreEqual(dowMonday, DOW);
end;

procedure TDateTimeUtilsTests.Test_GetDayOfYear;
var
  DOY: Word;
begin
  DOY := TDateTimeUtils.GetDayOfYear(EncodeDate(2024, 1, 1));
  Assert.AreEqual(Word(1), DOY);
end;

procedure TDateTimeUtilsTests.Test_GetWeekOfYear;
var
  WOY: Word;
begin
  WOY := TDateTimeUtils.GetWeekOfYear(EncodeDate(2024, 1, 8));
  Assert.IsTrue(WOY >= 1);
end;

procedure TDateTimeUtilsTests.Test_GetQuarter;
begin
  Assert.AreEqual(Word(1), TDateTimeUtils.GetQuarter(EncodeDate(2024, 2, 15)));
  Assert.AreEqual(Word(2), TDateTimeUtils.GetQuarter(EncodeDate(2024, 5, 15)));
  Assert.AreEqual(Word(3), TDateTimeUtils.GetQuarter(EncodeDate(2024, 8, 15)));
  Assert.AreEqual(Word(4), TDateTimeUtils.GetQuarter(EncodeDate(2024, 11, 15)));
end;

procedure TDateTimeUtilsTests.Test_DatePart;
var
  DT, DateOnly: TDateTime;
begin
  DT := EncodeDate(2024, 6, 15) + EncodeTime(14, 30, 0, 0);
  DateOnly := TDateTimeUtils.DatePart(DT);
  Assert.AreEqual(EncodeDate(2024, 6, 15), DateOnly);
end;

procedure TDateTimeUtilsTests.Test_TimePart;
var
  DT, TimeOnly: TDateTime;
begin
  DT := EncodeDate(2024, 6, 15) + EncodeTime(14, 30, 45, 0);
  TimeOnly := TDateTimeUtils.TimePart(DT);
  Assert.AreEqual(14, HourOf(TimeOnly));
  Assert.AreEqual(30, MinuteOf(TimeOnly));
end;

procedure TDateTimeUtilsTests.Test_Age;
var
  BirthDate: TDateTime;
  Age: Integer;
begin
  BirthDate := IncYear(Now, -25);
  Age := TDateTimeUtils.Age(BirthDate);
  Assert.AreEqual(25, Age);
end;

procedure TDateTimeUtilsTests.Test_IsSameDay;
begin
  Assert.IsTrue(TDateTimeUtils.IsSameDay(
    EncodeDate(2024, 6, 15) + EncodeTime(10, 0, 0, 0),
    EncodeDate(2024, 6, 15) + EncodeTime(20, 0, 0, 0)
  ));
  Assert.IsFalse(TDateTimeUtils.IsSameDay(
    EncodeDate(2024, 6, 15),
    EncodeDate(2024, 6, 16)
  ));
end;

procedure TDateTimeUtilsTests.Test_IsSameMonth;
begin
  Assert.IsTrue(TDateTimeUtils.IsSameMonth(
    EncodeDate(2024, 6, 1),
    EncodeDate(2024, 6, 30)
  ));
end;

procedure TDateTimeUtilsTests.Test_IsSameYear;
begin
  Assert.IsTrue(TDateTimeUtils.IsSameYear(
    EncodeDate(2024, 1, 1),
    EncodeDate(2024, 12, 31)
  ));
end;

procedure TDateTimeUtilsTests.Test_IsBefore;
begin
  Assert.IsTrue(TDateTimeUtils.IsBefore(
    EncodeDate(2024, 1, 1),
    EncodeDate(2024, 6, 1)
  ));
end;

procedure TDateTimeUtilsTests.Test_IsAfter;
begin
  Assert.IsTrue(TDateTimeUtils.IsAfter(
    EncodeDate(2024, 6, 1),
    EncodeDate(2024, 1, 1)
  ));
end;

procedure TDateTimeUtilsTests.Test_IsBetween;
begin
  Assert.IsTrue(TDateTimeUtils.IsBetween(
    EncodeDate(2024, 6, 15),
    EncodeDate(2024, 1, 1),
    EncodeDate(2024, 12, 31)
  ));
end;

procedure TDateTimeUtilsTests.Test_DayName;
var
  S: string;
begin
  S := TDateTimeUtils.DayName(dowMonday);
  Assert.IsNotEmpty(S);
end;

procedure TDateTimeUtilsTests.Test_MonthName;
var
  S: string;
begin
  S := TDateTimeUtils.MonthName(6);
  Assert.IsNotEmpty(S);
end;

initialization
  TDUnitX.RegisterTestFixture(TTimeSpanExTests);
  TDUnitX.RegisterTestFixture(TDateRangeTests);
  TDUnitX.RegisterTestFixture(TTimeZonesTests);
  TDUnitX.RegisterTestFixture(TDateTimeFormatTests);
  TDUnitX.RegisterTestFixture(TRelativeTimeTests);
  TDUnitX.RegisterTestFixture(TDateTimeCalcTests);
  TDUnitX.RegisterTestFixture(TBusinessDaysTests);
  TDUnitX.RegisterTestFixture(TDateTimeUtilsTests);

end.
