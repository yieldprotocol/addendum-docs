#!/bin/bash

SERIES_STRATEGIES=(\

### March series with V1 strategies (except for USDT which uses V2 strategy)
### March seriesId, June seriesId, March Strategy address, June Pool address, at time of writing
# 0x303130390000,0x0031FF00028b,0xe779cd75e6c574d83d3fd6c92f3cbe31dd32b1e1,0x02DbfAca22DF7e86897aDF65eb74188D79DAbeA6\ 
# 0x303230390000,0x0032FF00028b,0x92a5b31310a3ed4546e0541197a32101fcfbd5c8,0x536edc2a3dB3BFE558Cae74cEDCcD30F07F7121b\ 
# 0x303030390000,0x0030FF00028b,0xd5b43b2550751d372025d048553352ac60f27151,0x2769ABE33010c710e24eA6aF8A2683C630BbD7D0\ 
# 0x00a0ff000288,0x00a0ff00028b,0xfe2Aba5ba890AF0ee8B6F2d488B1f85C9E7C5643,0x035072cb2912DAaB7B578F468Bd6F0d32a269E32\ 
### June series with V2 strategies
### June seriesId, March seriesId, June Strategy address, March Pool address, at time of writing
0x0031FF00028b,0x303130390000,0x8a4f806376322258c4278A0572Db072C1a36ABe2,0x22E1e5337C5BA769e98d732518b2128dE14b553C\ 
# 0x0032FF00028b,0x303230390000,0x56C16E62A24B5cD2aBd2941d6e744eC0756Ded1b,0x2eb907fb4b71390dC5CD00e6b81B7dAAcE358193\ 
# 0x0030FF00028b,0x303030390000,0x3D9A3f957F34dE9d0BD2fcD3626aEDa107c092E6,0x79A6Be1Ae54153AA6Fc7e4795272c63F63B2a6DC\ 
# 0x00a0ff00028b,0x00a0ff000288,0x861509A3fA7d87FaA0154AAE2CB6C1f92639339A,0xb268E2C85861B74ec75fe728Ae40D9A2308AD9Bb
)

ILK_IDS=(\ 
  0x3030 # ETH \ 
  0x3031 # DAI \ 
  0x3032 # USDC \ 
#   0x3033 # WBTC \ 
#   0x3034 # WSTETH \ 
#   0x3036 # LINK \ 
#   0x3037 # ENS \ 
  # # 0x3039 # YVUSDC \ 
#   0x3130 # UNI \ 
#   0x3138 # FRAX \ 
  # 0x3330 # YSDAI6MMSASSET \ 
  # 0x3331 # YSDAI6MJDASSET \ 
  # 0x3332 # YSUSDC6MMSASSET \ 
  # 0x3333 # YSUSDC6MJDASSET \ 
  # 0x3334 # YSETH6MMSASSET \ 
  # 0x3335 # YSETH6MJDASSET \ 
  # 0x3336 # YSFRAX6MMSASSET \ 
  # 0x3337 # YSFRAX6MJDASSET \ 
  # 0x3338 # CRAB \ 
  0x30A0 # USDT\ 
)

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
export NETWORK="ARBITRUM"
export MOCK=false
export RECTIFY=false

for SERIES_STRATEGY in ${SERIES_STRATEGIES[@]}; do
  # echo $SERIES_STRATEGY
  SERIES_ID_=`echo $SERIES_STRATEGY | sed 's/,.*//'`
  ROLL_SERIES_ID_=`echo $SERIES_STRATEGY | sed 's/^[^,]*,//;s/,.*//'`
  STRATEGY_=`echo $SERIES_STRATEGY | sed 's/^[^,]*,[^,]*,\([^,]*\).*/\1/'`
  ROLL_POOL_=`echo $SERIES_STRATEGY | sed 's/.*,//'`
  for ILK_ID_ in ${ILK_IDS[@]}; do
    echo "SeriesId:       " $SERIES_ID_
    echo "Roll SeriesId:  " $ROLL_SERIES_ID_
    echo "IlkId:          " $ILK_ID_
    echo "Strategy:       " $STRATEGY_
    echo "Roll Pool:      " $ROLL_POOL_
    STRATEGY=$STRATEGY_ SERIES_ID=$SERIES_ID_ ROLL_SERIES_ID=$ROLL_SERIES_ID_ ILK_ID=$ILK_ID_ ROLL_POOL=$ROLL_POOL_ forge test --match-path test/RecipeHarness.t.sol

    # For ERC1155 tests 
    # STRATEGY=$STRATEGY_ SERIES_ID=$SERIES_ID_ ROLL_SERIES_ID=$ROLL_SERIES_ID_ ILK_ID=$ILK_ID_ ROLL_POOL=$ROLL_POOL_ forge test -c test/RecipeHarness.t.sol -vvvv --match-test testPostERC1155Collateral
    # STRATEGY=$STRATEGY_ SERIES_ID=$SERIES_ID_ ROLL_SERIES_ID=$ROLL_SERIES_ID_ ILK_ID=$ILK_ID_ ROLL_POOL=$ROLL_POOL_ forge test -c test/RecipeHarness.t.sol -vvvv -m testWithdrawERC1155Collateral
  done
done
