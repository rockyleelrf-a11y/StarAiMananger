#!/usr/bin/env node
/**
 * StarButler Cloud Relay Server (Zero-dependency, pure Node.js stdlib)
 * Handles User Auth (Register/Login) and WebSocket Relay between Mac Host and iOS Companion.
 */

const http = require('http');
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

const PORT = process.env.PORT || 8765;
const DB_FILE = path.join(__dirname, 'users.json');

// In-memory data store
let users = {}; // email -> { passwordHash, token, devices: [] }
let tokens = {}; // token -> email
let hosts = {}; // email -> { socket, machineName, lastSnapshot, lastSeen }
let clients = {}; // email -> Set<socket>

if (fs.existsSync(DB_FILE)) {
  try {
    const raw = JSON.parse(fs.readFileSync(DB_FILE, 'utf8'));
    users = raw.users || {};
    tokens = raw.tokens || {};
  } catch (e) {}
}

function saveDB() {
  try {
    fs.writeFileSync(DB_FILE, JSON.stringify({ users, tokens }, null, 2));
  } catch (e) {}
}

function hashPassword(pwd) {
  return crypto.createHash('sha256').update(pwd).digest('hex');
}

function parseJSON(req) {
  return new Promise((resolve) => {
    let body = '';
    req.on('data', chunk => body += chunk);
    req.on('end', () => {
      try { resolve(JSON.parse(body)); }
      catch (e) { resolve({}); }
    });
  });
}

function sendJSON(res, statusCode, data) {
  res.writeHead(statusCode, {
    'Content-Type': 'application/json; charset=utf-8',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization'
  });
  res.end(JSON.stringify(data));
}

// HTTP Server
const server = http.createServer(async (req, res) => {
  if (req.method === 'OPTIONS') {
    res.writeHead(200, {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization'
    });
    return res.end();
  }

  const url = new URL(req.url, `http://${req.headers.host}`);

  // Health check
  if (url.pathname === '/api/health') {
    return sendJSON(res, 200, { status: 'ok', onlineHosts: Object.keys(hosts).length });
  }

  // 1. User Registration
  if (req.method === 'POST' && url.pathname === '/api/auth/register') {
    const { email, password } = await parseJSON(req);
    if (!email || !password || email.length < 3 || password.length < 6) {
      return sendJSON(res, 400, { error: '邮箱格式不正确或密码少于6位' });
    }
    const cleanEmail = email.trim().toLowerCase();
    if (users[cleanEmail]) {
      return sendJSON(res, 409, { error: '该账号已存在，请直接登录' });
    }
    const token = crypto.randomBytes(24).toString('hex');
    users[cleanEmail] = {
      email: cleanEmail,
      passwordHash: hashPassword(password),
      token,
      registeredAt: Date.now()
    };
    tokens[token] = cleanEmail;
    saveDB();
    return sendJSON(res, 200, {
      message: '注册成功',
      token,
      email: cleanEmail
    });
  }

  // 2. User Login
  if (req.method === 'POST' && url.pathname === '/api/auth/login') {
    const { email, password } = await parseJSON(req);
    const cleanEmail = (email || '').trim().toLowerCase();
    const user = users[cleanEmail];
    if (!user || user.passwordHash !== hashPassword(password || '')) {
      return sendJSON(res, 401, { error: '账号或密码错误' });
    }
    const token = user.token || crypto.randomBytes(24).toString('hex');
    user.token = token;
    tokens[token] = cleanEmail;
    saveDB();
    
    const hostInfo = hosts[cleanEmail];
    return sendJSON(res, 200, {
      message: '登录成功',
      token,
      email: cleanEmail,
      hostOnline: !!hostInfo,
      hostName: hostInfo ? hostInfo.machineName : null
    });
  }

  // 3. Bound Host Status
  if (req.method === 'GET' && url.pathname === '/api/device/status') {
    const authHeader = req.headers['authorization'] || '';
    const token = authHeader.replace(/^Bearer\s+/i, '') || url.searchParams.get('token');
    const email = tokens[token];
    if (!email) {
      return sendJSON(res, 401, { error: '未授权或登录已过期' });
    }
    const host = hosts[email];
    return sendJSON(res, 200, {
      email,
      hostOnline: !!host,
      machineName: host ? host.machineName : '未连接的 Mac',
      lastSeen: host ? host.lastSeen : null,
      agentCount: host && host.lastSnapshot ? (host.lastSnapshot.agents || []).length : 0
    });
  }

  sendJSON(res, 404, { error: 'Not Found' });
});

