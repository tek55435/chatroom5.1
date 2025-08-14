// webrtc_helper.js extension for room sharing

// Function to extract room ID from URL parameters
function getRoomIdFromUrl() {
  const urlParams = new URLSearchParams(window.location.search);
  const roomId = urlParams.get('room');
  return roomId;
}

// Expose the room ID to the Flutter app
window.sharedRoomId = getRoomIdFromUrl();

// Generate a shareable link for a room
function generateShareableLink(roomId) {
  if (!roomId) return null;
  
  // Get the base URL (without query parameters)
  const url = new URL(window.location.href);
  url.search = ''; // Clear existing query parameters
  
  // Add the room parameter
  url.searchParams.set('room', roomId);
  
  return url.toString();
}

// Initialize when the document is loaded
document.addEventListener('DOMContentLoaded', () => {
  console.log("Room sharing helpers initialized");
  if (window.sharedRoomId) {
    console.log(`Detected shared room ID: ${window.sharedRoomId}`);
  }
});

// Expose functions to global scope
window.getRoomIdFromUrl = getRoomIdFromUrl;
window.generateShareableLink = generateShareableLink;
