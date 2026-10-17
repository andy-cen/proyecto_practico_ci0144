#!/usr/bin/env python3

import json
import os
import socket
import sys

SOCKET_PATH = "/run/kea/kea4-ctrl-socket"
OUTPUT_DIR = "/var/lib/node_exporter/textfile_collector"
OUTPUT_FILE = f"{OUTPUT_DIR}/kea_pools.prom"

SUBNETS = {
    105: "SJO",
    205: "LIM",
}


def get_statistics():
    request = json.dumps({
        "command": "statistic-get-all",
        "service": ["dhcp4"]
    }).encode()

    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as sock:
        sock.settimeout(5)
        sock.connect(SOCKET_PATH)
        sock.sendall(request)
        sock.shutdown(socket.SHUT_WR)

        chunks = []
        while True:
            chunk = sock.recv(65536)
            if not chunk:
                break
            chunks.append(chunk)

    response = json.loads(b"".join(chunks))

    if response.get("result") != 0:
        raise RuntimeError("Kea no devolvió estadísticas válidas")

    return response["arguments"]


def main():
    stats = get_statistics()

    lines = [
        "# HELP kea_dhcp_pool_assigned_addresses Direcciones DHCP asignadas",
        "# TYPE kea_dhcp_pool_assigned_addresses gauge",
        "# HELP kea_dhcp_pool_total_addresses Capacidad del pool DHCP",
        "# TYPE kea_dhcp_pool_total_addresses gauge",
        "# HELP kea_dhcp_pool_utilization_percent Porcentaje de utilizacion del pool DHCP",
        "# TYPE kea_dhcp_pool_utilization_percent gauge",
    ]

    for subnet, sede in SUBNETS.items():
        prefix = f"subnet[{subnet}].pool[0]"

        assigned = stats[f"{prefix}.assigned-addresses"][0][0]
        total = stats[f"{prefix}.total-addresses"][0][0]

        if total <= 0:
            raise ValueError(f"Capacidad inválida para subred {subnet}")

        utilization = assigned / total * 100
        labels = f'sede_pool="{sede}",subnet="{subnet}"'

        lines.extend([
            f"kea_dhcp_pool_assigned_addresses{{{labels}}} {assigned}",
            f"kea_dhcp_pool_total_addresses{{{labels}}} {total}",
            f"kea_dhcp_pool_utilization_percent{{{labels}}} {utilization:.2f}",
        ])

    temporary_file = OUTPUT_FILE + ".tmp"

    with open(temporary_file, "w", encoding="utf-8") as file:
        file.write("\n".join(lines) + "\n")

    import grp

    group_id = grp.getgrnam("node_exporter").gr_gid

    os.chown(temporary_file, 0, group_id)
    os.chmod(temporary_file, 0o640)
    os.replace(temporary_file, OUTPUT_FILE)

    print("Métricas de Kea generadas correctamente")


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(f"ERROR: {error}", file=sys.stderr)
        sys.exit(1)
