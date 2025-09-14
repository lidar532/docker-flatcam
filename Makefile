# 2025-0914 Dockerized by: W. Wright https://github.com/lidar532
#
# --------- Config ---------
WIN_DIR := /mnt/c/

# --------- Targets ---------
.PHONY: build run run-x11 run-rdp

build:
	@docker build -t flatcam-wsl:latest .

# Wayland (WSLg). Works on some GPUs; if it crashes, use run-x11.
run:
	@echo "Mounting $(WIN_DIR) -> /work (Wayland)"
	@docker run --rm --name flatcam_wsl \
		-e DISPLAY=$$DISPLAY \
		-e WAYLAND_DISPLAY=$$WAYLAND_DISPLAY \
		-e XDG_RUNTIME_DIR=/mnt/wslg/runtime-dir \
		-e PULSE_SERVER=/mnt/wslg/PulseServer \
		-e QT_QPA_PLATFORM=wayland \
		-e VISPY_BACKEND=pyqt5 \
		-v /mnt/wslg:/mnt/wslg \
		-v /tmp/.X11-unix:/tmp/.X11-unix \
		-v /usr/lib/wsl/lib:/usr/lib/wsl/lib \
		-v $(WIN_DIR):/work \
		-v $(WIN_DIR)/.config:/work/.config \
		-v $(WIN_DIR)/.local:/work/.local \
		--device=/dev/dxg \
		--group-add video \
		flatcam-wsl:latest

# X11 (recommended default on WSLg)
run-x11:
	@echo "Mounting $(WIN_DIR) -> /work (X11)"
	@docker run --rm --name flatcam_wsl \
		-e DISPLAY=$$DISPLAY \
		-e QT_QPA_PLATFORM=xcb \
		-e VISPY_BACKEND=pyqt5 \
		-v /tmp/.X11-unix:/tmp/.X11-unix \
		-v /usr/lib/wsl/lib:/usr/lib/wsl/lib \
		-v $(WIN_DIR):/work \
		-v $(WIN_DIR)/.config:/work/.config \
		-v $(WIN_DIR)/.local:/work/.local \
		--device=/dev/dxg \
		--group-add video \
		flatcam-wsl:latest

# RDP (connect to 127.0.0.1:3391; user: flatcam / pass: flatcam)
run-rdp:
	@echo "Mounting $(WIN_DIR) -> /work (RDP on localhost:3391; user=flatcam pass=flatcam)"
	@docker run --rm --name flatcam_rdp \
		-p 3391:3389 \
		-v $(WIN_DIR):/work \
		-v $(WIN_DIR)/.config:/work/.config \
		-v $(WIN_DIR)/.local:/work/.local \
		flatcam-wsl:latest \
		/usr/local/bin/start-rdp.sh

