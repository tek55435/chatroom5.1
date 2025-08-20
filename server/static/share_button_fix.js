// Direct share button fix for Chatroom5
// This uses a straightforward approach that works even in Firefox and Safari

// Create a global share function
// Direct fix for joining a chat
window.directJoinChat = function(sessionId) {
    console.log("[directJoinChat] Starting direct join with session ID:", sessionId || "new");
    
    try {
        // Generate ID if not provided
        if (!sessionId) {
            sessionId = '';
            for (let i = 0; i < 8; i++) {
                sessionId += Math.floor(Math.random() * 10);
            }
            console.log("[directJoinChat] Generated session ID:", sessionId);
        }
        
        // Call connect directly
        window.EphemeralChat.connect(
            sessionId,
            function(sid) {
                console.log("[directJoinChat] Connected with session:", sid);
                if (typeof window.dartChatConnectionChanged === "function") {
                    window.dartChatConnectionChanged(true, null);
                }
                alert("Successfully joined chat session: " + sid);
            },
            function(data) {
                console.log("[directJoinChat] Received message:", data);
                if (typeof window.dartChatMessageReceived === "function") {
                    window.dartChatMessageReceived(JSON.stringify(data));
                }
            },
            function() {
                console.log("[directJoinChat] Disconnected");
                if (typeof window.dartChatConnectionChanged === "function") {
                    window.dartChatConnectionChanged(false, null);
                }
            },
            function(err) {
                console.error("[directJoinChat] Error:", err);
                if (typeof window.dartChatConnectionChanged === "function") {
                    window.dartChatConnectionChanged(false, err ? err.toString() : "Unknown error");
                }
                alert("Error joining chat: " + (err ? err.toString() : "Unknown error"));
            }
        );
        
        return sessionId;
    } catch (err) {
        console.error("[directJoinChat] Exception:", err);
        alert("Failed to join chat: " + err.toString());
        return null;
    }
};

window.shareEphemeralChatUrl = function(url, title) {
    console.log("[shareEphemeralChatUrl] Called with URL:", url);
    
    try {
        // If Web Share API is available and not Firefox (where it's partially implemented)
        if (navigator.share && navigator.userAgent.indexOf("Firefox") === -1) {
            navigator.share({
                title: title || "Join my chat session",
                text: "Join my ephemeral chat session",
                url: url
            })
            .then(() => console.log("[shareEphemeralChatUrl] Share successful via Web Share API"))
            .catch(error => {
                console.error("[shareEphemeralChatUrl] Error sharing via Web Share API:", error);
                fallbackToClipboard(url);
            });
        } else {
            // Use clipboard fallback
            fallbackToClipboard(url);
        }
    } catch (err) {
        console.error("[shareEphemeralChatUrl] Error:", err);
        fallbackToClipboard(url);
    }
    
    // Return true to indicate function executed (not necessarily successful share)
    return true;
};

function fallbackToClipboard(url) {
    console.log("[fallbackToClipboard] Using clipboard fallback");
    
    // Create temporary textarea
    const textArea = document.createElement("textarea");
    textArea.value = url;
    textArea.style.position = "fixed";
    textArea.style.opacity = "0";
    document.body.appendChild(textArea);
    
    try {
        // Select and copy text
        textArea.select();
        const success = document.execCommand("copy");
        
        // Show alert based on success
        if (success) {
            console.log("[fallbackToClipboard] URL copied to clipboard successfully");
            window.alert("Chat URL has been copied to your clipboard:\n\n" + url);
        } else {
            console.error("[fallbackToClipboard] Failed to copy URL to clipboard");
            window.alert("Please copy this chat URL manually:\n\n" + url);
        }
    } catch (err) {
        console.error("[fallbackToClipboard] Error:", err);
        window.alert("Please copy this chat URL manually:\n\n" + url);
    } finally {
        // Clean up
        document.body.removeChild(textArea);
    }
}

console.log("[share_button_fix.js] Loaded successfully");
