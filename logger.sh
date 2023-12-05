#!/usr/bin/env bash

[ -f .env ] && source .env

# Utility functions
log_error() {
  echo "[ERROR] $1"
}
log_info() {
  if (("$DEBUG_LEVEL" > 0));
  then
    echo "[INFO ] $1"
  fi
}
log_debug() {
  if (("$DEBUG_LEVEL" > 1));
  then
    echo "[DEBUG] $1"
  fi
}
log_trace() {
  if (("$DEBUG_LEVEL" > 2));
  then
    echo "[TRACE] $1"
  fi
}

