import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/persona_provider.dart';
import 'persona_creation_dialog.dart';

class PersonaActionsDialog extends StatelessWidget {
  const PersonaActionsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final personaProvider = Provider.of<PersonaProvider>(context);
    final hasPersona = personaProvider.personas.isNotEmpty;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person),
                const SizedBox(width: 8),
                const Text('Persona', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
            const SizedBox(height: 8),
            if (hasPersona) ...[
              Text('Selected: ${personaProvider.selectedPersona?.name ?? "None"}'),
              const SizedBox(height: 12),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      // Navigate to persona list screen if available
                      Navigator.pop(context);
                      // Consumers can navigate to dedicated screens elsewhere
                    },
                    icon: const Icon(Icons.list),
                    label: const Text('Manage Personas'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      await showDialog(
                        context: context,
                        builder: (_) => const PersonaCreationDialog(),
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Create New'),
                  ),
                ],
              ),
            ] else ...[
              const Text('No personas yet.'),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  await showDialog(
                    context: context,
                    builder: (_) => const PersonaCreationDialog(),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('Create Persona'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
