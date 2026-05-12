class PatientProfile {
  final String name;
  final int age;
  final String pin;

  PatientProfile({
    required this.name,
    required this.age,
    required this.pin,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'age': age,
      };
}
