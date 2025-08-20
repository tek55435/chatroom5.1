const http = require('http');
const fs = require('fs');
const path = require('path');
const { URL } = require('url');
const https = require('https');

// Load environment variables from .env file if available
try {
  const envPath = path.join(__dirname, '.env');
  console.log(`Looking for .env file at: ${envPath}`);
  
  // Check if .env file exists
  if (fs.existsSync(envPath)) {
    console.log('.env file found, attempting to load...');
    // Simple .env file parser since we may not have dotenv installed
    const envContent = fs.readFileSync(envPath, 'utf8');
    console.log(`Loaded .env file content (${envContent.length} bytes)`);
    
    const envConfig = envContent
      .split('\n')
      .filter(line => line.trim() && !line.startsWith('#'))
      .reduce((acc, line) => {
        const parts = line.split('=');
        if (parts.length >= 2) {
          const key = parts[0].trim();
          // Join back parts in case the value itself contains = characters
          const value = parts.slice(1).join('=').trim();
          acc[key] = value;
          console.log(`Loaded env variable: ${key}=${value.substring(0, 4)}...`);
        }
        return acc;
      }, {});
      
    // Set environment variables
    Object.keys(envConfig).forEach(key => {
      if (!process.env[key]) {
        process.env[key] = envConfig[key];
        console.log(`Set process.env.${key} from .env file`);
      }
    });
    
    console.log('Successfully loaded environment variables from .env file');
  } else {
    console.log('No .env file found. Please create one based on .env.example');
  }
} catch (error) {
  console.error('Error loading .env file:', error);
}

// OpenAI API configuration
const OPENAI_API_KEY = process.env.OPENAI_API_KEY || ''; // Get API key from environment variable

const PORT = process.env.PORT || 3000;

const MIME_TYPES = {
  '.html': 'text/html',
  '.js': 'application/javascript',
  '.css': 'text/css',
  '.json': 'application/json',
  '.png': 'image/png',
  '.jpg': 'image/jpg',
  '.wav': 'audio/wav',
};

// Function to handle multipart form data parsing for STT
function parseMultipartForm(req, callback) {
  const contentType = req.headers['content-type'] || '';
  const boundary = contentType.split('boundary=')[1];
  
  if (!boundary) {
    callback(new Error('No boundary found in multipart form data'));
    return;
  }
  
  let body = [];
  req.on('data', (chunk) => {
    body.push(chunk);
  });
  
  req.on('end', () => {
    body = Buffer.concat(body);
    
    // Find the file data in the multipart form
    const boundaryBuffer = Buffer.from(`--${boundary}`);
    let startPos = body.indexOf(boundaryBuffer) + boundaryBuffer.length;
    let endPos = body.indexOf(boundaryBuffer, startPos);
    
    if (endPos === -1) {
      callback(new Error('Could not find file in form data'));
      return;
    }
    
    const headers = {};
    let headerEnd = body.indexOf(Buffer.from('\r\n\r\n'), startPos);
    
    // Parse headers
    const headerText = body.slice(startPos, headerEnd).toString();
    const headerLines = headerText.split('\r\n');
    for (const line of headerLines) {
      if (!line.includes(':')) continue;
      const [key, value] = line.split(':').map(part => part.trim());
      headers[key.toLowerCase()] = value;
    }
    
    // Extract file data
    const dataStart = headerEnd + 4; // Skip \r\n\r\n
    const dataEnd = endPos - 2; // Exclude \r\n before boundary
    const fileData = body.slice(dataStart, dataEnd);
    
    callback(null, { fileData, headers });
  });
}

// Function to handle JSON body parsing
function parseJsonBody(req, callback) {
  let body = [];
  req.on('data', (chunk) => {
    body.push(chunk);
  });
  
  req.on('end', () => {
    body = Buffer.concat(body).toString();
    try {
      const jsonData = JSON.parse(body);
      callback(null, jsonData);
    } catch (err) {
      callback(err);
    }
  });
}

