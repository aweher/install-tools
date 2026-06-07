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
