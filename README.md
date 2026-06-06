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
