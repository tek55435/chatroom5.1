/**
 * Direct debugging functions for chat functionality 
 */

console.log("Loading chat-debug.js...");

// Add a direct test method to the window object
window.testChatConnection = function() {
    console.log("=== Testing Chat Connection ===");
    
    try {
        // 1. Test if EphemeralChat is properly defined
        if (typeof window.EphemeralChat === "undefined") {
            console.error("EphemeralChat is not defined");
            alert("Error: EphemeralChat is not defined. Check the JavaScript includes.");
            return false;
        }
        
        // 2. Test session ID generation
        const sessionId = window.EphemeralChat.generateSessionId();
        console.log("Generated session ID:", sessionId);
        if (!sessionId || sessionId.length !== 8) {
            console.error("Session ID generation failed or returned invalid ID:", sessionId);
            alert("Error: Could not generate valid session ID");
            return false;
        }
        
        // 3. Try connecting directly
        console.log("Attempting direct connection with session ID:", sessionId);
        
        window.EphemeralChat.connect(
            sessionId,
            function(sid) {
                console.log("Connection SUCCESS. Session ID:", sid);
                alert("Connection successful with session ID: " + sid);
                
                // Test message sending
                const messageSent = window.EphemeralChat.sendMessage("Test message from direct JavaScript", "TestUser");
                console.log("Message sent result:", messageSent);
            },
            function(data) {
                console.log("Received message:", data);
            },
            function() {
                console.log("Connection closed");
                alert("Connection closed");
            },
            function(error) {
                console.error("Connection error:", error);
                alert("Connection error: " + error);
            }
        );
        
        console.log("Connection attempt initiated");
        return true;
    } catch (error) {
        console.error("Error in testChatConnection:", error);
        alert("Error testing chat connection: " + error.message);
        return false;
    }
};

// Add a method to fix any missing functions
window.repairChatFunctions = function() {
    console.log("=== Repairing Chat Functions ===");
    
    // Ensure generateSessionId works correctly
    if (typeof window.EphemeralChat !== "undefined") {
        const originalGenerateSessionId = window.EphemeralChat.generateSessionId;
        window.EphemeralChat.generateSessionId = function() {
            try {
                console.log("Enhanced generateSessionId called");
                // Call original if it exists
                if (typeof originalGenerateSessionId === "function") {
                    const id = originalGenerateSessionId.call(window.EphemeralChat);
                    console.log("Original generateSessionId returned:", id);
                    
                    // Verify and fix if necessary
                    if (id && id.length === 8) {
                        return id;
                    }
                    
                    console.warn("Original generateSessionId returned invalid ID, using fallback");
                }
                
                // Fallback implementation
                let id = '';
                for (let i = 0; i < 8; i++) {
                    id += Math.floor(Math.random() * 10);
                }
                console.log("Fallback generated ID:", id);
                return id;
            } catch (e) {
                console.error("Error in enhanced generateSessionId:", e);
                // Emergency fallback
                return String(Math.floor(Math.random() * 100000000)).padStart(8, '0');
            }
        };
        
        console.log("Enhanced generateSessionId function installed");
    } else {
        console.error("Cannot repair: EphemeralChat not defined");
        return false;
    }
    
    return true;
};

// Run repair automatically
try {
    window.repairChatFunctions();
    console.log("Chat functions repaired successfully");
} catch (e) {
    console.error("Failed to repair chat functions:", e);
}

console.log("chat-debug.js loaded successfully!");
