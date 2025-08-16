import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/persona_provider.dart';
import 'create_persona_screen.dart';
import 'edit_persona_screen.dart';
import '../widgets/app_menu_drawer.dart';
import '../widgets/share_dialog.dart';
import 'package:flutter/foundation.dart';
import 'dart:html' as html;
import 'help_dialog.dart';

class PersonaListScreen extends StatelessWidget {
  const PersonaListScreen({Key? key}) : super(key: key);

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
        title: const Text('Your Personas'),
      ),
      drawer: AppMenuDrawer(
        onInvite: () {
          final base = html.window.location.href.split('?').first;
          final uri = Uri.parse(html.window.location.href);
          final sessionId = uri.queryParameters['sessionId'] ?? 'unknown';
          final url = '$base?sessionId=$sessionId';
          showDialog(
            context: context,
            builder: (_) => ShareDialog(sessionId: sessionId, shareUrl: url),
          );
        },
        onPersona: () => showDialog(context: context, builder: (_) => const HelpDialog()),
        onHelp: () => showDialog(context: context, builder: (_) => const HelpDialog()),
        onSettings: () => showDialog(context: context, builder: (_) => const HelpDialog()),
        onDiagnostics: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Open diagnostics from Home'))),
      ),
      body: Consumer<PersonaProvider>(
        builder: (context, personaProvider, child) {
          if (personaProvider.personas.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'No personas created yet',
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CreatePersonaScreen(),
                        ),
                      );
                    },
                    child: const Text('Create Your First Persona'),
                  ),
                ],
              ),
            );
          }
          
          return ListView.builder(
            itemCount: personaProvider.personas.length,
            itemBuilder: (context, index) {
              final persona = personaProvider.personas[index];
              final isSelected = personaProvider.selectedPersona?.id == persona.id;
              
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage: persona.avatarUrl.isNotEmpty
                        ? NetworkImage(persona.avatarUrl)
                        : null,
                    child: persona.avatarUrl.isEmpty
                        ? Text(persona.name[0])
                        : null,
                  ),
                  title: Text(persona.name),
                  subtitle: Text(
                    persona.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSelected)
                        const Padding(
                          padding: EdgeInsets.only(right: 12),
                          child: Icon(Icons.check_circle, color: Colors.green),
                        ),
                      PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'edit') {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EditPersonaScreen(persona: persona),
                              ),
                            );
                          } else if (value == 'delete') {
                            // Show confirmation dialog
                            final shouldDelete = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Delete Persona'),
                                content: Text('Are you sure you want to delete ${persona.name}?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );
                            
                            if (shouldDelete == true) {
                              personaProvider.deletePersona(persona.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('${persona.name} deleted')),
                              );
                            }
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit),
                                SizedBox(width: 8),
                                Text('Edit'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Delete'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  onTap: () {
                    personaProvider.selectPersona(persona.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${persona.name} selected')),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreatePersonaScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