// RFC 6455 Pure Node.js WebSocket Upgrade
server.on('upgrade', (req, socket, head) => {
  const url = new URL(req.url, `http://${req.headers.host}`);
  if (url.pathname !== '/relay') {
    socket.destroy();
    return;
  }

  const token = url.searchParams.get('token');
  const role = url.searchParams.get('role'); // "host" or "client"
  const machineName = url.searchParams.get('name') || 'Mac 主机';
  const email = tokens[token];

  if (!email) {
    socket.write('HTTP/1.1 401 Unauthorized\r\n\r\n');
    socket.destroy();
    return;
  }

  // Complete WebSocket Handshake
  const key = req.headers['sec-websocket-key'];
  const acceptKey = crypto.createHash('sha1')
    .update(key + '258EAFA5-E914-47DA-95CA-C5AB0DC85B11')
    .digest('base64');

  const headers = [
    'HTTP/1.1 101 Switching Protocols',
    'Upgrade: websocket',
    'Connection: Upgrade',
    `Sec-WebSocket-Accept: ${acceptKey}`
  ];
  socket.write(headers.join('\r\n') + '\r\n\r\n');

  // Helper: send WS frame
  function sendFrame(payloadStr) {
    const payload = Buffer.from(payloadStr, 'utf8');
    const length = payload.length;
    let header;
    if (length < 126) {
      header = Buffer.from([0x81, length]);
    } else if (length < 65536) {
      header = Buffer.alloc(4);
      header[0] = 0x81;
      header[1] = 126;
      header.writeUInt16BE(length, 2);
    } else {
      header = Buffer.alloc(10);
      header[0] = 0x81;
      header[1] = 127;
      header.writeBigUInt64BE(BigInt(length), 2);
    }
    socket.write(Buffer.concat([header, payload]));
  }

  if (role === 'host') {
    hosts[email] = {
      socket,
      machineName,
      lastSnapshot: null,
      lastSeen: Date.now()
    };
    console.log(`[Host Connected] ${email} (${machineName})`);
    
    // Notify clients that host is online
    const clientSet = clients[email];
    if (clientSet) {
      clientSet.forEach(c => {
        try { c.sendFrame(JSON.stringify({ type: 'hostStatus', online: true, machineName })); }
        catch (e) {}
      });
    }
  } else {
    if (!clients[email]) clients[email] = new Set();
    socket.sendFrame = sendFrame;
    clients[email].add(socket);
    console.log(`[Client Connected] ${email}`);

    // If host is already online, send hostStatus and lastSnapshot immediately
    const host = hosts[email];
    sendFrame(JSON.stringify({
      type: 'hostStatus',
      online: !!host,
      machineName: host ? host.machineName : null
    }));
    if (host && host.lastSnapshot) {
      sendFrame(JSON.stringify(host.lastSnapshot));
    }
  }

  // Parse incoming frames
  let buffer = Buffer.alloc(0);
  socket.on('data', (chunk) => {
    buffer = Buffer.concat([buffer, chunk]);
    while (buffer.length >= 2) {
      const isFinal = (buffer[0] & 0x80) !== 0;
      const opcode = buffer[0] & 0x0F;
      const isMasked = (buffer[1] & 0x80) !== 0;
      let payloadLength = buffer[1] & 0x7F;
      let offset = 2;

      if (opcode === 0x8) { // Close frame
        socket.end();
        return;
      }
      if (opcode === 0x9) { // Ping
        socket.write(Buffer.from([0x8A, 0x00])); // Pong
        buffer = buffer.slice(offset);
        continue;
      }

      if (payloadLength === 126) {
        if (buffer.length < 4) return;
        payloadLength = buffer.readUInt16BE(2);
        offset = 4;
      } else if (payloadLength === 127) {
        if (buffer.length < 10) return;
        payloadLength = Number(buffer.readBigUInt64BE(2));
        offset = 10;
      }

      let maskKey = null;
      if (isMasked) {
        if (buffer.length < offset + 4) return;
        maskKey = buffer.slice(offset, offset + 4);
        offset += 4;
      }

      if (buffer.length < offset + payloadLength) return;

      const payload = buffer.slice(offset, offset + payloadLength);
      buffer = buffer.slice(offset + payloadLength);

      if (maskKey) {
        for (let i = 0; i < payload.length; i++) {
          payload[i] ^= maskKey[i % 4];
        }
      }

      const text = payload.toString('utf8');
      try {
        const msg = JSON.parse(text);
        if (role === 'host') {
          // Host sent snapshot or update: forward to all connected clients
          hosts[email].lastSnapshot = msg;
          hosts[email].lastSeen = Date.now();
          const clientSet = clients[email];
          if (clientSet) {
            clientSet.forEach(c => {
              try { c.sendFrame(text); } catch (e) {}
            });
          }
        } else {
          // Client sent action: forward directly to host socket
          const host = hosts[email];
          if (host && host.socket && !host.socket.destroyed) {
            try {
              // Send text frame to host
              const p = Buffer.from(text, 'utf8');
              const h = Buffer.from([0x81, p.length < 126 ? p.length : 126]);
              if (p.length < 126) {
                host.socket.write(Buffer.concat([h, p]));
              } else {
                const ext = Buffer.alloc(4);
                ext[0] = 0x81; ext[1] = 126; ext.writeUInt16BE(p.length, 2);
                host.socket.write(Buffer.concat([ext, p]));
              }
            } catch (e) {}
          }
        }
      } catch (e) {}
    }
  });

  socket.on('close', () => {
    if (role === 'host') {
      delete hosts[email];
      console.log(`[Host Disconnected] ${email}`);
      const clientSet = clients[email];
      if (clientSet) {
        clientSet.forEach(c => {
          try { c.sendFrame(JSON.stringify({ type: 'hostStatus', online: false, machineName })); }
          catch (e) {}
        });
      }
    } else {
      if (clients[email]) {
        clients[email].delete(socket);
        if (clients[email].size === 0) delete clients[email];
      }
      console.log(`[Client Disconnected] ${email}`);
    }
  });

  socket.on('error', () => {
    socket.destroy();
  });
});

server.listen(PORT, () => {
  console.log(`==> StarButler Cloud Relay Server listening on http://0.0.0.0:${PORT}`);
});
