# Secure Raspberry Pi Cluster with Tailscale and SSH

## Overview
This repository documents the design and implementation of a small Raspberry Pi cluster secured using Tailscale and hardened SSH configuration.

The focus of the project is not automation alone, but understanding how networking, authentication, and client behavior interact in a real-world environment. The setup was validated across multiple client devices (Windows, iPhone, iPhone) and multiple Linux nodes.

## Architecture
- Control node: pi-control
- Worker nodes: pi-worker1, pi-worker2
- Private mesh networking via Tailscale
- SSH access restricted to authenticated devices

### Nodes
- **pi-control**  
  Acts as the control node and primary entry point.
- **pi-worker1**
- **pi-worker2**

Each node runs Linux and is joined to the same Tailscale tailnet.

### Networking
- All nodes communicate over private Tailscale IPs (`100.x.x.x`)
- No inbound ports are exposed on the public internet
- SSH access is performed exclusively over the Tailscale mesh

## Goals
- Eliminate password-based SSH authentication
- Enable secure, passwordless access across all nodes
- Avoid public SSH exposure (no port forwarding)
- Maintain consistent SSH behavior across different client devices
- Build a foundation suitable for future orchestration or automation work

## Implementation Summary
High-level summary of how the system was built.
- Installed and authenticated Tailscale on all nodes
- Established SSH key-based authentication using Ed25519 keys
- Distributed public keys across nodes using `ssh-copy-id`
- Standardized SSH client configuration to ensure correct key selection
- Verified passwordless access between all nodes

## Security Hardening
Details of SSH configuration, key management, and network exposure decisions.

### SSH Client Behavior Differs Across Platforms
SSH behavior varied depending on the client device:
- Windows PowerShell
- Linux terminals on the Raspberry Pi nodes
- iPad and iPhone SSH clients

Some clients did not automatically select the intended private key, resulting in unexpected password prompts even when key-based authentication was correctly configured on the server.

**Lesson:** Explicit SSH client configuration (`~/.ssh/config`) is critical when working across heterogeneous clients.

---

### Key Authentication vs Password Fallback
Even after public keys were correctly installed on target nodes, SSH sessions could still fall back to password authentication if:
- The correct key was not offered by the client
- `IdentitiesOnly` was not enforced
- The SSH client attempted multiple keys in an unexpected order

**Lesson:** Successful SSH key distribution does not guarantee passwordless access unless client-side behavior is controlled.

---

### Host Key Verification Interruptions
Repeated SSH attempts across different nodes triggered host key verification prompts and failures when known hosts were missing or inconsistent.

**Lesson:** Host identity verification is a security feature, not an error. Managing `known_hosts` intentionally is necessary in multi-node environments.

---

### Package Management Conflicts
Installing Tailscale via Snap initially worked, but later caused unexpected behavior and inconsistencies.

**Lesson:** Mixing package managers can introduce subtle system-level issues. Standardizing on one installation method (APT) improves reliability and predictability.

## Issues Encountered & Lessons Learned
Documented problems, root causes, and resolutions.

SSH access was intentionally hardened in stages to avoid accidental lockout while ensuring a secure final state.

### Key-Based Authentication
- Ed25519 SSH keys were used for all access
- Public keys were explicitly installed per user on each node
- Password-based authentication was disabled only after validating key access from all client devices

### Network Exposure
- No SSH ports were exposed to the public internet
- All remote access is performed over the Tailscale private mesh
- Optional firewall rules were used to restrict SSH access to Tailscale IP ranges

### Principle of Least Privilege
- Root login over SSH was disabled
- Access is granted per user and per device
- Each client device maintains its own SSH key

## Validation
How access and security were verified.

The setup was validated using the following checks:

- Passwordless SSH access between all nodes
- Successful SSH access from Windows and mobile clients
- Verification that password-based authentication was no longer accepted
- Confirmation that SSH access functions only within the Tailscale network

These validations ensured both functionality and security goals were met.

## Next Steps
Planned improvements and extensions.

Planned extensions of this lab include:

- Automating node provisioning with shell scripts or Ansible
- Enforcing SSH access exclusively on the Tailscale interface
- Introducing containerized workloads
- Expanding the cluster with additional worker nodes
