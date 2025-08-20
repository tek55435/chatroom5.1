/**
 * Enhanced Share Functionality for Ephemeral Chat
 * This script addresses cross-browser sharing issues
 */

(function() {
    // Verify our namespace exists
    if (!window.ChatroomShare) {
        window.ChatroomShare = {};
    }

    // Enhanced shareUrl function that works better across browsers
    window.ChatroomShare.enhancedShareUrl = function(url, title = "Join my chat session") {
        console.log("[enhancedShareUrl] Starting enhanced share for URL:", url);
        
        // Try multiple sharing methods in sequence
        return this.tryWebShareApi(url, title)
            .then(success => success || this.tryClipboardApi(url))
            .then(success => success || this.tryExecCommand(url))
            .then(success => {
                if (!success) {
                    console.warn("[enhancedShareUrl] All sharing methods failed");
                    alert("Please copy this URL manually: " + url);
                }
                return success;
            })
            .catch(error => {
                console.error("[enhancedShareUrl] Error during share:", error);
                alert("Please copy this URL manually: " + url);
                return false;
            });
    };

    // Try Web Share API
    window.ChatroomShare.tryWebShareApi = function(url, title) {
        return new Promise((resolve) => {
            if (navigator.share && navigator.userAgent.indexOf("Firefox") === -1) {
                console.log("[enhancedShareUrl] Trying Web Share API");
                navigator.share({
                    title: title,
                    text: "Join my ephemeral chat session",
                    url: url
                })
                .then(() => {
                    console.log("[enhancedShareUrl] Web Share API successful");
                    resolve(true);
                })
                .catch(error => {
                    console.warn("[enhancedShareUrl] Web Share API failed:", error);
                    resolve(false);
                });
            } else {
                console.log("[enhancedShareUrl] Web Share API not available");
                resolve(false);
            }
        });
    };

    // Try Clipboard API
    window.ChatroomShare.tryClipboardApi = function(url) {
        return new Promise((resolve) => {
            if (navigator.clipboard && navigator.clipboard.writeText) {
                console.log("[enhancedShareUrl] Trying Clipboard API");
                navigator.clipboard.writeText(url)
                    .then(() => {
                        console.log("[enhancedShareUrl] Clipboard API successful");
                        alert("Chat URL copied to clipboard: " + url);
                        resolve(true);
                    })
                    .catch(error => {
                        console.warn("[enhancedShareUrl] Clipboard API failed:", error);
                        resolve(false);
                    });
            } else {
                console.log("[enhancedShareUrl] Clipboard API not available");
                resolve(false);
            }
        });
    };

    // Try execCommand (legacy)
    window.ChatroomShare.tryExecCommand = function(url) {
        return new Promise((resolve) => {
            console.log("[enhancedShareUrl] Trying execCommand");
            try {
                const textArea = document.createElement("textarea");
                textArea.value = url;
                textArea.style.position = "fixed";
                textArea.style.opacity = "0";
                document.body.appendChild(textArea);
                textArea.focus();
                textArea.select();
                
                const successful = document.execCommand("copy");
                document.body.removeChild(textArea);
                
                if (successful) {
                    console.log("[enhancedShareUrl] execCommand successful");
                    alert("Chat URL copied to clipboard: " + url);
                    resolve(true);
                } else {
                    console.warn("[enhancedShareUrl] execCommand failed");
                    resolve(false);
                }
            } catch (err) {
                console.error("[enhancedShareUrl] execCommand error:", err);
                resolve(false);
            }
        });
    };

    // Direct share button for use in Flutter integration
    window.directShareChatUrl = async function(url, title = "Join my chat session") {
        console.log("[directShareChatUrl] Direct share for URL:", url);
        
        try {
            // Try all methods
            const result = await window.ChatroomShare.enhancedShareUrl(url, title);
            return result;
        } catch (error) {
            console.error("[directShareChatUrl] Error:", error);
            return false;
        }
    };

    console.log("[share_fix.js] Enhanced share functions loaded");
})();
