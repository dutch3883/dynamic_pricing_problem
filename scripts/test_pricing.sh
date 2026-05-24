#!/bin/bash

BASE_URL="http://localhost:3000/api/v1/pricing"
PERIODS=("Summer" "Autumn" "Winter" "Spring")
HOTELS=("FloatingPointResort" "GitawayHotel" "RecursionRetreat")
ROOMS=("SingletonRoom" "BooleanTwin" "RestfulKing")

for period in "${PERIODS[@]}"; do
  for hotel in "${HOTELS[@]}"; do
    for room in "${ROOMS[@]}"; do
      response=$(curl -s --connect-timeout 3 --max-time 30 "$BASE_URL?period=$period&hotel=$hotel&room=$room")
      echo "$period | $hotel | $room => $response"
    done
  done
done
