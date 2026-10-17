#!/usr/bin/env python3

import ipaddress
import json
import socket
import subprocess
import sys

SOCKET = "/run/kea/kea4-ctrl-socket"
THRESHOLD = 80.0

POOLS = {
    105: ("SJO", "10.4.5.100", "10.4.5.199"),
    205: ("LIM", "10.4.21.100", "10.4.21.199"),
}


def kea_command(command, arguments=None):
    request = {"command": command}

    if arguments is not None:
        request["arguments"] = arguments

    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as sock:
        sock.settimeout(10)
        sock.connect(SOCKET)
        sock.sendall(json.dumps(request).encode() + b"\n")

        response = b""

        while True:
            chunk = sock.recv(65536)
            if not chunk:
                break
            response += chunk

    if not response:
        raise RuntimeError("Kea no devolvió respuesta")

    result = json.loads(response.decode())

    if result.get("result") != 0:
        raise RuntimeError(result.get("text", str(result)))

    return result.get("arguments", {})


def log(message, priority="info"):
    subprocess.run(
        ["logger", "-t", "kea-pool-monitor",
         "-p", f"daemon.{priority}", message],
        check=True
    )
    print(message)


def main():
    for subnet_id, (site, first, last) in POOLS.items():
        first_ip = int(ipaddress.IPv4Address(first))
        last_ip = int(ipaddress.IPv4Address(last))
        capacity = last_ip - first_ip + 1

        result = kea_command(
            "lease4-get-all",
            {"subnets": [subnet_id]}
        )

        leases = result.get("leases", [])

        occupied = set()

        for lease in leases:
            if lease.get("state") != 0:
                continue

            ip = int(ipaddress.IPv4Address(lease["ip-address"]))

            if first_ip <= ip <= last_ip:
                occupied.add(ip)

        used = len(occupied)
        percentage = used / capacity * 100

        message = (
            f"{site} (subnet {subnet_id}): "
            f"{used}/{capacity} direcciones del pool utilizadas "
            f"({percentage:.1f}%)"
        )

        if percentage > THRESHOLD:
            log("ALERTA DHCP: " + message, "warning")
        else:
            log("OK DHCP: " + message)


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        log(f"ERROR monitoreando Kea: {error}", "err")
        sys.exit(1)
