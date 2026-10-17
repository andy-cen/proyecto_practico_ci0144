#!/usr/bin/env python3

import subprocess
import re
import os

OUTPUT = "/var/lib/node_exporter/textfile_collector/ipsec.prom"

try:
    result = subprocess.run(
        ["swanctl", "--list-sas"],
        capture_output=True,
        text=True,
        check=True
    )

    data = result.stdout

    ike_up = 1 if re.search(r"sjo-lim:.*ESTABLISHED", data, re.DOTALL) else 0
    child_up = 1 if re.search(r"sjo-lim-child:.*INSTALLED", data, re.DOTALL) else 0

    in_packets = 0
    out_packets = 0
    in_bytes = 0
    out_bytes = 0

    match_in = re.search(
        r"\bin\s+\S+,\s+(\d+)\s+bytes,\s+(\d+)\s+packets",
        data
    )

    match_out = re.search(
        r"\bout\s+\S+,\s+(\d+)\s+bytes,\s+(\d+)\s+packets",
        data
    )

    if match_in:
        in_bytes = int(match_in.group(1))
        in_packets = int(match_in.group(2))

    if match_out:
        out_bytes = int(match_out.group(1))
        out_packets = int(match_out.group(2))

    metrics = f"""# HELP ipsec_ike_established Estado de la asociacion IKE
# TYPE ipsec_ike_established gauge
ipsec_ike_established{{tunnel="sjo-lim"}} {ike_up}

# HELP ipsec_child_installed Estado del tunel IPsec CHILD_SA
# TYPE ipsec_child_installed gauge
ipsec_child_installed{{tunnel="sjo-lim"}} {child_up}

# HELP ipsec_in_bytes Bytes recibidos por el tunel IPsec
# TYPE ipsec_in_bytes counter
ipsec_in_bytes{{tunnel="sjo-lim"}} {in_bytes}

# HELP ipsec_out_bytes Bytes enviados por el tunel IPsec
# TYPE ipsec_out_bytes counter
ipsec_out_bytes{{tunnel="sjo-lim"}} {out_bytes}

# HELP ipsec_in_packets Paquetes recibidos por el tunel IPsec
# TYPE ipsec_in_packets counter
ipsec_in_packets{{tunnel="sjo-lim"}} {in_packets}

# HELP ipsec_out_packets Paquetes enviados por el tunel IPsec
# TYPE ipsec_out_packets counter
ipsec_out_packets{{tunnel="sjo-lim"}} {out_packets}
"""

    # Monitoreo del tunel IPsec manual SJO-CAR mediante XFRM
    xfrm = subprocess.run(
        ["/usr/sbin/ip", "xfrm", "state"],
        capture_output=True,
        text=True,
        check=True,
        timeout=10
    ).stdout

    # Asociaciones ESP en ambos sentidos
    xfrm_out = bool(re.search(
        r"^src 172\.24\.133\.76 dst 172\.24\.133\.84\n"
        r"\s+proto esp\b",
        xfrm,
        re.MULTILINE
    ))

    xfrm_in = bool(re.search(
        r"^src 172\.24\.133\.84 dst 172\.24\.133\.76\n"
        r"\s+proto esp\b",
        xfrm,
        re.MULTILINE
    ))

    xfrm_installed = int(xfrm_out and xfrm_in)

    # Comprobar conectividad con CAR desde la red interna de SJO
    ping_result = subprocess.run(
        ["/usr/bin/ping", "-n", "-c", "2", "-W", "2",
         "-I", "10.4.0.1", "10.4.32.1"],
        capture_output=True,
        text=True,
        timeout=8
    )

    xfrm_reachable = int(ping_result.returncode == 0)

    # Contadores de trafico del tunel manual SJO-CAR
    xfrm_stats = subprocess.run(
        ["/usr/sbin/ip", "-s", "xfrm", "state"],
        capture_output=True,
        text=True,
        check=True,
        timeout=10
    ).stdout

    def obtener_contadores_xfrm(origen, destino):
        patron = (
            rf"^src {re.escape(origen)} dst {re.escape(destino)}\n"
            rf"(?:(?!^src ).*\n)*?"
            rf"^\s*lifetime current:\s*\n"
            rf"\s*(\d+)\(bytes\),\s*(\d+)\(packets\)"
        )

        coincidencia = re.search(patron, xfrm_stats, re.MULTILINE)

        if coincidencia:
            return int(coincidencia.group(1)), int(coincidencia.group(2))

        return 0, 0

    car_in_bytes, car_in_packets = obtener_contadores_xfrm(
        "172.24.133.84", "172.24.133.76"
    )

    car_out_bytes, car_out_packets = obtener_contadores_xfrm(
        "172.24.133.76", "172.24.133.84"
    )

    metrics += f"""
ipsec_in_bytes{{tunnel="sjo-car"}} {car_in_bytes}
ipsec_out_bytes{{tunnel="sjo-car"}} {car_out_bytes}
ipsec_in_packets{{tunnel="sjo-car"}} {car_in_packets}
ipsec_out_packets{{tunnel="sjo-car"}} {car_out_packets}
"""

    metrics += f"""
# HELP ipsec_xfrm_installed Asociaciones ESP manuales instaladas
# TYPE ipsec_xfrm_installed gauge
ipsec_xfrm_installed{{tunnel="sjo-car"}} {xfrm_installed}

# HELP ipsec_xfrm_reachable Conectividad ICMP hacia CAR
# TYPE ipsec_xfrm_reachable gauge
ipsec_xfrm_reachable{{tunnel="sjo-car"}} {xfrm_reachable}
"""

    tmp = OUTPUT + ".tmp"

    with open(tmp, "w") as f:
        f.write(metrics)

    os.chmod(tmp, 0o640)
    os.chown(tmp, os.stat(OUTPUT).st_uid if os.path.exists(OUTPUT) else 0, os.stat(OUTPUT).st_gid if os.path.exists(OUTPUT) else 0)
    os.rename(tmp, OUTPUT)

    print("Metricas IPsec generadas correctamente")

except Exception as e:
    print(f"Error generando metricas IPsec: {e}")
    raise
