<p align="center">
  <img src="https://hosted.inled.es/new-agent-tunnel.png" alt="Agent Tunnel Logo" width="200"/>
</p>

# Agent Tunnel 🚀

[Leer en Español](#agent-tunnel-es-🚀)

**The ultimate bridge for your agent in remote environments.**

Agent Tunnel allows your local instance of Gemini CLI, Claude Code, or any other agent to work transparently on any remote Linux server, router (OpenWrt/Entware), or Mac via SSH. Forget about manual file uploads or constant context switching: with Agent Tunnel, your local machine and the remote server become one.

## ✨ Key Features

- 🔄 **Real-time Sync**: Native integration with **Mutagen** for ultra-fast bi-directional synchronization.
- ⚡ **Command Interception**: Execute commands like `npm install`, `ls`, or `mkdir` directly on the remote host from your local terminal.
- 🌐 **Intuitive Web UI**: Configure your sessions, manage credentials, and monitor real-time logs at `http://localhost:3456`.
- 🔑 **Automatic Key Management**: Automatic generation and injection of SSH keys for a frictionless connection.
- 🛠️ **Direct Mode (SSH-Only)**: If the remote device doesn't support Mutagen (e.g., older architectures), Agent Tunnel automatically activates direct execution mode.

## 📦 Dependencies and Requirements

### Local Environment
- **Node.js**: >= 22.12.0
- **Astro**: ^6.1.1 (For Frontend development)
- **SSH2**: ^1.17.0 (SSH client for Node.js)
- **Mutagen**: Required for real-time file synchronization.
- **SSH Client**: Installed on the system.

### Remote Environment
- **SSH Server**: Compatible with public key authentication.
- **SFTP Server**: (Optional) Recommended for Mutagen synchronization.

## 🚀 Quick Start

1. **Start the Bridge**:
   ```bash
   ./start-bridge.sh
   ```
2. **Configure your Session**:
   Open `http://localhost:3456` in your browser.
3. **Connect**:
   Enter your remote host details, map your local folder, and click **Activate Sync**.
4. **Work**:
   Use Gemini CLI (or your preferred agent) in your local folder. All commands and file changes will be automatically reflected on the remote host.

## 🛠️ Architecture and Operation

Agent Tunnel injects smart files into your working directory to facilitate integration:
- `activate.sh`: Sets up environment variables for the active session.
- `GEMINI.md`: Provides direct instructions to the AI for using the tunnel.
- `remote-exec.sh`: The engine that wraps and sends your commands to the remote server.

## 🔧 Troubleshooting

### 1. SSH Key Rejected
If automatic injection fails, authorize the key manually from your local terminal:
```bash
ssh-copy-id -i ~/.ssh/id_rsa_bridge.pub [user]@[remote-ip]
```

### 2. SFTP / Mutagen Error (Routers and Embedded Systems)
If Mutagen fails to copy the agent or cannot find the SFTP server:

**On OpenWrt:**
```bash
opkg update && opkg install openssh-sftp-server
```

**On Entware (ASUS, Padavan, etc.):**
```bash
opkg update && opkg install sftp-server
```

### 3. Linux Server Permissions
Ensure the `.ssh` directory has the correct permissions:
```bash
mkdir -p ~/.ssh && chmod 700 ~/.ssh
touch ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys
```

### 4. Remote Login on macOS
To connect to a remote Mac, enable **Remote Login** in *System Settings > General > Sharing*.

## 🔒 Security
- All configurations are stored locally in `~/.gemini-bridge/configs/`.
- Credentials never leave your local environment.
- SSH keys are managed with standard Unix permissions (600/700).

---
*Developed with ❤️ by JaimeGH and Gemini.*

---

# Agent Tunnel (ES) 🚀

[Read in English](#agent-tunnel-🚀)

**El puente definitivo para tu agente en entornos remotos.**

Agent Tunnel permite que tu instancia local de Gemini CLI o Claude Code o lo que sea trabaje de forma transparente en cualquier servidor Linux remoto, router (OpenWrt/Entware) o Mac a través de SSH. Olvida las subidas manuales de archivos o el cambio constante de contexto: con Agent Tunnel, tu máquina local y el servidor remoto se convierten en uno solo.

## ✨ Características Principales

- 🔄 **Sincronización en Tiempo Real**: Integración nativa con **Mutagen** para una sincronización bidireccional ultrarrápida.
- ⚡ **Intercepción de Comandos**: Ejecuta comandos como `npm install`, `ls` o `mkdir` directamente en el remoto desde tu terminal local.
- 🌐 **Web UI Intuitiva**: Configura tus sesiones, gestiona credenciales y monitoriza logs en tiempo real desde `http://localhost:3456`.
- 🔑 **Gestión Automática de Llaves**: Generación e inyección automática de llaves SSH para una conexión sin fricción.
- 🛠️ **Modo Directo (SSH-Only)**: Si el dispositivo remoto no soporta Mutagen (ej. arquitecturas antiguas), Agent Tunnel activa automáticamente el modo de ejecución directa.

## 📦 Dependencias y Requisitos

### Entorno Local
- **Node.js**: >= 22.12.0
- **Astro**: ^6.1.1 (Para el desarrollo del Frontend)
- **SSH2**: ^1.17.0 (Cliente SSH para Node.js)
- **Mutagen**: Requerido para la sincronización de archivos en tiempo real.
- **SSH Client**: Instalado en el sistema.

### Entorno Remoto
- **Servidor SSH**: Compatible con autenticación por llave pública.
- **SFTP Server**: (Opcional) Recomendado para la sincronización con Mutagen.

## 🚀 Inicio Rápido

1. **Inicia el Bridge**:
   ```bash
   ./start-bridge.sh
   ```
2. **Configura tu Sesión**:
   Abre `http://localhost:3456` en tu navegador.
3. **Conecta**:
   Introduce los datos de tu host remoto, mapea tu carpeta local y haz clic en **Activate Sync**.
4. **Trabaja**:
   Usa Gemini CLI en tu carpeta local. Todos los comandos y cambios de archivos se reflejarán automáticamente en el remoto.

## 🛠️ Arquitectura y Funcionamiento

Agent Tunnel inyecta archivos inteligentes en tu directorio de trabajo para facilitar la integración:
- `activate.sh`: Configura las variables de entorno para la sesión activa.
- `GEMINI.md`: Proporciona instrucciones directas a la IA para el uso del túnel.
- `remote-exec.sh`: El motor que envuelve y envía tus comandos al servidor remoto.

## 🔧 Solución de Problemas (Troubleshooting)

### 1. Llave SSH Rechazada
Si la inyección automática falla, autoriza la llave manualmente desde tu terminal local:
```bash
ssh-copy-id -i ~/.ssh/id_rsa_bridge.pub [usuario]@[ip-remota]
```

### 2. Error de SFTP / Mutagen (Routers y Sistemas Embebidos)
Si Mutagen falla al copiar el agente o no encuentra el servidor SFTP:

**En OpenWrt:**
```bash
opkg update && opkg install openssh-sftp-server
```

**En Entware (ASUS, Padavan, etc.):**
```bash
opkg update && opkg install sftp-server
```

### 3. Permisos en el Servidor Linux
Asegúrate de que el directorio `.ssh` tenga los permisos correctos:
```bash
mkdir -p ~/.ssh && chmod 700 ~/.ssh
touch ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys
```

### 4. Remote Login en macOS
Para conectar con un Mac remoto, activa **Sesión remota** en *Ajustes del Sistema > General > Compartir*.

## 🔒 Seguridad
- Todas las configuraciones se almacenan localmente en `~/.gemini-bridge/configs/`.
- Las credenciales nunca salen de tu entorno local.
- Las llaves SSH se gestionan con permisos estándar de Unix (600/700).

---
*Developed with ❤️ by JaimeGH and Gemini.*
