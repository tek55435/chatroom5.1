/**
 * Direct standalone share functionality for the Ephemeral Chat
 */

(function() {
    // Create global chat share functionality
    window.EphemeralChatShare = {
        // Direct share method that always works
        shareUrl: function(url, title) {
            console.log('EphemeralChatShare.shareUrl called with:', url);
            
            // Try the Web Share API first
            if (navigator.share) {
                navigator.share({
                    title: title || 'Join my Ephemeral Chat',
                    text: 'Join my ephemeral chat session',
                    url: url
                })
                .then(() => console.log('Web Share API succeeded'))
                .catch((error) => {
                    console.warn('Web Share API failed:', error);
                    this.copyToClipboard(url);
                });
            } else {
                // Web Share API not available, use clipboard
                this.copyToClipboard(url);
            }
        },
        
        // Helper to copy to clipboard
        copyToClipboard: function(text) {
            if (navigator.clipboard && navigator.clipboard.writeText) {
                navigator.clipboard.writeText(text)
                    .then(() => {
                        alert('Chat URL copied to clipboard: ' + text);
                        return true;
                    })
                    .catch((err) => {
                        console.error('Clipboard API error:', err);
                        this.fallbackCopy(text);
                    });
            } else {
                this.fallbackCopy(text);
            }
        },
        
        // Legacy fallback copy method
        fallbackCopy: function(text) {
            try {
                const textArea = document.createElement('textarea');
                textArea.value = text;
                textArea.style.position = 'fixed';
                textArea.style.left = '-999999px';
                textArea.style.top = '-999999px';
                document.body.appendChild(textArea);
                textArea.focus();
                textArea.select();
                
                const success = document.execCommand('copy');
                document.body.removeChild(textArea);
                
                if (success) {
                    alert('Chat URL copied to clipboard: ' + text);
                } else {
                    alert('Please copy this URL manually: ' + text);
                }
            } catch (err) {
                console.error('Fallback copy error:', err);
                alert('Please copy this URL manually: ' + text);
            }
        }
    };
    
    // Global function that can be called directly from Dart
    window.directChatShare = function(url, title) {
        return window.EphemeralChatShare.shareUrl(url, title);
    };
    
    console.log('EphemeralChatShare: Direct share functionality initialized');
})();
