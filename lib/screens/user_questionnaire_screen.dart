import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/user_profile_model.dart';
import '../services/recommendation_service.dart';
import '../services/firebase_firestore_service.dart';
import 'scheme_results_screen.dart';

class UserQuestionnaireScreen extends StatefulWidget {
  const UserQuestionnaireScreen({super.key});

  @override
  State<UserQuestionnaireScreen> createState() => _UserQuestionnaireScreenState();
}

class _UserQuestionnaireScreenState extends State<UserQuestionnaireScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  
  // User profile data
  String? _gender;
  int? _age;
  String? _state;
  String? _areaOfResidence;
  String? _category;
  bool? _hasDisability;
  bool? _isMinority;
  bool? _isStudent;
  bool? _isBPL;
  double? _annualIncome;
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _incomeController = TextEditingController();

  // Indian states list
  final List<String> _states = [
    'Andhra Pradesh', 'Arunachal Pradesh', 'Assam', 'Bihar', 'Chhattisgarh',
    'Goa', 'Gujarat', 'Haryana', 'Himachal Pradesh', 'Jharkhand',
    'Karnataka', 'Kerala', 'Madhya Pradesh', 'Maharashtra', 'Manipur',
    'Meghalaya', 'Mizoram', 'Nagaland', 'Odisha', 'Punjab',
    'Rajasthan', 'Sikkim', 'Tamil Nadu', 'Telangana', 'Tripura',
    'Uttar Pradesh', 'Uttarakhand', 'West Bengal',
    'Andaman and Nicobar Islands', 'Chandigarh', 'Dadra and Nagar Haveli',
    'Daman and Diu', 'Delhi', 'Jammu and Kashmir', 'Ladakh', 'Lakshadweep', 'Puducherry'
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _ageController.dispose();
    _incomeController.dispose();
    super.dispose();
  }

  void _nextStep() {
    // Validate required fields before moving to next step
    if (_currentStep == 0) {
      // Step 1: Gender is required
      if (_gender == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select your gender'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    } else if (_currentStep == 1) {
      // Step 2: State and Area of Residence are required
      if (_state == null || _state!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select your state'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      if (_areaOfResidence == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select your area of residence'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    } else if (_currentStep == 2) {
      // Step 3: Category is required
      if (_category == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select your category'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }
    
    if (_currentStep < 7) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() {
        _currentStep++;
      });
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() {
        _currentStep--;
      });
    }
  }

  Future<void> _submitAndGetRecommendations() async {
    // Save profile to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final profile = UserProfile(
      gender: _gender,
      age: _age,
      state: _state,
      areaOfResidence: _areaOfResidence,
      category: _category,
      hasDisability: _hasDisability,
      isMinority: _isMinority,
      isStudent: _isStudent,
      isBPL: _isBPL,
      annualIncome: _annualIncome,
    );

    // Save to SharedPreferences
    final profileJson = jsonEncode(profile.toJson());
    await prefs.setString('userProfile', profileJson);

    if (mounted) {
      Navigator.of(context).pop(); // Close questionnaire
      // Navigate to results screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SchemeResultsScreen(userProfile: profile),
        ),
      );
    }
  }

  Future<void> _skipToResults() async {
    final profile = UserProfile(
      gender: _gender,
      age: _age,
      state: _state,
      areaOfResidence: _areaOfResidence,
      category: _category,
      hasDisability: _hasDisability,
      isMinority: _isMinority,
      isStudent: _isStudent,
      isBPL: _isBPL,
      annualIncome: _annualIncome,
    );

    // Save to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final profileJson = jsonEncode(profile.toJson());
    await prefs.setString('userProfile', profileJson);

    if (mounted) {
      Navigator.of(context).pop(); // Close questionnaire
      // Navigate to results screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SchemeResultsScreen(userProfile: profile),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue[400]!,
              Colors.purple[400]!,
              Colors.pink[400]!,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Progress indicator
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: (_currentStep + 1) / 8,
                        backgroundColor: Colors.white.withOpacity(0.3),
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      '${_currentStep + 1}/8',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              // Skip to results button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _skipToResults,
                    child: const Text(
                      'Skip to Results',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ),
              ),
              // Page content
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    SingleChildScrollView(child: _buildStep1()),
                    SingleChildScrollView(child: _buildStep2()),
                    SingleChildScrollView(child: _buildStep3()),
                    SingleChildScrollView(child: _buildStep4()),
                    SingleChildScrollView(child: _buildStep5()),
                    SingleChildScrollView(child: _buildStep6()),
                    SingleChildScrollView(child: _buildStep7()),
                    SingleChildScrollView(child: _buildStep8()),
                  ],
                ),
              ),
              // Navigation buttons
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_currentStep > 0)
                      ElevatedButton(
                        onPressed: _previousStep,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.3),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        ),
                        child: const Text('Previous'),
                      )
                    else
                      const SizedBox(width: 100),
                    ElevatedButton(
                      onPressed: _currentStep == 7 ? _submitAndGetRecommendations : _nextStep,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.blue[600],
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        elevation: 4,
                      ),
                      child: Text(_currentStep == 7 ? 'Submit' : 'Next'),
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

  // Step 1: Gender and Age
  Widget _buildStep1() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.person_outline,
            size: 80,
            color: Colors.white,
          ),
          const SizedBox(height: 24),
          const Text(
            'Tell us about yourself',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 48),
          const Text(
            'Gender *',
            style: TextStyle(
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildGenderButton('Male', Icons.male, 'male'),
              const SizedBox(width: 16),
              _buildGenderButton('Female', Icons.female, 'female'),
              const SizedBox(width: 16),
              _buildGenderButton('Other', Icons.person, 'other'),
            ],
          ),
          const SizedBox(height: 48),
          const Text(
            'Age',
            style: TextStyle(
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 200,
            child: TextField(
              controller: _ageController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, fontSize: 18),
              decoration: InputDecoration(
                hintText: 'Enter your age',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.2),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
              onChanged: (value) {
                setState(() {
                  _age = int.tryParse(value);
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderButton(String label, IconData icon, String value) {
    final isSelected = _gender == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _gender = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: isSelected ? Colors.blue[600] : Colors.white),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.blue[600] : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Step 2: State and Area of Residence
  Widget _buildStep2() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.location_on,
            size: 80,
            color: Colors.white,
          ),
          const SizedBox(height: 24),
          const Text(
            'Where do you live?',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 48),
          const Text(
            'State *',
            style: TextStyle(
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButton<String>(
              value: _state,
              isExpanded: true,
              dropdownColor: Colors.blue[600],
              style: const TextStyle(color: Colors.white, fontSize: 16),
              underline: const SizedBox(),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
              hint: Text(
                'Select State',
                style: TextStyle(color: Colors.white.withOpacity(0.7)),
              ),
              items: _states.map((state) {
                return DropdownMenuItem(
                  value: state,
                  child: Text(state),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _state = value;
                });
              },
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Area of Residence *',
            style: TextStyle(
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildResidenceButton('Urban', Icons.location_city, 'urban'),
              const SizedBox(width: 16),
              _buildResidenceButton('Rural', Icons.landscape, 'rural'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResidenceButton(String label, IconData icon, String value) {
    final isSelected = _areaOfResidence == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _areaOfResidence = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28, color: isSelected ? Colors.blue[600] : Colors.white),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.blue[600] : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Step 3: Category
  Widget _buildStep3() {
    final categories = [
      {'label': 'General', 'value': 'general', 'icon': Icons.people},
      {'label': 'OBC', 'value': 'obc', 'icon': Icons.people_outline},
      {'label': 'PVTG', 'value': 'pvtg', 'icon': Icons.group},
      {'label': 'SC', 'value': 'sc', 'icon': Icons.person_outline},
      {'label': 'ST', 'value': 'st', 'icon': Icons.group_outlined},
      {'label': 'DNT Communities', 'value': 'dnt', 'icon': Icons.diversity_1},
    ];

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.category,
            size: 80,
            color: Colors.white,
          ),
          const SizedBox(height: 24),
          const Text(
            'You belong to *',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 48),
          Flexible(
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.5,
              ),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                final isSelected = _category == category['value'];
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _category = category['value'] as String;
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          category['icon'] as IconData,
                          size: 36,
                          color: isSelected ? Colors.blue[600] : Colors.white,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          category['label'] as String,
                          style: TextStyle(
                            color: isSelected ? Colors.blue[600] : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Step 4: Disability
  Widget _buildStep4() {
    return _buildYesNoStep(
      icon: Icons.accessible,
      title: 'Disability',
      question: 'Do you have a disability?',
      value: _hasDisability,
      onChanged: (value) {
        setState(() {
          _hasDisability = value;
        });
      },
    );
  }

  // Step 5: Minority
  Widget _buildStep5() {
    return _buildYesNoStep(
      icon: Icons.diversity_3,
      title: 'Minority Status',
      question: 'Do you belong to a minority community?',
      value: _isMinority,
      onChanged: (value) {
        setState(() {
          _isMinority = value;
        });
      },
    );
  }

  // Step 6: Student
  Widget _buildStep6() {
    return _buildYesNoStep(
      icon: Icons.school,
      title: 'Student Status',
      question: 'Are you a student?',
      value: _isStudent,
      onChanged: (value) {
        setState(() {
          _isStudent = value;
        });
      },
    );
  }

  // Step 7: BPL
  Widget _buildStep7() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.account_balance_wallet,
            size: 80,
            color: Colors.white,
          ),
          const SizedBox(height: 24),
          const Text(
            'BPL Status',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          const Text(
            'Do you belong to Below Poverty Line (BPL)?',
            style: TextStyle(
              fontSize: 18,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 48),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildYesNoButton('Yes', true),
              const SizedBox(width: 24),
              _buildYesNoButton('No', false),
            ],
          ),
          if (_isBPL == true) ...[
            const SizedBox(height: 48),
            const Text(
              'Annual Income',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 250,
              child: TextField(
                controller: _incomeController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontSize: 18),
                decoration: InputDecoration(
                  hintText: 'Enter annual income (₹)',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.2),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(16),
                  prefixText: '₹ ',
                  prefixStyle: const TextStyle(color: Colors.white, fontSize: 18),
                ),
                onChanged: (value) {
                  setState(() {
                    _annualIncome = double.tryParse(value);
                  });
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildYesNoButton(String label, bool value) {
    final isSelected = _isBPL == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _isBPL = value;
          if (value == false) {
            _annualIncome = null;
            _incomeController.clear();
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 20),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white,
            width: 2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.blue[600] : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
    );
  }

  // Step 8: Submit
  Widget _buildStep8() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle_outline,
            size: 100,
            color: Colors.white,
          ),
          const SizedBox(height: 32),
          const Text(
            'All Set!',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          const Text(
            'We\'ll find the best schemes for you based on your profile.',
            style: TextStyle(
              fontSize: 18,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 48),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              children: [
                Text(
                  'Your Profile Summary',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 16),
                // Profile summary will be shown here
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYesNoStep({
    required IconData icon,
    required String title,
    required String question,
    required bool? value,
    required Function(bool?) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 80, color: Colors.white),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          Text(
            question,
            style: const TextStyle(
              fontSize: 18,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 48),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildYesNoButton('Yes', true),
              const SizedBox(width: 24),
              _buildYesNoButton('No', false),
            ],
          ),
        ],
      ),
    );
  }
}

