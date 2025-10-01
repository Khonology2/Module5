# Personal Development Hub - Design System

A comprehensive design system for the Personal Development Hub Flutter application, providing consistent styling, components, and responsive behavior across the entire app.

## 🎨 Design System Overview

This design system follows a dark theme with red accents, providing a modern and professional look for the Personal Development Hub application.

### Key Features
- **Dark Theme**: Blue-gray backgrounds with red accents
- **Responsive Design**: Adapts to mobile, tablet, and desktop screens
- **Consistent Typography**: Poppins font family throughout
- **Standardized Components**: Reusable UI components
- **Accessibility**: High contrast and readable text

## 📁 File Structure

```
lib/design_system/
├── app_colors.dart          # Color system and palette
├── app_typography.dart      # Typography system
├── app_spacing.dart         # Spacing system
├── app_breakpoints.dart     # Responsive breakpoints
├── app_components.dart      # Reusable UI components
├── app_theme.dart          # Theme configuration
├── sidebar_config.dart     # Sidebar navigation configuration
└── README.md              # This documentation
```

## 🎨 Color System

### Primary Colors
```dart
AppColors.backgroundColor    // Dark blue-gray (#1F2840)
AppColors.hoverColor        // Lighter blue-gray (#2A3652)
AppColors.activeColor       // Red accent (#C10D00)
AppColors.cardBackground    // Card background (#1F2840)
```

### Text Colors
```dart
AppColors.textPrimary       // White text
AppColors.textSecondary     // Semi-transparent white
AppColors.textMuted         // More transparent white
```

### Accent Colors
```dart
AppColors.successColor      // Green (#00C853)
AppColors.warningColor      // Orange (orangeAccent)
AppColors.dangerColor       // Red (redAccent)
AppColors.infoColor         // Teal (tealAccent)
```

## 📝 Typography System

### Headings
```dart
AppTypography.heading1      // Large heading (28px)
AppTypography.heading2    // Medium heading (24px)
AppTypography.heading3     // Small heading (20px)
AppTypography.heading4     // Extra small heading (18px)
```

### Body Text
```dart
AppTypography.bodyLarge    // Large body text (16px)
AppTypography.bodyMedium   // Standard body text (14px)
AppTypography.bodySmall    // Small body text (12px)
```

### Special Text
```dart
AppTypography.kpiValue     // KPI/Metric values
AppTypography.navigation   // Navigation items
AppTypography.buttonLarge  // Button text
```

## 📏 Spacing System

### Base Spacing Units
```dart
AppSpacing.xs = 4.0         // Extra small
AppSpacing.sm = 8.0         // Small
AppSpacing.md = 12.0        // Medium
AppSpacing.lg = 16.0        // Large
AppSpacing.xl = 20.0        // Extra large
AppSpacing.xxl = 24.0       // Double extra large
```

### Component Spacing
```dart
AppSpacing.cardPadding      // Card padding (16px)
AppSpacing.screenPadding   // Screen padding
AppSpacing.buttonPadding    // Button padding
```

## 📱 Responsive Breakpoints

### Screen Sizes
```dart
AppBreakpoints.isSmall(context)    // < 600px (Mobile)
AppBreakpoints.isMedium(context)   // 600px - 1000px (Tablet)
AppBreakpoints.isLarge(context)    // > 1000px (Desktop)
```

### Responsive Utilities
```dart
AppBreakpoints.getResponsivePadding(context)
AppBreakpoints.getResponsiveColumns(context)
AppBreakpoints.getResponsiveSidebarWidth(context, isCollapsed)
```

## 🧩 Component Library

### Cards
```dart
// Standard card
AppComponents.card(
  child: YourContent(),
)

// KPI card
AppComponents.kpiCard(
  label: 'Active Goals',
  value: '8',
  icon: Icons.track_changes,
  iconColor: AppColors.activeColor,
)

// Accent card with left border
AppComponents.accentCard(
  child: YourContent(),
  accentColor: AppColors.activeColor,
)
```

### Buttons
```dart
// Primary button
AppComponents.primaryButton(
  label: 'Add Goal',
  icon: Icons.add,
  onPressed: () {},
)

// Secondary button
AppComponents.secondaryButton(
  label: 'Cancel',
  icon: Icons.close,
  onPressed: () {},
)

// Filter chip
AppComponents.filterChip(
  label: 'Active',
  isSelected: true,
  onTap: () {},
)
```

### Input Components
```dart
// Text input field
AppComponents.textInput(
  label: 'Goal Title',
  hintText: 'Enter your goal title',
  controller: controller,
)
```

### List Components
```dart
// Activity item
AppComponents.activityItem(
  icon: Icons.check_circle,
  title: 'Completed "Learn React"',
  subtitle: '2 hours ago',
  iconColor: AppColors.successColor,
)
```

