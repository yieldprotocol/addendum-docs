#!/bin/bash
SERIES_IDS=(\ 
  0x30303039\  
)

ILK_IDS=(\ 
  0x3030 # ETH \ 
  0x3031 # DAI \ 
  0x3032 # USDC \ 
  0x3033 # WBTC \ 
  0x3034 # WSTETH \ 
  0x3036 # LINK \ 
  0x3037 # ENS \ 
  0x3039 # YVUSDC \ 
  0x3130 # UNI \ 
  0x3138 # FRAX \ 
  0x3330 # YSDAI6MMSASSET \ 
  0x3331 # YSDAI6MJDASSET \ 
  0x3332 # YSUSDC6MMSASSET \ 
  0x3333 # YSUSDC6MJDASSET \ 
  0x3334 # YSETH6MMSASSET \ 
  0x3335 # YSETH6MJDASSET \ 
  0x3336 # YSFRAX6MMSASSET \ 
  0x3337 # YSFRAX6MJDASSET \ 
  0x3338 # CRAB \ 
)

# ERC1155
# 0x3132 # FDAI2203 \ 
# 0x3133 # FUSDC2203 \ 
# 0x3134 # FDAI2206 \ 
# 0x3135 # FUSDC2206 \ 
# 0x3136 # FDAI2209 \ 
# 0x3137 # FUSDC2209 \ 
# 0x3233 # FDAI2212 \ 
# 0x3234 # FUSDC2212 \ 
# 0x3235 # FDAI2303 \ 
# 0x3236 # FUSDC2303 \ 
# 0x3238 # FETH2212 \ 
# 0x3239 # FETH2303 \ 

# Not ilks
# 0x3035 # STETH \ 
# 0x3038 # YVDAI \ 
# 0x3131 # MKR \ 
# 0x3139 # CVX3CRV \ 
# 0x3230 # EWETH \ 
# 0x3231 # EDAI \ 
# 0x3232 # EUSDC \ 
# 0x3237 # EFRAX \ 
# 0x3339 # OSQTH \ 

export RPC="HARNESS"
export NETWORK="MAINNET"
export MOCK=false

for SERIES_ID_ in ${SERIES_IDS[@]}; do
  echo "SeriesId: " $SERIES_ID_
  for ILK_ID_ in ${ILK_IDS[@]}; do
    echo "IlkId: " $ILK_ID_
      SERIES_ID=$SERIES_ID_ ILK_ID=$ILK_ID_ forge test --match-path test/RecipeHarness.t.sol $1
  done
done