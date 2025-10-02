// import 'package:flutter/material.dart';
// import 'package:percent_indicator/percent_indicator.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:pdh/design_system/app_colors.dart';
// import 'package:pdh/design_system/app_typography.dart';
// import 'package:pdh/design_system/app_spacing.dart';
// import 'package:pdh/design_system/sidebar_config.dart';
// import 'package:pdh/widgets/app_scaffold.dart';
// import 'package:pdh/auth_service.dart';
// import 'package:pdh/services/database_service.dart';
// import 'package:pdh/services/manager_realtime_service.dart';
// import 'package:pdh/models/user_profile.dart';
// import 'package:pdh/models/goal.dart';

// class ProgressVisualsScreen extends StatefulWidget {
//   final bool embedded;
  
//   const ProgressVisualsScreen({
//     super.key,
//     this.embedded = false,
//   });

//   @override
//   State<ProgressVisualsScreen> createState() => _ProgressVisualsScreenState();
// }

// class _ProgressVisualsScreenState extends State<ProgressVisualsScreen> {
//   UserProfile? userProfile;
//   bool isLoading = true;
//   String? error;

//   @override
//   void initState() {
//     super.initState();
//     _loadUserData();
//   }

//   Future<void> _loadUserData() async {
//     try {
//       setState(() {
//         isLoading = true;
//         error = null;
//       });

//       final user = FirebaseAuth.instance.currentUser;
//       if (user != null) {
//         final profile = await DatabaseService.getUserProfile(user.uid);
        
//         setState(() {
//           userProfile = profile;
//           isLoading = false;
//         });
//       }
//     } catch (e) {
//       setState(() {
//         error = e.toString();
//         isLoading = false;
//       });
//     }
//   }

//   bool get isManager => userProfile?.role == 'manager';

//   Stream<UserProfile?> _getUserProfileStream() {
//     final user = FirebaseAuth.instance.currentUser;
//     if (user == null) return Stream.value(null);
    
