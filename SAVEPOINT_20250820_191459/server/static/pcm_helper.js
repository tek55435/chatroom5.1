// File: C:\Dev\Chatroom5\flutter_client\web\pcm_helper.js
// Using a namespace to avoid conflicts with other PCMHelper implementations
window.WebPCMHelper = window.WebPCMHelper || {};

window.WebPCMHelper.createHelper = function() {
  return new WebPCMHelperClass();
};

class WebPCMHelperClass {
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
window.pcmHelper = window.WebPCMHelper.createHelper();
