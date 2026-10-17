# Proyecto Práctico CI-0144

Repositorio correspondiente al **Proyecto Práctico del curso CI-0144 – Diseño y Operación de Servicios de Infraestructura**, de la **Universidad de Costa Rica**.

El proyecto comprende el diseño, implementación, configuración y operación de una infraestructura tecnológica distribuida entre tres sedes: **San José (SJO), Limón (LIM) y Cartago (CAR)**.

## Integrantes

| Nombre |
|---|
| Marco Calderón Guevara |
| Andy Cen Wu |
| Juliana Rodríguez Mora |

---

## Etapa 1 – Infraestructura de borde

Durante la **[Etapa 1](./etapa_1/)** se implementó la infraestructura de borde para las tres sedes de la organización:

- **San José (SJO)** — sede central.
- **Limón (LIM)**.
- **Cartago (CAR)**.

La implementación incluye segmentación mediante **VLAN**, firewall con `nftables`, NAT, acceso administrativo mediante **SSH**, protección con **Fail2Ban**, sincronización de tiempo mediante **Chrony** y una malla completa de túneles **IPsec** entre las tres sedes.

### Infraestructura por sede

#### [San José (SJO)](./etapa_1/san_josé/)

| Recurso | Descripción |
|---|---|
| [Capturas](./etapa_1/san_josé/capturas/) | Evidencias y pruebas realizadas |
| [Chrony](./etapa_1/san_josé/chrony/) | Configuración de sincronización de tiempo |
| [Fail2Ban](./etapa_1/san_josé/fail2ban/) | Protección del acceso SSH |
| [Firewall](./etapa_1/san_josé/firewall/) | Reglas y configuración de `nftables` |
| [IPsec](./etapa_1/san_josé/ipsec/) | Configuración de los túneles IPsec |
| [Network](./etapa_1/san_josé/network/) | Configuración de interfaces, VLAN y direccionamiento |
| [SSH](./etapa_1/san_josé/ssh/) | Configuración del acceso administrativo |

#### [Limón (LIM)](./etapa_1/limón/)

| Recurso | Descripción |
|---|---|
| [Capturas](./etapa_1/limón/capturas/) | Evidencias y pruebas realizadas |
| [Chrony](./etapa_1/limón/chrony/) | Configuración de sincronización de tiempo |
| [Fail2Ban](./etapa_1/limón/fail2ban/) | Protección del acceso SSH |
| [Firewall](./etapa_1/limón/firewall/) | Reglas y configuración de `nftables` |
| [IPsec](./etapa_1/limón/ipsec/) | Configuración de los túneles IPsec |
| [Network](./etapa_1/limón/network/) | Configuración de interfaces, VLAN y direccionamiento |
| [SSH](./etapa_1/limón/ssh/) | Configuración del acceso administrativo |

#### [Cartago (CAR)](./etapa_1/cartago/)

| Recurso | Descripción |
|---|---|
| [Capturas](./etapa_1/cartago/capturas/) | Evidencias y pruebas realizadas |
| [Chrony](./etapa_1/cartago/chrony/) | Configuración de sincronización de tiempo |
| [Fail2Ban](./etapa_1/cartago/fail2ban/) | Protección del acceso SSH |
| [Firewall](./etapa_1/cartago/firewall/) | Reglas y configuración de `nftables` |
| [IPsec](./etapa_1/cartago/ipsec/) | Configuración de los túneles IPsec |
| [Network](./etapa_1/cartago/network/) | Configuración de interfaces, VLAN y direccionamiento |
| [SSH](./etapa_1/cartago/ssh/) | Configuración del acceso administrativo |

### Documentación y evidencias

La Etapa 1 incluye documentación técnica, vistas arquitectónicas y evidencias de implementación:

- [Capturas generales](./etapa_1/capturas/)
- [Anexo 2](./etapa_1/capturas/anexo_2/)
- [Documentos](./etapa_1/docs/)
- [Figuras de arquitectura](./etapa_1/figuras/)

---

## Etapa 2 – Servicios de infraestructura y operación

Durante la **[Etapa 2](./etapa_2/)** se amplió la infraestructura implementada anteriormente mediante el despliegue de servicios de red, monitoreo, gestión de registros y automatización en las tres sedes.

La implementación comprende los siguientes componentes:

- **Segmentación y seguridad:** organización de las redes en zonas de seguridad mediante VLAN y políticas de filtrado con `nftables`, controlando las comunicaciones entre clientes, servidores internos, DMZ y administración.
- **DHCP:** asignación de direcciones IPv4 mediante ISC Kea, reservas por dirección MAC, agentes DHCP Relay y alta disponibilidad `hot-standby` entre San José y Limón.
- **DNS:** implementación de un servidor primario oculto en San José y servidores secundarios autoritativos en Limón y Cartago, con transferencias de zona autenticadas mediante TSIG, actualizaciones dinámicas y protección DNSSEC.
- **Resolución recursiva:** despliegue de un resolvedor DNS interno independiente en San José, con restricciones de acceso y consultas recursivas.
- **Monitoreo:** supervisión centralizada mediante Prometheus, Grafana, Node Exporter, Blackbox Exporter y Alertmanager, incluyendo métricas de infraestructura, servicios DHCP, DNS y túneles IPsec.
- **Registros y alertas:** centralización de bitácoras mediante `rsyslog`, políticas de rotación y retención, tableros de monitoreo por sede y notificaciones mediante Telegram.
- **Automatización:** despliegue automático de zonas DNS, respaldos diarios de configuraciones con transferencia entre sedes y verificaciones periódicas del estado de los servicios.

