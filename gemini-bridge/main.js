const { app, BrowserWindow, Tray, Menu, nativeImage } = require('electron');
const path = require('path');
const http = require('http');

// Integrar el servidor directamente en el proceso principal
// Esto asegura que el servidor funcione en producción sin depender de un binario 'node' externo
require('./server.js');

let mainWindow;
let tray;

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1200,
    height: 850,
    title: "Agent Tunnel",
    icon: path.join(__dirname, 'logo.png'),
    show: false, // No mostrar hasta que esté listo
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true
    }
  });

  const url = 'http://localhost:3456';
  
  // Reintentar la carga hasta que el servidor interno esté listo
  const loadWithRetry = () => {
    mainWindow.loadURL(url).then(() => {
        mainWindow.show();
    }).catch(() => {
        console.log("Servidor no listo, reintentando...");
        setTimeout(loadWithRetry, 500);
    });
  };

  loadWithRetry();

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
  let image = nativeImage.createFromPath(iconPath);
  
  if (image.isEmpty()) {
    console.error("No se pudo cargar el icono del tray desde:", iconPath);
    // Fallback simple si falla la carga
    image = nativeImage.createEmpty();
  }

  // En macOS, marcar como template para que cambie de color (blanco/negro) automáticamente
  if (process.platform === 'darwin') {
    image.setTemplateImage(true);
  }

  const trayIcon = image.resize({ width: 18, height: 18 });
  tray = new Tray(trayIcon);
  tray.setToolTip('Agent Tunnel');

  tray.on('click', () => {
    if (mainWindow) mainWindow.show();
  });

  updateTrayMenu();
  // Actualizar el menú del Tray periódicamente para reflejar cambios en las sesiones
  setInterval(updateTrayMenu, 5000);
}

async function updateTrayMenu() {
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
  req.write(postData);
  req.end();
}

app.whenReady().then(() => {
  createWindow();
  createTray();

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on('window-all-closed', () => {
  // Mantener la app viva en el tray
});

app.on('before-quit', () => {
  app.isQuitting = true;
});
