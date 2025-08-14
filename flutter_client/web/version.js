// Version and build info for the Chatroom5 application
window.appVersion = {
  version: "1.0.1",
  buildDate: "2025-08-13",
  features: [
    "Real-time voice and text chat",
    "Accessibility modes (Type-to-Speak and Speak-to-Type)",
    "Direct room sharing via URL",
    "Edit and delete messages",
    "Speech-to-text transcription",
    "Text-to-speech synthesis"
  ],
  environment: {
    server: "http://localhost:3000",
    platform: navigator.platform,
    userAgent: navigator.userAgent
  }
};

// Log version info on startup
console.log(`Chatroom5 v${window.appVersion.version} (${window.appVersion.buildDate})`);
console.log("Features enabled:", window.appVersion.features);
