import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_persona.dart';
import '../providers/persona_provider.dart';
import '../services/voice_service.dart';

class EditPersonaScreen extends StatefulWidget {
  final UserPersona persona;
  
  const EditPersonaScreen({Key? key, required this.persona}) : super(key: key);

  @override
  State<EditPersonaScreen> createState() => _EditPersonaScreenState();
}

class _EditPersonaScreenState extends State<EditPersonaScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _avatarUrlController;
  late String _selectedVoiceId;
  
  List<Voice> _availableVoices = [];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.persona.name);
    _descriptionController = TextEditingController(text: widget.persona.description);
    _avatarUrlController = TextEditingController(text: widget.persona.avatarUrl);
    _selectedVoiceId = widget.persona.voiceId;
    
    _availableVoices = VoiceService.getAvailableVoices();
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Persona'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'Enter a name for your persona',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Describe your persona',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a description';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _avatarUrlController,
              decoration: const InputDecoration(
                labelText: 'Avatar URL (Optional)',
                hintText: 'Enter URL for avatar image',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Select Voice',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...List.generate(
              _availableVoices.length,
              (index) => _buildVoiceOption(_availableVoices[index]),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _savePersona,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceOption(Voice voice) {
    return RadioListTile<String>(
      title: Text(voice.name),
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
      final updatedPersona = UserPersona(
        id: widget.persona.id,
        name: _nameController.text,
        description: _descriptionController.text,
        voiceId: _selectedVoiceId,
        avatarUrl: _avatarUrlController.text,
      );

      Provider.of<PersonaProvider>(context, listen: false).updatePersona(updatedPersona);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Persona updated successfully')),
      );
      
      Navigator.pop(context);
    }
  }
}
