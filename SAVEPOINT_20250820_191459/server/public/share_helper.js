/**
 * Web sharing utilities for Chatroom application
 */

// Namespace to avoid conflicts
window.ChatroomShare = {
  // Share URL via Web Share API if available, otherwise fallback to clipboard
  shareUrl: function(url, title = "Join my chat session") {
    console.log("Web share function called for URL:", url);
    
    // Check if Web Share API is available
    if (navigator.share) {
      navigator.share({
        title: title,
        text: 'Join my ephemeral chat session',
        url: url,
      })
      .then(() => console.log('Share successful'))
      .catch((error) => {
        console.error('Error sharing:', error);
        this.fallbackShare(url);
      });
      return true;
    } else {
      console.log("Web Share API not available, using fallback");
      return this.fallbackShare(url);
    }
  },
  
  // Fallback to clipboard copy + alert
  fallbackShare: function(url) {
    try {
      // Copy to clipboard
      const textArea = document.createElement("textarea");
      textArea.value = url;
      textArea.style.position = "fixed";  // Prevent scrolling to bottom
      document.body.appendChild(textArea);
      textArea.focus();
      textArea.select();
      
      const successful = document.execCommand('copy');
      document.body.removeChild(textArea);
      
      if (successful) {
        alert("Chat URL copied to clipboard: " + url);
        return true;
      } else {
        console.error("Failed to copy URL to clipboard");
        alert("Could not share URL. Please copy this link manually: " + url);
        return false;
      }
    } catch (err) {
      console.error("Share fallback error:", err);
      alert("Could not share URL. Please copy this link manually: " + url);
      return false;
    }
  }
};

console.log("ChatroomShare initialized");
