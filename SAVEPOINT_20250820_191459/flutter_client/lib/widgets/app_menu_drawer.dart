import 'package:flutter/material.dart';

class AppMenuDrawer extends StatelessWidget {
  const AppMenuDrawer({
    super.key,
    this.onInvite,
    this.onPersona,
    this.onHelp,
    this.onSettings,
    this.onDiagnostics,
  });

  final VoidCallback? onInvite;
  final VoidCallback? onPersona;
  final VoidCallback? onHelp;
  final VoidCallback? onSettings;
  final VoidCallback? onDiagnostics;

  void _handleTap(BuildContext context, VoidCallback? cb, String label) {
    // Always close the drawer first
    if (Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }
    if (cb != null) {
      cb();
    } else {
      // ignore: avoid_print
      print('$label tapped - no handler wired');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.blue),
            child: Text(
              "Menu",
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.share),
            title: const Text("Invite / Share"),
            onTap: () => _handleTap(context, onInvite, 'Invite'),
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text("Persona"),
            onTap: () => _handleTap(context, onPersona, 'Persona'),
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text("Help"),
            onTap: () => _handleTap(context, onHelp, 'Help'),
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text("Settings"),
            onTap: () => _handleTap(context, onSettings, 'Settings'),
          ),
          ListTile(
            leading: const Icon(Icons.bug_report),
            title: const Text("Diagnostics / Logs"),
            onTap: () => _handleTap(context, onDiagnostics, 'Diagnostics'),
          ),
        ],
      ),
    );
  }
}
