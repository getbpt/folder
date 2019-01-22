#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
RUNTIME_DIR="$ROOT_DIR/.runtime"
BINARY_DIR="$RUNTIME_DIR/.bin"
GOMETALINTER="${BINARY_DIR}/gometalinter"
GOENV_DIR="$RUNTIME_DIR/.goenv"
export GOENV_ROOT="$GOENV_DIR"
export PATH="$GOENV_ROOT/bin:${BINARY_DIR}:$PATH"

function verbose() { echo -e "$*"; }
function error() { echo -e "ERROR: $*" 1>&2; }
function fatal() { echo -e "ERROR: $*" 1>&2; exit 1; }
function pushd () { command pushd "$@" > /dev/null; }
function popd () { command popd > /dev/null; }

function trap_add() {
  local localtrap_add_cmd=$1; shift || fatal "${FUNCNAME[*]} usage error: $?"
  for trap_add_name in "$@"; do
    trap -- "$(
      extract_trap_cmd() { printf '%s\n' "$3"; }
      eval "extract_trap_cmd $(trap -p "${trap_add_name}")"
      printf '%s\n' "${trap_add_cmd}"
    )" "${trap_add_name}" || fatal "unable to add to trap ${trap_add_name}: $?"
  done
}
declare -f -t trap_add

function get_platform() {
  local unameOut
  unameOut="$(uname -s)" || fatal "unable to get platform type: $?"
  case "${unameOut}" in
    Linux*)
      echo "linux"
    ;;
    Darwin*)
      echo "darwin"
    ;;
    *)
      echo "Unsupported machine type :${unameOut}"
      exit 1
    ;;
  esac
}

PLATFORM=$(get_platform)
GOMETALINTER_URL="https://github.com/alecthomas/gometalinter/releases/download/v2.0.12/gometalinter-2.0.12-$PLATFORM-amd64.tar.gz"

function get_go_version() {
  local go_version
  go_version="$(cat "$ROOT_DIR/.go-version")" || fatal "failed to read go version: $?"
  echo "$go_version"
}

function download_go() {
  if [[ ! -d "$GOENV_DIR" ]]; then
    git clone https://github.com/syndbg/goenv.git "$GOENV_DIR" || fatal "failed to get goenv: $?"
  fi
  eval "$(goenv init - --no-rehash)"
  local go_version="$(get_go_version)"
  goenv install ${go_version} --skip-existing || fatal "failed to install go ${go_version}: $?"
  goenv rehash 2> /dev/null || fatal "failed to rehash goenv: $?"
  activate_go
}

function activate_go() {
  eval "$(goenv init - --no-rehash)"
  local go_version="$(get_go_version)"
  goenv shell ${go_version} || fatal "Failed to run switch to go ${go_version}: $?"
}

function download_gometalinter() {
  if [[ ! -f "$GOMETALINTER" ]]; then
    verbose "   --> $GOMETALINTER"
    local tmpdir=`mktemp -d`
    trap_add "rm -rf $tmpdir" EXIT
    pushd ${tmpdir}
    curl -L -s -O ${GOMETALINTER_URL} || fatal "failed to download '$GOMETALINTER_URL': $?"
    for i in *.tar.gz; do
      [[ "$i" = "*.tar.gz" ]] && continue
      tar xzf "$i" -C ${tmpdir} --strip-components 1 && rm -r "$i"
    done
    popd
    mkdir -p ${BINARY_DIR}
    cp ${tmpdir}/* ${BINARY_DIR}/
  fi
}

function download_goveralls() {
  if [[ -n "$TRAVIS" ]]; then
    if [[ ! -x "$(command -v goveralls)" ]]; then
      echo "   --> goveralls"
      go get github.com/mattn/goveralls || fatal "go get 'github.com/mattn/goveralls' failed: $?"
    fi
  fi
}

function download_binaries() {
  verbose "Fetching binaries..."
  download_go || fatal "failed to download 'go': $?"
  download_gometalinter || fatal "failed to download 'gometalinter': $?"
  download_goveralls || fatal "failed to download 'goveralls': $?"
}

function format_source() {
  local gofiles=$(find . -path ./vendor -prune -o -path ./.runtime -prune -o -print | grep '\.go$')

  verbose "Formatting source..."
  if [[ ${#gofiles[@]} -gt 0 ]]; then
    while read -r gofile; do
      gofmt -s -w $PWD/${gofile}
    done <<< "$gofiles"
  fi

  if [[ -n "$TRAVIS" ]] && [[ -n "$(git status --porcelain)" ]]; then
    fatal "Source not formatted"
  fi
}

function lint_source() {
  verbose "Linting source..."
  ${GOMETALINTER} --disable-all --enable=vet --enable=gocyclo --cyclo-over=15 --enable=golint --min-confidence=.85 --enable=ineffassign --skip=Godeps --skip=vendor --skip=third_party --skip=testdata --vendor ./... || fatal "gometalinter failed: $?"
}

function run_tests() {
  verbose "Running tests..."
  if [[ -n "$TRAVIS" ]]; then
    goveralls -v -service=travis-ci || fatal "goveralls: $?"
  else
    go test -v ./... || fatal "$gopackage tests failed: $?"
  fi
}

function prepare() {
  download_binaries
}

function build() {
  activate_go
  format_source
  lint_source
  run_tests
}