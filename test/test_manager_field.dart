/// Test script to check employees assigned to manager using the 'manager' field
/// Run this to verify the database query works correctly

import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  print('=== Testing Manager Field Query ===');
  
  try {
    // Step 1: Find the manager's document
    print('\n1. Looking for manager document...');
    final managerQuery = await FirebaseFirestore.instance
        .collection('onboarding')
        .where('email', isEqualTo: 'Nkosinathi.Radebe1@khonology.com')
        .limit(1)
        .get();
    
    if (managerQuery.docs.isEmpty) {
      print('❌ Manager not found with email: Nkosinathi.Radebe1@khonology.com');
      return;
    }
    
    final managerDoc = managerQuery.docs.first;
    final managerData = managerDoc.data();
    
    // Get the manager's full name
    final managerName = managerData['displayName'] ?? 
                       managerData['fullName'] ?? 
                       managerData['firstName'] ?? 
                       managerData['name'] ?? 
                       'Unknown Manager';
    
    print('✅ Manager found:');
    print('   Email: ${managerData['email']}');
    print('   Name: $managerName');
    print('   Document ID: ${managerDoc.id}');
    
    // Step 2: Query for employees using the 'manager' field
    print('\n2. Looking for employees with manager field...');
    
    // Try different possible manager name formats
    final possibleManagerNames = [
      managerName,
      'Nkosinathi Radebe',
      'Nkosinathi.Radebe1@khonology.com',
      'Nkosinathi',
      'Radebe'
    ];
    
    for (final name in possibleManagerNames) {
      print('\n   Trying with manager name: "$name"');
      
      final employeesQuery = await FirebaseFirestore.instance
          .collection('onboarding')
          .where('manager', isEqualTo: name)
          .get();
      
      if (employeesQuery.docs.isNotEmpty) {
        print('   ✅ Found ${employeesQuery.docs.length} employee(s):');
        
        for (final doc in employeesQuery.docs) {
          final data = doc.data();
          final employeeName = data['displayName'] ?? 
                              data['fullName'] ?? 
                              data['firstName'] ?? 
                              data['name'] ?? 
                              'Unknown Employee';
          final email = data['email'] ?? 'No email';
          final designation = data['designation'] ?? 'No designation';
          
          print('     - $employeeName ($email) - $designation');
          print('       Document ID: ${doc.id}');
          print('       manager field: "${data['manager']}"');
        }
      } else {
        print('   ❌ No employees found for manager name: "$name"');
      }
    }
    
    // Step 3: Check all documents that have manager field
    print('\n3. Checking all documents with manager field...');
    final allWithManager = await FirebaseFirestore.instance
        .collection('onboarding')
        .where('manager', isNull: false)
        .limit(20) // Limit to avoid too much data
        .get();
    
    print('   Found ${allWithManager.docs.length} documents with manager field:');
    final Map<String, List<DocumentSnapshot>> groupedByManager = {};
    
    for (final doc in allWithManager.docs) {
      final data = doc.data();
      final manager = data['manager']?.toString() ?? 'Unknown';
      
      if (!groupedByManager.containsKey(manager)) {
        groupedByManager[manager] = [];
      }
      groupedByManager[manager]!.add(doc);
    }
    
    print('\n   Employees grouped by manager:');
    for (final entry in groupedByManager.entries) {
      print('   Manager: "${entry.key}" - ${entry.value.length} employee(s)');
      
      for (final doc in entry.value.take(3)) { // Show max 3 per manager
        final data = doc.data();
        final employeeName = data['displayName'] ?? 
                            data['fullName'] ?? 
                            data['firstName'] ?? 
                            data['name'] ?? 
                            'Unknown Employee';
        print('     - $employeeName');
      }
      if (entry.value.length > 3) {
        print('     ... and ${entry.value.length - 3} more');
      }
    }
    
    // Step 4: Summary
    print('\n4. Summary:');
    print('   Total documents with manager field: ${allWithManager.docs.length}');
    print('   Unique manager names: ${groupedByManager.keys.length}');
    
    if (groupedByManager.isNotEmpty) {
      print('\n   Manager names found:');
      for (final managerName in groupedByManager.keys) {
        print('     - "$managerName" (${groupedByManager[managerName]!.length} employees)');
      }
    }
    
  } catch (e, stackTrace) {
    print('❌ Error: $e');
    print('Stack trace: $stackTrace');
  }
  
  print('\n=== Test Complete ===');
}
