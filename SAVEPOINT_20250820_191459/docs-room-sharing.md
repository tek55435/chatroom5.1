# Room Sharing in HearAll Chat Application

## Overview

The room sharing feature allows users to share links to specific chat rooms, enabling others to join directly without having to manually enter the room ID. When users open a shared link, they will automatically be prompted to set up their persona and then join the specified room.

## How It Works

1. **Room Link Generation**: When a user clicks the "Share Room" button, a link containing the room ID is generated and copied to the clipboard.

2. **URL Parameter Handling**: The application checks for a "room" URL parameter when loading, and automatically uses it to join the specified room.

3. **Auto-Join Flow**: When a user opens a shared link:
   - The application detects the room ID from the URL
   - The persona dialog is immediately shown to set up their name and voice
   - After completing the persona setup, they automatically join the specified room

## Implementation Details

### Client-Side

- **URL Parameter Detection**: JavaScript code extracts the room ID from the URL and exposes it to the Flutter app.
- **Automatic Room Joining**: After persona setup, the Flutter app automatically joins the detected room.
- **Share Link Generation**: Uses the WebShare API when available, with clipboard fallback.

### Server-Side

- **Route Handling**: The server checks for room ID parameters and logs relevant information.
- **Room Validation**: The server validates if the room exists before joining.

## JavaScript Helpers

Two key JavaScript functions are provided:

```javascript
// Extract room ID from URL parameters
function getRoomIdFromUrl() {
  const urlParams = new URLSearchParams(window.location.search);
  return urlParams.get('room');
}

// Generate a shareable link for a room
function generateShareableLink(roomId) {
  const url = new URL(window.location.href);
  url.search = '';
  url.searchParams.set('room', roomId);
  return url.toString();
}
```

## User Experience

1. **Sharing a Room**:
   - User clicks the "Share" button in the app header
   - A shareable link is generated and copied to clipboard
   - A notification confirms the link was copied

2. **Joining via Shared Link**:
   - User opens the shared link in a browser
   - The persona dialog appears immediately
   - After setting name and voice, they join the room automatically

## Testing

To test room sharing:

1. Start a session and join a room
2. Click the "Share" button
3. Open the generated link in a new browser window
4. Verify that the persona dialog appears and joining works correctly after setup

## Troubleshooting

- If auto-join doesn't work, check browser console for JavaScript errors
- Verify that all required script files are loaded correctly
- Check that the room ID is correctly passed in the URL
