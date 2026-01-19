# Secure Raspberry Pi Cluster with Tailscale and SSH

## Overview
This project documents the setup of a multi-node Raspberry Pi cluster secured with Tailscale and SSH key-based authentication.

## Architecture
- Control node: pi-control
- Worker nodes: pi-worker1, pi-worker2
- Private mesh networking via Tailscale
- SSH access restricted to authenticated devices

## Goals
- Remote access without exposing ports to the public internet
- Passwordless, key-based SSH authentication
- Consistent access from multiple client devices (Windows, macOS/iOS)
- Hardened SSH configuration suitable for production-like environments

## Implementation Summary
High-level summary of how the system was built.

## Security Hardening
Details of SSH configuration, key management, and network exposure decisions.

## Issues Encountered & Lessons Learned
Documented problems, root causes, and resolutions.

## Validation
How access and security were verified.

## Next Steps
Planned improvements and extensions.
