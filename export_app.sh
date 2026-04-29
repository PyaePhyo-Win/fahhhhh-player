#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'HELP'
Usage: ./export_app.sh [options]

Builds FahhPlayer and exports a macOS .app bundle.

Options:
  --output-dir <path>      Directory to receive FahhPlayer.app and FahhPlayer.zip
  --configuration <name>   Xcode build configuration to use (default: Release)
  --no-zip                 Skip creating FahhPlayer.zip
  --help                   Show this help message
HELP
}

resolve_zip_stamp() {
  local marketing_version

  marketing_version="$(xcodebuild \
    -project "${PROJECT_PATH}" \
    -scheme "${SCHEME}" \
    -configuration "${CONFIGURATION}" \
    -showBuildSettings 2>/dev/null | awk -F ' = ' '/MARKETING_VERSION/ { print $2; exit }')"

  marketing_version="$(printf '%s' "${marketing_version}" | tr -d '[:space:]')"

  if [[ -n "${marketing_version}" ]]; then
    printf '%s' "${marketing_version}"
  else
    date '+%Y%m%d'
  fi
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

cleanup_internal_exports() {
  local candidate_path

  [[ ${EXPORT_SUCCEEDED} -eq 1 ]] || return

  rm -rf "${DERIVED_DATA_PATH}"

  [[ -d "${PROJECT_BUILD_ROOT}" ]] || return

  for candidate_path in "${PROJECT_BUILD_ROOT}"/export-output*; do
    [[ -e "${candidate_path}" ]] || continue
    [[ "$(cd "${candidate_path}" && pwd)" == "${OUTPUT_DIR_CANONICAL}" ]] && continue
    rm -rf "${candidate_path}"
  done
}

OUTPUT_DIR="${HOME}/Desktop"
CONFIGURATION="Release"
CREATE_ZIP=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output-dir)
      [[ $# -ge 2 ]] || { echo "Missing value for --output-dir" >&2; exit 1; }
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --configuration)
      [[ $# -ge 2 ]] || { echo "Missing value for --configuration" >&2; exit 1; }
      CONFIGURATION="$2"
      shift 2
      ;;
    --no-zip)
      CREATE_ZIP=0
      shift
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

require_command xcodebuild
require_command ditto

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_PATH="${PROJECT_ROOT}/FahhPlayer.xcodeproj"
SCHEME="FahhPlayer"
APP_NAME="FahhPlayer.app"
PROJECT_BUILD_ROOT="${PROJECT_ROOT}/.build"
DERIVED_DATA_PATH="${PROJECT_BUILD_ROOT}/export-derived-data"
BUILD_OUTPUT_PATH="${DERIVED_DATA_PATH}/Build/Products/${CONFIGURATION}/${APP_NAME}"
EXPORT_SUCCEEDED=0

if [[ ! -d "${PROJECT_PATH}" ]]; then
  echo "Project file not found at ${PROJECT_PATH}" >&2
  exit 1
fi

mkdir -p "${OUTPUT_DIR}"
OUTPUT_DIR_CANONICAL="$(cd "${OUTPUT_DIR}" && pwd)"
trap cleanup_internal_exports EXIT

rm -rf "${DERIVED_DATA_PATH}"

echo "Building ${SCHEME} (${CONFIGURATION})..."
xcodebuild \
  -project "${PROJECT_PATH}" \
  -scheme "${SCHEME}" \
  -configuration "${CONFIGURATION}" \
  -derivedDataPath "${DERIVED_DATA_PATH}" \
  build

if [[ ! -d "${BUILD_OUTPUT_PATH}" ]]; then
  echo "Built app not found at ${BUILD_OUTPUT_PATH}" >&2
  exit 1
fi

DEST_APP_PATH="${OUTPUT_DIR}/${APP_NAME}"
ZIP_STAMP="$(resolve_zip_stamp)"
ZIP_NAME="FahhPlayer-${ZIP_STAMP}.zip"
DEST_ZIP_PATH="${OUTPUT_DIR}/${ZIP_NAME}"

rm -rf "${DEST_APP_PATH}"
cp -R "${BUILD_OUTPUT_PATH}" "${DEST_APP_PATH}"

echo "Exported app: ${DEST_APP_PATH}"

if [[ ${CREATE_ZIP} -eq 1 ]]; then
  rm -f "${DEST_ZIP_PATH}"
  ditto -c -k --sequesterRsrc --keepParent "${DEST_APP_PATH}" "${DEST_ZIP_PATH}"
  echo "Exported zip: ${DEST_ZIP_PATH}"
fi

EXPORT_SUCCEEDED=1
