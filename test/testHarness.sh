#!/bin/bash

SERIES_STRATEGIES=(\
#   SERIES_ID, ALT_SERIES_ID, SERIES_STRATEGY, ALT_SERIES_POOL 
#  0x0030FF00028B,0x0030FF00028E,0xb268E2C85861B74ec75fe728Ae40D9A2308AD9Bb,0xD129B0351416C75C9f0623fB43Bb93BB4107b2A4\ 
#  0x0031FF00028B,0x0031FF00028E,0x9ca2a34ea52bc1264D399aCa042c0e83091FEECe,0xC2a463278387e649eEaA5aE5076e283260B0B1bE\ 
#  0x0032FF00028B,0x0032FF00028E,0x5dd6DcAE25dFfa0D46A04C9d99b4875044289fB2,0x06aaF385809c7BC00698f1E266eD4C78d6b8ba75\ 
#  0x0138FF00028B,0x0138FF00028E,0x4B010fA49E8b673D0682CDeFCF7834328076748C,0x2E8F62e3620497DbA8A2D7A18EA8212215805F22\ 
#  0x00A0FF00028B,0x00A0FF00028E,0x428e229aC5BC52a2e07c379B2F486fefeFd674b1,0xB4DbEc738Ffe47981D337C02Cb5746E456ecd505\ 
#  0x0030FF00028E,0x0030FF00028B,0x11f30C6B1173Ec6e0a6d622C8F17EEf3dc593764,0xc33Ec597244008B058AD0811f144E5b2B85BC1e0\ 
#  0x0031FF00028E,0x0031FF00028B,0xa6dbC40c75037895deE8D2415f1cE9E0Fb08Cf49,0x8808510D380B6f96dD2e2d9980D370B098840916\ 
#  0x0032FF00028E,0x0032FF00028B,0x59E9Db2c8995Ceeaf6A9ad0896601A5D3289444E,0x243118102406ea39e313568ED4c52e3B2c0e9EC1\ 
#  0x0138FF00028E,0x0138FF00028B,0x45A37D7a93416934EbF7AD85b35bCf39fCd68696,0x6d8fF80D3Cfc38c376D6E8af9C2C9Da88F9661F2\ 
#  0x00A0FF00028E,0x00A0FF00028B,0xF708005ceE17b2c5Fe1a01591E32ad6183A12EaE,0x98A0883856fc11e6131eAA25211a4d7474a5FD98\
   0x0030FF00028E,0030FF000291,0x3AE72b6F5Fb854eaa2B2b862359B6fCA7e4bC2fc,0xB9345c19291bB073b0E6483048fAFD0986AB82dF\ 
   0x0032FF00028E,0032FF000291,0xa874c4dF3CAA250307C0351AAa13d3d20f70c321,0x3667362C4B666B952383eDBE12fC9cC108D09cD7\
)

#    0x0030FF00028B,0xD129B0351416C75C9f0623fB43Bb93BB4107b2A4
#    0x0031FF00028B,0xC2a463278387e649eEaA5aE5076e283260B0B1bE
#    0x0032FF00028B,0x06aaF385809c7BC00698f1E266eD4C78d6b8ba75
#    0x0138FF00028B,0x2E8F62e3620497DbA8A2D7A18EA8212215805F22
#    0x00A0FF00028B,0xB4DbEc738Ffe47981D337C02Cb5746E456ecd505
#    0x0030FF00028E,0xc33Ec597244008B058AD0811f144E5b2B85BC1e0
#    0x0031FF00028E,0x8808510D380B6f96dD2e2d9980D370B098840916
#    0x0032FF00028E,0x243118102406ea39e313568ED4c52e3B2c0e9EC1
#    0x0138FF00028E,0x6d8fF80D3Cfc38c376D6E8af9C2C9Da88F9661F2
#    0x00A0FF00028E,0x98A0883856fc11e6131eAA25211a4d7474a5FD98

#    0x1030FF000000,0xb268E2C85861B74ec75fe728Ae40D9A2308AD9Bb
#    0x1031FF000000,0x9ca2a34ea52bc1264D399aCa042c0e83091FEECe
#    0x1032FF000000,0x5dd6DcAE25dFfa0D46A04C9d99b4875044289fB2
#    0x1138FF000000,0x4B010fA49E8b673D0682CDeFCF7834328076748C
#    0x10A0FF000000,0x428e229aC5BC52a2e07c379B2F486fefeFd674b1
#    0x1030FF000001,0x11f30C6B1173Ec6e0a6d622C8F17EEf3dc593764
#    0x1031FF000001,0xa6dbC40c75037895deE8D2415f1cE9E0Fb08Cf49
#    0x1032FF000001,0x59E9Db2c8995Ceeaf6A9ad0896601A5D3289444E
#    0x1138FF000001,0x45A37D7a93416934EbF7AD85b35bCf39fCd68696
#    0x10A0FF000001,0xF708005ceE17b2c5Fe1a01591E32ad6183A12EaE

ILK_IDS=(\ 
#  0x3030 # ETH \ 
#  0x3031 # DAI \ 
#  0x3032 # USDC \ 
#  0x3033 # WBTC \ 
#  0x3034 # WSTETH \ 
#  0x3036 # LINK \ 
#  0x3037 # ENS \ 
#  0x3130 # UNI \ 
#  0x3138 # FRAX \ 
  # 0x3039 # YVUSDC \ 
  # 0x3330 # YSDAI6MMSASSET \ 
  # 0x3331 # YSDAI6MJDASSET \ 
  # 0x3332 # YSUSDC6MMSASSET \ 
  # 0x3333 # YSUSDC6MJDASSET \ 
  # 0x3334 # YSETH6MMSASSET \ 
  # 0x3335 # YSETH6MJDASSET \ 
  # 0x3336 # YSFRAX6MMSASSET \ 
  # 0x3337 # YSFRAX6MJDASSET \ 
# 0x3338 # CRAB \ 
 0x30A0 # USDT \

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
export NETWORK="MAINNET"
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
    STRATEGY=$STRATEGY_ SERIES_ID=$SERIES_ID_ ROLL_SERIES_ID=$ROLL_SERIES_ID_ ILK_ID=$ILK_ID_ ROLL_POOL=$ROLL_POOL_ forge test --mp test/RecipeHarness.t.sol -v

    # For ERC1155 tests 
    # STRATEGY=$STRATEGY_ SERIES_ID=$SERIES_ID_ ROLL_SERIES_ID=$ROLL_SERIES_ID_ ILK_ID=$ILK_ID_ ROLL_POOL=$ROLL_POOL_ forge test -c test/RecipeHarness.t.sol -vvvv --match-test testPostERC1155Collateral
    # STRATEGY=$STRATEGY_ SERIES_ID=$SERIES_ID_ ROLL_SERIES_ID=$ROLL_SERIES_ID_ ILK_ID=$ILK_ID_ ROLL_POOL=$ROLL_POOL_ forge test -c test/RecipeHarness.t.sol -vvvv -m testWithdrawERC1155Collateral
  done
done
