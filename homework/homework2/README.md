# Homework 2 - Network Programmability

## Topologia

- 2 Switch OVS: DC1, DC2
- Host tenant (H1x, H2x) in reti 10.0.1.0/24 e 10.0.2.0/24
- Management LAN: 10.0.100.0/24
- GRE tunnel tra DC1 e DC2 via interfaccia 10.0.10.0/30

## Comandi

Costruzione:
```bash
sudo bash create_topology.sh
```

Pulizia:
```bash
sudo bash clean_topology.sh
```
