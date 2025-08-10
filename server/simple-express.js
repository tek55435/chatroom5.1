import express from 'express';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
const PORT = 3000;

// Global request logger
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} - ${req.method} ${req.url}`);
  next();
});

// Serve static files
app.use(express.static(path.join(__dirname, 'public')));

// Root route
app.get('/', (req, res) => {
  console.log('GET request to /');
  res.send('Express server is working!');
});

// Test route
app.get('/test', (req, res) => {
  console.log('GET request to /test');
  res.send('Express Test Route is Working!');
});

// Start the server
app.listen(PORT, '0.0.0.0', () => {
  console.log(`Express server running on http://localhost:${PORT}`);
}).on('error', (err) => {
  console.error('Server failed to start:', err);
  if (err.code === 'EADDRINUSE') {
    console.error(`Port ${PORT} is already in use`);
  }
});

console.log('Script executed to this point');
