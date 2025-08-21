import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';
import '../models/user_persona.dart';
import '../providers/persona_provider.dart';
import '../services/voice_service.dart';
import '../widgets/app_menu_drawer.dart';
import 'help_dialog.dart';

class CreatePersonaScreen extends StatefulWidget {
  const CreatePersonaScreen({Key? key}) : super(key: key);

  @override
  State<CreatePersonaScreen> createState() => _CreatePersonaScreenState();
}

class _CreatePersonaScreenState extends State<CreatePersonaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedVoiceId = '';
  final _avatarUrlController = TextEditingController();

  List<Voice> _availableVoices = [];

  @override
  void initState() {
    super.initState();
    _availableVoices = VoiceService.getAvailableVoices();
    if (_availableVoices.isNotEmpty) {
      _selectedVoiceId = _availableVoices.first.id;
    }
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
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            tooltip: 'Menu',
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text('Create Persona'),
      ),
      drawer: AppMenuDrawer(
        onHelp: () => showDialog(context: context, builder: (_) => const HelpDialog()),
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
              child: const Text('Create Persona'),
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
      final newPersona = UserPersona(
        id: const Uuid().v4(),
        name: _nameController.text,
        description: _descriptionController.text,
        voiceId: _selectedVoiceId,
        avatarUrl: _avatarUrlController.text,
      );

      Provider.of<PersonaProvider>(context, listen: false).addPersona(newPersona);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Persona created successfully')),
      );
      
      Navigator.pop(context);
    }
  }
}
