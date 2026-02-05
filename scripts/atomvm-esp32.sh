#!/usr/bin/env bash
set -Eeuo pipefail

if [ -z "${BASH_VERSION:-}" ]; then
  exec /usr/bin/env bash "$0" "$@"
fi

# Colors (disabled when not a TTY; respects NO_COLOR)
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  C_RESET=$'\033[0m'
  C_BOLD=$'\033[1m'
  C_RED=$'\033[31m'
  C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m'
  C_CYAN=$'\033[36m'
else
  C_RESET=""
  C_BOLD=""
  C_RED=""
  C_GREEN=""
  C_YELLOW=""
  C_CYAN=""
fi

usage() {
  local script_name
  script_name="$(basename "$0")"

  cat <<EOF
Usage:
  ${script_name} <command> [options]

Commands:
  doctor    Print resolved paths and basic checks (no changes)
  install   Ensure AtomVM exists, link component, patch config, build + flash firmware
  monitor   Attach serial monitor (idf.py monitor)

Options:
  --atomvm-repo PATH   AtomVM repo root (or wrapper containing AtomVM/)
  --idf-dir PATH       ESP-IDF root (contains export.sh). Optional.
  --target TARGET      esp32 / esp32s3 / etc (default: esp32s3)
  --port PORT          Serial device (required for install/monitor)
  -h, --help           Show help

Examples:
  ${script_name} doctor
  ${script_name} install --target esp32s3 --port /dev/ttyACM0
  ${script_name} monitor --port /dev/ttyACM0

ESP-IDF discovery (if --idf-dir not provided):
  Uses ESP_IDF_DIR, then IDF_PATH, else defaults to: \$HOME/esp/esp-idf
EOF
}

die() {
  printf "%b✖%b %s\n" "${C_RED}${C_BOLD}" "${C_RESET}" "$*" >&2
  exit 1
}

say() {
  local msg="$*"

  case "${msg}" in
  "✔"*)
    printf "%b%s%b\n" "${C_GREEN}" "${msg}" "${C_RESET}"
    ;;
  "Next:"*)
    printf "%b%s%b\n" "${C_YELLOW}" "${msg}" "${C_RESET}"
    ;;
  *)
    printf "%s\n" "${msg}"
    ;;
  esac
}

run() {
  printf "%b+%b %s\n" "${C_CYAN}${C_BOLD}" "${C_RESET}" "$*"
  "$@"
}

require_cmd() {
  local cmd="$1"
  if command -v "${cmd}" >/dev/null 2>&1; then
    :
  else
    die "Missing dependency: ${cmd}"
  fi
}

script_dir() {
  cd "$(dirname "${BASH_SOURCE[0]}")" && pwd
}

repo_root() {
  # Assumes this script lives under <repo>/scripts/
  cd "$(script_dir)/.." && pwd
}

resolve_idf_dir() {
  local override="$1"

  if [ -n "${override}" ]; then
    printf "%s" "${override}"
    return 0
  fi

  if [ -n "${ESP_IDF_DIR:-}" ]; then
    printf "%s" "${ESP_IDF_DIR}"
    return 0
  fi

  if [ -n "${IDF_PATH:-}" ]; then
    printf "%s" "${IDF_PATH}"
    return 0
  fi

  printf "%s" "${HOME}/esp/esp-idf"
}

