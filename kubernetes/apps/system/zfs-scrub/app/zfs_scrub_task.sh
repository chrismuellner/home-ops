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

# expect "scrub repaired 0B in ... with 0 errors" and "errors: No known data errors";
# anything else (repaired data, scrub errors, data errors) fails the job
scan_line=$(echo "$final_status" | grep "^ *scan:")
if ! echo "$scan_line" | grep -Eq "scrub repaired 0B .* with 0 errors" ||
  ! echo "$final_status" | grep -q "errors: No known data errors"; then
  echo "ALERT: zpool scrub on '$ZPOOL' found problems."
  echo "$final_status"
  exit 1
else
  scrub_info=$(echo "$scan_line" | sed 's/.*scrub/scrub/')
  echo "OK: zpool scrub on '$ZPOOL' completed successfully. $scrub_info"
fi
