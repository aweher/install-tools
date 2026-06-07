# install-tools

Instalador con menú interactivo (TUI) que descarga e instala herramientas según
tu sistema operativo y arquitectura. Inspirado en
[install-restic](https://github.com/aweher/install-restic).

## Uso rápido (TUI)

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/aweher/install-tools/main/install.sh)
```

Descarga el repo a un directorio temporal y abre el menú interactivo.

## Uso local

```bash
git clone https://github.com/aweher/install-tools.git
cd install-tools
./install.sh                 # menú TUI
./install.sh chisel          # instala chisel directamente
./install.sh --all           # instala todas las soportadas
./install.sh --list          # lista herramientas
./install.sh --help          # ayuda
```

## Plataformas soportadas

- Linux: amd64, arm64, armv7, armv6, 386
- macOS (darwin): amd64 (Intel), arm64 (Apple Silicon)

Los binarios se instalan en `/usr/local/bin` (usa `sudo` si hace falta).

## Herramientas

| Herramienta | Descripción |
|-------------|-------------|
| chisel      | Túnel TCP/UDP rápido sobre HTTP (jpillora/chisel) |
| acme.sh     | Cliente ACME/Let's Encrypt (acmesh-official/acme.sh) |
| restic      | Backup rápido y seguro (vía restic-install.arreg.la) |
| mc          | Cliente MinIO, se instala como `m` (vía minioclient-install.arreg.la) |
| maldet      | Linux Malware Detect (LMD); **solo Linux**, requiere systemd |
| filebeat    | Shipper de logs de Elastic hacia Graylog/Logstash; **solo Linux** |
| basics      | Instala un set de herramientas básicas vía apt; **solo Linux** |
| bash-tuning | Tuning idempotente de bash (history, aliases, funciones); **solo Linux** |
| snmpd       | Agente Net-SNMP con config para LibreNMS; **solo Linux** |
| serial-console | Habilita consola serie (getty + GRUB); **solo Linux** |

> `restic` y `mc` se instalan ejecutando sus scripts oficiales
> (`curl … | bash`), no descargando el binario directamente. En Debian/Ubuntu,
> `restic` además fija un pin de apt e instala `bzip2`. Ambos ignoran el destino
> `/usr/local/bin` (el script decide la ubicación). `mc` queda disponible como
> el comando `m`.

> `maldet` solo funciona en Linux: instala `inotify-tools`, clona
> [rfxn/linux-malware-detect](https://github.com/rfxn/linux-malware-detect),
> ejecuta su `install.sh`, escribe `conf.maldet` + `monitor_paths` en
> `/usr/local/maldetect` y habilita el servicio systemd. Define `MALDET_EMAIL`
> para el destino de alertas (por defecto `noc@ayuda.la`):
>
> ```bash
> MALDET_EMAIL=noc@tudominio.com ./install.sh maldet
> ```

> `filebeat` solo funciona en Linux: añade el repo APT de Elastic, instala el
> paquete, escribe `/etc/filebeat/filebeat.yml` (envía `/var/log/*.log` al host
> Graylog/Logstash), habilita el módulo `system` y el servicio systemd. Por
> defecto usa `loghost` y lo mapea a `127.5.1.4` en `/etc/hosts`. Personaliza
> con `FILEBEAT_GRAYLOG_HOST` (si no es `loghost`, no se toca `/etc/hosts`):
>
> ```bash
> FILEBEAT_GRAYLOG_HOST=syslog.midominio.com ./install.sh filebeat
> ```

> `basics` solo funciona en Linux/Debian: instala vía `apt` un set de
> herramientas (git, vim, nmap, ripgrep, tmux, ufw, fail2ban, rkhunter, snmp,
> qemu-guest-agent, etc.), fija `vim` como editor por defecto y activa
> `liquidprompt`. Si algún paquete falla, reintenta uno por uno e informa los
> que no pudo instalar.

> `bash-tuning` aplica un tuning de bash a los dotfiles del usuario actual
> (`~/.bashrc`, `~/.bash_aliases`, `~/.bash_functions`): formato de history,
> aliases (`..`, `usage10`, `ip -color`, …) y funciones (`crearvenv`,
> `mygrants`). Es **idempotente**: cada bloque va entre marcadores y solo se
> agrega si falta, sin pisar contenido existente. Escribe en `$HOME` (sin
> `sudo`); usa `BASH_TUNING_HOME` para apuntar a otro home (p. ej. `/root`):
>
> ```bash
> BASH_TUNING_HOME=/root ./install.sh bash-tuning
> ```

> `snmpd` solo funciona en Linux/Debian: instala `snmp snmpd
> snmp-mibs-downloader`, escribe `/etc/snmp/snmpd.conf` y `/etc/default/snmpd`,
> descarga el script `distro` de LibreNMS a `/usr/local/bin` y habilita el
> servicio. **Consulta** `community`, `sysLocation` y `sysContact`: usa las
> variables de entorno si están definidas, si no las pregunta (cuando hay
> terminal) y, en último caso, aplica los valores por defecto.
>
> ```bash
> SNMPD_COMMUNITY=secreta SNMPD_SYSLOCATION="DC Norte" \
>   SNMPD_SYSCONTACT="NOC <noc@midominio.com>" ./install.sh snmpd
> ```

> `serial-console` solo funciona en Linux: por cada puerto habilita un getty
> (systemd `serial-getty@`, con fallback a upstart `/etc/init/<puerto>.conf`) y
> apunta la consola de GRUB al primer puerto serie editando
> `GRUB_CMDLINE_LINUX` en `/etc/default/grub` (con backup `.000`) y regenerando
> (`update-grub` o `grub2-mkconfig`). Por defecto `ttyS0 ttyS1` a `115200`.
> **Requiere reiniciar** para aplicar GRUB. Personaliza con `SERIAL_PORTS` /
> `SERIAL_BAUD`; `SERIAL_SKIP_GRUB` evita tocar GRUB:
>
> ```bash
> SERIAL_PORTS="ttyS0" SERIAL_BAUD=115200 ./install.sh serial-console
> ```

> `acme.sh` no es un binario: se instala con su propio `--install` en
> `~/.acme.sh` (alias + cron de auto-renovación), por lo que se ignora el
> destino `/usr/local/bin`. Define `ACME_SH_EMAIL` para registrar un email de
> cuenta durante la instalación:
>
> ```bash
> ACME_SH_EMAIL=tu@email.com ./install.sh acme.sh
> ```

## Añadir una herramienta

Crea `tools/<nombre>.sh` con este contrato:

```bash
TOOL_NAME="mitool"
TOOL_DESC="Descripción corta"

tool_supported() { local os="$1" arch="$2"; ...; return 0|1; }
tool_install()   { local os="$1" arch="$2" destdir="${3:-/usr/local/bin}"; ...; }
```

Usa los helpers de `lib/` (`latest_release`, `download_to`, `install_binary`).
El TUI lo descubre automáticamente.

## Requisitos

`curl`, `gzip`, `tar`. El menú usa [gum](https://github.com/charmbracelet/gum)
(se instala automáticamente vía brew/go si falta).

## Desarrollo

```bash
shellcheck install.sh lib/*.sh tools/*.sh
bats tests/
```

En macOS, ejecutar la suite de tests requiere bash 5 (`brew install bash`),
ya que algunos tests usan `source <(...)`, no soportado por el bash 3.2 que
trae el sistema. CI corre en Ubuntu (bash 5+), donde no hace falta nada extra.
