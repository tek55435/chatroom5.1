// File: C:\Dev\Chatroom5\flutter_client\web\pcm_helper.js
class PCMHelper {
  constructor() {
    this.audioContext = new (window.AudioContext || window.webkitAudioContext)();
  }
  
  async convertBlobToBase64(blob) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onloadend = () => resolve(reader.result.split(',')[1]);
      reader.onerror = reject;
      reader.readAsDataURL(blob);
    });
  }
  // Add other PCM processing methods here
}
// Make available globally
window.pcmHelper = new PCMHelper();