### Infraestructura por sede

#### [San José (SJO)](./etapa_2/san_josé/)

Sede central de la organización, donde se concentran los servicios principales de DNS, resolución recursiva y monitoreo.

| Servidor | Función |
|---|---|
| [firewall01](./etapa_2/san_josé/firewall01/) | Seguridad perimetral, segmentación, enrutamiento, IPsec y DHCP Relay |
| [dhcp01](./etapa_2/san_josé/dhcp01/) | Servidor DHCP principal, reservas, alta disponibilidad y actualizaciones DNS |
| [dns01](./etapa_2/san_josé/dns01/) | DNS primario oculto, administración de zonas, DNSSEC y despliegue automatizado |
| [resolver01](./etapa_2/san_josé/resolver01/) | Resolución DNS recursiva para las redes internas |
| [monitoreo01](./etapa_2/san_josé/monitoreo01/) | Prometheus, Grafana, Alertmanager, monitoreo de servicios y centralización de registros |

#### [Limón (LIM)](./etapa_2/limón/)

Sede que proporciona servicios de infraestructura locales y participa en los mecanismos de redundancia y alta disponibilidad.

| Servidor | Función |
|---|---|
| [firewall01](./etapa_2/limón/firewall01/) | Seguridad perimetral, segmentación, enrutamiento, IPsec y DHCP Relay |
| [dhcp01](./etapa_2/limón/dhcp01/) | Servidor DHCP secundario en modalidad `hot-standby`, reservas y actualizaciones DNS |
| [dns01](./etapa_2/limón/dns01/) | DNS secundario autoritativo y transferencias de zona autenticadas |

#### [Cartago (CAR)](./etapa_2/cartago/)

Sede con servicios DHCP independientes y participación en la arquitectura DNS autoritativa distribuida.

| Servidor | Función |
|---|---|
| firewall01 | Seguridad perimetral, segmentación, enrutamiento, IPsec y DHCP Relay |
| dhcp01 | Servicio DHCP local, ámbitos y reservas de direcciones |
| dns01 | DNS secundario autoritativo y transferencias de zona autenticadas |

**Nota:** las configuraciones de Cartago correspondientes a la Etapa 2 se encuentran pendientes de incorporar al repositorio.

### Vistas de arquitectura

La Etapa 2 actualiza las cuatro vistas arquitectónicas para representar los nuevos servicios, sus dependencias y los mecanismos de operación y seguridad.

| Vista | Descripción |
|---|---|
| [Contexto y despliegue](./etapa_2/figuras/Vista%201%20-%20Contexto%20y%20despliegue.svg) | Distribución de componentes y servicios entre las tres sedes |
| [Red y comunicaciones](./etapa_2/figuras/Vista%202%20-%20Red%20y%20comunicaciones.svg) | Segmentación, direccionamiento y flujos de comunicación |
| [Seguridad](./etapa_2/figuras/Vista%203%20-%20Seguridad.svg) | Zonas de confianza, controles de acceso y protección de servicios |
| [Operación y gestión](./etapa_2/figuras/Vista%204%20-%20Operación%20y%20gestión.svg) | Monitoreo, registros, automatización, respaldos y administración |

---

## Estructura del repositorio

```text
proyecto_practico_ci0144/
├── README.md
│
├── etapa_1/
│   ├── capturas/
│   │   └── anexo_2/
│   ├── cartago/
│   │   ├── capturas/
│   │   ├── chrony/
│   │   ├── fail2ban/
│   │   ├── firewall/
│   │   ├── ipsec/
│   │   ├── network/
│   │   └── ssh/
│   ├── docs/
│   ├── figuras/
│   ├── limón/
│   │   ├── capturas/
│   │   ├── chrony/
│   │   ├── fail2ban/
│   │   ├── firewall/
│   │   ├── ipsec/
│   │   ├── network/
│   │   └── ssh/
│   └── san_josé/
│       ├── capturas/
│       ├── chrony/
│       ├── fail2ban/
│       ├── firewall/
│       ├── ipsec/
│       ├── network/
│       └── ssh/
│
└── etapa_2/
    ├── cartago/
    ├── figuras/
    ├── limón/
    │   ├── dhcp01/
    │   ├── dns01/
    │   └── firewall01/
    └── san_josé/
        ├── dhcp01/
        ├── dns01/
        ├── firewall01/
        ├── monitoreo01/
        └── resolver01/
```

Cada etapa y sede mantiene sus configuraciones, scripts, documentación y evidencias organizados de manera independiente, facilitando su revisión, mantenimiento y trazabilidad.

---

**CI-0144 – Diseño y Operación de Servicios de Infraestructura**  
**Universidad de Costa Rica – II Semestre, 2026**