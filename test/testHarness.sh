#!/bin/bash
SERIES_STRATEGIES=(\ 
# 0x30303039\ 
# 0x30313039\ 
# 0x30323039\ 
# 0x31383039\  
# 0x0030FF00028B\ 
# 0x0031FF00028B\ 
# 0x0032FF00028B\ 
# 0x0138FF00028B\ 
#   0x0030FF00028B,0xb268E2C85861B74ec75fe728Ae40D9A2308AD9Bb\ 
# 0x0031FF00028B,0x9ca2a34ea52bc1264D399aCa042c0e83091FEECe\ 
# 0x0032FF00028B,0x5dd6DcAE25dFfa0D46A04C9d99b4875044289fB2\ 
# 0x0138FF00028B,0x4B010fA49E8b673D0682CDeFCF7834328076748C\ 
0x00A0FF000288,0x861509A3fA7d87FaA0154AAE2CB6C1f92639339A
# 0x00A0FF00028B,0xfe2Aba5ba890AF0ee8B6F2d488B1f85C9E7C5643\ 
)

ILK_IDS=(\ 
  0x3030 # ETH \ 
  # 0x3031 # DAI \ 
  # 0x3032 # USDC \ 
# 0x3033 # WBTC \ 
# 0x3034 # WSTETH \ 
# 0x3036 # LINK \ 
# 0x3037 # ENS \ 
# # # 0x3039 # YVUSDC \ 
# 0x3130 # UNI \ 
# 0x3138 # FRAX \ 
# 0x3330 # YSDAI6MMSASSET \ 
# 0x3331 # YSDAI6MJDASSET \ 
# 0x3332 # YSUSDC6MMSASSET \ 
# 0x3333 # YSUSDC6MJDASSET \ 
# 0x3334 # YSETH6MMSASSET \ 
# 0x3335 # YSETH6MJDASSET \ 
# 0x3336 # YSFRAX6MMSASSET \ 
# 0x3337 # YSFRAX6MJDASSET \ 
# 0x3338 # CRAB \ 
  # 0x30A0 # USDT\
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

export RPC="ARBITRUM"
export NETWORK="ARBITRUM"
export MOCK=false

# testBorrowUnderlying -> fyTokenInForSharesOut
# testRepayUnderlyingBeforeMaturity -> fyTokenOutForSharesIn
# testRepayVaultUnderlyingBeforeMaturity -> sharesInForFYTokenOut
# testLend -> fyTokenOutForSharesIn
# testCloseLendBeforeMaturity -> sharesOutForFYTokenIn

for SERIES_STRATEGY in ${SERIES_STRATEGIES[@]}; do
  # echo $SERIES_STRATEGY
  SERIES_ID_=`echo $SERIES_STRATEGY | sed 's/,.*//g'`
  STRATEGY_=`echo $SERIES_STRATEGY | sed 's/.*,//g'`
  for ILK_ID_ in ${ILK_IDS[@]}; do
    echo "SeriesId: " $SERIES_ID_
    echo "IlkId:    " $ILK_ID_
    echo "Strategy: " $STRATEGY_
    STRATEGY=$STRATEGY_ SERIES_ID=$SERIES_ID_ ILK_ID=$ILK_ID_ forge test -c test/RecipeHarness.t.sol -vvvv -m testBorrowUnderlying
    # STRATEGY=$STRATEGY_ SERIES_ID=$SERIES_ID_ ILK_ID=$ILK_ID_ forge test -c test/RecipeHarness.t.sol -vvvv -m testProvideLiquidityByBorrowing
  done
done
