# Some helpful functions
yell() { echo -e "${RED}FAILED> $* ${NC}" >&2; }
die() {
  yell "$*"
  exit 1
}
try() { "$@" || die "failed executing: $*"; }
log() { echo -e "--> $*"; }

# Colors for colorizing
RED='\033[0;31m'
GREEN='\033[0;32m'
PURPLE='\033[0;35m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m'

function maybe_sudo() {
  if [[ "$NEED_SUDO" == '1' ]]; then
    sudo "$@"
  else
    "$@"
  fi
}