//     return FirebaseFirestore.instance
//         .collection('users')
//         .doc(user.uid)
//         .snapshots()
//         .map((doc) {
//       if (!doc.exists) return null;
//       return UserProfile.fromFirestore(doc);
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return AppScaffold(
//       title: 'Progress Visuals',
//       showAppBar: false,
//       embedded: widget.embedded,
//       items: isManager 
//           ? SidebarConfig.getItemsForRole('manager')
//           : SidebarConfig.getItemsForRole('employee'),
//       currentRouteName: '/progress_visuals',
//       onNavigate: (route) {
//         final current = ModalRoute.of(context)?.settings.name;
//         if (current != route) {
//           Navigator.pushNamed(context, route);
//         }
//       },
//       onLogout: () async {
//         final navigator = Navigator.of(context);
//         await AuthService().signOut();
//         if (mounted) {
//           navigator.pushNamedAndRemoveUntil(
//             '/sign_in',
//             (route) => false,
//           );
//         }
//       },
//       content: Container(
//         decoration: BoxDecoration(
//           gradient: LinearGradient(
//             begin: Alignment.topLeft,
//             end: Alignment.bottomRight,
//             colors: [
//               AppColors.backgroundColor,
//               AppColors.backgroundColor.withValues(alpha: 0.8),
//             ],
//           ),
//         ),
//         child: StreamBuilder<UserProfile?>(
//           stream: _getUserProfileStream(),
//           builder: (context, profileSnapshot) {
//             if (profileSnapshot.connectionState == ConnectionState.waiting) {
//               return const Center(
//                 child: CircularProgressIndicator(
//                   valueColor: AlwaysStoppedAnimation<Color>(AppColors.activeColor),
//                 ),
//               );
//             }

//             if (profileSnapshot.hasError) {
//               return Center(
//                 child: Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     Icon(
//                       Icons.error_outline,
//                       size: 64,
//                       color: AppColors.dangerColor,
//                     ),
//                     const SizedBox(height: 16),
//                     Text(
//                       'Error loading user data',
//                       style: AppTypography.heading4,
//                     ),
//                     const SizedBox(height: 8),
//                     Text(
//                       profileSnapshot.error.toString(),
//                       style: AppTypography.bodyMedium.copyWith(
//                         color: AppColors.textSecondary,
//                       ),
//                       textAlign: TextAlign.center,
//                     ),
//                     const SizedBox(height: 16),
//                     ElevatedButton(
//                       onPressed: () {
//                         setState(() {}); 
//                       },
//                       child: const Text('Retry'),
//                     ),
//                   ],
//                 ),
//               );
//             }

//             userProfile = profileSnapshot.data;
            
//             if (userProfile == null) {
//               return const Center(
//                 child: CircularProgressIndicator(
//                   valueColor: AlwaysStoppedAnimation<Color>(AppColors.activeColor),
//                 ),
//               );
//             }
            
//             return RefreshIndicator(
//               onRefresh: () async {
//                 setState(() {}); 
//               },
//               child: isManager 
//                   ? ManagerProgressVisualsContent(userProfile: userProfile!)
//                   : EmployeeProgressVisualsContent(userProfile: userProfile!),
//             );
//           },
//         ),
//       ),
//     );
//   }
// }

// class ManagerProgressVisualsContent extends StatefulWidget {
//   final UserProfile userProfile;

//   const ManagerProgressVisualsContent({
//     super.key,
//     required this.userProfile,
//   });

//   @override
//   State<ManagerProgressVisualsContent> createState() => _ManagerProgressVisualsContentState();
// }

// class _ManagerProgressVisualsContentState extends State<ManagerProgressVisualsContent> {
//   TimeFilter currentTimeFilter = TimeFilter.month;
//   String? selectedDepartment;

//   @override
//   Widget build(BuildContext context) {
//     return SingleChildScrollView(
//       padding: AppSpacing.screenPadding,
//       physics: const AlwaysScrollableScrollPhysics(),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Expanded(
//                 child: Text(
//                   'Team Progress Overview',
//                   style: AppTypography.heading2.copyWith(color: AppColors.textPrimary),
//                 ),
//               ),
//               _buildFilterDropdown(),
//               const SizedBox(width: AppSpacing.md),
//               _buildDepartmentDropdown(),
//             ],
//           ),
//           const SizedBox(height: AppSpacing.xl),
          
//           StreamBuilder<TeamMetrics>(
//             stream: ManagerRealtimeService.getTeamMetricsStream(
//               department: selectedDepartment,
//               timeFilter: currentTimeFilter,
//             ),
//             builder: (context, metricsSnapshot) {
//               if (metricsSnapshot.connectionState == ConnectionState.waiting) {
//                 return const Center(
//                   child: CircularProgressIndicator(
//                     valueColor: AlwaysStoppedAnimation<Color>(AppColors.activeColor),
//                   ),
//                 );
//               }

//               if (metricsSnapshot.hasError) {
//                 return _buildErrorState(metricsSnapshot.error.toString());
//               }

//               final metrics = metricsSnapshot.data;
//               if (metrics == null) {
//                 return _buildNoDataState();
//               }

//               return Column(
//                 children: [
//                   _buildTeamMetricsCards(metrics),
//                   const SizedBox(height: AppSpacing.xxl),
                  
//                   StreamBuilder<List<TeamInsight>>(
//                     stream: ManagerRealtimeService.getTeamInsightsStream(
//                       department: selectedDepartment,
//                       timeFilter: currentTimeFilter,
//                     ),
//                     builder: (context, insightsSnapshot) {
//                       if (insightsSnapshot.hasData && insightsSnapshot.data!.isNotEmpty) {
//                         return Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text(
//                               'Team Insights',
//                               style: AppTypography.heading3.copyWith(color: AppColors.textPrimary),
//                             ),
//                             const SizedBox(height: AppSpacing.md),
//                             ...insightsSnapshot.data!.take(5).map((insight) => 
//                               Padding(
//                                 padding: const EdgeInsets.only(bottom: AppSpacing.sm),
//                                 child: _buildInsightCard(insight),
//                               ),
//                             ),
//                             const SizedBox(height: AppSpacing.xxl),
//                           ],
//                         );
//                       }
//                       return const SizedBox.shrink();
//                     },
//                   ),
                  
//                   Text(
//                     'Team Member Progress',
//                     style: AppTypography.heading3.copyWith(color: AppColors.textPrimary),
//                   ),
//                   const SizedBox(height: AppSpacing.md),
                  
//                   StreamBuilder<List<EmployeeData>>(
//                    stream: ManagerRealtimeService.getTeamDataStream(
//                      department: selectedDepartment,
//                      timeFilter: currentTimeFilter,
//                    ),
//                    builder: (context, teamSnapshot) {
//                      if (teamSnapshot.connectionState == ConnectionState.waiting) {
//                        return const Center(
//                          child: CircularProgressIndicator(
//                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.activeColor),
//                          ),
//                        );
//                      }
 
//                      if (teamSnapshot.hasError) {
//                        return _buildErrorState(teamSnapshot.error.toString());
//                      }
 
//                      final employees = teamSnapshot.data ?? [];
//                      if (employees.isEmpty) {
//                        return _buildNoEmployeesState();
//                      }
 
//                      return Column(
//                        children: employees.map((employee) => 
//                          Padding(
//                            padding: const EdgeInsets.only(bottom: AppSpacing.md),
//                            child: _buildEmployeeCard(employee),
//                          ),
//                        ).toList(),
//                      );
//                    },
//                  ),
//                 ],
//               );
//             },
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildFilterDropdown() {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//       decoration: BoxDecoration(
//         color: AppColors.elevatedBackground,
//         borderRadius: BorderRadius.circular(8),
//         border: Border.all(color: AppColors.borderColor),
//       ),
//       child: DropdownButton<TimeFilter>(
//         value: currentTimeFilter,
//         underline: const SizedBox(),
//         style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
//         onChanged: (TimeFilter? filter) {
//           if (filter != null) {
//             setState(() {
//               currentTimeFilter = filter;
//             });
//           }
//         },
//         items: TimeFilter.values.map((filter) {
//           return DropdownMenuItem<TimeFilter>(
//             value: filter,
//             child: Text(filter.name.toUpperCase()),
//           );
//         }).toList(),
//       ),
//     );
//   }

//   Widget _buildDepartmentDropdown() {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//       decoration: BoxDecoration(
//         color: AppColors.elevatedBackground,
//         borderRadius: BorderRadius.circular(8),
//         border: Border.all(color: AppColors.borderColor),
//       ),
//       child: DropdownButton<String?>(
//         value: selectedDepartment,
//         underline: const SizedBox(),
//         style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
//         hint: Text('All Departments', style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary)),
//         onChanged: (String? department) {
//           setState(() {
//             selectedDepartment = department;
//           });
//         },
//         items: [
//           DropdownMenuItem<String?>(
//             value: null,
//             child: Text('All Departments'),
//           ),
//           DropdownMenuItem<String?>(
//             value: widget.userProfile.department,
//             child: Text(widget.userProfile.department.isEmpty ? 'Department' : widget.userProfile.department),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildTeamMetricsCards(TeamMetrics metrics) {
//     return Column(
//       children: [
//         Row(
//           children: [
//             Expanded(
//               child: _buildMetricCard(
//                 title: 'Team Members',
//                 value: metrics.totalEmployees.toString(),
//                 icon: Icons.people_outline,
//                 color: AppColors.activeColor,
//                 subtitle: '${metrics.activeEmployees} active',
//               ),
//             ),
//             const SizedBox(width: AppSpacing.md),
//             Expanded(
//               child: _buildMetricCard(
//                 title: 'Average Progress',
//                 value: '${metrics.avgTeamProgress.toStringAsFixed(1)}%',
//                 icon: Icons.trending_up,
//                 color: metrics.avgTeamProgress >= 70 ? AppColors.successColor : 
//                        metrics.avgTeamProgress >= 40 ? AppColors.warningColor : AppColors.dangerColor,
//                 subtitle: 'Team average',
//               ),
//             ),
//           ],
//         ),
//         const SizedBox(height: AppSpacing.md),
//         Row(
//           children: [
//             Expanded(
//               child: _buildMetricCard(
//                 title: 'Goals Completed',
//                 value: metrics.goalsCompleted.toString(),
//                 icon: Icons.check_circle_outline,
//                 color: AppColors.successColor,
//                 subtitle: 'This period',
//               ),
//             ),
//             const SizedBox(width: AppSpacing.md),
//             Expanded(
//               child: _buildMetricCard(
//                 title: 'Overdue Goals',
//                 value: metrics.overdueGoals.toString(),
//                 icon: Icons.warning_outlined,
//                 color: AppColors.dangerColor,
//                 subtitle: 'Needs attention',
//               ),
//             ),
//           ],
//         ),
//         const SizedBox(height: AppSpacing.md),
//         _buildMetricCard(
//           title: 'Team Engagement',
//           value: '${metrics.teamEngagement.toStringAsFixed(1)}%',
//           icon: Icons.groups,
//           color: metrics.teamEngagement >= 70 ? AppColors.successColor : 
//                  metrics.teamEngagement >= 40 ? AppColors.warningColor : AppColors.dangerColor,
//           subtitle: 'Active in last 7 days',
//           fullWidth: true,
//         ),
//       ],
//     );
//   }

//   Widget _buildMetricCard({
//     required String title,
//     required String value,
//     required IconData icon,
//     required Color color,
//     String? subtitle,
//     bool fullWidth = false,
//   }) {
//     return Container(
//       width: fullWidth ? double.infinity : null,
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: AppColors.elevatedBackground,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: AppColors.borderColor),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Icon(icon, color: color, size: 24),
//               const SizedBox(width: 8),
//               Expanded(
//                 child: Text(
//                   title,
//                   style: AppTypography.bodyMedium.copyWith(
//                     color: AppColors.textSecondary,
//                     fontWeight: FontWeight.w500,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 12),
//           Text(
//             value,
//             style: AppTypography.heading3.copyWith(
//               color: AppColors.textPrimary,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//           if (subtitle != null) ...[
//             const SizedBox(height: 4),
//             Text(
//               subtitle,
//               style: AppTypography.bodySmall.copyWith(
//                 color: AppColors.textSecondary,
//               ),
//             ),
//           ],
//         ],
//       ),
//     );
//   }

//   Widget _buildInsightCard(TeamInsight insight) {
//     Color priorityColor;
//     IconData priorityIcon;
    
//     switch (insight.priority) {
//       case InsightPriority.urgent:
//         priorityColor = AppColors.dangerColor;
//         priorityIcon = Icons.priority_high;
//         break;
//       case InsightPriority.high:
//         priorityColor = AppColors.warningColor;
//         priorityIcon = Icons.warning;
//         break;
//       case InsightPriority.medium:
//         priorityColor = AppColors.infoColor;
//         priorityIcon = Icons.info_outline;
//         break;
//       case InsightPriority.low:
//         priorityColor = AppColors.successColor;
//         priorityIcon = Icons.check_circle_outline;
//         break;
//     }

//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: AppColors.elevatedBackground,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: priorityColor.withValues(alpha: 0.3)),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Icon(priorityIcon, color: priorityColor, size: 20),
//               const SizedBox(width: 8),
//               Expanded(
//                 child: Text(
//                   insight.title,
//                   style: AppTypography.bodyMedium.copyWith(
//                     color: AppColors.textPrimary,
//                     fontWeight: FontWeight.w600,
//                   ),
//                 ),
//               ),
//               Text(
//                 insight.priority.name.toUpperCase(),
//                 style: AppTypography.bodySmall.copyWith(
//                   color: priorityColor,
//                   fontWeight: FontWeight.w600,
//                   fontSize: 10,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 8),
//           Text(
//             insight.description,
//             style: AppTypography.bodyMedium.copyWith(
//               color: AppColors.textSecondary,
//             ),
//           ),
//           const SizedBox(height: 8),
//           Container(
//             padding: const EdgeInsets.all(8),
//             decoration: BoxDecoration(
//               color: priorityColor.withValues(alpha: 0.1),
//               borderRadius: BorderRadius.circular(6),
//             ),
//             child: Row(
//               children: [
//                 Icon(
//                   Icons.lightbulb_outline,
//                   color: priorityColor,
//                   size: 16,
//                 ),
//                 const SizedBox(width: 6),
//                 Expanded(
//                   child: Text(
//                     insight.actionRequired,
//                     style: AppTypography.bodySmall.copyWith(
//                       color: priorityColor,
//                       fontWeight: FontWeight.w500,
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           if (insight.priority == InsightPriority.urgent || insight.priority == InsightPriority.high) ...[
//             const SizedBox(height: 12),
//             Row(
//               children: [
//                 Expanded(
//                   child: ElevatedButton.icon(
//                     onPressed: () => _sendNudgeToEmployee(insight.employeeName),
//                     icon: const Icon(Icons.send, size: 16),
//                     label: const Text('Send Nudge'),
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: priorityColor,
//                       foregroundColor: Colors.white,
//                       padding: const EdgeInsets.symmetric(vertical: 8),
//                     ),
//                   ),
//                 ),
//                 const SizedBox(width: 8),
//                 OutlinedButton.icon(
//                   onPressed: () => _scheduleMeeting(insight.employeeName),
//                   icon: const Icon(Icons.calendar_today, size: 16),
//                   label: const Text('Meet'),
//                   style: OutlinedButton.styleFrom(
//                     foregroundColor: priorityColor,
//                     side: BorderSide(color: priorityColor),
//                     padding: const EdgeInsets.symmetric(vertical: 8),
//                   ),
//                 ),
//               ],
//             ),
//           ],
//         ],
//       ),
//     );
//   }

//   Widget _buildEmployeeCard(EmployeeData employee) {
//     Color statusColor;
//     IconData statusIcon;
//     String statusText;

//     switch (employee.status) {
//       case EmployeeStatus.onTrack:
//         statusColor = AppColors.successColor;
//         statusIcon = Icons.check_circle;
//         statusText = 'On Track';
//         break;
//       case EmployeeStatus.atRisk:
//         statusColor = AppColors.warningColor;
//         statusIcon = Icons.warning;
//         statusText = 'At Risk';
//         break;
//       case EmployeeStatus.overdue:
//         statusColor = AppColors.dangerColor;
//         statusIcon = Icons.error_outline;
//         statusText = 'Overdue';
//         break;
//       case EmployeeStatus.inactive:
//         statusColor = AppColors.textSecondary;
//         statusIcon = Icons.pause_circle_outline;
//         statusText = 'Inactive';
//         break;
//     }

//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: AppColors.elevatedBackground,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: statusColor.withValues(alpha: 0.3)),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               CircleAvatar(
//                 radius: 20,
//                 backgroundColor: statusColor.withValues(alpha: 0.1),
//                 child: Text(
//                   employee.profile.displayName.isNotEmpty 
//                       ? employee.profile.displayName[0].toUpperCase()
//                       : '?',
//                   style: AppTypography.bodyMedium.copyWith(
//                     color: statusColor,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//               ),
//               const SizedBox(width: 12),
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       employee.profile.displayName,
//                       style: AppTypography.bodyMedium.copyWith(
//                         color: AppColors.textPrimary,
//                         fontWeight: FontWeight.w600,
//                       ),
//                     ),
//                     Text(
//                       employee.profile.jobTitle.isNotEmpty 
//                           ? employee.profile.jobTitle
//                           : employee.profile.department,
//                       style: AppTypography.bodySmall.copyWith(
//                         color: AppColors.textSecondary,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                 decoration: BoxDecoration(
//                   color: statusColor.withValues(alpha: 0.1),
//                   borderRadius: BorderRadius.circular(12),
//                   border: Border.all(color: statusColor.withValues(alpha: 0.3)),
//                 ),
//                 child: Row(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     Icon(statusIcon, color: statusColor, size: 14),
//                     const SizedBox(width: 4),
//                     Text(
//                       statusText,
//                       style: AppTypography.bodySmall.copyWith(
//                         color: statusColor,
//                         fontWeight: FontWeight.w600,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 16),
          
//           Row(
//             children: [
//               Expanded(
//                 child: _buildEmployeeMetricChip(
//                   icon: Icons.track_changes,
//                   label: 'Active Goals',
//                   value: employee.goals.where((g) => g.status != GoalStatus.completed).length.toString(),
//                   color: AppColors.activeColor,
//                 ),
//               ),
//               const SizedBox(width: 8),
//               Expanded(
//                 child: _buildEmployeeMetricChip(
//                   icon: Icons.check_circle_outline,
//                   label: 'Completed',
//                   value: employee.completedGoalsCount.toString(),
//                   color: AppColors.successColor,
//                 ),
//               ),
//               const SizedBox(width: 8),
//               Expanded(
//                 child: _buildEmployeeMetricChip(
//                   icon: Icons.access_time,
//                   label: 'Progress',
//                   value: '${employee.avgProgress.toStringAsFixed(1)}%',
//                   color: employee.avgProgress >= 70 ? AppColors.successColor : 
//                          employee.avgProgress >= 40 ? AppColors.warningColor : AppColors.dangerColor,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 12),
          
//           if (employee.goals.isNotEmpty) ...[
//             Text(
//               'Goals',
//               style: AppTypography.bodySmall.copyWith(
//                 color: AppColors.textSecondary,
//                 fontWeight: FontWeight.w500,
//               ),
//             ),
//             const SizedBox(height: 8),
//             ...employee.goals.take(3).map((goal) => Padding(
//               padding: const EdgeInsets.only(bottom: 4),
//               child: _buildGoalRow(goal),
//             )),
//             if (employee.goals.length > 3)
//               Padding(
//                 padding: const EdgeInsets.only(top: 4),
//                 child: Text(
//                   '+${employee.goals.length - 3} more goals',
//                   style: AppTypography.bodySmall.copyWith(
//                     color: AppColors.activeColor,
//                     fontWeight: FontWeight.w500,
//                   ),
//                 ),
//               ),
//           ] else ...[
//             Container(
//               padding: const EdgeInsets.all(12),
//               decoration: BoxDecoration(
//                 color: AppColors.textSecondary.withValues(alpha: 0.05),
//                 borderRadius: BorderRadius.circular(8),
//               ),
//               child: Row(
//                 children: [
//                   Icon(
//                     Icons.info_outline,
//                     color: AppColors.textSecondary,
//                     size: 16,
//                   ),
//                   const SizedBox(width: 8),
//                   Text(
//                     'No goals yet',
//                     style: AppTypography.bodySmall.copyWith(
//                       color: AppColors.textSecondary,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ],
          
//           const SizedBox(height: 16),
          
//           Row(
//             children: [
//               Expanded(
//                 child: OutlinedButton.icon(
//                   onPressed: () => _viewEmployeeDetails(employee),
//                   icon: const Icon(Icons.person_outline, size: 16),
//                   label: const Text('View Details'),
//                   style: OutlinedButton.styleFrom(
//                     foregroundColor: AppColors.activeColor,
//                     side: BorderSide(color: AppColors.activeColor),
//                   ),
//                 ),
//               ),
//               const SizedBox(width: 8),
//               Expanded(
//                 child: ElevatedButton.icon(
//                   onPressed: () => _sendNudgeToEmployee(employee.profile.displayName),
//                   icon: const Icon(Icons.send, size: 16),
//                   label: const Text('Send Nudge'),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: AppColors.activeColor,
//                     foregroundColor: Colors.white,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildEmployeeMetricChip({
//     required IconData icon,
//     required String label,
//     required String value,
//     required Color color,
//   }) {
//     return Container(
//       padding: const EdgeInsets.all(8),
//       decoration: BoxDecoration(
//         color: color.withValues(alpha: 0.1),
//         borderRadius: BorderRadius.circular(8),
//         border: Border.all(color: color.withValues(alpha: 0.3)),
//       ),
//       child: Column(
//         children: [
//           Icon(icon, color: color, size: 16),
//           const SizedBox(height: 4),
//           Text(
//             value,
//             style: AppTypography.bodySmall.copyWith(
//               color: color,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//           Text(
//             label,
//             style: AppTypography.bodySmall.copyWith(
//               color: AppColors.textSecondary,
//               fontSize: 10,
//             ),
//             textAlign: TextAlign.center,
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildGoalRow(Goal goal) {
//     Color priorityColor = _getPriorityColor(goal.priority);
    
//     return Container(
//       padding: const EdgeInsets.all(8),
//       decoration: BoxDecoration(
//         color: AppColors.textSecondary.withValues(alpha: 0.05),
//         borderRadius: BorderRadius.circular(6),
//       ),
//       child: Row(
//         children: [
//           Container(
//             width: 8,
//             height: 8,
//             decoration: BoxDecoration(
//               color: priorityColor,
//               shape: BoxShape.circle,
//             ),
//           ),
//           const SizedBox(width: 8),
//           Expanded(
//             child: Text(
//               goal.title,
//               style: AppTypography.bodySmall.copyWith(
//                 color: AppColors.textPrimary,
//               ),
//               maxLines: 1,
//               overflow: TextOverflow.ellipsis,
//             ),
//           ),
//           const SizedBox(width: 8),
//           Flexible(
//             child: LinearProgressIndicator(
//               value: goal.progress / 100.0,
//               backgroundColor: AppColors.borderColor,
//               valueColor: AlwaysStoppedAnimation<Color>(priorityColor),
//               minHeight: 4,
//             ),
//           ),
//           const SizedBox(width: 8),
//           Text(
//             '${goal.progress}%',
//             style: AppTypography.bodySmall.copyWith(
//               color: AppColors.textSecondary,
//               fontWeight: FontWeight.w600,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Color _getPriorityColor(GoalPriority priority) {
//     switch (priority) {
//       case GoalPriority.high:
//         return AppColors.dangerColor;
//       case GoalPriority.medium:
//         return AppColors.warningColor;
//       case GoalPriority.low:
//         return AppColors.successColor;
//     }
//   }

//   Widget _buildErrorState(String error) {
//     return Container(
//       padding: const EdgeInsets.all(32),
//       decoration: BoxDecoration(
//         color: AppColors.elevatedBackground,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: AppColors.borderColor),
//       ),
//       child: Column(
//         children: [
//           Icon(
//             Icons.error_outline,
//             size: 48,
//             color: AppColors.dangerColor,
//           ),
//           const SizedBox(height: 16),
//           Text(
//             'Error loading team data',
//             style: AppTypography.heading4.copyWith(
//               color: AppColors.textPrimary,
//             ),
//           ),
//           const SizedBox(height: 8),
//           Text(
//             error,
//             style: AppTypography.bodyMedium.copyWith(
//               color: AppColors.textSecondary,
//             ),
//             textAlign: TextAlign.center,
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildNoDataState() {
//     return Container(
//       padding: const EdgeInsets.all(32),
//       decoration: BoxDecoration(
//         color: AppColors.elevatedBackground,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: AppColors.borderColor),
//       ),
//       child: Column(
//         children: [
//           Icon(
//             Icons.people_outline,
//             size: 48,
//             color: AppColors.textSecondary,
//           ),
//           const SizedBox(height: 16),
//           Text(
//             'No team data available',
//             style: AppTypography.heading4.copyWith(
//               color: AppColors.textPrimary,
//             ),
//           ),
//           const SizedBox(height: 8),
//           Text(
//             'Team metrics and insights will appear here once employees start using the system.',
//             style: AppTypography.bodyMedium.copyWith(
//               color: AppColors.textSecondary,
//             ),
//             textAlign: TextAlign.center,
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildNoEmployeesState() {
//     return Container(
//       padding: const EdgeInsets.all(32),
//       decoration: BoxDecoration(
//         color: AppColors.elevatedBackground,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: AppColors.borderColor),
//       ),
//       child: Column(
//         children: [
//           Icon(
//             Icons.groups_outlined,
//             size: 48,
//             color: AppColors.textSecondary,
//           ),
//           const SizedBox(height: 16),
//           Text(
//             'No team members found',
//             style: AppTypography.heading4.copyWith(
//               color: AppColors.textPrimary,
//             ),
//           ),
//           const SizedBox(height: 8),
//           Text(
//             'Make sure your team members have been added to your department or check your filter settings.',
//             style: AppTypography.bodyMedium.copyWith(
//               color: AppColors.textSecondary,
//             ),
//             textAlign: TextAlign.center,
//           ),
//         ],
//       ),
//     );
//   }

//   void _sendNudgeToEmployee(String employeeName) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text('Nudge sent to $employeeName'),
//         backgroundColor: AppColors.activeColor,
//       ),
//     );
//   }

//   void _scheduleMeeting(String employeeName) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Schedule Meeting'),
//         content: Text('Schedule a 1:1 meeting with $employeeName'),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text('Cancel'),
//           ),
//           ElevatedButton(
//             onPressed: () {
//               Navigator.pop(context);
//               ScaffoldMessenger.of(context).showSnackBar(
//                 SnackBar(
//                   content: Text('Meeting scheduled with $employeeName'),
//                   backgroundColor: AppColors.activeColor,
//                 ),
//               );
//             },
//             child: const Text('Schedule'),
//           ),
//         ],
//       ),
//     );
//   }

//   void _viewEmployeeDetails(EmployeeData employee) {
//     Navigator.pushNamed(context, '/employee_profile', arguments: employee.profile.uid);
//   }
// }

// class EmployeeProgressVisualsContent extends StatelessWidget {
//   final UserProfile userProfile;

//   const EmployeeProgressVisualsContent({
//     super.key,
//     required this.userProfile,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return SingleChildScrollView(
//       padding: AppSpacing.screenPadding,
//       physics: const AlwaysScrollableScrollPhysics(),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             'Your Progress Overview',
//             style: AppTypography.heading2.copyWith(color: AppColors.textPrimary),
//           ),
//           const SizedBox(height: AppSpacing.xl),
          
//           StreamBuilder<List<Goal>>(
//             stream: _getUserGoalsStream(),
//             builder: (context, snapshot) {
//               if (snapshot.connectionState == ConnectionState.waiting) {
//                 return const Center(
//                   child: CircularProgressIndicator(
//                     valueColor: AlwaysStoppedAnimation<Color>(AppColors.activeColor),
//                   ),
//                 );
//               }

//               if (snapshot.hasError) {
//                 return _buildErrorState(snapshot.error.toString());
//               }

//               final goals = snapshot.data ?? [];
              
//               return Column(
//                 children: [
//                   _buildPersonalOverview(goals),
//                   const SizedBox(height: AppSpacing.xxl),
//                   _buildGoalsProgress(context, goals),
//                 ],
//               );
//             },
//           ),
//         ],
//       ),
//     );
//   }

//   Stream<List<Goal>> _getUserGoalsStream() {
//     final user = FirebaseAuth.instance.currentUser;
//     if (user == null) return Stream.value([]);
    
//     return FirebaseFirestore.instance
//         .collection('goals')
//         .where('userId', isEqualTo: user.uid)
//         .snapshots()
//         .map((snapshot) {
//       final goals = snapshot.docs.map((doc) {
//         final .data();
//         return Goal(
//           id: doc.id,
//           userId: data['userId'] ?? user.uid,
//           title: data['title'] ?? '',
//           description: data['description'] ?? '',
//           category: GoalCategory.values.firstWhere(
//               (e) => e.name == (data['category'] ?? 'personal'),
//               orElse: () => GoalCategory.personal,
//           ),
//           priority: GoalPriority.values.firstWhere(
//               (e) => e.name == (data['Priority'] ?? 'medium'),
//               orElse: () => GoalPriority.medium,
//           ),
//           status: GoalStatus.values.firstWhere(
//               (e) => e.name == (data['status'] ?? 'notStarted'),
//               orElse: () => GoalStatus.notStarted,
//           ),
//           progress: (data['progress'] ?? 0) as int,
//           createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
//           targetDate: (data['targetDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
//           points: (data['points'] ?? 0) as int,
//         );
//       }).toList();
      
//       goals.sort((a, b) => b.createdAt.compareTo(a.createdAt));
//       return goals;
//     });
//   }

//   Widget _buildPersonalOverview(List<Goal> goals) {
//     final totalGoals = goals.length;
//     final completedGoals = goals.where((goal) => goal.status == GoalStatus.completed).length;
//     final activeGoals = goals.where((goal) => goal.status == GoalStatus.inProgress).length;
//     final overallProgress = totalGoals > 0 ? (completedGoals / totalGoals) : 0.0;
    
//     return Row(
//       children: [
//         Expanded(
//           child: _buildOverviewCard(
//             title: 'Completion Rate',
//             value: '${(overallProgress * 100).toInt()}%',
//             progress: overallProgress,
//             color: AppColors.successColor,
//             icon: Icons.check_circle_outline,
//           ),
//         ),
//         const SizedBox(width: AppSpacing.md),
//         Expanded(
//           child: _buildOverviewCard(
//             title: 'Active Goals',
//             value: activeGoals.toString(),
//             progress: totalGoals > 0 ? (activeGoals / totalGoals) : 0.0,
//             color: AppColors.activeColor,
//             icon: Icons.track_changes,
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildOverviewCard({
//     required String title,
//     required String value,
//     required double progress,
//     required Color color,
//     required IconData icon,
//   }) {
//     return Container(
//       height: 120,
//       decoration: BoxDecoration(
//         color: AppColors.elevatedBackground,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: AppColors.borderColor),
//       ),
//       padding: const EdgeInsets.all(16.0),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Icon(icon, color: color, size: 20),
//               const SizedBox(width: 8),
//               Text(
//                 title,
//                 style: AppTypography.bodySmall.copyWith(
//                   color: AppColors.textSecondary,
//                 ),
//               ),
//             ],
//           ),
//           const Spacer(),
//           Text(
//             value,
//             style: AppTypography.heading4.copyWith(
//               color: AppColors.textPrimary,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//           const SizedBox(height: 8),
//           LinearProgressIndicator(
//             value: progress.clamp(0.0, 1.0),
//             backgroundColor: AppColors.borderColor,
//             valueColor: AlwaysStoppedAnimation<Color>(color),
//             minHeight: 4,
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildGoalsProgress(BuildContext context, List<Goal> goals) {
//     final activeGoals = goals
//         .where((goal) => goal.status != GoalStatus.completed)
//         .toList()
//       ..sort((a, b) => a.targetDate.compareTo(b.targetDate));

//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Row(
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: [
//             Text(
//               'Your Goals Progress',
//               style: AppTypography.heading3.copyWith(color: AppColors.textPrimary),
//             ),
//             if (activeGoals.isNotEmpty)
//               TextButton.icon(
//                 onPressed: () {
//                   Navigator.pushNamed(context, '/my_goal_workspace');
//                 },
//                 icon: Icon(Icons.add, color: AppColors.activeColor, size: 18),
//                 label: Text(
//                   'Add Goal',
//                   style: AppTypography.bodySmall.copyWith(
//                     color: AppColors.activeColor,
//                   ),
//                 ),
//               ),
//           ],
//         ),
//         const SizedBox(height: AppSpacing.md),
//         if (activeGoals.isEmpty)
//           _buildEmptyGoalsState(context)
//         else
//           ...activeGoals.take(5).map((goal) => Padding(
//             padding: const EdgeInsets.only(bottom: AppSpacing.md),
//             child: _buildGoalProgressCard(context, goal: goal),
//           )),
//       ],
//     );
//   }

//   Widget _buildEmptyGoalsState(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.all(32),
//       decoration: BoxDecoration(
//         color: AppColors.elevatedBackground,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: AppColors.borderColor),
//       ),
//       child: Column(
//         children: [
//           Icon(
//             Icons.flag_outlined,
//             size: 48,
//             color: AppColors.textSecondary,
//           ),
//           const SizedBox(height: 16),
//           Text(
//             'No Active Goals',
//             style: AppTypography.heading4.copyWith(
//               color: AppColors.textPrimary,
//             ),
//           ),
//           const SizedBox(height: 8),
//           Text(
//             'Create your first goal to start tracking your progress!',
//             style: AppTypography.bodyMedium.copyWith(
//               color: AppColors.textSecondary,
//             ),
//             textAlign: TextAlign.center,
//           ),
//           const SizedBox(height: 16),
//           ElevatedButton.icon(
//             onPressed: () {
//               Navigator.pushNamed(context, '/my_goal_workspace');
//             },
//             icon: const Icon(Icons.add),
//             label: const Text('Create Goal'),
//             style: ElevatedButton.styleFrom(
//               backgroundColor: AppColors.activeColor,
//               foregroundColor: AppColors.textPrimary,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildGoalProgressCard(BuildContext context, {required Goal goal}) {
//     final now = DateTime.now();
//     final daysUntilDeadline = goal.targetDate.difference(now).inDays;
//     final progress = goal.progress / 100.0;
    
//     String deadlineText;
//     Color deadlineColor;
    
//     if (daysUntilDeadline < 0) {
//       deadlineText = 'Overdue by ${(-daysUntilDeadline)} day${(-daysUntilDeadline) == 1 ? '' : 's'}';
//       deadlineColor = AppColors.dangerColor;
//     } else if (daysUntilDeadline == 0) {
//       deadlineText = 'Due today';
//       deadlineColor = AppColors.warningColor;
//     } else if (daysUntilDeadline <= 7) {
//       deadlineText = 'Due in $daysUntilDeadline day${daysUntilDeadline == 1 ? '' : 's'}';

//     } else {
//       deadlineText = 'Due in $daysUntilDeadline days';
//       deadlineColor = AppColors.textSecondary;
//     }

//     Color progressColor = _getPriorityColor(goal.priority);

//     return Container(
//       padding: const EdgeInsets.all(16.0),
//       decoration: BoxDecoration(
//         color: AppColors.elevatedBackground,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: AppColors.borderColor),
//       ),
//       child: Row(
//         children: [
//           CircularPercentIndicator(
//             radius: 30.0,
//             lineWidth: 6.0,
//             percent: progress.clamp(0.0, 1.0),
//             center: Text(
//               "${goal.progress}%",
//               style: AppTypography.bodySmall.copyWith(
//                 color: AppColors.textSecondary,
//                 fontWeight: FontWeight.w600,
//               ),
//             ),
//             progressColor: progressColor,
// )
