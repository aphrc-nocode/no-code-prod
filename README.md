# No-Code Platform – Production Deployment

This repository lets you deploy the latest **No-Code App** directly from Docker Hub.
It includes automatic image updates — no rebuilds or manual pulls required.

---

## Quick Start

### Prerequisites
Make sure you have:
- [Docker](https://docs.docker.com/get-docker/)
- [Docker Swarm](https://docs.docker.com/engine/swarm/)
- Linux OS (or WSL) - **(OPTIONAL)**
  - Window users can also run the APP via WSL. See [WSL](https://github.com/CYGUBICKO/wsl-setup) for installation instructions.

---

### Deploy the App

Clone this repository:

```bash
git clone https://github.com/aphrc-nocode/no-code-prod.git
cd no-code-prod
```

---

### Start the App

```bash
./start.sh
```

The app can be accessed via the url: *IP:8088* also shown when the app is started.


### Stop the App

```bash
./stop.sh
```

### Troubleshooting

At times, with Docker Swarm you need to initialize to set the correct IP:


```bash
docker swarm init --advertise-addr IP
```

Where IP can be obtained via:


```bash
hostname -I
```

Docker group issues: The service fails to start due docker group permission:

```bash
sudo mkdir -p /etc/systemd/system/docker.socket.d
sudo tee /etc/systemd/system/docker.socket.d/override.conf <<EOF
[Socket]
SocketMode=0666
EOF
sudo systemctl daemon-reload
sudo systemctl restart docker.socket
```
