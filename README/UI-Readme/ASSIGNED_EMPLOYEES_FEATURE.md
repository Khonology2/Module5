# Assigned Employees Widget Feature

## Overview
This document describes the implementation of an "Assigned Employees" widget on the manager dashboard that displays all employees managed by the logged-in manager.

## Problem Statement
The manager dashboard needed a way to show which employees are assigned to each manager. The widget should query the `onboarding` collection and display users who have the current manager assigned to them.

## Database Structure
- **Collection**: `onboarding`
- **Field**: `manager` (string format: "name surname")
- **Example**: `manager: "Nkosinathi Radebe"`

## Implementation Details

### Widget Location
- **File**: `lib/manager_dashboard_screen.dart`
- **Position**: Under the "Top Performers" widget on the manager dashboard
- **Method**: `_buildAssignedEmployees()`

### Key Features
1. **Dynamic Query**: Uses the logged-in manager's name to find assigned employees
2. **Multiple Name Formats**: Tries various name formats to ensure compatibility
3. **Refresh Functionality**: Manual refresh button for data updates
4. **Error Handling**: Comprehensive error handling and user feedback
5. **Debug Logging**: Detailed logging for troubleshooting

### Query Logic
The widget queries the `onboarding` collection using:
```dart
FirebaseFirestore.instance
    .collection('onboarding')
    .where('manager', isEqualTo: managerName)
    .get()
```

### Name Resolution Strategy
The system tries these manager name variations:
1. Full name from onboarding (e.g., "Nkosinathi Radebe") - **Primary**
2. Email format (e.g., "Nkosinathi.Radebe1@khonology.com")
3. First name only (e.g., "Nkosinathi")
4. Last name only (e.g., "Radebe")
5. Combined without space (e.g., "NkosinathiRadebe")

### Manager Name Loading
```dart
Future<void> _loadManagerName() async {
  final user = FirebaseAuth.instance.currentUser;
  // Try to get name from onboarding collection first
  final onboardingName = await DatabaseService.getUserNameFromOnboarding(
    userId: user.uid,
    email: user.email,
  );
  // Use full name (not just first name)
  name = onboardingName ?? fallbackName;
}
```

### Widget Structure
```dart
Widget _buildAssignedEmployees() {
  return _card(
    child: Column(
      children: [
        // Header with refresh button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Assigned Employees'),
            IconButton(onPressed: refreshData, icon: Icon(Icons.refresh))
          ],
        ),
        // FutureBuilder for async data loading
        FutureBuilder<List<DocumentSnapshot>>(
          future: _getAssignedEmployees(),
          builder: (context, snapshot) {
            // Loading, error, and data states
          },
        ),
      ],
    ),
  );
}
```

## User Interface
- **Card Layout**: Matches other dashboard widgets
- **Employee List**: Shows employee names with "Employee" label
- **Empty State**: Helpful message when no employees are assigned
- **Loading State**: Circular progress indicator
- **Error State**: Error message with retry option

## Test Files
- **Location**: `test/` folder
- **Files**:
  - `test_manager_field.dart` - Comprehensive database query test
  - `simple_manager_test.dart` - Basic format verification

## Debug Information
The widget includes detailed logging:
```
AssignedEmployees: Querying with manager name: "Nkosinathi Radebe"
AssignedEmployees: Found X employees with manager name: "Nkosinathi Radebe"
```

## Technical Requirements for ChatGPT Assistance

### What I Need Help With
1. **Database Query Optimization**: Improve the query performance for large datasets
2. **Name Matching Algorithm**: Better fuzzy matching for manager names
3. **Real-time Updates**: Convert from FutureBuilder to StreamBuilder for live updates
4. **Pagination**: Handle large numbers of assigned employees
5. **Search/Filter**: Add search functionality within assigned employees
6. **Employee Details**: Navigate to employee details when clicked
7. **Bulk Actions**: Add actions for multiple employees (message, assign tasks, etc.)

### Current Code Structure
```dart
class _ManagerDashboardScreenState extends State<ManagerDashboardScreen> {
  String _managerName = 'Manager';
  List<String> _alternativeManagerNames = [];
  int _assignedEmployeesRefreshKey = 0;
  
  Future<List<DocumentSnapshot>> _getAssignedEmployees() async {
    // Try multiple manager name variations
    for (final managerName in _alternativeManagerNames) {
      final query = await FirebaseFirestore.instance
          .collection('onboarding')
          .where('manager', isEqualTo: managerName)
          .get();
      if (query.docs.isNotEmpty) return query.docs;
    }
    return [];
  }
}
```

### Database Schema
```json
{
  "collection": "onboarding",
  "fields": {
    "manager": "string (format: 'First Last')",
    "displayName": "string",
    "email": "string",
    "firstName": "string",
    "lastName": "string"
  }
}
```

### Expected Behavior
1. Manager logs into the application
2. Dashboard loads with "Assigned Employees" widget
3. Widget queries `onboarding` collection for documents where `manager` field matches the logged-in manager's name
4. Display list of assigned employees
5. Manager can refresh to get latest data

### Known Issues to Address
1. **Name Format Variations**: Different managers might have their names stored in various formats
2. **Case Sensitivity**: Query should be case-insensitive
3. **Performance**: Multiple queries for name variations might be slow
4. **Real-time Updates**: Current implementation requires manual refresh

### Enhancement Ideas
1. **Caching**: Cache manager name and employee list
2. **Indexing**: Add Firestore index for `manager` field
3. **Normalization**: Standardize manager name storage format
4. **Batch Operations**: Load multiple employees in single query
5. **Offline Support**: Cache data for offline viewing

## Files Modified
- `lib/manager_dashboard_screen.dart` - Main widget implementation
- `test/test_manager_field.dart` - Database query testing
- `test/simple_manager_test.dart` - Basic format verification

## Git Branch
- **Branch**: `manager-allocations`
- **Commit**: "new widget placed on the manager dashboard"

## Next Steps
1. Test with real data to verify query works correctly
2. Optimize performance for large employee lists
3. Add real-time updates using StreamBuilder
4. Implement search and filtering functionality
5. Add employee interaction features
