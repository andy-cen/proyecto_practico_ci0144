# Proyecto Práctico CI-0144

Repositorio correspondiente al **Proyecto Práctico del curso CI-0144 – Diseño y Operación de Servicios de Infraestructura**, de la **Universidad de Costa Rica**.

| Integrantes |
|---|
| Marco Calderón Guevara |
| Andy Cen Wu |
| Juliana Rodríguez Mora |

---

## Etapa 1

Durante la **[Etapa 1](./etapa_1/)** se implementó la infraestructura de borde para las tres sedes de la organización:

- **San José (SJO)** — sede central
- **Limón (LIM)**
- **Cartago (CAR)**

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

---

## Evidencias generales

Además de las evidencias almacenadas por sede, la Etapa 1 contiene recursos generales utilizados para documentar y verificar la implementación:

- [Capturas generales](./etapa_1/capturas/)
- [Anexo 2](./etapa_1/capturas/anexo_2/)
- [Documentos](./etapa_1/docs/)
- [Figuras](./etapa_1/figuras/)

---

## Consideraciones de seguridad

Las configuraciones almacenadas en este repositorio **no contienen contraseñas, PSK, llaves privadas ni otros secretos en texto claro**.

Los valores sensibles utilizados durante la implementación se omiten o sustituyen por valores de referencia en los archivos almacenados en el repositorio.

---

## Estructura del repositorio

```text
proyecto_practico_ci0144/
└── etapa_1/
    ├── capturas/
    │   └── anexo_2/
    ├── cartago/
    │   ├── capturas/
    │   ├── chrony/
    │   ├── fail2ban/
    │   ├── firewall/
    │   ├── ipsec/
    │   ├── network/
    │   └── ssh/
    ├── figuras/
    ├── figuras/
    ├── limón/
    │   ├── capturas/
    │   ├── chrony/
    │   ├── fail2ban/
    │   ├── firewall/
    │   ├── ipsec/
    │   ├── network/
    │   └── ssh/
    └── san_josé/
        ├── capturas/
        ├── chrony/
        ├── fail2ban/
        ├── firewall/
        ├── ipsec/
        ├── network/
        └── ssh/
```

Cada sede mantiene sus configuraciones y evidencias organizadas de forma independiente para facilitar su revisión, mantenimiento y trazabilidad.

---

**CI-0144 – Diseño y Operación de Servicios de Infraestructura**  
**Universidad de Costa Rica - II Semestre, 2026**