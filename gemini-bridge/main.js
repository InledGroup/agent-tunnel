const { app, BrowserWindow, Tray, Menu, nativeImage } = require('electron');
const path = require('path');
const http = require('http');
const { spawn } = require('child_process');

let mainWindow;
let tray;
let serverProcess;

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1200,
    height: 850,
    title: "Agent Tunnel",
    icon: path.join(__dirname, 'logo.png'),
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true
    }
  });

  // En producción cargamos el servidor local
  const url = 'http://localhost:3456';
  
  // Pequeña espera para asegurar que el servidor ha arrancado
  setTimeout(() => {
    mainWindow.loadURL(url).catch(() => {
        // Reintentar si falla (el servidor está arrancando)
        setTimeout(() => mainWindow.loadURL(url), 1000);
    });
  }, 1000);

  mainWindow.on('close', (event) => {
    if (!app.isQuitting) {
      event.preventDefault();
      mainWindow.hide();
    }
    return false;
  });
}

function createTray() {
  const iconPath = path.join(__dirname, 'logo.png');
  // Usamos un icono redimensionado para el tray
  const icon = nativeImage.createFromPath(iconPath).resize({ width: 18, height: 18 });
  tray = new Tray(icon);
  tray.setToolTip('Agent Tunnel');

  tray.on('click', () => {
    mainWindow.show();
  });

  updateTrayMenu();
}

async function updateTrayMenu() {
  // Consultar sesiones activas al servidor local
  const req = http.get('http://localhost:3456/api/sessions', (res) => {
    let data = '';
    res.on('data', chunk => data += chunk);
    res.on('end', () => {
      try {
        const parsed = JSON.parse(data);
        const sessions = parsed.sessionStatus || {};
        const activeNames = Object.keys(sessions).filter(name => sessions[name].active);
        
        const contextMenu = Menu.buildFromTemplate([
          { label: 'Agent Tunnel', enabled: false },
          { type: 'separator' },
          { label: 'Open Interface', click: () => mainWindow.show() },
          { type: 'separator' },
          { label: 'Active Tunnels:', enabled: false },
          ...(activeNames.length > 0 
            ? activeNames.map(name => ({
                label: `🛑 Stop ${name}`,
                click: () => stopSession(name)
              }))
            : [{ label: ' (No active tunnels)', enabled: false }]
          ),
          { type: 'separator' },
          { label: 'Quit', click: () => {
              app.isQuitting = true;
              app.quit();
            }
          }
        ]);
        tray.setContextMenu(contextMenu);
      } catch (e) {
        defaultMenu();
      }
    });
  });
  
  req.on('error', () => defaultMenu());
}

function defaultMenu() {
  const contextMenu = Menu.buildFromTemplate([
    { label: 'Agent Tunnel', enabled: false },
    { type: 'separator' },
    { label: 'Open Interface', click: () => mainWindow.show() },
    { label: 'Quit', click: () => {
        app.isQuitting = true;
        app.quit();
      }
    }
  ]);
  tray.setContextMenu(contextMenu);
}

function stopSession(name) {
  const postData = JSON.stringify({ name });
  const req = http.request({
    hostname: 'localhost',
    port: 3456,
    path: '/api/stop-session',
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Content-Length': postData.length
    }
  });
  req.on('error', (e) => console.error('Error stopping session via tray:', e));
  req.write(postData);
  req.end();
}

app.whenReady().then(() => {
  // Iniciar el servidor de Agent Tunnel (el mismo que usa la CLI)
  serverProcess = spawn('node', ['server.js'], {
    cwd: __dirname,
    stdio: 'inherit'
  });

  createWindow();
  createTray();

  // Actualizar el menú del Tray cada 5 segundos para reflejar cambios
  setInterval(updateTrayMenu, 5000);

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    // En Windows/Linux se queda en el tray
  }
});

app.on('before-quit', () => {
  app.isQuitting = true;
  if (serverProcess) serverProcess.kill();
});
