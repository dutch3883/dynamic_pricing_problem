#!/bin/bash

BASE_URL="${RATE_API_URL:-http://localhost:8080}"
TOKEN="${RATE_API_TOKEN:-04aa6f42aa03f220c2ae9a276cd68c62}"
PERIODS=("Summer" "Autumn" "Winter" "Spring")
HOTELS=("FloatingPointResort" "GitawayHotel" "RecursionRetreat")
ROOMS=("SingletonRoom" "BooleanTwin" "RestfulKing")

for period in "${PERIODS[@]}"; do
  for hotel in "${HOTELS[@]}"; do
    for room in "${ROOMS[@]}"; do
      body=$(cat <<EOF
{"attributes":[{"period":"$period","hotel":"$hotel","room":"$room"}]}
EOF
)
      code=$(curl -s --connect-timeout 3 --max-time 10 -o /tmp/rate_api_response -w "%{http_code}" -X POST "$BASE_URL/pricing" \
        -H "Content-Type: application/json" \
        -H "token: $TOKEN" \
        -d "$body")
      body=$(tr -d '\n' < /tmp/rate_api_response)
      echo "$period | $hotel | $room => [$code] $body"
    done
  done
done
