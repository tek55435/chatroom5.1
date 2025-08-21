class Voice {
  final String id;
  final String name;
  final String description;
  final String previewUrl;

  Voice({
    required this.id,
    required this.name,
    required this.description,
    required this.previewUrl,
  });
}

class VoiceService {
  // This would typically come from an API, but for this example we'll hardcode some voices
  static List<Voice> getAvailableVoices() {
    return [
      Voice(
        id: 'alloy',
        name: 'Alloy',
        description: 'A neutral voice with balanced tone',
        previewUrl: 'assets/voices/alloy_preview.mp3',
      ),
      Voice(
        id: 'echo',
        name: 'Echo',
        description: 'A soft and melodic voice',
        previewUrl: 'assets/voices/echo_preview.mp3',
      ),
      Voice(
        id: 'fable',
        name: 'Fable',
        description: 'A narrating voice with a storytelling style',
        previewUrl: 'assets/voices/fable_preview.mp3',
      ),
      Voice(
        id: 'onyx',
        name: 'Onyx',
        description: 'A deep and authoritative voice',
        previewUrl: 'assets/voices/onyx_preview.mp3',
      ),
      Voice(
        id: 'nova',
        name: 'Nova',
        description: 'A bright and energetic voice',
        previewUrl: 'assets/voices/nova_preview.mp3',
      ),
    ];
  }

  static Voice getVoiceById(String id) {
    return getAvailableVoices().firstWhere(
      (voice) => voice.id == id,
      orElse: () => getAvailableVoices().first,
    );
  }
}
