import 'package:flutter/material.dart';
import 'package:pdh/services/role_service.dart'; // Import RoleService
import 'package:pdh/manager_nav_drawer.dart';
import 'package:pdh/employee_drawer.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    // The currentRoute is no longer used for highlighting, as we are using separate drawers.
    // final currentRoute = ModalRoute.of(context)?.settings.name;

    return StreamBuilder<String?>( // Use StreamBuilder to react to role changes
      stream: RoleService.instance.roleStream(),
      builder: (context, snapshot) {
        final role = snapshot.data;
        final isManager = role == 'manager';

        if (role == null) {
          return const Drawer(
            backgroundColor: Colors.red,
            child: Center(child: CircularProgressIndicator()),
          ); // Or a loading indicator
        }

        // Return the appropriate drawer based on the role
        return isManager ? const ManagerNavDrawer() : const EmployeeDrawer();
      },
    );
  }
}
