#!/bin/bash
# Mataram repository source selector
MAIN_REPO="https://raw.githubusercontent.com/faisin/mataram/main"
RELEASE_ZIP="https://github.com/faisin/mataram/releases/latest/download/mataram-release.zip"

check_main(){ curl -fs "$MAIN_REPO/version" >/dev/null 2>&1; }
select_repo(){
 if check_main; then
   REPO="$MAIN_REPO"; SOURCE_TYPE="main"; return 0
 fi
 REPO="$RELEASE_ZIP"; SOURCE_TYPE="release"; return 1
}
get_arch(){
 case "$(uname -m)" in
 x86_64|amd64) echo amd64;;
 aarch64|arm64) echo arm64;;
 *) echo unknown;;
 esac
}
