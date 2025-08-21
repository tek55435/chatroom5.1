import 'package:flutter/material.dart';
import '../models/user_persona.dart';
import '../providers/persona_provider.dart';
import '../providers/settings_provider.dart';
import 'package:provider/provider.dart';

class PersonaCreationDialog extends StatefulWidget {
  final VoidCallback? onPersonaCreated;

  const PersonaCreationDialog({
    super.key,
    this.onPersonaCreated,
  });

  @override
  State<PersonaCreationDialog> createState() => _PersonaCreationDialogState();
}

class _PersonaCreationDialogState extends State<PersonaCreationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _avatarUrlController = TextEditingController();
  
  String _selectedVoice = 'alloy';
  bool _isTypeToSpeakMode = true;
  
  // Available voices for TTS
  final List<Map<String, String>> _availableVoices = [
    {'id': 'alloy', 'name': 'Alloy', 'gender': 'Neutral'},
    {'id': 'echo', 'name': 'Echo', 'gender': 'Male'},
    {'id': 'fable', 'name': 'Fable', 'gender': 'Female'},
    {'id': 'onyx', 'name': 'Onyx', 'gender': 'Male'},
    {'id': 'nova', 'name': 'Nova', 'gender': 'Female'},
    {'id': 'shimmer', 'name': 'Shimmer', 'gender': 'Female'},
  ];

  @override
  void initState() {
    super.initState();
    _generateAvatarUrl();
  }

  void _generateAvatarUrl() {
    // Generate avatar URL based on name or use a default
    String name = _nameController.text.isNotEmpty ? _nameController.text : 'User';
    _avatarUrlController.text = 'https://api.dicebear.com/7.x/avataaars/png?seed=$name';
  }

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions for responsive design
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 600;
    
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 12 : 40,
        vertical: isSmallScreen ? 16 : 40,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: isSmallScreen ? double.infinity : 500,
          maxHeight: screenHeight * (isSmallScreen ? 0.95 : 0.9),
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(isSmallScreen ? 16 : 16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(isSmallScreen ? 16 : 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header section with close button
              Container(
                padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade600, Colors.blue.shade400],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Create Your Persona',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 20 : 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white),
                      iconSize: isSmallScreen ? 20 : 24,
                    ),
                  ],
                ),
              ),
              
              // Content section
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Avatar section
                        Center(
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: isSmallScreen ? 40 : 50,
                                backgroundColor: Colors.blue.shade50,
                                backgroundImage: _avatarUrlController.text.isNotEmpty
                                    ? NetworkImage(_avatarUrlController.text)
                                    : null,
                                child: _avatarUrlController.text.isEmpty
                                    ? Icon(
                                        Icons.person,
                                        size: isSmallScreen ? 40 : 50,
                                        color: Colors.blue.shade300,
                                      )
                                    : null,
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: Icon(
                                    Icons.edit,
                                    size: isSmallScreen ? 14 : 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: isSmallScreen ? 16 : 20),
                        
                        // Name field
                        _buildModernTextField(
                          controller: _nameController,
                          label: 'Your Name',
                          hint: 'Enter your name or alias',
                          icon: Icons.person_outline,
                          isSmallScreen: isSmallScreen,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a name';
                            }
                            return null;
                          },
                          onChanged: (value) {
                            _generateAvatarUrl();
                            setState(() {});
                          },
                        ),
                        SizedBox(height: isSmallScreen ? 12 : 16),
                        
                        // Description field
                        _buildModernTextField(
                          controller: _descriptionController,
                          label: 'Description (Optional)',
                          hint: 'Tell us about yourself',
                          icon: Icons.description_outlined,
                          isSmallScreen: isSmallScreen,
                          maxLines: 2,
                        ),
                        SizedBox(height: isSmallScreen ? 16 : 24),
                        
                        // Communication preference section
                        _buildSectionCard(
                          title: 'Communication Style',
                          isSmallScreen: isSmallScreen,
                          child: Column(
                            children: [
                              _buildCommunicationOption(
                                title: 'Type to Speak',
                                subtitle: 'I prefer typing messages',
                                icon: Icons.keyboard_outlined,
                                value: true,
                                groupValue: _isTypeToSpeakMode,
                                onChanged: (bool? value) {
                                  if (value != null) {
                                    setState(() {
                                      _isTypeToSpeakMode = value;
                                    });
                                  }
                                },
                                isSmallScreen: isSmallScreen,
                              ),
                              _buildCommunicationOption(
                                title: 'Speak to Type',
                                subtitle: 'I prefer speaking messages',
                                icon: Icons.mic_outlined,
                                value: false,
                                groupValue: _isTypeToSpeakMode,
                                onChanged: (bool? value) {
                                  if (value != null) {
                                    setState(() {
                                      _isTypeToSpeakMode = value;
                                    });
                                  }
                                },
                                isSmallScreen: isSmallScreen,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: isSmallScreen ? 16 : 24),
                        
                        // Voice selection section
                        _buildSectionCard(
                          title: 'Voice Selection',
                          isSmallScreen: isSmallScreen,
                          child: Column(
                            children: _availableVoices.map((voice) =>
                              _buildModernVoiceOption(voice, isSmallScreen)
                            ).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              // Footer with buttons
              Container(
                padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  border: Border(
                    top: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            vertical: isSmallScreen ? 12 : 16,
                          ),
                          side: BorderSide(color: Colors.grey.shade400),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 14 : 16,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: isSmallScreen ? 12 : 16),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _savePersona,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            vertical: isSmallScreen ? 12 : 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 2,
                        ),
                        child: Text(
                          'Create Persona',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 14 : 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
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

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isSmallScreen,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextFormField(
        controller: controller,
        validator: validator,
        onChanged: onChanged,
        maxLines: maxLines,
        style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: Colors.blue.shade400),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: isSmallScreen ? 12 : 16,
          ),
          labelStyle: TextStyle(
            color: Colors.grey.shade600,
            fontSize: isSmallScreen ? 12 : 14,
          ),
          hintStyle: TextStyle(
            color: Colors.grey.shade400,
            fontSize: isSmallScreen ? 12 : 14,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required Widget child,
    required bool isSmallScreen,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(isSmallScreen ? 16 : 12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: EdgeInsets.all(isSmallScreen ? 16 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: isSmallScreen ? 16 : 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
          SizedBox(height: isSmallScreen ? 12 : 12),
          child,
        ],
      ),
    );
  }

  Widget _buildCommunicationOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required bool groupValue,
    required void Function(bool?) onChanged,
    required bool isSmallScreen,
  }) {
    final isSelected = value == groupValue;
    
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(isSmallScreen ? 16 : 16),
        margin: EdgeInsets.only(bottom: isSmallScreen ? 12 : 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 8),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSmallScreen && isSelected ? [
            BoxShadow(
              color: Colors.blue.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ] : null,
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 10 : 8),
              decoration: BoxDecoration(
                color: isSelected ? Colors.blue.shade100 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 8),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.blue.shade700 : Colors.grey.shade600,
                size: isSmallScreen ? 24 : 24,
              ),
            ),
            SizedBox(width: isSmallScreen ? 16 : 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: isSmallScreen ? 16 : 16,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.blue.shade800 : Colors.grey.shade800,
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 4 : 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: isSmallScreen ? 14 : 14,
                      color: isSelected ? Colors.blue.shade600 : Colors.grey.shade600,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 4 : 2),
              child: Radio<bool>(
                value: value,
                groupValue: groupValue,
                onChanged: onChanged,
                activeColor: Colors.blue,
                materialTapTargetSize: isSmallScreen 
                    ? MaterialTapTargetSize.padded 
                    : MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernVoiceOption(Map<String, String> voice, bool isSmallScreen) {
    final isSelected = _selectedVoice == voice['id'];
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedVoice = voice['id']!;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              voice['gender'] == 'Male' ? Icons.face : 
              voice['gender'] == 'Female' ? Icons.face_3 : Icons.face_6,
              color: isSelected ? Colors.blue : Colors.grey.shade500,
              size: isSmallScreen ? 20 : 24,
            ),
            SizedBox(width: isSmallScreen ? 8 : 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    voice['name']!,
                    style: TextStyle(
                      fontSize: isSmallScreen ? 14 : 16,
                      fontWeight: FontWeight.w500,
                      color: isSelected ? Colors.blue.shade800 : Colors.grey.shade800,
                    ),
                  ),
                  Text(
                    voice['gender']!,
                    style: TextStyle(
                      fontSize: isSmallScreen ? 12 : 14,
                      color: isSelected ? Colors.blue.shade600 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Radio<String>(
              value: voice['id']!,
              groupValue: _selectedVoice,
              onChanged: (String? value) {
                if (value != null) {
                  setState(() {
                    _selectedVoice = value;
                  });
                }
              },
              activeColor: Colors.blue,
            ),
          ],
        ),
      ),
    );
  }

  void _savePersona() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      // Create a new persona using UserPersona model
      final newPersona = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'voiceId': _selectedVoice,
        'avatarUrl': _avatarUrlController.text,
        'isTypeToSpeakMode': _isTypeToSpeakMode,
      };

      // Create UserPersona from map
      final userPersona = UserPersona.fromJson(newPersona);

      // Save persona using provider
      final personaProvider = Provider.of<PersonaProvider>(context, listen: false);
      await personaProvider.addPersona(userPersona);

      // Update settings
      final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
      await settingsProvider.setAvatarSeed(_nameController.text.trim());

      // Set audio defaults based on interaction mode
      // Type to Speak users: playIncomingAudio = false (they don't want to hear others)
      // Speak to Type users: playIncomingAudio = true (they want to hear others)
      await settingsProvider.setPlayIncomingAudio(!_isTypeToSpeakMode);

      // Close dialog
      Navigator.of(context).pop();

      // Trigger callback if provided
      if (widget.onPersonaCreated != null) {
        widget.onPersonaCreated!();
      }
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating persona: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _avatarUrlController.dispose();
    super.dispose();
  }
}
