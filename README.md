# Kubernetes on Cloudspace

Hands-on Kubernetes lab environment designed to run inside **GitHub Codespaces**.
This repository provides a simple and reliable way to bootstrap a local **k3s cluster** for learning, experimentation, and Kubernetes security labs.

This project is part of the **PeachyCloudSecurity** learning ecosystem, focused on Cloud, DevSecOps, and Kubernetes Security education.

---

## Overview

This repository contains:

* A bootstrap script to install and start [**k3s**](https://k3s.io/) inside GitHub Codespaces
* A minimal, clean setup that avoids systemd and rootless complexity
* A foundation for extending into Kubernetes and cloud security labs

The setup is intentionally simple so it works consistently in container-based development environments like Codespaces.

---

## Quick Start (GitHub Codespaces)

1. Open this repository in a **GitHub Codespace**
2. Run the bootstrap script:

```bash
chmod +x k3s-codespaces-bootstrap.sh
./k3s-codespaces-bootstrap.sh
```

3. The script will:

   * Install k3s
   * Start the Kubernetes control plane
   * Configure kubeconfig automatically

4. Verify the cluster:

```bash
kubectl get nodes
kubectl get pods -A
```

You should see the node in `Ready` state and all system pods running.

---

## What This Setup Is Good For

* Learning Kubernetes fundamentals
* Running Kubernetes workloads in Codespaces
* Building and testing Kubernetes security labs
* RBAC, networking, and pod security experiments
* Workshop and demo environments

---
## Support

- 🤝 Ko-fi: https://ko-fi.com/peachycloudsecurity
- 👍 Topmate: topmate.io/peachycloudsecurity
- 🎥 YouTube: youtube.com/@peachycloudsecurity

---

## License

This project is licensed under the **GPL-3.0 License**. See the `LICENSE` file for details.
