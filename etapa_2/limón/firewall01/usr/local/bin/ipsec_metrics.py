#!/usr/bin/env python3
import os
import re
import subprocess
import tempfile

OUTPUT = "/var/lib/node_exporter/textfile_collector/ipsec.prom"

TUNNELS = {
    "sjo-lim": "sjo-lim-child",
    "car-lim": "car-lim-child",
}

result = subprocess.run(
    ["/usr/sbin/swanctl", "--list-sas"],
    capture_output=True,
    text=True,
    timeout=15,
    check=True,
)

output = result.stdout
lines = output.splitlines()

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

for tunnel, child in TUNNELS.items():
    section = []
    collecting = False

    for line in lines:
        if line and not line.startswith(" ") and re.match(r"^[\w-]+: #", line):
            name = line.split(":", 1)[0]
            collecting = name == tunnel

        if collecting:
            section.append(line)

    text = "\n".join(section)

    ike = int(bool(re.search(rf"^{re.escape(tunnel)}:.*ESTABLISHED", text, re.M)))
    installed = int(bool(re.search(rf"^\s+{re.escape(child)}:.*INSTALLED", text, re.M)))

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

    for name, value in values.items():
        metrics.append(f'{name}{{tunnel="{tunnel}"}} {value}')

directory = os.path.dirname(OUTPUT)

fd, temporary = tempfile.mkstemp(dir=directory, prefix=".ipsec-", suffix=".tmp")

try:
    with os.fdopen(fd, "w") as file:
        file.write("\n".join(metrics) + "\n")

    os.chmod(temporary, 0o644)
    os.replace(temporary, OUTPUT)
finally:
    if os.path.exists(temporary):
        os.unlink(temporary)
