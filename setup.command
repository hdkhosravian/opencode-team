#!/bin/bash
# macOS: double-click this file. It runs setup.sh and keeps the Terminal window open at the end.
SETUP_PAUSE=1 exec bash "$(cd "$(dirname "$0")" && pwd)/setup.sh" "$@"