### Progress Components
```dart
// Progress bar
AppComponents.progressBar(
  value: 0.7,
  label: '70% Complete',
)
```

### Background Components
```dart
// Background with image and blur
AppComponents.backgroundWithImage(
  imagePath: 'assets/background.png',
  child: YourContent(),
)
```

## 🏗️ AppScaffold Usage

The `AppScaffold` component provides a consistent layout with responsive sidebar navigation.

```dart
AppScaffold(
  title: 'Screen Title',
  showAppBar: false,
  items: SidebarConfig.employeeItems,
  currentRouteName: '/employee_dashboard',
  onNavigate: (route) {
    Navigator.pushNamed(context, route);
  },
  onLogout: () async {
    await AuthService().signOut();
    Navigator.pushNamedAndRemoveUntil(context, '/sign_in', (route) => false);
  },
  content: YourScreenContent(),
)
```

## 🧭 Sidebar Configuration

### Employee Sidebar
```dart
SidebarConfig.employeeItems  // Standard employee navigation
```

### Manager Sidebar
```dart
SidebarConfig.managerItems   // Manager-specific navigation
```

### Admin Sidebar
```dart
SidebarConfig.adminItems     // Admin-specific navigation
```

### Dynamic Sidebar
```dart
// Get items based on user role
SidebarConfig.getItemsForRole('employee')
SidebarConfig.getItemsForRole('manager')
SidebarConfig.getItemsForRole('admin')
```

## 🎯 Usage Examples

### Complete Screen Example
```dart
class MyScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'My Screen',
      showAppBar: false,
      items: SidebarConfig.employeeItems,
      currentRouteName: '/my_screen',
      onNavigate: (route) => Navigator.pushNamed(context, route),
      onLogout: () => AuthService().signOut(),
      content: AppComponents.backgroundWithImage(
        imagePath: 'assets/background.png',
        child: SingleChildScrollView(
          padding: AppSpacing.screenPadding,
          child: Column(
            children: [
              AppComponents.card(
                child: Column(
                  children: [
                    Text('Welcome', style: AppTypography.heading3),
                    const SizedBox(height: AppSpacing.md),
                    AppComponents.kpiCard(
                      label: 'Goals',
                      value: '5',
                      icon: Icons.track_changes,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

### Responsive Grid Example
```dart
AppComponents.responsiveGrid(
  context: context,
  children: [
    AppComponents.kpiCard(label: 'Active', value: '8'),
    AppComponents.kpiCard(label: 'Completed', value: '12'),
    AppComponents.kpiCard(label: 'Points', value: '1,250'),
  ],
)
```

## 🔧 Theme Integration

The design system is automatically integrated into your app's theme:

```dart
// In main.dart
MaterialApp(
  theme: AppTheme.darkTheme,
  // ... other configuration
)
```

## 📱 Responsive Behavior

### Mobile (< 600px)
- Sidebar becomes a drawer
- Single column layout
- Compact spacing

### Tablet (600px - 1000px)
- Collapsed sidebar (72px width)
- Two column layout
- Medium spacing

### Desktop (> 1000px)
- Expandable sidebar (72px/240px width)
- Three column layout
- Full spacing

## 🎨 Customization

### Custom Colors
```dart
// Use custom colors with the design system
AppComponents.card(
  backgroundColor: Colors.blue,
  child: YourContent(),
)
```

### Custom Typography
```dart
// Use custom text styles
Text(
  'Custom Text',
  style: AppTypography.heading3.copyWith(
    color: Colors.blue,
    fontSize: 24,
  ),
)
```

### Custom Spacing
```dart
// Use custom spacing
Container(
  padding: AppSpacing.symmetric(vertical: 20, horizontal: 16),
  child: YourContent(),
)
```

## 🚀 Best Practices

1. **Always use AppScaffold** for main screens with sidebar
2. **Use design system colors** instead of hardcoded values
3. **Follow the spacing system** for consistent layouts
4. **Use responsive components** for different screen sizes
5. **Leverage the component library** for consistent UI elements
6. **Follow the typography hierarchy** for readable content
7. **Use the sidebar configuration** for consistent navigation

## 🔄 Migration Guide

### From Old Components
```dart
// Old way
Container(
  padding: EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: Color(0xFF1F2840),
    borderRadius: BorderRadius.circular(10),
  ),
  child: Text('Hello'),
)

// New way
AppComponents.card(
  child: Text('Hello'),
)
```

### From Custom Styling
```dart
// Old way
Text(
  'Title',
  style: TextStyle(
    color: Colors.white,
    fontSize: 18,
    fontWeight: FontWeight.bold,
  ),
)

// New way
Text(
  'Title',
  style: AppTypography.heading4,
)
```

This design system provides a solid foundation for building consistent, responsive, and accessible user interfaces in the Personal Development Hub application.
