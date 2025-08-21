# Room Sharing Feature

The Room Sharing feature allows users to generate and share direct links to their chatrooms, making it easy for others to join the conversation.

## How It Works

1. When a user creates or joins a room, they can click the "Share" button in the app bar
2. The system generates a unique URL containing the room ID as a query parameter
3. This URL is copied to the clipboard and can also be shared via the Web Share API (if supported by the browser)
4. When someone opens the shared link, the application automatically detects the room ID from the URL
5. The user is then prompted to set up their persona (name and accessibility mode)
6. After completing the persona setup, they're automatically joined to the shared room

## Technical Implementation

### Client-Side (Flutter)

- The Flutter app checks for room ID parameters in the URL on startup
- It uses JavaScript interop to access window.sharedRoomId
- When a shared room ID is detected, it prompts the user for their persona details
- After the persona is configured, it automatically connects to the room

### Server-Side (Node.js)

- The server detects room ID parameters in the request URL
- It logs information about shared room accesses
- The server checks if the requested room exists and logs the participant count

### Web Integration

- webrtc_diagnostic.js extracts the room parameter from the URL
- It makes this parameter available to the Flutter app via window.sharedRoomId
- A generateShareableLink function helps create properly formatted share URLs

## User Experience

- Users don't need to manually type or remember room IDs
- Direct links create a seamless joining experience
- The persona setup ensures new users still configure their accessibility preferences before joining
- Share button provides immediate feedback with a snackbar showing the copied link

## Security Considerations

- Room IDs are randomly generated alphanumeric strings
- No sensitive information is included in the URL
- Users still need to configure their persona before joining a room
