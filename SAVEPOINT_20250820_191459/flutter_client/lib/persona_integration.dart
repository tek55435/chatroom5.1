import 'package:flutter/material.dart';
import 'models/user_persona.dart';
import 'providers/persona_provider.dart';
import 'screens/persona_list_screen.dart';
import 'services/voice_service.dart';

/// This class provides integration for the User Persona feature with the main application
class PersonaIntegration {
  final BuildContext context;
  final PersonaProvider personaProvider;

  PersonaIntegration(this.context, this.personaProvider);

  /// Navigate to the persona list screen
  void openPersonaScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PersonaListScreen()),
    );
  }

  /// Get the currently selected persona
  UserPersona? get selectedPersona => personaProvider.selectedPersona;

  /// Get the voice ID for the currently selected persona, or default if none
  String getSelectedVoiceId() {
    return personaProvider.selectedPersona?.voiceId ?? 'alloy';
  }

  /// Get display name for messages based on selected persona
  String getDisplayName(String defaultName) {
    return personaProvider.selectedPersona?.name ?? defaultName;
  }

  /// Method to create a Floating Action Button for the persona feature
  Widget buildPersonaFloatingActionButton() {
    return FloatingActionButton(
      heroTag: 'persona_fab',
      onPressed: openPersonaScreen,
      tooltip: 'Manage Personas',
      child: const Icon(Icons.person),
    );
  }
  
  /// Method to create a persona selector in an AppBar
  Widget buildPersonaSelector(String defaultName) {
    final currentPersona = personaProvider.selectedPersona;
    
    return InkWell(
      onTap: openPersonaScreen,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundImage: currentPersona?.avatarUrl.isNotEmpty == true
                  ? NetworkImage(currentPersona!.avatarUrl)
                  : null,
              child: currentPersona?.avatarUrl.isEmpty != false
                  ? Text(currentPersona?.name.isNotEmpty == true 
                        ? currentPersona!.name[0]
                        : defaultName[0])
                  : null,
            ),
            const SizedBox(width: 8),
            Text(
              currentPersona?.name ?? defaultName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }
  
  /// Create a session update message with the selected persona's voice
  Map<String, dynamic> createSessionUpdateWithVoice() {
    final voiceId = getSelectedVoiceId();
    
    return {
      'type': 'session.update',
      'session': {
        'voice': voiceId,
        'temperature': 0.8,
        'input_audio_format': 'pcm16',
        'output_audio_format': 'pcm16',
        'max_response_output_tokens': 'inf',
        'speed': 1.0
      }
    };
  }
}
