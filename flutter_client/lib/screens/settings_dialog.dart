import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../providers/persona_provider.dart';
import '../models/user_persona.dart';

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({Key? key}) : super(key: key);

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late TextEditingController _avatarSeedController;

  @override
  void initState() {
    super.initState();
    _avatarSeedController = TextEditingController(
      text: Provider.of<SettingsProvider>(context, listen: false).avatarSeed
    );
  }

  @override
  void dispose() {
    _avatarSeedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Dialog Header
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16.0),
                  topRight: Radius.circular(16.0),
                ),
              ),
              child: Center(
                child: Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ),
            
            // Settings Content
            Container(
              constraints: const BoxConstraints(maxHeight: 400),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Appearance Section
                      _buildSectionHeader('Appearance'),
                      _buildDarkModeToggle(),
                      const Divider(),
                      
                      // Interaction Section
                      _buildSectionHeader('Interaction'),
                      _buildInteractionModeSelector(),
                      _buildPlayIncomingAudioToggle(),
                      const Divider(),
                      
                      // Profile Section
                      _buildSectionHeader('Profile'),
                      _buildAvatarSeedInput(),
                    ],
                  ),
                ),
              ),
            ),
            
            // Dialog Actions
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildDarkModeToggle() {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, _) {
        return SwitchListTile(
          title: const Text('Dark Mode'),
          subtitle: const Text('Enable dark theme throughout the app'),
          value: settingsProvider.darkMode,
          onChanged: (value) {
            settingsProvider.setDarkMode(value);
          },
        );
      },
    );
  }

  Widget _buildInteractionModeSelector() {
    return Consumer2<PersonaProvider, SettingsProvider>(
      builder: (context, personaProvider, settingsProvider, _) {
        final currentPersona = personaProvider.selectedPersona;
        if (currentPersona == null) {
          return const ListTile(
            title: Text('Interaction Mode'),
            subtitle: Text('Please create a persona first'),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ListTile(
              title: Text('Interaction Mode'),
              subtitle: Text('Choose how you prefer to communicate'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment<bool>(
                    value: true,
                    label: Text('Type to Speak'),
                    icon: Icon(Icons.keyboard),
                  ),
                  ButtonSegment<bool>(
                    value: false,
                    label: Text('Speak to Type'),
                    icon: Icon(Icons.mic),
                  ),
                ],
                selected: {currentPersona.isTypeToSpeakMode},
                onSelectionChanged: (Set<bool> selection) {
                  if (selection.isNotEmpty) {
                    final isTypeToSpeakMode = selection.first;
                    final updatedPersona = UserPersona(
                      id: currentPersona.id,
                      name: currentPersona.name,
                      description: currentPersona.description,
                      voiceId: currentPersona.voiceId,
                      avatarUrl: currentPersona.avatarUrl,
                      isTypeToSpeakMode: isTypeToSpeakMode,
                    );
                    personaProvider.updatePersona(updatedPersona);

                    // Update audio settings based on interaction mode
                    settingsProvider.setPlayIncomingAudio(!isTypeToSpeakMode);
                  }
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPlayIncomingAudioToggle() {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, _) {
        return SwitchListTile(
          title: const Text('Play Incoming Audio'),
          subtitle: const Text('Play audio for incoming messages'),
          value: settingsProvider.playIncomingAudio,
          onChanged: (value) {
            settingsProvider.setPlayIncomingAudio(value);
          },
        );
      },
    );
  }

  Widget _buildAvatarSeedInput() {
    return Consumer<PersonaProvider>(
      builder: (context, personaProvider, _) {
        final currentPersona = personaProvider.selectedPersona;
        if (currentPersona == null) {
          return const ListTile(
            title: Text('Avatar'),
            subtitle: Text('Please create a persona first'),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                title: const Text('Update Profile Picture'),
                subtitle: const Text('Enter a seed to generate a new avatar'),
                leading: CircleAvatar(
                  backgroundImage: currentPersona.avatarUrl.isNotEmpty
                      ? NetworkImage(currentPersona.avatarUrl)
                      : null,
                  child: currentPersona.avatarUrl.isEmpty
                      ? Text(currentPersona.name[0])
                      : null,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _avatarSeedController,
                        decoration: const InputDecoration(
                          labelText: 'Avatar Seed',
                          hintText: 'Enter text to generate avatar',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        final seed = _avatarSeedController.text;
                        if (seed.isNotEmpty) {
                          final avatarUrl = 'https://api.dicebear.com/7.x/adventurer/png?seed=${Uri.encodeComponent(seed)}';
                          
                          // Update the persona with new avatar URL
                          final updatedPersona = UserPersona(
                            id: currentPersona.id,
                            name: currentPersona.name,
                            description: currentPersona.description,
                            voiceId: currentPersona.voiceId,
                            avatarUrl: avatarUrl,
                            isTypeToSpeakMode: currentPersona.isTypeToSpeakMode,
                          );
                          
                          personaProvider.updatePersona(updatedPersona);
                          
                          // Also update the settings provider
                          Provider.of<SettingsProvider>(context, listen: false).setAvatarSeed(seed);
                          
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Avatar updated!')),
                          );
                        }
                      },
                      child: const Text('Update'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
