/// Comprehensive debugging script for Assigned Employees widget
/// This will help identify exactly what's happening with the data fetching

import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<void> main() async {
  print('=== Assigned Employees Debugging ===');
  
  try {
    // Step 1: Verify current logged-in user
    print('\n1. Checking logged-in user...');
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      print('❌ No user is logged in');
      return;
    }
    
    print('✅ User logged in:');
    print('   UID: ${currentUser.uid}');
    print('   Email: ${currentUser.email}');
    print('   Display Name: ${currentUser.displayName}');
    
    // Step 2: Get manager's name from onboarding collection
    print('\n2. Getting manager name from onboarding...');
    final managerDoc = await FirebaseFirestore.instance
        .collection('onboarding')
        .doc(currentUser.uid)
        .get();
    
    if (!managerDoc.exists) {
      print('❌ Manager document not found in onboarding collection');
      
      // Try to find by email
      print('   Trying to find by email...');
      final emailQuery = await FirebaseFirestore.instance
          .collection('onboarding')
          .where('email', isEqualTo: currentUser.email)
          .limit(1)
          .get();
      
      if (emailQuery.docs.isEmpty) {
        print('❌ Manager not found by email either');
        return;
      }
      
      final managerData = emailQuery.docs.first.data();
      print('✅ Found manager by email:');
      print('   Document ID: ${emailQuery.docs.first.id}');
      print('   Data: $managerData');
    } else {
      final managerData = managerDoc.data();
      print('✅ Found manager document:');
      print('   Document ID: ${managerDoc.id}');
      print('   Data: $managerData');
    }
    
    // Extract manager name with all possible fields
    final data = managerDoc.exists ? managerDoc.data() : 
                 (await FirebaseFirestore.instance
                     .collection('onboarding')
                     .where('email', isEqualTo: currentUser.email)
                     .limit(1)
                     .get()).first.data();
    
    final possibleNames = {
      'displayName': data['displayName']?.toString(),
      'fullName': data['fullName']?.toString(),
      'firstName': data['firstName']?.toString(),
      'lastName': data['lastName']?.toString(),
      'name': data['name']?.toString(),
      'email': data['email']?.toString(),
    };
    
    print('\n3. Possible manager names found:');
    for (final entry in possibleNames.entries) {
      if (entry.value != null && entry.value!.isNotEmpty) {
        print('   ${entry.key}: "${entry.value}"');
      }
    }
    
    // Step 4: Test queries with different name formats
    print('\n4. Testing queries with different name formats...');
    
    final testNames = [
      data['displayName']?.toString(),
      data['fullName']?.toString(),
      '${data['firstName']} ${data['lastName']}'.trim(),
      data['firstName']?.toString(),
      data['lastName']?.toString(),
      data['name']?.toString(),
      currentUser.email,
      'Nkosinathi Radebe',
      'Nkosinathi.Radebe1@khonology.com',
    ].where((name) => name != null && name.isNotEmpty).toSet().toList();
    
    for (final testName in testNames) {
      print('\n   Testing with manager name: "$testName"');
      
      try {
        final query = await FirebaseFirestore.instance
            .collection('onboarding')
            .where('manager', isEqualTo: testName)
            .get();
        
        print('   Results: ${query.docs.length} documents found');
        
        if (query.docs.isNotEmpty) {
          print('   ✅ SUCCESS with name: "$testName"');
          for (final doc in query.docs) {
            final empData = doc.data();
            
            // Enhanced name field analysis
            final firstName = empData['firstName']?.toString() ?? '';
            final lastName = empData['lastName']?.toString() ?? '';
            final displayName = empData['displayName']?.toString() ?? '';
            final fullName = empData['fullName']?.toString() ?? '';
            final name = empData['name']?.toString() ?? '';
            final email = empData['email']?.toString() ?? 'No email';
            final managerField = empData['manager']?.toString() ?? 'No manager field';
            
            print('     - Employee Document ID: ${doc.id}');
            print('       Name Fields Analysis:');
            print('         firstName: "$firstName"');
            print('         lastName: "$lastName"');
            print('         displayName: "$displayName"');
            print('         fullName: "$fullName"');
            print('         name: "$name"');
            print('       Email: $email');
            print('       Manager field: "$managerField"');
            
            // Show what the final name would be
            String finalName = '';
            if (firstName.isNotEmpty && lastName.isNotEmpty) {
              finalName = '$firstName $lastName';
            } else if (displayName.isNotEmpty) {
              finalName = displayName;
            } else if (fullName.isNotEmpty) {
              finalName = fullName;
            } else if (name.isNotEmpty) {
              finalName = name;
            } else if (firstName.isNotEmpty) {
              finalName = firstName;
            } else if (lastName.isNotEmpty) {
              finalName = lastName;
            } else {
              finalName = 'Unknown Employee';
            }
            
            print('       Final Display Name: "$finalName"');
            print('');
          }
        }
      } catch (e) {
        print('   ❌ Error with name "$testName": $e');
      }
    }
    
    // Step 5: Check all documents with manager field
    print('\n5. Analyzing all documents with manager field...');
    final allWithManager = await FirebaseFirestore.instance
        .collection('onboarding')
        .where('manager', isNull: false)
        .limit(50) // Limit to avoid too much data
        .get();
    
    print('   Total documents with manager field: ${allWithManager.docs.length}');
    
    final Map<String, int> managerCounts = {};
    final Set<String> uniqueManagerNames = {};
    
    // Analyze name field completeness
    int completeNames = 0;
    int partialNames = 0;
    int missingNames = 0;
    final List<Map<String, dynamic>> nameIssues = [];
    
    for (final doc in allWithManager.docs) {
      final docData = doc.data();
      final managerName = docData['manager']?.toString() ?? 'Unknown';
      uniqueManagerNames.add(managerName);
      managerCounts[managerName] = (managerCounts[managerName] ?? 0) + 1;
      
      // Analyze name fields
      final firstName = docData['firstName']?.toString()?.trim() ?? '';
      final lastName = docData['lastName']?.toString()?.trim() ?? '';
      final displayName = docData['displayName']?.toString()?.trim() ?? '';
      final fullName = docData['fullName']?.toString()?.trim() ?? '';
      final name = docData['name']?.toString()?.trim() ?? '';
      
      bool hasFirstName = firstName.isNotEmpty;
      bool hasLastName = lastName.isNotEmpty;
      bool hasDisplayName = displayName.isNotEmpty;
      bool hasFullName = fullName.isNotEmpty;
      bool hasName = name.isNotEmpty;
      
      if (hasFirstName && hasLastName) {
        completeNames++;
      } else if (hasFirstName || hasLastName || hasDisplayName || hasFullName || hasName) {
        partialNames++;
        nameIssues.add({
          'docId': doc.id,
          'firstName': firstName,
          'lastName': lastName,
          'displayName': displayName,
          'fullName': fullName,
          'name': name,
        });
      } else {
        missingNames++;
      }
    }
    
    print('\n   Name Field Analysis:');
    print('     Complete names (firstName + lastName): $completeNames');
    print('     Partial names (some fields only): $partialNames');
    print('     Missing names (no name fields): $missingNames');
    
    if (nameIssues.isNotEmpty) {
      print('\n   Sample Name Issues (first 5):');
      for (int i = 0; i < nameIssues.length && i < 5; i++) {
        final issue = nameIssues[i];
        print('     Document ${issue['docId']}:');
        print('       firstName: "${issue['firstName']}"');
        print('       lastName: "${issue['lastName']}"');
        print('       displayName: "${issue['displayName']}"');
        print('       fullName: "${issue['fullName']}"');
        print('       name: "${issue['name']}"');
        print('');
      }
    }
    
    print('\n   Unique manager names found:');
    for (final name in uniqueManagerNames) {
      print('     - "$name" (${managerCounts[name]} employees)');
    }
    
    // Step 6: Case sensitivity test
    print('\n6. Testing case sensitivity...');
    final testManagerName = 'Nkosinathi Radebe';
    
    final caseTests = [
      testManagerName,
      testManagerName.toLowerCase(),
      testManagerName.toUpperCase(),
      '  $testManagerName  ', // with extra spaces
      testManagerName.trim(),
    ];
    
    for (final testCase in caseTests) {
      final query = await FirebaseFirestore.instance
          .collection('onboarding')
          .where('manager', isEqualTo: testCase)
          .get();
      
      print('   "$testCase": ${query.docs.length} results');
    }
    
    // Step 7: Recommendations
    print('\n7. Debugging Recommendations:');
    print('   - Check if manager names are stored consistently');
    print('   - Verify case sensitivity in queries');
    print('   - Ensure no extra spaces in manager field');
    print('   - Consider using manager ID instead of name');
    print('   - Add Firestore index for manager field');
    
  } catch (e, stackTrace) {
    print('❌ Debug script error: $e');
    print('Stack trace: $stackTrace');
  }
  
  print('\n=== Debug Complete ===');
}
