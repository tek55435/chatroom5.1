/**
 * Direct debug tool for the share functionality
 * This file adds a simple debug utility to test sharing from the console
 */

// Add a debug namespace
window.ShareDebug = {
    // Test if our share functions are correctly loaded
    testShareFunctions: function() {
        console.log('=== SHARE FUNCTION DEBUG TEST ===');
        
        // Test 1: Check if ChatroomShare exists
        console.log('ChatroomShare exists:', typeof window.ChatroomShare === 'object');
        
        // Test 2: Check shareUrl function
        console.log('ChatroomShare.shareUrl exists:', 
            typeof window.ChatroomShare === 'object' && 
            typeof window.ChatroomShare.shareUrl === 'function');
            
        // Test 3: Check enhancedShareUrl function
        console.log('ChatroomShare.enhancedShareUrl exists:', 
            typeof window.ChatroomShare === 'object' && 
            typeof window.ChatroomShare.enhancedShareUrl === 'function');
        
        // Test 4: Check direct functions
        console.log('directChatShare exists:', typeof window.directChatShare === 'function');
        console.log('shareChat exists:', typeof window.shareChat === 'function');
        console.log('shareEphemeralChatUrl exists:', typeof window.shareEphemeralChatUrl === 'function');
        console.log('EphemeralChatShare exists:', typeof window.EphemeralChatShare === 'object');
        
        // Test 5: Check Web Share API
        console.log('Web Share API available:', typeof navigator.share === 'function');
        
        console.log('=== END DEBUG TEST ===');
        return true;
    },
    
    // Attempt to directly invoke share with a test URL
    testShare: function() {
        const testUrl = window.location.href + '?test=true';
        console.log('Testing share with URL:', testUrl);
        
        // Try each share method directly
        try {
            if (typeof window.directShareChatUrl === 'function') {
                console.log('Trying directShareChatUrl...');
                return window.directShareChatUrl(testUrl);
            } else if (typeof window.ChatroomShare === 'object' && 
                       typeof window.ChatroomShare.enhancedShareUrl === 'function') {
                console.log('Trying ChatroomShare.enhancedShareUrl...');
                return window.ChatroomShare.enhancedShareUrl(testUrl);
            } else if (typeof window.shareEphemeralChatUrl === 'function') {
                console.log('Trying shareEphemeralChatUrl...');
                return window.shareEphemeralChatUrl(testUrl);
            } else if (typeof window.ChatroomShare === 'object' && 
                       typeof window.ChatroomShare.shareUrl === 'function') {
                console.log('Trying ChatroomShare.shareUrl...');
                return window.ChatroomShare.shareUrl(testUrl);
            } else if (navigator.clipboard && navigator.clipboard.writeText) {
                console.log('Trying navigator.clipboard.writeText...');
                navigator.clipboard.writeText(testUrl);
                alert('URL copied to clipboard: ' + testUrl);
                return true;
            } else {
                console.log('No share methods available!');
                alert('Unable to share. Copy this URL manually: ' + testUrl);
                return false;
            }
        } catch (error) {
            console.error('Error in testShare:', error);
            alert('Error while sharing: ' + error.toString());
            return false;
        }
    }
};

// Add a direct function on window
window.testShareButton = function() {
    return window.ShareDebug.testShare();
};

// Log that we've loaded
console.log('Share debug tools loaded successfully');