// Function to make TTS request to OpenAI API
async function makeTTSRequest(text) {
  return new Promise((resolve, reject) => {
    if (!OPENAI_API_KEY) {
      reject(new Error('OpenAI API key not set. Please set the OPENAI_API_KEY environment variable.'));
      return;
    }
    
    const requestData = JSON.stringify({
      model: 'tts-1',
      input: text,
      voice: 'alloy', // Can be 'alloy', 'echo', 'fable', 'onyx', 'nova', or 'shimmer'
      response_format: 'mp3'
    });
    
    const options = {
      hostname: 'api.openai.com',
      port: 443,
      path: '/v1/audio/speech',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${OPENAI_API_KEY}`,
        'Content-Length': requestData.length
      }
    };
    
    const req = https.request(options, (res) => {
      if (res.statusCode !== 200) {
        let errorData = '';
        res.on('data', (chunk) => {
          errorData += chunk;
        });
        res.on('end', () => {
          reject(new Error(`OpenAI API returned ${res.statusCode}: ${errorData}`));
        });
        return;
      }
      
      const chunks = [];
      res.on('data', (chunk) => {
        chunks.push(chunk);
      });
      res.on('end', () => {
        const buffer = Buffer.concat(chunks);
        resolve(buffer);
      });
    });
    
    req.on('error', (error) => {
      reject(error);
    });
    
    req.write(requestData);
    req.end();
  });
}

// Function to make STT request to OpenAI API
async function makeSTTRequest(audioBuffer) {
  return new Promise((resolve, reject) => {
    if (!OPENAI_API_KEY) {
      reject(new Error('OpenAI API key not set. Please set the OPENAI_API_KEY environment variable.'));
      return;
    }
    
    // Boundary for multipart form data
    const boundary = `boundary_${Date.now().toString(16)}`;
    
    // Prepare form data parts
    const formParts = [
      `--${boundary}\r\n`,
      'Content-Disposition: form-data; name="file"; filename="recording.webm"\r\n',
      'Content-Type: audio/webm\r\n\r\n'
    ];
    
    // Add file data and closing boundary
    const dataParts = [
      Buffer.from(formParts.join('')),
      audioBuffer,
      Buffer.from(`\r\n--${boundary}\r\n`),
      Buffer.from('Content-Disposition: form-data; name="model"\r\n\r\n'),
      Buffer.from('whisper-1\r\n'),
      Buffer.from(`--${boundary}--\r\n`)
    ];
    
    const requestBody = Buffer.concat(dataParts);
    
    const options = {
      hostname: 'api.openai.com',
      port: 443,
      path: '/v1/audio/transcriptions',
      method: 'POST',
      headers: {
        'Content-Type': `multipart/form-data; boundary=${boundary}`,
        'Authorization': `Bearer ${OPENAI_API_KEY}`,
        'Content-Length': requestBody.length
      }
    };
    
    const req = https.request(options, (res) => {
      if (res.statusCode !== 200) {
        let errorData = '';
        res.on('data', (chunk) => {
          errorData += chunk;
        });
        res.on('end', () => {
          reject(new Error(`OpenAI API returned ${res.statusCode}: ${errorData}`));
        });
        return;
      }
      
      let responseData = '';
      res.on('data', (chunk) => {
        responseData += chunk;
      });
      res.on('end', () => {
        try {
          const jsonResponse = JSON.parse(responseData);
          resolve(jsonResponse);
        } catch (error) {
          reject(new Error(`Failed to parse API response: ${error.message}`));
        }
      });
    });
    
    req.on('error', (error) => {
      reject(error);
    });
    
    req.write(requestBody);
    req.end();
  });
}

const server = http.createServer(async (req, res) => {
  console.log(`Request received: ${req.method} ${req.url}`);
  
  // Parse the URL
  const parsedUrl = new URL(req.url, `http://localhost:${PORT}`);
  const pathname = parsedUrl.pathname;
  
  // Handle API requests
  if (pathname === '/api/tts' && req.method === 'POST') {
    parseJsonBody(req, async (err, jsonData) => {
      if (err) {
        console.error('Error parsing JSON:', err);
        res.writeHead(400);
        res.end(JSON.stringify({ error: 'Invalid JSON' }));
        return;
      }
      
      if (!jsonData.text) {
        res.writeHead(400);
        res.end(JSON.stringify({ error: 'No text provided' }));
        return;
      }
      
      try {
        console.log(`Processing TTS request for text: "${jsonData.text}"`);
        const audioBuffer = await makeTTSRequest(jsonData.text);
        console.log(`TTS response received: ${audioBuffer.length} bytes of MP3 audio`);
        
        // Set proper headers for MP3 audio
        res.writeHead(200, {
          'Content-Type': 'audio/mpeg', // More standard MIME type for MP3
          'Content-Length': audioBuffer.length,
          'Cache-Control': 'no-cache' // Prevent caching issues
        });
        res.end(audioBuffer);
      } catch (error) {
        console.error('Error with TTS API:', error);
        res.writeHead(500);
        res.end(JSON.stringify({ error: error.message }));
      }
    });
    return;
  }
  
  // Handle Speech-to-Text API
  if (pathname === '/api/stt' && req.method === 'POST') {
    parseMultipartForm(req, async (err, formData) => {
      if (err) {
        console.error('Error parsing form data:', err);
        res.writeHead(400);
        res.end(JSON.stringify({ error: 'Invalid form data' }));
        return;
      }
      
      if (!formData || !formData.fileData) {
        res.writeHead(400);
        res.end(JSON.stringify({ error: 'No audio file provided' }));
        return;
      }
      
      try {
        console.log(`Processing STT request: ${formData.fileData.length} bytes of audio data`);
        const transcriptionResult = await makeSTTRequest(formData.fileData);
        console.log('STT response received:', transcriptionResult);
        
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify(transcriptionResult));
      } catch (error) {
        console.error('Error with STT API:', error);
        res.writeHead(500);
        res.end(JSON.stringify({ error: error.message }));
      }
    });
    return;
  }
  
  // Handle static files
  let filePath = pathname === '/' ? '/audio-test.html' : pathname;
  filePath = path.join(__dirname, 'public', filePath);
  
  // Get the file extension
  const extname = path.extname(filePath);
  const contentType = MIME_TYPES[extname] || 'text/plain';
  
  // Read the file
  fs.readFile(filePath, (err, content) => {
    if (err) {
      if (err.code === 'ENOENT') {
        console.error(`File not found: ${filePath}`);
        res.writeHead(404);
        res.end('File not found');
      } else {
        console.error(`Server error: ${err.code}`);
        res.writeHead(500);
        res.end(`Server Error: ${err.code}`);
      }
    } else {
      console.log(`Serving file: ${filePath} as ${contentType}`);
      res.writeHead(200, { 'Content-Type': contentType });
      res.end(content);
    }
  });
});

server.listen(PORT, () => {
  console.log(`Audio test server running at http://localhost:${PORT}`);
  console.log(`Open http://localhost:${PORT}/audio-test.html to test audio functionality`);
  
  if (!OPENAI_API_KEY) {
    console.warn('\n⚠️  WARNING: OpenAI API key not set. TTS and STT features will not work.');
    console.warn('Set the OPENAI_API_KEY environment variable to use these features.\n');
  } else {
    console.log(`\n✅ OpenAI API key loaded successfully (starts with: ${OPENAI_API_KEY.substring(0, 10)}...)`);
    console.log('TTS and STT features should work properly.\n');
  }
});
