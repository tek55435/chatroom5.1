// File: C:\Dev\Chatroom5\flutter_client\web\tts_handler.js
class TTSHandler {
  constructor() {
    this.synth = window.speechSynthesis;
    this.voices = [];
    this.initialized = false;
    // Initialize voices when available
    this.synth.onvoiceschanged = () => {
      this.voices = this.synth.getVoices();
      this.initialized = true;
      console.log('TTS voices loaded:', this.voices.length);
    };
  }
  
  speak(text, voiceName = null) {
    const utterance = new SpeechSynthesisUtterance(text);
    if (voiceName && this.initialized) {
      const voice = this.voices.find(v => v.name === voiceName);
      if (voice) utterance.voice = voice;
    }
    this.synth.speak(utterance);
    return true;
  }
}
// Make available globally
window.ttsHandler = new TTSHandler();
