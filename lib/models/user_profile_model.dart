class UserProfile {
  final String? gender; // 'male', 'female', 'other'
  final int? age;
  final String? state;
  final String? areaOfResidence; // 'urban', 'rural'
  final String? category; // 'general', 'obc', 'pvtg', 'sc', 'st', 'dnt'
  final bool? hasDisability;
  final bool? isMinority;
  final bool? isStudent;
  final bool? isBPL;
  final double? annualIncome; // Only if BPL is true

  UserProfile({
    this.gender,
    this.age,
    this.state,
    this.areaOfResidence,
    this.category,
    this.hasDisability,
    this.isMinority,
    this.isStudent,
    this.isBPL,
    this.annualIncome,
  });

  // Check if profile has minimum data for recommendations
  bool hasMinimumData() {
    return gender != null || 
           age != null || 
           state != null || 
           areaOfResidence != null ||
           category != null;
  }

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'gender': gender,
      'age': age,
      'state': state,
      'areaOfResidence': areaOfResidence,
      'category': category,
      'hasDisability': hasDisability,
      'isMinority': isMinority,
      'isStudent': isStudent,
      'isBPL': isBPL,
      'annualIncome': annualIncome,
    };
  }

  // Create from JSON
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      gender: json['gender'],
      age: json['age'],
      state: json['state'],
      areaOfResidence: json['areaOfResidence'],
      category: json['category'],
      hasDisability: json['hasDisability'],
      isMinority: json['isMinority'],
      isStudent: json['isStudent'],
      isBPL: json['isBPL'],
      annualIncome: json['annualIncome']?.toDouble(),
    );
  }

  // Create a copy with updated values
  UserProfile copyWith({
    String? gender,
    int? age,
    String? state,
    String? areaOfResidence,
    String? category,
    bool? hasDisability,
    bool? isMinority,
    bool? isStudent,
    bool? isBPL,
    double? annualIncome,
  }) {
    return UserProfile(
      gender: gender ?? this.gender,
      age: age ?? this.age,
      state: state ?? this.state,
      areaOfResidence: areaOfResidence ?? this.areaOfResidence,
      category: category ?? this.category,
      hasDisability: hasDisability ?? this.hasDisability,
      isMinority: isMinority ?? this.isMinority,
      isStudent: isStudent ?? this.isStudent,
      isBPL: isBPL ?? this.isBPL,
      annualIncome: annualIncome ?? this.annualIncome,
    );
  }
}

