# No-Code Platform – Production Deployment

This repository lets you deploy the latest **No-Code App** directly from Docker Hub.
It includes automatic image updates — no rebuilds or manual pulls required.

---

## Quick Start

### Prerequisites
Make sure you have:
- [Docker](https://docs.docker.com/get-docker/)
- [Docker Compose](https://docs.docker.com/compose/install/)
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
docker compose up -d
```

The app can be accessed via [http://localhost:3838](http://localhost:3838) or [http://127.0.0.1:3838](http://127.0.0.1:3838)
