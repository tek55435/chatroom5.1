class UserPersona {
  final String id;
  final String name;
  final String description;
  final String voiceId;
  final String avatarUrl;
  final bool isTypeToSpeakMode; // True for Type-to-Speak, False for Speak-to-Type
  
  UserPersona({
    required this.id,
    required this.name,
    required this.description,
    required this.voiceId,
    this.avatarUrl = '',
    this.isTypeToSpeakMode = true, // Default to Type-to-Speak
  });

  factory UserPersona.fromJson(Map<String, dynamic> json) {
    return UserPersona(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      voiceId: json['voiceId'],
      avatarUrl: json['avatarUrl'] ?? '',
      isTypeToSpeakMode: json['isTypeToSpeakMode'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'voiceId': voiceId,
      'avatarUrl': avatarUrl,
      'isTypeToSpeakMode': isTypeToSpeakMode,
    };
  }
}
