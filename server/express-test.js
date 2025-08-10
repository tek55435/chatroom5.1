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

// Serve static files with detailed logging
app.use(express.static(path.join(__dirname, 'public'), { 
  setHeaders: (res, path) => {
    console.log(`Serving static file: ${path}`);
  }
}));

// Root route
app.get('/', (req, res) => {
  console.log('GET request to /');
  res.sendFile(path.join(__dirname, 'public/index.html'));
});

// Test route
app.get('/test', (req, res) => {
  console.log('GET request to /test');
  res.send('Express Test Route is Working!');
});

// Start the server
const server = app.listen(PORT, '0.0.0.0', () => {
  console.log(`Express test server running on http://localhost:${PORT}`);
  console.log(`Server address: ${JSON.stringify(server.address())}`);
}).on('error', (err) => {
  console.error('Server failed to start:', err);
  if (err.code === 'EADDRINUSE') {
    console.error(`Port ${PORT} is already in use. Please close the application using this port or change the PORT value.`);
  }
});
