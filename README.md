Run Flatcam on windows with either WSLg, or via RDP.

# 🖥️ FlatCAM in Docker (WSL2 + WSLg + RDP)

This project builds a fully-contained [FlatCAM](https://bitbucket.org/jpcgt/flatcam/src/Beta/) 
environment inside a Docker container that works seamlessly on **Windows 11 with WSL2**.  

It is designed for **PCB isolation milling workflows**, where FlatCAM is used to convert 
Gerber/Excellon output from PCB CAD tools into G-code or toolpaths for laser engravers, 
CNC mills, or other PCB prototyping tools.

---

## ✨ Features

- 🐳 **Containerized FlatCAM**  
  Runs entirely inside Docker; no local FlatCAM install needed.

- 💻 **GUI support via WSLg (Wayland) or X11**  
  Works natively on Windows 11 with WSL2 and GPU acceleration enabled.

- 🖧 **RDP access (Remote Desktop Protocol)**  
  Optional mode that launches a full XFCE desktop inside the container, with FlatCAM auto-starting.  
  Useful when WSLg/X11 GUI support is unstable or unavailable.

- 📁 **Shared /work directory**  
  Mounts a chosen Windows folder into `/work` inside the container, so you can easily open and save files to your host machine.

- ⚙️ **Persistent configuration**  
  Maps `.config` and `.local` from your Windows home folder to preserve preferences, tools, and settings across rebuilds.

- 📦 **Reproducible build**  
  Builds FlatCAM from the official `Beta` branch, installs all dependencies (PyQt5, vispy, shapely, rasterio, ortools, etc.), and includes an auto-launch script.

---

## 📂 Project Layout


```
docker-flatcam/
├── Dockerfile # Builds FlatCAM + Xfce + XRDP
├── Makefile # Easy commands to build and run
└── README.md # This file
```


---

## ⚡ Prerequisites

- **Windows 11**
- **WSL2 enabled**
- **Docker Desktop for Windows**  
  - Enable **WSL2 backend**  
  - Enable **GPU acceleration** if available
- Optional: **Remote Desktop Connection** app (for RDP mode)

---

## 🚀 Usage

### 1. Build the image
```bash
make build
```


2. Run with GUI via WSLg (Wayland)

Preferred on newer GPUs.
```
make run
```

3. Run with GUI via X11 (More stable)

Recommended default — most reliable.

make run-x11

4. Run via RDP (XFCE desktop)

Full desktop session. Connect with Remote Desktop.
```
make run-rdp
```


Then open Remote Desktop Connection on Windows:

* Server: 127.0.0.1:3391

* Username: flatcam

* Password: flatcam

💡 FlatCAM will launch automatically inside XFCE.

📁 File Sharing

The Makefile maps your Windows directory from:

```
WIN_DIR := /mnt/c/
```


This becomes /work inside the container.
All FlatCAM file dialogs default to /work, so files you save will appear on your Windows filesystem.

🧹 Cleanup

To remove old dangling images:
```
docker image prune -f
```

⚡ Notes

* All FlatCAM user data (config, tools, recent files) is stored under /work/.config and /work/.local on your host.

* GPU acceleration is used when available (via /dev/dxg on WSL2).

* The container defaults to QT_QPA_PLATFORM=xcb when running under X11, or wayland when running under WSLg.

📜 License

This project wraps the official FlatCAM Beta
 (GPLv3 licensed) in a Docker-based runtime for convenience.
All Docker configuration scripts are provided under the MIT license.

💡 Credits

FlatCAM by Juan Pablo Caram

Docker-based setup by C. W. Wright https://github.com/lidar532



