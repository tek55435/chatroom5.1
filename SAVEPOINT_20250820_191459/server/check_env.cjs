require('dotenv').config();
if (process.env.OPENAI_API_KEY) {
  console.log('OPENAI_KEY_LOADED');
} else {
  console.log('OPENAI_KEY_MISSING');
}
