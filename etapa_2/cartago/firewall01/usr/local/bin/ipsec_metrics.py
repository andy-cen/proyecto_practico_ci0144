
#!/usr/bin/env python3

import os
import re
import subprocess
import tempfile

OUTPUT = "/var/lib/node_exporter/textfile_collector/ipsec.prom"

# Tunel CAR-LIM administrado por strongSwan
TUNNEL = "car-lim"
CHILD = "car-lim-child"

result = subprocess.run(
    ["/usr/sbin/swanctl", "--list-sas"],
    capture_output=True,
    text=True,
    timeout=15,
    check=True,
)

lines = result.stdout.splitlines()
section = []
collecting = False

for line in lines:
    if line and not line.startswith(" ") and re.match(r"^[\w-]+: #", line):
        collecting = line.split(":", 1)[0] == TUNNEL

    if collecting:
        section.append(line)

text = "\n".join(section)

ike = int(bool(re.search(
    rf"^{re.escape(TUNNEL)}:.*ESTABLISHED", text, re.M
)))

installed = int(bool(re.search(
    rf"^\s+{re.escape(CHILD)}:.*INSTALLED", text, re.M
)))

values = {
    "ipsec_ike_established": ike,
    "ipsec_child_installed": installed,
    "ipsec_in_bytes": 0,
    "ipsec_out_bytes": 0,
    "ipsec_in_packets": 0,
    "ipsec_out_packets": 0,
}

for direction in ("in", "out"):
    match = re.search(
        rf"^\s+{direction}\s+\S+,\s+(\d+)\s+bytes,\s+(\d+)\s+packets",
        text,
        re.M,
    )
    if match:
        values[f"ipsec_{direction}_bytes"] = int(match.group(1))
        values[f"ipsec_{direction}_packets"] = int(match.group(2))

metrics = [
    "# HELP ipsec_ike_established IKE SA established (1=yes, 0=no)",
    "# TYPE ipsec_ike_established gauge",
    "# HELP ipsec_child_installed IPsec CHILD SA installed (1=yes, 0=no)",
    "# TYPE ipsec_child_installed gauge",
    "# HELP ipsec_in_bytes Bytes received through IPsec tunnel",
    "# TYPE ipsec_in_bytes gauge",
    "# HELP ipsec_out_bytes Bytes sent through IPsec tunnel",
    "# TYPE ipsec_out_bytes gauge",
    "# HELP ipsec_in_packets Packets received through IPsec tunnel",
    "# TYPE ipsec_in_packets gauge",
    "# HELP ipsec_out_packets Packets sent through IPsec tunnel",
    "# TYPE ipsec_out_packets gauge",
]

for name, value in values.items():
    metrics.append(f'{name}{{tunnel="{TUNNEL}"}} {value}')

# Tunel manual CAR-SJO mediante XFRM
xfrm = subprocess.run(
    ["/usr/sbin/ip", "xfrm", "state"],
    capture_output=True,
    text=True,
    timeout=10,
    check=True,
).stdout

outbound = bool(re.search(
    r"^src 172\.24\.133\.84 dst 172\.24\.133\.76\n"
    r"\s+proto esp spi 0x00001002\b",
    xfrm,
    re.M,
))

inbound = bool(re.search(
    r"^src 172\.24\.133\.76 dst 172\.24\.133\.84\n"
    r"\s+proto esp spi 0x00001001\b",
    xfrm,
    re.M,
))

xfrm_installed = int(outbound and inbound)

ping = subprocess.run(
    ["/usr/bin/ping", "-n", "-c", "2", "-W", "2",
     "-I", "10.4.32.1", "10.4.0.1"],
    capture_output=True,
    text=True,
    timeout=8,
)

xfrm_reachable = int(ping.returncode == 0)

metrics.extend([
    "# HELP ipsec_xfrm_installed Asociaciones ESP manuales instaladas",
    "# TYPE ipsec_xfrm_installed gauge",
    "# HELP ipsec_xfrm_reachable Conectividad ICMP por el tunel manual",
    "# TYPE ipsec_xfrm_reachable gauge",
    f'ipsec_xfrm_installed{{tunnel="sjo-car"}} {xfrm_installed}',
    f'ipsec_xfrm_reachable{{tunnel="sjo-car"}} {xfrm_reachable}',
])

# Contadores de trafico del tunel manual CAR-SJO
xfrm_stats = subprocess.run(
    ["/usr/sbin/ip", "-s", "xfrm", "state"],
    capture_output=True,
    text=True,
    timeout=10,
    check=True,
).stdout

def obtener_contadores_xfrm(src, dst, spi):
    patron = (
        rf"^src {re.escape(src)} dst {re.escape(dst)}\n"
        rf"\s+proto esp spi {re.escape(spi)}\b"
        rf"(?P<bloque>.*?)(?=^src |\Z)"
    )

    match = re.search(patron, xfrm_stats, re.M | re.S)

    if not match:
        return 0, 0

    lifetime = re.search(
        r"lifetime current:\s*\n\s*(\d+)\(bytes\),\s*(\d+)\(packets\)",
        match.group("bloque"),
    )

    if not lifetime:
        return 0, 0

    return int(lifetime.group(1)), int(lifetime.group(2))


out_bytes, out_packets = obtener_contadores_xfrm(
    "172.24.133.84",
    "172.24.133.76",
    "0x00001002",
)

in_bytes, in_packets = obtener_contadores_xfrm(
    "172.24.133.76",
    "172.24.133.84",
    "0x00001001",
)

metrics.extend([
    f'ipsec_in_bytes{{tunnel="sjo-car"}} {in_bytes}',
    f'ipsec_out_bytes{{tunnel="sjo-car"}} {out_bytes}',
    f'ipsec_in_packets{{tunnel="sjo-car"}} {in_packets}',
    f'ipsec_out_packets{{tunnel="sjo-car"}} {out_packets}',
])

directory = os.path.dirname(OUTPUT)

fd, temporary = tempfile.mkstemp(
    dir=directory, prefix=".ipsec-", suffix=".tmp"
)

try:
    with os.fdopen(fd, "w") as file:
        file.write("\n".join(metrics) + "\n")

    os.chmod(temporary, 0o644)
    os.replace(temporary, OUTPUT)
finally:
    if os.path.exists(temporary):
        os.unlink(temporary)

print("Metricas IPsec de CAR generadas correctamente")
