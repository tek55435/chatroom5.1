import 'package:flutter/material.dart';

class HelpDialog extends StatelessWidget {
  const HelpDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.help_outline),
                  const SizedBox(width: 8),
                  const Text('Help', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                "Here's a quick guide to get you started.",
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              // Type to Speak Mode
              const Text(
                'Type to Speak Mode',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                "Choose this if you prefer to type. Your messages will be read aloud for others. By default, you won't hear incoming audio.",
              ),
              const SizedBox(height: 12),
              // Speak to Type Mode
              const Text(
                'Speak to Type Mode',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Choose this if you prefer to talk. Your voice will be turned into text. You\'ll automatically hear messages from "Type to Speak" users.',
              ),
              const SizedBox(height: 12),
              // Pro Tip
              Row(
                children: const [
                  Icon(Icons.headset_mic_outlined, size: 18),
                  SizedBox(width: 6),
                  Text('Pro Tip for Better Audio', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                "For the best voice-to-text results, we recommend using a headset. If you're using your phone's built-in mic, make sure your phone is in speakerphone mode to help it pick up your voice clearly.",
              ),
              const SizedBox(height: 12),
              // Inviting Friends
              Row(
                children: const [
                  Icon(Icons.share_outlined, size: 18),
                  SizedBox(width: 6),
                  Text('Inviting Friends', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'To invite others to your current chat, click the Share icon in the header. You can share the link via text, email, or by letting them scan the QR code.',
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    // TODO: Wire to actual bug/feature form or mailto link
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Bug/Feature Report: coming soon')),
                    );
                  },
                  icon: const Icon(Icons.bug_report_outlined),
                  label: const Text('Report a Bug or Request a Feature'),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