resolve_atomvm_paths() {
  local this_repo_root="$1"
  local override="$2"

  local atomvm_root=""
  local esp32_dir=""

  if [ -n "${override}" ]; then
    if [ -d "${override}/src/platforms/esp32" ]; then
      atomvm_root="${override}"
      esp32_dir="${override}/src/platforms/esp32"
      printf "%s\n%s\n" "${atomvm_root}" "${esp32_dir}"
      return 0
    fi

    if [ -d "${override}/AtomVM/src/platforms/esp32" ]; then
      atomvm_root="${override}/AtomVM"
      esp32_dir="${override}/AtomVM/src/platforms/esp32"
      printf "%s\n%s\n" "${atomvm_root}" "${esp32_dir}"
      return 0
    fi

    die "Could not find AtomVM under --atomvm-repo: ${override}"
  fi

  # If this repo already lives under AtomVM's esp32/components, derive paths from that.
  case "${this_repo_root}" in
  */src/platforms/esp32/components/*)
    esp32_dir="$(cd "${this_repo_root}/../.." && pwd)"
    atomvm_root="$(cd "${esp32_dir}/../../../.." && pwd)"
    printf "%s\n%s\n" "${atomvm_root}" "${esp32_dir}"
    return 0
    ;;
  esac

  atomvm_root="${HOME}/atomvm/AtomVM"
  esp32_dir="${atomvm_root}/src/platforms/esp32"
  printf "%s\n%s\n" "${atomvm_root}" "${esp32_dir}"
}

ensure_atomvm_repo() {
  local atomvm_root="$1"
  local override_was_set="$2"

  local url="https://github.com/atomvm/AtomVM.git"
  local branch="main"

  if [ "${override_was_set}" = "1" ]; then
    if [ -d "${atomvm_root}/.git" ]; then
      :
    else
      die "AtomVM repo not found at --atomvm-repo location: ${atomvm_root}"
    fi
    return 0
  fi

  if [ -d "${atomvm_root}/.git" ]; then
    say "✔ AtomVM repo exists: ${atomvm_root}"
    return 0
  fi

  if [ -e "${atomvm_root}" ]; then
    die "Default AtomVM path exists but is not a git repo: ${atomvm_root}"
  fi

  require_cmd git
  mkdir -p "$(dirname "${atomvm_root}")"
  say "Cloning AtomVM into: ${atomvm_root}"
  run git clone --filter=blob:none --depth 1 --branch "${branch}" "${url}" "${atomvm_root}"
}

canonical_path() {
  local path="$1"

  if command -v realpath >/dev/null 2>&1; then
    realpath "${path}" 2>/dev/null || true
    return 0
  fi

  if command -v readlink >/dev/null 2>&1; then
    readlink -f "${path}" 2>/dev/null || true
    return 0
  fi

  printf "%s" ""
}

ensure_component_link() {
  local this_repo_root="$1"
  local esp32_dir="$2"

  local name=""
  name="$(basename "${this_repo_root}")"

  local want="${esp32_dir}/components/${name}"

  mkdir -p "${esp32_dir}/components"

  if [ -L "${want}" ]; then
    local want_real=""
    local repo_real=""
    want_real="$(canonical_path "${want}")"
    repo_real="$(canonical_path "${this_repo_root}")"

    if [ -n "${want_real}" ] && [ -n "${repo_real}" ]; then
      if [ "${want_real}" = "${repo_real}" ]; then
        say "✔ component symlink ok: ${want}"
        return 0
      fi
      die "Component symlink exists but points elsewhere: ${want} -> ${want_real}"
    fi

    # If we cannot resolve canonical paths, accept the existing symlink.
    say "✔ component symlink present: ${want}"
    return 0
  fi

  if [ -e "${want}" ]; then
    die "Component path exists but is not a symlink: ${want}"
  fi

  say "Linking component into: ${want}"
  run ln -s "${this_repo_root}" "${want}"
}

patch_sdkconfig_defaults() {
  local esp32_dir="$1"
  local path="${esp32_dir}/sdkconfig.defaults"
  local want='CONFIG_PARTITION_TABLE_CUSTOM_FILENAME="partitions-elixir.csv"'

  if [ -f "${path}" ]; then
    :
  else
    die "sdkconfig.defaults not found: ${path}"
  fi

  if grep -qF "${want}" "${path}"; then
    say "✔ sdkconfig.defaults already configured (partitions-elixir.csv)"
    return 0
  fi

  printf "\n%s\n" "${want}" >>"${path}"
  say "✔ patched: ${path}"
}

build_boot_avm_if_needed() {
  local atomvm_root="$1"
  local boot_avm="${atomvm_root}/build/libs/esp32boot/elixir_esp32boot.avm"

  if [ -f "${boot_avm}" ]; then
    return 0
  fi

  require_cmd cmake

  say "Generating boot AVM (Generic UNIX build)"
  mkdir -p "${atomvm_root}/build"

  (
    cd "${atomvm_root}/build"
    run cmake ..
    run cmake --build .
  )

  if [ -f "${boot_avm}" ]; then
    :
  else
    die "boot AVM missing after build: ${boot_avm}"
  fi
}

with_idf_env() {
  local idf_dir="$1"
  local workdir="$2"
  shift 2

  if [ -f "${idf_dir}/export.sh" ]; then
    :
  else
    die "ESP-IDF export.sh not found: ${idf_dir}/export.sh"
  fi

  if [ -d "${workdir}" ]; then
    :
  else
    die "Workdir not found: ${workdir}"
  fi

  (
    set -Eeuo pipefail
    # shellcheck source=/dev/null
    source "${idf_dir}/export.sh" >/dev/null 2>&1

    if command -v idf.py >/dev/null 2>&1; then
      :
    else
      die "idf.py not found in PATH after sourcing ESP-IDF"
    fi

    cd "${workdir}"
    "$@"
  )
}

doctor_cmd() {
  local this_repo_root="$1"
  local atomvm_root="$2"
  local esp32_dir="$3"
  local idf_dir="$4"
  local target="$5"
  local port_display="$6"
  local override_was_set="$7"

  local component_name=""
  component_name="$(basename "${this_repo_root}")"

  say ""
  say "Paths"
  say "- repo_root:   ${this_repo_root}"
  say "- atomvm_root: ${atomvm_root}"
  say "- esp32_dir:   ${esp32_dir}"
  say "- idf_dir:     ${idf_dir}"
  say ""
  say "Config"
  say "- target:      ${target}"
  say "- port:        ${port_display}"
  say ""
  say "Checks"

  if [ -f "${idf_dir}/export.sh" ]; then
    say "- ESP-IDF:     export.sh found"
  else
    say "- ESP-IDF:     missing export.sh"
  fi

  if [ -d "${atomvm_root}/.git" ]; then
    say "- AtomVM:      ok"
  else
    if [ "${override_was_set}" = "1" ]; then
      say "- AtomVM:      missing at --atomvm-repo"
    else
      say "- AtomVM:      missing at default (install will clone)"
    fi
  fi

  if [ -d "${esp32_dir}" ]; then
    say "- ESP32 dir:   ok"
  else
    say "- ESP32 dir:   missing"
  fi

  if [ -e "${esp32_dir}/components/${component_name}" ]; then
    say "- Component:   present (${esp32_dir}/components/${component_name})"
  else
    say "- Component:   not present under esp32/components"
  fi

  if [ "${port_display}" != "(not set)" ]; then
    if [ -e "${port_display}" ]; then
      say "- Port:        ok"
    else
      say "- Port:        not found (${port_display})"
    fi
  fi

  say ""

  say "Inspect"

  if [ -d "${esp32_dir}/components" ]; then
    say "- components:   ${esp32_dir}/components"
    run ls -1 "${esp32_dir}/components"
  else
    say "- components:   missing (${esp32_dir}/components)"
  fi

  say ""

  if [ -f "${esp32_dir}/sdkconfig.defaults" ]; then
    say "- sdkconfig.defaults: ${esp32_dir}/sdkconfig.defaults"
    run cat "${esp32_dir}/sdkconfig.defaults"
  else
    say "- sdkconfig.defaults: missing (${esp32_dir}/sdkconfig.defaults)"
  fi

  say ""
}

install_cmd() {
  local this_repo_root="$1"
  local atomvm_root="$2"
  local esp32_dir="$3"
  local idf_dir="$4"
  local target="$5"
  local port="$6"
  local override_was_set="$7"

  if [ -n "${port}" ]; then
    :
  else
    die "--port is required for install (e.g. --port /dev/ttyACM0)"
  fi

  if [ -e "${port}" ]; then
    :
  else
    die "Serial port not found: ${port}"
  fi

  ensure_atomvm_repo "${atomvm_root}" "${override_was_set}"

  if [ -d "${esp32_dir}" ]; then
    :
  else
    die "AtomVM ESP32 platform dir missing: ${esp32_dir}"
  fi

  ensure_component_link "${this_repo_root}" "${esp32_dir}"
  patch_sdkconfig_defaults "${esp32_dir}"
  build_boot_avm_if_needed "${atomvm_root}"

  say "Building + flashing AtomVM firmware"
  with_idf_env "${idf_dir}" "${esp32_dir}" bash -Eeuo pipefail -c '
    target="$1"
    port="$2"

    echo "+ idf.py fullclean"
    idf.py fullclean

    echo "+ idf.py set-target ${target}"
    idf.py set-target "${target}"

    echo "+ idf.py reconfigure"
    idf.py reconfigure

    echo "+ idf.py build"
    idf.py build

    echo "+ idf.py -p ${port} flash"
    idf.py -p "${port}" flash
  ' _ "${target}" "${port}"

  say "✔ install complete"
  say "Next: flash the Elixir app from examples/elixir (mix do clean + atomvm.esp32.flash ...)"
}

monitor_cmd() {
  local esp32_dir="$1"
  local idf_dir="$2"
  local port="$3"

  if [ -n "${port}" ]; then
    :
  else
    die "--port is required for monitor (e.g. --port /dev/ttyACM0)"
  fi

  if [ -e "${port}" ]; then
    :
  else
    die "Serial port not found: ${port}"
  fi

  say "Starting serial monitor"
  with_idf_env "${idf_dir}" "${esp32_dir}" idf.py -p "${port}" monitor
}

main() {
  local cmd="${1:-}"
  if [ -n "${cmd}" ]; then
    :
  else
    usage
    return 2
  fi

  if [ "${cmd}" = "-h" ] || [ "${cmd}" = "--help" ]; then
    usage
    return 0
  fi
  shift || true

  local atomvm_repo_override=""
  local idf_dir_override=""
  local override_was_set="0"
  local target="esp32s3"
  local port=""

  while [ "$#" -gt 0 ]; do
    case "$1" in
    --atomvm-repo)
      shift
      if [ "$#" -gt 0 ]; then
        atomvm_repo_override="$1"
        override_was_set="1"
        shift
      else
        die "--atomvm-repo requires a value"
      fi
      ;;
    --idf-dir)
      shift
      if [ "$#" -gt 0 ]; then
        idf_dir_override="$1"
        shift
      else
        die "--idf-dir requires a value"
      fi
      ;;
    --target)
      shift
      if [ "$#" -gt 0 ]; then
        target="$1"
        shift
      else
        die "--target requires a value"
      fi
      ;;
    --port | -p)
      shift
      if [ "$#" -gt 0 ]; then
        port="$1"
        shift
      else
        die "--port requires a value"
      fi
      ;;
    -h | --help)
      usage
      return 0
      ;;
    *)
      die "Unknown option: $1 (use --help)"
      ;;
    esac
  done

  local this_repo_root=""
  this_repo_root="$(repo_root)"

  local idf_dir=""
  idf_dir="$(resolve_idf_dir "${idf_dir_override}")"

  local atomvm_root=""
  local esp32_dir=""
  {
    IFS=$'\n' read -r atomvm_root
    IFS=$'\n' read -r esp32_dir
  } < <(resolve_atomvm_paths "${this_repo_root}" "${atomvm_repo_override}")

  local port_display="(not set)"
  if [ -n "${port}" ]; then
    port_display="${port}"
  fi

  case "${cmd}" in
  doctor)
    doctor_cmd "${this_repo_root}" "${atomvm_root}" "${esp32_dir}" "${idf_dir}" "${target}" "${port_display}" "${override_was_set}"
    ;;
  install)
    install_cmd "${this_repo_root}" "${atomvm_root}" "${esp32_dir}" "${idf_dir}" "${target}" "${port}" "${override_was_set}"
    ;;
  monitor)
    monitor_cmd "${esp32_dir}" "${idf_dir}" "${port}"
    ;;
  *)
    usage
    die "Unknown command: ${cmd}"
    ;;
  esac
}

main "$@"
