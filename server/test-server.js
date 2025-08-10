import http from 'http';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const PORT = 3000;

const server = http.createServer((req, res) => {
  console.log(`Request received: ${req.url}`);
  
  if (req.url === "/") {
    res.writeHead(200, { "Content-Type": "text/html" });
    res.end("<html><body><h1>Server is working!</h1></body></html>");
  } else {
    const filePath = path.join(__dirname, "public", req.url);
    fs.readFile(filePath, (err, data) => {
      if (err) {
        console.error(`Error reading file ${filePath}:`, err);
        res.writeHead(404);
        res.end("File not found");
        return;
      }
      
      console.log(`Serving file: ${filePath}`);
      res.writeHead(200);
      res.end(data);
    });
  }
});

server.listen(PORT, "0.0.0.0", () => {
  console.log(`Test server running on http://localhost:${PORT}`);
});
