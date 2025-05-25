#!/bin/bash

###
# Active Directory Scan
# z2rts
###

#ctrl + c control 
cleanup() {
  echo -e "\n[!] Scan interrupted by user. Cleaning up..."
  [[ -n "$scan_pid" ]] && kill "$scan_pid" 2>/dev/null
  exit 1
}
trap cleanup INT

#spinner
spinner() {
  local pid=$1
  local spin='-\|/'
  local i=0

  while kill -0 "$pid" 2>/dev/null; do
    i=$(( (i+1) %4 ))
    printf "\rExtract ports... ${spin:$i:1}"
    sleep 0.2
  done
  printf "\rExtract ports... Done!\n"
}

ip="$1"

if [[ -z "$ip" ]]; then
  echo "Usage: $0 <IP_ADDRESS>"
  exit 1
fi

ttl=$(ping -c 1 "$ip" | grep ttl= | awk -F'ttl=' '{print $2}' | awk '{print $1}')

if [[ "$ttl" -eq 127 || "$ttl" -eq 128 ]]; then
  echo "Is Windows (TTL=$ttl)"

  # Run nmap in the background
  scan_output=$(mktemp)
  nmap -p- -sS --min-rate 5000 --open -n -Pn "$ip" > "$scan_output" 2>/dev/null &
  scan_pid=$!
  spinner "$scan_pid"
  wait "$scan_pid"

  ports=$(grep '^[0-9]' "$scan_output" | cut -d '/' -f1 | tr '\n' ',' | sed 's/,$//')
  rm -f "$scan_output"

  if [[ -z "$ports" ]]; then
    echo "No open ports"
    exit 0
  fi

  num_ports=$(echo "$ports" | tr ',' '\n' | wc -l)
  echo "$num_ports ports detected, detailed scan..."
  nmap -p "$ports" -sCV -Pn "$ip" -oN ScanResult_$ip
  echo "\n=> Output file ScanResult_$ip\n"

else
  echo "Not Windows (TTL=$ttl)"
fi
