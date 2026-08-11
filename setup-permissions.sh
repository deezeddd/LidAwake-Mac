#!/bin/bash
# One-time setup: lets LidAwake flip the sleep setting without a password prompt.
# Installs a sudoers rule scoped to exactly two pmset commands, nothing else.
set -e

RULE="$(whoami) ALL=(ALL) NOPASSWD: /usr/bin/pmset -a disablesleep 1, /usr/bin/pmset -a disablesleep 0"
TMP=$(mktemp)
echo "$RULE" > "$TMP"

sudo visudo -cf "$TMP"
sudo install -m 440 -o root -g wheel "$TMP" /etc/sudoers.d/lid-awake
rm -f "$TMP"
echo "Installed /etc/sudoers.d/lid-awake"
