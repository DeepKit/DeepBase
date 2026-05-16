# Studio Tool - Quick Test Guide

**Purpose**: Verify that i18n and button functionality work correctly

---

## Pre-requisites

- Windows System Language: Chinese (Simplified) - 中文(简�?
- SQLite database with Settings table
- Studio.exe compiled and ready
- `Studio.dpr` links `DeepBase.Persistence.Manager.FireDAC`; otherwise startup can fail with `No DB connection adapter registered`.

---

## Test Case 1: i18n Auto-Detection

### Setup
1. Ensure Windows system language is set to Chinese (Simplified)
2. Launch `Studio.exe`

### Expected Result
�?**ALL UI text should display in Chinese:**
- Window title: `DeepBase Studio`
- Top panel: `打开数据�?..` (Open Database...)
- Navigation: `配置` (Configuration), `数据` (Data)
- Buttons: `打开数据�?..`, `刷新`, `添加`, `删除`

### Verify
- [ ] Window title in Chinese
- [ ] All button labels in Chinese
- [ ] Navigation categories in Chinese

---

## Test Case 2: Open Database Button

### Steps
1. Click `打开数据�?..` button
2. Navigate to any SQLite database file (.db)
3. Click Open

### Expected Result
�?**Database opens successfully:**
- Status label shows database name
- Window title updates to `DeepBase Studio - filename.db`
- Configuration frame is ready to load data

### Verify
- [ ] File dialog opens
- [ ] Database connection succeeds
- [ ] UI updates to show database name

---

## Test Case 3: Refresh Button

### Prerequisites
- Database opened (see Test Case 2)
- Database contains Settings table with data

### Steps
1. Click `刷新` (Refresh) button in ConfigFrame

### Expected Result
�?**Configuration data loads:**
- Settings table populates vleConfig grid
- Each key-value pair displays correctly

### Verify
- [ ] Grid shows configuration items
- [ ] Data displays correctly

---

## Test Case 4: Add Button (Critical Test for Event Binding)

### Prerequisites
- Database opened (see Test Case 2)
- btnAdd event is properly bound

### Steps
1. Click `添加` (Add Key) button
2. Enter Key in dialog box: `TestKey`
3. Click OK
4. Enter Value in dialog box: `TestValue`
5. Click OK

### Expected Result
�?**New configuration item added:**
- Success message appears: `Config added successfully`
- Grid refreshes and shows new item
- New key-value pair visible in configuration list

### Verify
- [ ] First dialog accepts key input
- [ ] Second dialog accepts value input
- [ ] Success message displays
- [ ] Grid updates with new item
- [ ] **btnAdd event properly bound �?*

### Troubleshooting
If button doesn't work:
- Check console for error messages
- Verify database connection is active
- Ensure Settings table exists and is writable

---

## Test Case 5: Delete Button

### Prerequisites
- Database opened
- At least one configuration item in grid
- Item must be selected (highlighted)

### Steps
1. Click any row in the configuration grid to select it
2. Click `删除` (Delete) button
3. Confirmation dialog appears: `确定删除配置 "KeyName"?`
4. Click Yes to confirm

### Expected Result
�?**Item deleted:**
- Configuration item removed from database
- Grid refreshes without deleted item

### Verify
- [ ] Row selection works
- [ ] Confirmation dialog appears
- [ ] Item removed from grid

---

## Test Case 6: Navigation Between Tabs

### Steps
1. Click `数据` (Data) category in left panel
2. Verify Logs view displays
3. Click `配置` (Configuration) category
4. Verify Configuration view with grid returns

### Expected Result
�?**Navigation works:**
- CardPanel switches between views
- Configuration and Logs frames display correctly

### Verify
- [ ] Tab switching works smoothly
- [ ] Data persists when switching back

---

## Summary Checklist

| Feature | Test Status | Notes |
|---------|------------|-------|
| Chinese i18n | [ ] PASS | All UI text in Chinese |
| Open Database | [ ] PASS | File dialog and connection |
| Refresh Config | [ ] PASS | Grid loads settings |
| Add Config | [ ] PASS | **CRITICAL** - btnAdd event works |
| Delete Config | [ ] PASS | Confirmation and deletion |
| Navigation | [ ] PASS | Tab switching works |

---

## Known Limitations

1. **i18n requires Chinese system language**
   - Windows system language must be set to Chinese (Simplified)
   - Otherwise defaults to English

2. **Database must have Settings table**
   - Table should have: Key (TEXT), Value (TEXT) columns
   - If missing, buttons will fail silently

3. **No network/remote databases**
   - Only local SQLite files supported

---

## Additional Notes

- All timestamps are UTC
- Error messages display in current language
- Database changes are committed immediately
- No undo/rollback available

---

**Test Date**: ___________  
**Tester**: ___________  
**Result**: [ ] PASS [ ] FAIL  
**Issues Found**: ___________________________________

---

*Generated: 2025-11-28*
