import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_persona.dart';

class PersonaProvider extends ChangeNotifier {
  List<UserPersona> _personas = [];
  UserPersona? _selectedPersona;
  
  List<UserPersona> get personas => _personas;
  UserPersona? get selectedPersona => _selectedPersona;
  
  PersonaProvider() {
    loadPersonas();
  }
  
  Future<void> loadPersonas() async {
    final prefs = await SharedPreferences.getInstance();
    final personasJson = prefs.getStringList('personas') ?? [];
    
    _personas = personasJson
        .map((json) => UserPersona.fromJson(jsonDecode(json)))
        .toList();
    
    final selectedId = prefs.getString('selectedPersonaId');
    if (selectedId != null && _personas.isNotEmpty) {
      _selectedPersona = _personas.firstWhere(
        (persona) => persona.id == selectedId,
        orElse: () => _personas.first,
      );
    } else if (_personas.isNotEmpty) {
      _selectedPersona = _personas.first;
    }
    
    notifyListeners();
  }
  
  Future<void> savePersonas() async {
    final prefs = await SharedPreferences.getInstance();
    final personasJson = _personas
        .map((persona) => jsonEncode(persona.toJson()))
        .toList();
    
    await prefs.setStringList('personas', personasJson);
    
    if (_selectedPersona != null) {
      await prefs.setString('selectedPersonaId', _selectedPersona!.id);
    }
  }
  
  Future<void> addPersona(UserPersona persona) async {
    _personas.add(persona);
    if (_personas.length == 1) {
      _selectedPersona = persona;
    }
    notifyListeners();
    await savePersonas();
  }
  
  Future<void> updatePersona(UserPersona updatedPersona) async {
    final index = _personas.indexWhere((p) => p.id == updatedPersona.id);
    if (index != -1) {
      _personas[index] = updatedPersona;
      if (_selectedPersona?.id == updatedPersona.id) {
        _selectedPersona = updatedPersona;
      }
      notifyListeners();
      await savePersonas();
    }
  }
  
  Future<void> deletePersona(String personaId) async {
    _personas.removeWhere((p) => p.id == personaId);
    if (_selectedPersona?.id == personaId) {
      _selectedPersona = _personas.isNotEmpty ? _personas.first : null;
    }
    notifyListeners();
    await savePersonas();
  }
  
  Future<void> selectPersona(String personaId) async {
    final persona = _personas.firstWhere((p) => p.id == personaId);
    _selectedPersona = persona;
    notifyListeners();
    await savePersonas();
  }
}
