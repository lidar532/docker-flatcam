# FlatCAM (Beta) for WSLg — GUI via X11/Wayland (default) or RDP (optional)
# 2025-0914 Dockerized by: W. Wright https://github.com/lidar532

FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Etc/UTC \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    VISPY_BACKEND=pyqt5 \
    QT_QPA_PLATFORM=xcb

# ---------- System dependencies ----------
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
      # Python base
      python3 python3-pip python3-venv python3-scipy python3-tk \
      git wget unzip ca-certificates xauth \
      # GL / EGL / Wayland / X11 (WSLg)
      libgl1 libegl1 mesa-utils \
      libwayland-client0 libwayland-cursor0 libwayland-egl1 \
      libx11-6 libxext6 libxrender1 libxrandr2 libxi6 libsm6 libice6 \
      libxcomposite1 \
      libxcb1 libxcb-render0 libxcb-shape0 libxcb-xfixes0 \
      libxcb-icccm4 libxcb-image0 libxcb-keysyms1 libxcb-randr0 \
      libxcb-util1 libxcb-glx0 libxkbcommon0 libxkbcommon-x11-0 \
      # GLib + friends (PyQt runtime)
      libglib2.0-0 libdbus-1-3 libpcre2-8-0 \
      # Fonts
      libfontconfig1 libfreetype6 fonts-dejavu-core \
      # Geometry/GIS libs for shapely/rtree/rasterio
      libgeos-dev libspatialindex-dev gdal-bin libgdal-dev \
      # Wayland plugin for Qt (optional)
      qtwayland5 \
      # ---- RDP packages ----
      xrdp xorgxrdp dbus-x11 xfce4 xfce4-terminal \
    && rm -rf /var/lib/apt/lists/*

# ---- RDP packages (add Xorg + legacy wrapper) ----
RUN apt-get update && apt-get install -y --no-install-recommends \
    xrdp xorgxrdp dbus-x11 xfce4 xfce4-terminal \
    xserver-xorg-core xserver-xorg-legacy && \
    rm -rf /var/lib/apt/lists/*

# Allow Xorg to be started by regular users (needed for xrdp inside containers)
RUN if [ -f /etc/Xwrapper.config ]; then \
      sed -i 's/^allowed_users=.*/allowed_users=anybody/' /etc/Xwrapper.config || true; \
    else \
      echo 'allowed_users=anybody' > /etc/Xwrapper.config; \
    fi

# Defensive: check GLib
RUN test -f /usr/lib/x86_64-linux-gnu/libgthread-2.0.so.0

# ---------- Fetch FlatCAM (Beta) ----------
RUN mkdir -p /opt/flatcam
WORKDIR /opt/flatcam
RUN git clone --depth 1 -b Beta https://bitbucket.org/jpcgt/flatcam.git src || \
    git clone --depth 1 https://bitbucket.org/jpcgt/flatcam.git src
WORKDIR /opt/flatcam/src

# ---------- Virtualenv + pinned deps (block NumPy 2.x) ----------
RUN python3 -m venv /opt/flatcam/src/.venv && \
    . /opt/flatcam/src/.venv/bin/activate && \
    python -m pip install --upgrade pip wheel setuptools && \
    printf "numpy==1.23.5\n" > /tmp/constraints.txt && \
    pip install -c /tmp/constraints.txt "numpy==1.23.5" && \
    pip install -c /tmp/constraints.txt \
      PyQt5==5.15.10 \
      vispy==0.6.6 \
      PyOpenGL>=3.1.6 PyOpenGL_accelerate>=3.1.6 \
      pillow "matplotlib==3.8.*" && \
    pip install -c /tmp/constraints.txt \
      shapely>=2.0 rtree ezdxf \
      svgpathtools svg.path \
      rasterio lxml reportlab svglib \
      ortools pyserial qrcode[pil] simplejson descartes dill && \
    ( [ -f requirements.txt ] && pip install -c /tmp/constraints.txt -r requirements.txt || true ) && \
    python - <<'PY'
import numpy, vispy, ctypes
print("NUMPY=", numpy.__version__, "VISPY=", vispy.__version__)
assert numpy.__version__.startswith("1.23."), "NumPy pin failed"
assert vispy.__version__=="0.6.6", "VisPy pin failed"
ctypes.CDLL("libgthread-2.0.so.0")
PY

# ---------- Qt file-dialog shim (force /work) ----------
RUN mkdir -p /opt/flatcam/src/.venv/lib/python3.10/site-packages && \
    cat > /opt/flatcam/src/.venv/lib/python3.10/site-packages/sitecustomize.py << 'PY'
import os, sys
WORK = os.environ.get("FLATCAM_DEFAULT_DIR", "/work")
APP_PATH = os.environ.get("FLATCAM_APP_PATH", "/opt/flatcam/src")
def _fix(dirpath: object) -> str:
    try:
        s = "" if dirpath is None else str(dirpath)
    except Exception:
        s = ""
    if not s or s.startswith(APP_PATH):
        return WORK
    return s
if not getattr(sys, "_flatcam_sitecustomize_logged", False):
    sys._flatcam_sitecustomize_logged = True
    print(f"[sitecustomize] forcing QFileDialog directories to {WORK} (APP_PATH={APP_PATH})",
          file=sys.stderr)
