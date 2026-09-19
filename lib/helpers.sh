#!/usr/bin/env bash

c_reset="\033[0m"
c_brand="\033[38;2;220;20;60m"   # crimson

# for logging colors
c_info="\033[1;34m"; c_ok="\033[1;32m"; c_warn="\033[1;33m"; c_err="\033[1;31m"

info()    { echo -e "${c_info}==>${c_reset} $*"; }
success() { echo -e "${c_ok}✔${c_reset} $*"; }
warn()    { echo -e "${c_warn}⚠${c_reset} $*"; }
error()   { echo -e "${c_err}✖${c_reset} $*" >&2; }


print_banner() {
  clear
  echo -ne "$c_brand"
  cat <<'BANNER'
███████╗███╗   ███╗      ███████╗███████╗██████╗  ██████╗ ██████╗  █████╗ 
██╔════╝████╗ ████║      ██╔════╝██╔════╝██╔══██╗██╔═══██╗██╔══██╗██╔══██╗
█████╗  ██╔████╔██║█████╗█████╗  █████╗  ██║  ██║██║   ██║██████╔╝███████║
██╔══╝  ██║╚██╔╝██║╚════╝██╔══╝  ██╔══╝  ██║  ██║██║   ██║██╔══██╗██╔══██║
██║     ██║ ╚═╝ ██║      ██║     ███████╗██████╔╝╚██████╔╝██║  ██║██║  ██║
╚═╝     ╚═╝     ╚═╝      ╚═╝     ╚══════╝╚═════╝  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝
BANNER
  echo -ne "$c_reset"
  echo
  echo "  Welcome to fm-fedora — your Fedora box, set up your way."
  echo "  Sit back, this'll take a few minutes."
  echo
}

