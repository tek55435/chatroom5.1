# TTS Handler Testing

This folder contains a test setup for evaluating and debugging the Text-to-Speech (TTS) handler functionality in the Chatroom5 application.

## Components

- `tts_handler.js`: Processes WebRTC data channel messages and handles TTS audio playback
- `pcm_helper.js`: Helper functions for handling PCM audio buffers and audio playback
- `tts-test-server.js`: Express server for testing the TTS functionality
- `tts-test.html`: Simple HTML test page for manual testing

## Running the Test Server

To run the test server:

```
cd c:\Dev\Chatroom5\server
node tts-test-server.js
```

The server will start on http://localhost:3000

## Testing Methods

### Method 1: Using the Test Page

1. Start the test server
2. Open http://localhost:3000/tts-test in your browser
3. Click "Initialize Audio Context" to initialize the Web Audio API
4. Click "Test Audio Output" to verify that audio playback works
5. Enter text in the textarea and click "Send TTS Request" to simulate a TTS request
6. Use the individual buttons to test specific functionality:
   - "Send Audio Metadata" - Sends audio format information
   - "Send Audio Chunk" - Sends a test audio chunk

### Method 2: Using the API Endpoints

The test server provides REST API endpoints for testing:

- `POST /api/tts` - Submit a TTS request
  ```
  curl -X POST http://localhost:3000/api/tts -H "Content-Type: application/json" -d "{\"text\":\"Hello, this is a test\"}"
  ```

- `GET /api/tts/:id/audio` - Get audio data for a TTS request
  ```
  curl http://localhost:3000/api/tts/abc123/audio
  ```

### Method 3: Using the HTML Test Page

A simple HTML test page is available at http://localhost:3000/tts-test.html which provides a UI for testing the TTS functionality.

## Debugging

The test page includes a log area that shows detailed information about the TTS process. You can also use the browser's developer console to see more detailed logs.

### Common Issues

1. **Audio playback not working**
   - Check that your browser allows audio playback
   - Make sure audio context is initialized and running
   - Verify that audio data is being received correctly

2. **WebRTC data channel errors**
   - These tests simulate WebRTC data channel communication, but do not use actual WebRTC
   - Check the message format if errors occur

## TTS Handler Flow

1. Client sends a text message (`conversation.item.create`)
2. Server responds with audio metadata (`audio.metadata`)
3. Server sends audio chunks (`audio.chunk`)
4. Client processes audio chunks and plays them

This test setup allows testing each part of this flow individually.
