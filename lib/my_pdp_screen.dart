import 'package:flutter/material.dart';
// Drawer removed in favor of persistent sidebar

class MyPdpScreen extends StatefulWidget {
  const MyPdpScreen({super.key});

  @override
  State<MyPdpScreen> createState() => _MyPdpScreenState();
}

class _MyPdpScreenState extends State<MyPdpScreen> {
  // State for toggling expansion of sections
  bool _isOperationalExpanded = true;
  bool _isCustomerExpanded = true;
  bool _isFinancialExpanded = true;

  @override
  Widget build(BuildContext context) {
    return FocusScope(
      node: FocusScopeNode(), // Create a new FocusScopeNode
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0), // Adjust padding as needed
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('My Personal Development Plan', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _buildKeyPerformanceArea(
              title: 'Operational Excellence',
              isExpanded: _isOperationalExpanded,
              onToggle: (bool expanded) {
                setState(() {
                  _isOperationalExpanded = expanded;
                });
              },
            ),
            const SizedBox(height: 20),
            _buildKeyPerformanceArea(
              title: 'Customer Excellence',
              isExpanded: _isCustomerExpanded,
              onToggle: (bool expanded) {
                setState(() {
                  _isCustomerExpanded = expanded;
                });
              },
            ),
            const SizedBox(height: 20),
            _buildKeyPerformanceArea(
              title: 'Financial Excellence',
              isExpanded: _isFinancialExpanded,
              onToggle: (bool expanded) {
                setState(() {
                  _isFinancialExpanded = expanded;
                });
              },
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyPerformanceArea({
    required String title,
    required bool isExpanded,
    required ValueChanged<bool> onToggle,
  }) {
    return Material( // Moved Material widget here
      color: Colors.transparent, // Ensure it's transparent
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1F2840), // App's card background color
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            ListTile(
              title: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: const Text(
                'Key Performance Area/Key Performance Indicator',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              trailing: Icon(
                isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                color: Colors.white,
              ),
              onTap: () => onToggle(!isExpanded),
            ),
            if (isExpanded)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSubSection('Goals (3)'),
                    const SizedBox(height: 10),
                    _buildSubSection('Milestones (3)'),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Adding Goal to $title')),
                        );
                      },
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text(
                        'Add Goal',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(
                          0xFFC10D00,
                        ), // App's red color
                        minimumSize: const Size.fromHeight(
                          40,
                        ), // Make button full width
                        shape: const StadiumBorder(), // Changed to StadiumBorder
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Adding Milestone to $title')),
                        );
                      },
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text(
                        'Add Milestone',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(
                          0xFFC10D00,
                        ), // App's red color
                        minimumSize: const Size.fromHeight(
                          40,
                        ), // Make button full width
                        shape: const StadiumBorder(), // Changed to StadiumBorder
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubSection(String text) {
    return Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
        const Icon(
          Icons.keyboard_arrow_down,
          color: Colors.white70,
        ), // Placeholder for actual items
      ],
    );
  }
}
