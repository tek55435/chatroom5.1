Chatroom Features

✅ Features Already Implemented
Your app already has a strong foundation with these key features fully integrated:
Persona Creation: A dialog prompts new users to create a persona, including a custom name, voice selection, and an auto-generated avatar.
Dual Interaction Modes: Users can select between "Type to Speak" and "Speak to Type" modes when creating their persona.
Speech-to-Text (STT): The core "press and hold" microphone functionality is working, transcribing speech to text in real-time.
Real-time Chat: The app successfully sends and receives messages in real-time using Firebase.
Sticky Header & Footer: The app bar and message input bar are fixed and always visible.
Auto-Scrolling Chat: The chat view correctly keeps the most recent message visible.
Persistent Persona: The user's persona is saved locally, so they don't have to create it every time they open the app.
Basic Settings Panel: A settings panel exists and allows users to toggle dark mode and change their interaction mode.

📝 Features to Be Implemented (In Order of Priority)
Here is the prioritized list of what's needed to complete the app and fully match the functionality of your Next.js version.
High Priority (Core Functionality & UX)
Implement Text-to-Speech (TTS) Playback: This is the most critical missing feature. Messages from "Type to Speak" users need to be converted to audio and played automatically.
SHare button should be disabled until user has started a session ID
Add a “Start New Chat” button in the settings menu
Add Onboarding & Help Dialogs: Create the one-time welcome instructions dialog with a "Don't show this again" option and add a persistent help icon in the header to view them again.
Implement Message Editing: Add the UI (e.g., a pencil icon on your own messages) and the logic to allow users to edit their messages after sending.
Add Send Button to Input Bar: Re-introduce the dedicated "Send" button next to the microphone icon in the message input field.
Implement Voice Sample Previews: Make the voices in the persona creation dialog playable so users can hear a sample before selecting one.
Medium Priority (Key Enhancements)
Enhance the Settings Panel:
Allow users to update their persona (name and voice) from within the settings.
Add the mode-specific toggles: "Single-Device Audio" and "Auto-Send on Mic Release."
Add "Now Playing" Indicator: Implement the animated sound wave icon that appears next to a message while its audio is playing.
Implement Sharing Functionality: Add the "Share" button to the header that generates a QR code and a copyable link to invite others.
Low Priority (Polishing & Final Touches)
Add New Message Highlight: Implement the subtle, fading highlight animation for new messages as they appear in the chat.
Implement Bug Reporting: Add the "Report a Bug" button to the help dialog that opens the user's email client with a pre-filled template.
Refine Audio Defaults: Ensure that the "play incoming audio" setting is on by default for "Speak to Type" users and off by default for "Type to Speak" users. 








OLD


User Persona & Interaction Modes
Persona Creation: A modal dialog prompts new users to create a persona before joining the chat. This includes:
Name: A custom display name.
Voice Selection: A choice from a curated list of 8 unique voices (e.g., Orion, Aurora, Sterling).
Voices play when tapped so users can hear the voice
Avatar: An avatar is automatically generated based on the user's name using the DiceBear API.


Dual Interaction Modes: Users select one of two modes that define their primary way of communicating.
Type to Speak: Optimized for users who prefer to type. Their messages are converted to audio and spoken aloud for other users.
Speak to Type: Optimized for users who prefer to speak. Their speech is transcribed into text in real-time.


Audio & Speech Features
Text-to-Speech (TTS): Messages sent by users in "Type to Speak" mode are automatically converted to audio and played on the devices of users who have incoming audio enabled. Play audio is on by default for users who speak-to-text. Play audio is off by default for users who do text-to-speech
Speech-to-Text (STT): The microphone button allows "Speak to Type" users to speak their messages, which are transcribed live and in real time while the user is holding the mic button.
"Press and Hold" Microphone: The mic button functions like a walkie-talkie; the user presses to talk and releases to stop.
DO WE NEED THIS FEATURE? Autoplay Unlock: The app correctly handles browser security policies by requiring a one-time user interaction (like clicking "Enable Audio") to unlock automatic audio playback for the session.
No Historical Audio: When a user joins a chat, the app correctly prevents the audio of all previous messages from playing, only playing new messages that arrive in real-time.
"Now Playing" Indicator: A small, animated sound wave icon appears next to a message while its audio is actively being played, providing clear visual feedback.
Voice Sample Previews: Users can click on any voice in the selection menu to hear a short, pre-recorded sample.
User Interface (UI) & User Experience (UX)
Sticky Header & Footer: The header and the message input bar are fixed to the top and bottom of the screen, ensuring they are always visible, even on mobile.
Auto-Scrolling Chat: The chat view automatically scrolls to the bottom whenever a new message is posted so the latest message is always in view.
New Message Highlight: The most recent message in the chat is briefly highlighted with a subtle, fading background color to provide a visual cue.
Persistent Persona: The user's created persona is saved to local storage, so they don't have to create it again on subsequent visits.
Message Editing: Users can edit their own messages after they've been sent. The UI includes an auto-resizing text area and keyboard shortcuts (Enter to save, Esc to cancel).
Need a “send” button next to the mic button in the message input field


Settings & Onboarding
Initial Persona Dialog: A non-dismissable, scrollable modal that guides new users through the required setup process.
One-Time Instructions: A welcome dialog appears for new users with a "Don't show this again" option.
In-App Help: A permanent "Help" (?) icon in the header allows users to view the instructions at any time.
Expandable Instructions: The instructions dialog includes a "Read More" section with more detailed information.
Bug Reporting: A "Report a Bug" button in the instructions dialog opens the user's email client with a pre-filled template.
Sharing: A "Share" button in the header uses the native Web Share API on mobile to easily send the chat link.
Settings Panel: A dedicated panel for users to:
Update their persona (name and voice).
Switch between "Type to Speak" and "Speak to Type" modes.
Toggle mode-specific settings like "Single-Device Audio" and "Auto-Send on Mic Release."
Toggle Dark Mode.
Invite friends using a QR code and a copyable link.





Create a New Function: Click the "Create Function" button and use these settings:
Function name: hearall-tts
Region: Choose a region close to your users (e.g., us-central1).
Trigger type: Select "HTTP".
Authentication: For development, select "Allow unauthenticated invocations". Note: For a production app, you would want to secure this.