try:
    from PyQt5.QtWidgets import QFileDialog
    from PyQt5.QtCore import QUrl
    _orig_init = QFileDialog.__init__
    def _patched_init(self, *a, **k):
        if len(a) >= 3:
            a = list(a); a[2] = _fix(a[2]); a = tuple(a)
        elif 'directory' in k:
            k['directory'] = _fix(k.get('directory'))
        return _orig_init(self, *a, **k)
    QFileDialog.__init__ = _patched_init
    _orig_set_dir = QFileDialog.setDirectory
    def _patched_set_dir(self, directory):
        return _orig_set_dir(self, _fix(directory))
    QFileDialog.setDirectory = _patched_set_dir
    _orig_set_dir_url = QFileDialog.setDirectoryUrl
    def _patched_set_dir_url(self, url):
        try:
            if isinstance(url, QUrl):
                path = url.toLocalFile()
                if not path or path.startswith(APP_PATH):
                    url = QUrl.fromLocalFile(WORK)
        except Exception:
            pass
        return _orig_set_dir_url(self, url)
    QFileDialog.setDirectoryUrl = _patched_set_dir_url
    _go  = QFileDialog.getOpenFileName
    _gos = QFileDialog.getOpenFileNames
    _gs  = QFileDialog.getSaveFileName
    _gd  = QFileDialog.getExistingDirectory
    def getOpenFileName(*a, **k):
        if len(a) >= 3:
            a = list(a); a[2] = _fix(a[2]); a = tuple(a)
        else:
            k['directory'] = _fix(k.get('directory'))
        return _go(*a, **k)
    def getOpenFileNames(*a, **k):
        if len(a) >= 3:
            a = list(a); a[2] = _fix(a[2]); a = tuple(a)
        else:
            k['directory'] = _fix(k.get('directory'))
        return _gos(*a, **k)
    def getSaveFileName(*a, **k):
        if len(a) >= 3:
            a = list(a); a[2] = _fix(a[2]); a = tuple(a)
        else:
            k['directory'] = _fix(k.get('directory'))
        return _gs(*a, **k)
    def getExistingDirectory(*a, **k):
        if len(a) >= 2:
            a = list(a); a[1] = _fix(a[1]); a = tuple(a)
        else:
            k['directory'] = _fix(k.get('directory'))
        return _gd(*a, **k)
    QFileDialog.getOpenFileName      = getOpenFileName
    QFileDialog.getOpenFileNames     = getOpenFileNames
    QFileDialog.getSaveFileName      = getSaveFileName
    QFileDialog.getExistingDirectory = getExistingDirectory
except Exception:
    pass
PY

# ---------- FlatCAM launcher (WSLg default) ----------
RUN mkdir -p /work && \
    cat > /usr/local/bin/flatcam <<'EOF'
#!/usr/bin/env bash
set -e
export HOME=/work
export XDG_CONFIG_HOME=/work/.config
export XDG_CACHE_HOME=/work/.cache
export XDG_DATA_HOME=/work/.local/share
export FLATCAM_DEFAULT_DIR=/work
export FLATCAM_APP_PATH=/opt/flatcam/src
export PYTHONPATH=/opt/flatcam/src/.venv/lib/python3.10/site-packages${PYTHONPATH:+:$PYTHONPATH}
mkdir -p "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$XDG_DATA_HOME" /work/.FlatCAM
cd /work
source /opt/flatcam/src/.venv/bin/activate
exec python /opt/flatcam/src/FlatCAM.py
EOF
RUN chmod +x /usr/local/bin/flatcam

# ---------- RDP setup ----------
# Create a regular user for RDP logins (user/pass: flatcam / flatcam)
RUN useradd -m -s /bin/bash flatcam && echo "flatcam:flatcam" | chpasswd && usermod -aG ssl-cert flatcam

# Autostart FlatCAM in Xfce
RUN mkdir -p /home/flatcam/.config/autostart && \
    cat > /home/flatcam/.config/autostart/flatcam.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=FlatCAM
Exec=/usr/local/bin/flatcam
X-GNOME-Autostart-enabled=true
EOF
RUN chown -R flatcam:flatcam /home/flatcam/.config

# Ensure Xfce session for xrdp logins
RUN bash -lc 'echo startxfce4 > /home/flatcam/.xsession' && \
    chown flatcam:flatcam /home/flatcam/.xsession


RUN cat >/usr/local/bin/start-rdp.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

# dbus (used by XFCE) — tolerate already-running
service dbus start || true

# xrdp runtime dirs & perms
mkdir -p /var/run/xrdp /var/run/xrdp/sockdir
chmod 1777 /var/run/xrdp /var/run/xrdp/sockdir

# Extra sanity: Xorg wrapper permission (container-safe)
if [ -f /etc/Xwrapper.config ]; then
  grep -q '^allowed_users=anybody' /etc/Xwrapper.config || \
    sed -i 's/^allowed_users=.*/allowed_users=anybody/' /etc/Xwrapper.config
fi

# Start sesman, then xrdp in foreground (so container logs show output)
exec /usr/sbin/xrdp-sesman --nodaemon &
exec /usr/sbin/xrdp --nodaemon
EOF
RUN chmod +x /usr/local/bin/start-rdp.sh


# Workspace
RUN mkdir -p /work
WORKDIR /work

# Default: start FlatCAM for WSLg (run/run-x11). RDP target overrides CMD.
CMD ["/usr/local/bin/flatcam"]

EXPOSE 3389

