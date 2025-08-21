# User Persona Feature

This feature allows users to create, edit, and select different personas with custom voices for use in the chat application.

## Components

1. **Models**
   - `UserPersona` - Data model for storing persona information

2. **Providers**
   - `PersonaProvider` - State management for personas

3. **Screens**
   - `PersonaListScreen` - Displays all personas and allows selection
   - `CreatePersonaScreen` - Form for creating new personas
   - `EditPersonaScreen` - Form for editing existing personas

4. **Services**
   - `VoiceService` - Manages available voices for personas

5. **Integration**
   - `PersonaIntegration` - Helper class to integrate the persona feature with the main app

## How to Use

### Setup

1. Make sure the required dependencies are in `pubspec.yaml`:
   ```yaml
   dependencies:
     provider: ^6.0.5
     uuid: ^4.0.0
     shared_preferences: ^2.2.2
   ```

2. Run `flutter pub get` to install dependencies

### Integration into Main App

To integrate the persona feature into your existing app:

1. Wrap your app with the `PersonaProvider` in `main.dart`:
   ```dart
   void main() {
     runApp(
       MultiProvider(
         providers: [
           ChangeNotifierProvider(create: (_) => PersonaProvider()),
           // Other providers...
         ],
         child: const MyApp(),
       ),
     );
   }
   ```

2. Add a way to access the Persona screen, for example:

   ```dart
   // In your app bar or drawer
   IconButton(
     icon: const Icon(Icons.person),
     onPressed: () {
       Navigator.push(
         context,
         MaterialPageRoute(builder: (context) => const PersonaListScreen()),
       );
     },
   ),
   ```

3. Or use the `PersonaIntegration` helper class:
   ```dart
   final personaIntegration = PersonaIntegration(
     context, 
     Provider.of<PersonaProvider>(context, listen: false)
   );
   
   // Then use the helper methods
   appBar: AppBar(
     title: const Text('Chat App'),
     actions: [
       personaIntegration.buildPersonaSelector('Guest'),
     ],
   ),
   ```

### Using Personas in WebRTC

When sending a WebRTC session update, use the selected persona's voice:

```dart
// Get the current voice from the persona provider
final voiceId = Provider.of<PersonaProvider>(context, listen: false)
    .selectedPersona?.voiceId ?? 'alloy';

// Include in the session update
final sessionConfig = {
  'type': 'session.update',
  'session': {
    'voice': voiceId,
    // other session parameters...
  }
};
```

Or use the integration helper:
```dart
final sessionConfig = personaIntegration.createSessionUpdateWithVoice();
```

## Voice Options

Currently supported voices:
- Alloy (neutral)
- Echo (soft)
- Fable (storytelling)
- Onyx (deep)
- Nova (energetic)

Additional voices can be added to `VoiceService.getAvailableVoices()` method.

## Data Storage

Personas are stored using `SharedPreferences` and will persist between app sessions. The selected persona is also remembered.
