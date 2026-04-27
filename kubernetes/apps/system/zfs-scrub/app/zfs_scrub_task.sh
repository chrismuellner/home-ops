#!/bin/sh

ZPOOL="${ZPOOL:-zfspv-pool}"

if [ -z "$ZPOOL" ]; then
  echo "Error: ZPOOL name is not set." >&2
  exit 1
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') - Starting scrub on zpool $ZPOOL"
zpool scrub "$ZPOOL"

while true; do
  sleep 60

  zpool_status=$(zpool status "$ZPOOL")
  scrub_line=$(echo "$zpool_status" | grep -n "^ *scan:" | cut -d: -f1)

  if [ -n "$scrub_line" ]; then
    scan_info=$(echo "$zpool_status" | sed -n "$scrub_line,$(($scrub_line + 2))p")
  else
    scan_info="No scan information found."
  fi

  echo "$(date '+%Y-%m-%d %H:%M:%S') - $scan_info"

  if ! echo "$scan_info" | grep -q "scrub in progress"; then
    break
  fi
done

final_status=$(zpool status "$ZPOOL")
echo "$(date '+%Y-%m-%d %H:%M:%S') - Scrub completed."

if echo "$final_status" | grep -q "errors" && ! echo "$final_status" | grep -q "0 errors"; then
  echo "ALERT: zpool scrub on '$ZPOOL' completed with errors."
  echo "$final_status"
  exit 1
else
  scrub_info=$(echo "$final_status" | grep "^ *scan:" | sed 's/.*scrub/scrub/')
  echo "OK: zpool scrub on '$ZPOOL' completed successfully. $scrub_info"
fi
