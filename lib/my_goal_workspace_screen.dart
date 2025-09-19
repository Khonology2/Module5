import 'package:flutter/material.dart';
import 'dart:ui'; // Import for ImageFilter
import 'package:pdh/employee_drawer.dart'; // Import the EmployeeDrawer

class MyGoalWorkspaceScreen extends StatefulWidget {
  const MyGoalWorkspaceScreen({super.key});

  @override
  State<MyGoalWorkspaceScreen> createState() => _MyGoalWorkspaceScreenState();
}

class _MyGoalWorkspaceScreenState extends State<MyGoalWorkspaceScreen> {
  // Checkbox states for SMART criteria
  bool _isSpecific = false;
  bool _isMeasurable = false;
  bool _isAchievable = false;
  bool _isRelevant = false;
  bool _isTimeBound = false;

  // Controllers for text fields
  final _goalTitleController = TextEditingController();
  final _goalDescriptionController = TextEditingController();
  final _dependenciesController = TextEditingController();
  final _successMetricsController = TextEditingController();

  // Date variables
  DateTime? _startDate;
  DateTime? _targetDate;

  // Dropdown selected values
  String? _goalCategory;
  String? _currentStatus;

  // Lists for dropdowns
  final List<String> _goalCategories = ['Career', 'Skills', 'Wellness', 'Finance', 'Other'];
  final List<String> _currentStatuses = ['In Progress', 'On Track', 'At Risk', 'Completed'];

  Future<void> _selectDate(BuildContext context, {required bool isStartDate}) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF00C853), // App's green color
              onPrimary: Colors.white,
              surface: Color(0xFF1F2840), // App's card background
              onSurface: Colors.white,
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: Color(0xFF0A1931), // App's background
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _targetDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Set Scaffold background to transparent
      extendBodyBehindAppBar: true, // Extend the body behind the AppBar
      appBar: AppBar(
        title: const Text(
          'Personal Development Goal',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent, // Make AppBar transparent
        elevation: 0, // Remove AppBar shadow
        actions: [
          IconButton(
            icon: const Icon(Icons.apps, color: Colors.white),
            onPressed: () {
              // Handle menu action
            },
          ),
        ],
      ),
      drawer: const EmployeeDrawer(), // Use the EmployeeDrawer widget
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/hillyxyz_Generate_a_background_image_for_a_personal_development_app._Theme_7058e6a9-bc4e-49a4-836d-7344ed124d1f.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0), // Apply stronger blur effect
              child: Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.2,
                    colors: [
                      Color(0x880A0F1F), // More opaque semi-transparent overlay (alpha 0x88)
                      Color(0x88040610), // More opaque semi-transparent overlay (alpha 0x88)
                    ],
                    stops: [0.0, 1.0],
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 100, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader('Goal Information'),
                      _buildTextField(
                        controller: _goalTitleController,
                        hintText: 'Enter your development goal title',
                      ),
                      _buildTextField(
                        controller: _goalDescriptionController,
                        hintText: 'Describe your goal in detail...',
                        maxLines: 5,
                      ),
                      const SizedBox(height: 20),
                      _buildSectionHeader('Goal Details'),
                      Row(
                        children: [
                          Expanded(child: _buildDateInput(context, 'Start Date', _startDate, isStartDate: true)),
                          const SizedBox(width: 10),
                          Expanded(child: _buildDateInput(context, 'Target Date', _targetDate, isStartDate: false)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _buildDropdownField(
                        hintText: 'Select category',
                        value: _goalCategory,
                        items: _goalCategories,
                        onChanged: (String? newValue) {
                          setState(() {
                            _goalCategory = newValue;
                          });
                        },
                      ),
                      _buildDropdownField(
                        hintText: 'Select status',
                        value: _currentStatus,
                        items: _currentStatuses,
                        onChanged: (String? newValue) {
                          setState(() {
                            _currentStatus = newValue;
                          });
                        },
                      ),
                      const SizedBox(height: 20),
                      _buildSmartCriteriaSection(),
                      const SizedBox(height: 20),
                      _buildSectionHeader('Dependencies & Prerequisites'),
                      _buildTextField(
                        controller: _dependenciesController,
                        hintText: 'List any dependencies or prerequisites needed to achieve this goal\n\ne.g., Complete certification course, Save \$5000, Learn specific skills...',
                        maxLines: 4,
                      ),
                      const SizedBox(height: 20),
                      _buildSectionHeader('Success Metrics'),
                      _buildTextField(
                        controller: _successMetricsController,
                        hintText: 'Define specific metrics or milestones...',
                        maxLines: 4,
                      ),
                      const SizedBox(height: 40),
                      _buildActionButtons(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    int maxLines = 1,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2840), // App's card background color
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.white70.withValues(alpha: 0.5)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  Widget _buildDateInput(BuildContext context, String hintText, DateTime? date, {required bool isStartDate}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2840), // App's card background color
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            date != null ? '${date.day}/${date.month}/${date.year}' : hintText,
            style: TextStyle(
              color: date != null ? Colors.white : Colors.white70.withValues(alpha: 0.5),
            ),
          ),
          GestureDetector(
            onTap: () => _selectDate(context, isStartDate: isStartDate),
            child: const Icon(Icons.calendar_today, color: Colors.white70, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownField({
    required String hintText,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2840), // App's card background color
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        dropdownColor: const Color(0xFF1F2840), // App's card background color
        style: const TextStyle(color: Colors.white, fontSize: 16),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.white70.withValues(alpha: 0.5)),
          border: InputBorder.none,
        ),
        icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
        onChanged: onChanged,
        items: items.map<DropdownMenuItem<String>>((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSmartCriteriaSection() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF00C853).withValues(alpha: 0.2), // App's green color with transparency
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF00C853).withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.lightbulb_outline, color: Color(0xFF00C853), size: 20), // App's green color
              SizedBox(width: 10),
              Text(
                'SMART Criteria Verification',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildSmartCheckbox('Specific - Goal is clear and well-defined', _isSpecific, (value) {
            setState(() => _isSpecific = value!);
          }),
          _buildSmartCheckbox('Measurable - Progress can be tracked', _isMeasurable, (value) {
            setState(() => _isMeasurable = value!);
          }),
          _buildSmartCheckbox('Achievable - Goal is realistic and attainable', _isAchievable, (value) {
            setState(() => _isAchievable = value!);
          }),
          _buildSmartCheckbox('Relevant - Goal aligns with your values', _isRelevant, (value) {
            setState(() => _isRelevant = value!);
          }),
          _buildSmartCheckbox('Time-bound - Goal has a clear deadline', _isTimeBound, (value) {
            setState(() => _isTimeBound = value!);
          }),
        ],
      ),
    );
  }

  Widget _buildSmartCheckbox(String title, bool value, ValueChanged<bool?> onChanged) {
    return Theme(
      data: ThemeData(
        unselectedWidgetColor: Colors.white70,
      ),
      child: CheckboxListTile(
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFF00C853), // App's green color
        checkColor: Colors.white,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              // Handle "Back to Dashboard"
              Navigator.pop(context);
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white70),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Back to Dashboard'),
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              // Handle "Save Goal"
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Goal saved!')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C853), // App's green color
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Save Goal'),
          ),
        ),
      ],
    );
  }
}