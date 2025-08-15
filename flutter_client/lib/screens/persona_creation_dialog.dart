import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/user_persona.dart';
import '../providers/persona_provider.dart';
import '../providers/settings_provider.dart';
import '../services/voice_service.dart';

class PersonaCreationDialog extends StatefulWidget {
  const PersonaCreationDialog({Key? key}) : super(key: key);

  @override
  State<PersonaCreationDialog> createState() => _PersonaCreationDialogState();
}

class _PersonaCreationDialogState extends State<PersonaCreationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedVoiceId = '';
  final _avatarUrlController = TextEditingController();

  List<Voice> _availableVoices = [];
  bool _isTypeToSpeakMode = true; // Default to Type to Speak

  @override
  void initState() {
    super.initState();
    _availableVoices = VoiceService.getAvailableVoices();
    if (_availableVoices.isNotEmpty) {
      _selectedVoiceId = _availableVoices.first.id;
    }
    
    // Generate avatar URL based on DiceBear API
    _generateAvatarUrl();
  }

  void _generateAvatarUrl() {
    // Use DiceBear API to generate an avatar based on name
    // This will update whenever the name changes
    final name = _nameController.text.isNotEmpty ? _nameController.text : 'User';
    final avatarUrl = 'https://api.dicebear.com/7.x/adventurer/svg?seed=${Uri.encodeComponent(name)}';
    _avatarUrlController.text = avatarUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _avatarUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Create Your Persona',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                
                // Avatar preview
                Center(
                  child: CircleAvatar(
                    radius: 50,
                    backgroundImage: _avatarUrlController.text.isNotEmpty
                        ? NetworkImage(_avatarUrlController.text)
                        : null,
                    child: _avatarUrlController.text.isEmpty
                        ? const Icon(Icons.person, size: 50)
                        : null,
                  ),
                ),
                const SizedBox(height: 20),
                
                // Name field
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    hintText: 'Enter your name or alias',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a name';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    // Generate new avatar when name changes
                    _generateAvatarUrl();
                    setState(() {});
                  },
                ),
                const SizedBox(height: 16),
                
                // Description field
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    hintText: 'Describe your persona',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 24),
                
                // Interaction mode selection
                const Text(
                  'How do you prefer to communicate?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<bool>(
                        title: const Text('Type to Speak'),
                        subtitle: const Text('I prefer to type messages'),
                        value: true,
                        groupValue: _isTypeToSpeakMode,
                        onChanged: (bool? value) {
                          if (value != null) {
                            setState(() {
                              _isTypeToSpeakMode = value;
                            });
                          }
                        },
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<bool>(
                        title: const Text('Speak to Type'),
                        subtitle: const Text('I prefer to speak messages'),
                        value: false,
                        groupValue: _isTypeToSpeakMode,
                        onChanged: (bool? value) {
                          if (value != null) {
                            setState(() {
                              _isTypeToSpeakMode = value;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                const Text(
                  'Select Voice',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                
                // Voice selection
                ...List.generate(
                  _availableVoices.length,
                  (index) => _buildVoiceOption(_availableVoices[index]),
                ),
                
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _savePersona,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Create Persona & Join Chat'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVoiceOption(Voice voice) {
    return RadioListTile<String>(
      title: Row(
        children: [
          Text(voice.name),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.play_circle_outline),
            tooltip: 'Play sample',
            onPressed: () {
              // Play voice sample
              // This would need to be implemented
            },
          ),
        ],
      ),
      subtitle: Text(voice.description),
      value: voice.id,
      groupValue: _selectedVoiceId,
      onChanged: (String? value) {
        if (value != null) {
          setState(() {
            _selectedVoiceId = value;
          });
        }
      },
    );
  }

  void _savePersona() {
    if (_formKey.currentState!.validate()) {
      final newPersona = UserPersona(
        id: const Uuid().v4(),
        name: _nameController.text,
        description: _descriptionController.text.isEmpty 
          ? 'No description' 
          : _descriptionController.text,
        voiceId: _selectedVoiceId,
        avatarUrl: _avatarUrlController.text,
        isTypeToSpeakMode: _isTypeToSpeakMode,
      );
      
      // Save the persona
      Provider.of<PersonaProvider>(context, listen: false).addPersona(newPersona);
      
      // Update the avatar seed in settings
      Provider.of<SettingsProvider>(context, listen: false).setAvatarSeed(_nameController.text);
      
      // Configure audio defaults based on interaction mode
      Provider.of<SettingsProvider>(context, listen: false).setPlayIncomingAudio(!_isTypeToSpeakMode);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Welcome, ${newPersona.name}!')),
      );
      
      Navigator.pop(context);
    }
  }
}
