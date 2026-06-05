const http = require('http');
const { spawn, execSync } = require('child_process');
const path = require('path');
const fs = require('fs');

const TARGET_PORT = 8081; // Local port for Python FastAPI
const PORT = process.env.PORT || 3000; // Port provided by Plesk / Phusion Passenger

// 1. Self-healing Python Venv Setup (Runs if venv is missing)
const venvPath = path.join(__dirname, 'venv');
if (!fs.existsSync(venvPath)) {
  console.log('[Proxy Setup] Python virtual environment not found. Creating and installing packages...');
  try {
    execSync('python3 -m venv venv', { cwd: __dirname, stdio: 'inherit' });
    
    // Determine the pip path based on OS
    const pipPath = process.platform === 'win32' 
      ? path.join(venvPath, 'Scripts', 'pip')
      : path.join(venvPath, 'bin', 'pip');

    execSync(`"${pipPath}" install --upgrade pip`, { cwd: __dirname, stdio: 'inherit' });
    execSync(`"${pipPath}" install -r requirements.txt`, { cwd: __dirname, stdio: 'inherit' });
    console.log('[Proxy Setup] Python dependencies installed successfully!');
  } catch (error) {
    console.error('[Proxy Setup Error] Failed to create venv or install packages:', error.message);
  }
}

// 2. Determine Python path and spawn uvicorn FastAPI process
const pythonBin = process.platform === 'win32'
  ? path.join(venvPath, 'Scripts', 'python')
  : path.join(venvPath, 'bin', 'python');
const pythonCmd = fs.existsSync(pythonBin) ? pythonBin : 'python3';

console.log(`[Proxy] Starting FastAPI backend using: ${pythonCmd}`);
const fastapi = spawn(
  pythonCmd, 
  ['-m', 'uvicorn', 'main:app', '--host', '127.0.0.1', '--port', String(TARGET_PORT)], 
  {
    cwd: __dirname,
    env: { ...process.env, PYTHONUNBUFFERED: '1' }
  }
);

fastapi.stdout.on('data', (data) => {
  console.log(`[FastAPI] ${data.toString().trim()}`);
});

fastapi.stderr.on('data', (data) => {
  console.error(`[FastAPI Error] ${data.toString().trim()}`);
});

fastapi.on('close', (code) => {
  console.log(`[FastAPI] Process exited with code ${code}. Restarting in 5s...`);
  // Simple recovery: if FastAPI exits, restart after 5 seconds
  setTimeout(() => {
    process.exit(1); // Exit Node.js wrapper so Plesk/Passenger automatically spawns a fresh wrapper instance
  }, 5000);
});

// 3. Create a zero-dependency HTTP Reverse Proxy
const server = http.createServer((req, res) => {
  const options = {
    hostname: '127.0.0.1',
    port: TARGET_PORT,
    path: req.url,
    method: req.method,
    headers: req.headers
  };

  const proxyReq = http.request(options, (proxyRes) => {
    res.writeHead(proxyRes.statusCode, proxyRes.headers);
    proxyRes.pipe(res, { end: true });
  });

  proxyReq.on('error', (err) => {
    console.error('[Proxy HTTP Error] Connection to FastAPI failed:', err.message);
    res.writeHead(502, { 'Content-Type': 'text/plain' });
    res.end(`Bad Gateway: Failed to connect to FastAPI backend. Details: ${err.message}`);
  });

  req.pipe(proxyReq, { end: true });
});

server.listen(PORT, () => {
  console.log(`[Proxy] Reverse proxy listening on port ${PORT}, routing to 127.0.0.1:${TARGET_PORT}`);
});
