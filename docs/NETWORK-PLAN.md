# CARTER / McKAY Network Plan

This file is the source of truth for the current home-network addressing. Update it whenever the eero network or a reservation changes.

## Confirmed on July 22, 2026

| Item | Current value | Status |
|---|---:|---|
| eero LAN | `192.168.4.0/22` | Active network |
| eero gateway | `192.168.4.1` | Router address, do not assign to a device |
| DNS | `192.168.4.1` | eero-provided DNS |
| Reported eero range | `192.168.4.1` through `192.168.6.222` | Reported in the eero app |
| First safe device reservation | `192.168.4.2` | Leaves the gateway untouched |
| CARTER Proxmox | `192.168.4.121` | Current DHCP address, reservation still required |
| Proxmox web interface | `https://192.168.4.121:8006` | CARTER management page |
| McKAY Proxmox | `ENTER_HERE` | Not yet confirmed |
| Home Assistant VM | `ENTER_HERE` | Must be discovered separately from Proxmox |
| MG PBX VM | `ENTER_HERE` | Must be discovered separately from Proxmox |

## Retired addresses

All `192.168.12.x` addresses are retired for this deployment. They belonged to the upstream network and must not appear in the final eero-based configuration.

In particular, do not reuse:

- `192.168.12.20` for CARTER;
- `192.168.12.21` for Home Assistant;
- `192.168.12.201` for CARTER;
- `192.168.12.1` as the gateway or DNS server.

## Important distinction

CARTER's Proxmox host and the Home Assistant virtual machine are two different systems and require two different addresses.

- Proxmox host: `192.168.4.121`
- Home Assistant VM: discover and reserve a different address
- Windows MG PBX VM: discover and reserve another different address

Never assign `192.168.4.121` to Home Assistant or the PBX.

## Discover the remaining VM addresses

On CARTER, first list the virtual machines:

```bash
qm list
```

For a running VM with the QEMU guest agent available, try:

```bash
qm guest cmd 100 network-get-interfaces
qm guest cmd 110 network-get-interfaces
```

Home Assistant OS may not return an address through the guest-agent command. In that case:

1. Open the eero app.
2. Open **Devices**.
3. Look for `homeassistant`, `Home Assistant`, `HAOS`, or a newly connected wired device.
4. Compare its MAC address with the VM's network-device MAC in Proxmox.
5. Open **Reservation & port forwarding** and reserve the verified address.

Repeat the same process for the Windows MG PBX VM.

## Required eero reservations

Create four distinct reservations:

1. CARTER Proxmox host
2. McKAY Proxmox host
3. Shared Home Assistant service address
4. Shared MG PBX service address

Before reserving an address, verify that it is:

- inside `192.168.4.2` through `192.168.6.222`;
- not currently assigned to another device;
- not the eero gateway;
- not shared by the Proxmox host and a VM.

McKAY standby service VMs must remain stopped during normal CARTER operation. They may reuse the shared Home Assistant and PBX service addresses only during a controlled failover.

## Verify CARTER from its console

```bash
ip -4 address show vmbr0
ip route
```

The expected result is an address in the eero network and a default route through `192.168.4.1`. After the eero reservation is created, CARTER should continue receiving `192.168.4.121`.
