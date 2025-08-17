Features to implement



Dual Interaction Modes: Users can select between "Type to Speak" and "Speak to Type" modes when creating their persona. 
Dual Interaction Modes: Users select one of two modes that define their primary way of communicating.
Type to Speak: Optimized for users who prefer to type. Their messages are converted to audio and spoken aloud for other users.
Speak to Type: Optimized for users who prefer to speak. Their speech is transcribed into text in real-time. Refine Audio Defaults: Ensure that the "play incoming audio" setting is on by default for "Speak to Type" users and off by default for "Type to Speak" users. 






In-App Help: A permanent "Help" (?) icon in the header allows users to view the app instructions at any time. Add button for but report here too. The Bug Report should be a pop up modal that captures device information and also allows the user to submit text, screenshots, picures, and video recordings. Expandable Instructions: The instructions dialog includes a "Read More" section with more detailed information.

Add a participants button next to the settings button. This should be some sort of modal that pops up. Then users can see who is in the chat with them. 

Speech-to-Text (STT): The "press and hold" microphone functionality is working, transcribing speech to text in real-time.

Auto-Scrolling Chat: The chat view correctly keeps the most recent message visible.

Chat history should be persistent if the user reloads the page. The chat history should only be erased when the last user leaves the chat room



Implement Message Editing: Add the UI (e.g., a pencil icon on your own messages) and the logic to allow users to edit their messages after sending.

Implement Voice Sample Previews: Make the voices in the persona creation dialog playable so users can hear a sample before selecting one.

Add "Now Playing" Indicator: Implement the animated sound wave icon that appears next to a message while its audio is playing. "Now Playing" Indicator: A small, animated sound wave icon appears next to a message while its audio is actively being played, providing clear visual feedback.


Make users auto join. They should not need to click the join button

Allow users to upload their own profile picture in the Settings

Remove Person Icon button to edit the persona. All Persona editing should be done in the setting modal. 











DONE

DONE? Persona Creation: A modal dialog prompts new users to create a persona before joining the chat. This includes:
Name: User enters their custom display name.
Voice Selection: A choice from a curated list of 8 unique voices (e.g., Orion, Aurora, Sterling). Voices play when tapped so users can hear the voice. Avatar: An avatar is automatically generated based on the user's name using the DiceBear API. Persistent Persona: The user's persona is saved locally, so they don't have to create it every time they open the app.

Add Settings Panel: Add settings button to top right corner near share button and help icon button. A settings panel exists and allows users to toggle dark mode and change their interaction mode, update their interaction mode to SST ot TTS, update their profile pictures. 

Implement Sharing Functionality: When the first user Joins/Creates the initial chat, there should be a session random session ID (numeric only) that is appended to the URL. When the share link or invite is sent...this link should include the same session ID at the end of it so the invitee and invited end up in the same chat room. Right now users are not able to join the same chatroom and talk to eachother. Add the "Share" button to the header that generates a QR code and a copyable link to invite others. Also use the devices built-in share feature on phones so they can easily share it vian an app. Please enable the user of session IDs and make it so when a share link is sent to someone, they join the same chat room that the invite was sent from