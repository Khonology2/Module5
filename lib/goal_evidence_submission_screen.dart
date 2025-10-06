import 'package:flutter/material.dart';
import 'dart:async'; // Required for Future.delayed
import 'package:cloud_firestore/cloud_firestore.dart'; // New: Import Cloud Firestore
import 'package:firebase_auth/firebase_auth.dart'; // New: Import Firebase Auth

// --- 1. Custom Color Definitions (from Dashboard Spec) ---
const Color accentRed = Color(0xFFC10D00); // Primary Accent Color
const Color containerDark = Color(0xFF1F2840); // Main Card/Container Background
const Color tileDark = Color(0xFF2C3E50); // Input/Secondary Tile Background
const Color textLight = Colors.white;
const Color textFaded = Colors.white70; // Corresponds to rgba(255, 255, 255, 0.7)

class SubmissionScreen extends StatefulWidget {
  const SubmissionScreen({super.key});

  @override
  State<SubmissionScreen> createState() => _SubmissionScreenState();
}

class _SubmissionScreenState extends State<SubmissionScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  String? _message;

  // Form field controllers
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _linkController = TextEditingController();
  DateTime? _selectedDate; // New: To store the selected date

  Future<void> _submitEvidence() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedDate == null) {
        setState(() {
          _message = 'Please select a completion date.';
        });
        return;
      }

      setState(() {
        _isSubmitting = true;
        _message = null; // Clear previous messages
      });

      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          setState(() {
            _message = 'User not logged in.';
            _isSubmitting = false;
          });
          return;
        }

        await FirebaseFirestore.instance.collection('goalEvidence').add({
          'userId': user.uid,
          'title': _titleController.text.trim(),
          'description': _descriptionController.text.trim(),
          'evidenceLink': _linkController.text.trim(),
          'completionDate': Timestamp.fromDate(_selectedDate!),
          'submissionDate': FieldValue.serverTimestamp(),
        });

        // Simulate network delay/API call (1.5 seconds) - Removed, as Firestore call is async
        await Future.delayed(const Duration(milliseconds: 500)); // Small delay for UI feedback

        // Simulate successful submission
        setState(() {
          _isSubmitting = false;
          _message = 'Evidence submitted successfully! Great job on completing your goal.';
          
          // Reset form fields
          _titleController.clear();
          _descriptionController.clear();
          _linkController.clear();
          _selectedDate = null; // Clear selected date as well
        });
        
        // In a real app, file upload logic would go here, 
        // but for this UI, we just simulate the success state.
      } catch (e) {
        setState(() {
          _isSubmitting = false;
          _message = 'Failed to submit evidence: ${e.toString()}';
        });
      }
    }
  }

  // --- 2. Input Field Widget Builder ---
  Widget _buildFormInput({
    required String label,
    required TextEditingController controller,
    String? hintText,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    bool required = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4.0),
          child: Text(
            label,
            style: const TextStyle(
                color: textLight, fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: const TextStyle(color: textLight),
          decoration: InputDecoration(
            hintText: hintText,
          ),
          validator: (value) {
            if (required && (value == null || value.isEmpty)) {
              return 'This field is required.';
            }
            return null;
          },
        ),
      ],
    );
  }

  // --- 3. Build the Date Picker Field ---
  Widget _buildDateField() {
    // In a real app, this would use a DateTime variable and showDatePicker
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 4.0),
          child: Text(
            'Date Completed',
            style: TextStyle(
                color: textLight, fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
        GestureDetector(
          onTap: () async {
            DateTime? pickedDate = await showDatePicker(
              context: context,
              initialDate: _selectedDate ?? DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2101),
              builder: (context, child) {
                return Theme(
                  data: ThemeData.dark().copyWith(
                    colorScheme: const ColorScheme.dark(
                      primary: accentRed, // Header background color
                      onPrimary: textLight, // Header text color
                      surface: containerDark, // Calendar background color
                      onSurface: textLight, // Calendar text color
                    ),
                    textButtonTheme: TextButtonThemeData(
                      style: TextButton.styleFrom(
                        foregroundColor: accentRed, // Button text color
                      ),
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (pickedDate != null && pickedDate != _selectedDate) {
              setState(() {
                _selectedDate = pickedDate;
              });
            }
          },
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: tileDark,
              borderRadius: BorderRadius.circular(10.0),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedDate == null
                      ? 'Select date (Required)'
                      : '${_selectedDate!.toLocal().day}/${_selectedDate!.toLocal().month}/${_selectedDate!.toLocal().year}',
                  style: TextStyle(color: _selectedDate == null ? textFaded.withValues(alpha: 127) : textLight),
                ),
                const Icon(Icons.calendar_today, size: 18, color: textFaded),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- 4. Build the File Input Field (Simulated) ---
  Widget _buildFileInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 4.0),
          child: Text(
            'Evidence (Upload File)',
            style: TextStyle(
                color: textLight, fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
        ElevatedButton.icon(
          onPressed: _isSubmitting ? null : () {
            // Simulate file selection action
          },
          icon: const Icon(Icons.upload_file, size: 16, color: accentRed),
          label: const Text('Choose File', style: TextStyle(color: textLight, fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: accentRed.withValues(alpha: 25),
            minimumSize: const Size(double.infinity, 48), // Match height of other inputs
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 4.0),
          child: Text(
            'Accepted formats: Images, PDF, Word documents. Max size: 5MB.',
            style: TextStyle(color: textFaded, fontSize: 10),
          ),
        ),
      ],
    );
  }

  // --- 5. Message Box Widget ---
  Widget _buildMessageBox() {
    if (_message == null) return const SizedBox.shrink();

    // Styled for dark success (green-900/50, text-green-300, border-green-700)
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade900.withValues(alpha: 127),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.shade700),
      ),
      child: Text(
        _message!,
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.green.shade300, fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Removed the Row containing the back button and 'Goal Proof' title
        // Removed the SizedBox below the header
        Center(
          // Removed SingleChildScrollView here as MainLayout already provides one
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600), // Max width for tablet/desktop view
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: containerDark,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: accentRed.withValues(alpha: 38),
                    spreadRadius: 2,
                    blurRadius: 8,
                  ),
                ],
                border: Border.all(color: accentRed.withValues(alpha: 76), width: 1), // Border from spec
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    const Text(
                      'Goal Completion Evidence',
                      style: TextStyle(
                          color: textLight,
                          fontSize: 28,
                          fontWeight: FontWeight.w900),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(top: 4.0, bottom: 24.0),
                      child: Text(
                        'Document your achievement and submit proof of completion.',
                        style: TextStyle(color: textFaded, fontSize: 16),
                      ),
                    ),

                    // Form Fields
                    _buildFormInput(
                        label: 'Goal Title',
                        controller: _titleController,
                        hintText: 'e.g., Complete 5k run in under 30 minutes'),
                    const SizedBox(height: 20),
                    _buildFormInput(
                        label: 'Detailed Outcome / Reflection',
                        controller: _descriptionController,
                        hintText: 'Describe how you achieved the goal and what you learned.',
                        maxLines: 4),
                    const SizedBox(height: 20),
                    _buildDateField(),
                    const SizedBox(height: 20),
                    _buildFileInput(), // Simulated File Upload
                    const SizedBox(height: 20),
                    _buildFormInput(
                        label: 'Evidence Link (Optional)',
                        controller: _linkController,
                        hintText: 'e.g., https://yourblog.com/post-about-goal',
                        required: false,
                        keyboardType: TextInputType.url),
                    const SizedBox(height: 32),

                    // Submit Button
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitEvidence,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentRed,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 4,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: textLight,
                                  strokeWidth: 3,
                                ),
                              )
                            : const Text(
                                'Submit Evidence',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: textLight),
                              ),
                    ),

                    // Message Box
                    _buildMessageBox(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
