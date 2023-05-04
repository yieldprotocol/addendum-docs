#!/bin/bash

SERIES_IDS=(\ 
  0x0030FF00028B\ 
  0x0031FF00028B\ 
  0x0032FF00028B\ 
  0x0138FF00028B\ 
  0x00A0FF00028B\ 
  0x303030390000\ 
  0x303130390000\ 
  0x303230390000\ 
  0x313830390000\ 
  0x00A0FF000288\ 
)

export RPC="HARNESS"
export NETWORK="MAINNET"
export MOCK=false

for SERIES_ID in ${SERIES_IDS[@]}; do
  echo "SeriesId:       " $SERIES_ID
  SERIES_ID=$SERIES_ID forge test --match-path test/PoolHarness.t.sol -v
done
