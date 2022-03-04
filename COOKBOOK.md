```
                                        __________________   __________________
                                    .-/|                  \ /                  |\-.
                                    ||||                   |                   ||||
                                    ||||                   |                   ||||
                                    ||||                   |                   ||||
                                    ||||      Yield        |   "Recipes        ||||
                                    ||||                   |   made with love  ||||
                                    ||||     COOKBOOK      |   just like mama  ||||
                                    ||||                   |   used to make"   ||||
                                    ||||                   |                   ||||
                                    ||||                   |                   ||||
                                    ||||                   |                   ||||
                                    ||||__________________ | __________________||||
                                    ||/===================\|/===================\||
                                    `--------------------~___~-------------------''
```
### TABLE OF CONTENTS

[Vault creation, collateral posting, and borrowing](#vault-creation-collateral-posting-and-borrowing)
  - [Build a vault](#build-a-vault)
  - [Post ERC20 collateral (Join Approval)](#post-erc20-collateral-join-approval)
  - [Post ERC20 collateral (Ladle Approval)](#post-erc20-collateral-ladle-approval)
  - [Post ERC1155 collateral (Ladle Approval)](#post-erc1155-collateral-ladle-approval)
  - [Withdraw ERC20 collateral](#withdraw-erc20-collateral)
  - [Post Ether as collateral](#post-ether-as-collateral)
  - [Borrow fyToken](#borrow-fytoken)
  - [Borrow underlying](#borrow-underlying)
  - [Post ERC20 collateral and borrow underlying](#post-erc20-collateral-and-borrow-underlying)


[Debt Repayment](#debt-repayment)
  - [Repay with underlying before maturity](#repay-with-underlying-before-maturity)
  - [Repay a whole vault with underlying before maturity](#repay-a-whole-vault-with-underlying-before-maturity)
  - [Repay with underlying after maturity](#repay-with-underlying-after-maturity)
  - [Redeem](#redeem)

[Vault Management](#vault-management)
  - [Destroy a vault](#destroy-a-vault)
  - [Merge two vaults into one](#merge-two-vaults-into-one)
  - [Split a vault into two](#split-a-vault-into-two)
  - [Roll debt before maturity](#roll-debt-before-maturity)

[Lending](#lending)
  - [Lend](#lend)
  - [Close lending before maturity](#close-lending-before-maturity)
  - [Close lending after maturity](#close-lending-after-maturity)
  - [Roll lending before maturity](#roll-lending-before-maturity)
  - [Roll lending after maturity](#roll-lending-after-maturity)


[Liquidity Providing](#liquidity-providing)
  - [Provide liquidity by borrowing](#provide-liquidity-by-borrowing)
  - [Provide liquidity by borrowing, using only underlying](#provide-liquidity-by-borrowing-using-only-underlying)
  - [Provide liquidity by buying](#provide-liquidity-by-buying)
  - [Remove liquidity and repay](#remove-liquidity-and-repay)
  - [Remove liquidity, repay and sell](#remove-liquidity-repay-and-sell)
  - [Remove liquidity and redeem](#remove-liquidity-and-redeem)
  - [Remove liquidity and sell](#remove-liquidity-and-sell)
  - [Remove liquidity, redeem and close](#remove-liquidity-redeem-and-close)
  - [Roll liquidity before maturity](#roll-liquidity-before-maturity)
  - [Provide liquidity to strategy by borrowing](#provide-liquidity-to-strategy-by-borrowing)
  - [Provide liquidity to strategy by buying](#provide-liquidity-to-strategy-by-buying)
  - [Remove liquidity from strategy](#remove-liquidity-from-strategy)


[V1 Liquidity Migration](#v1-liquidity-migration)
  - [Use V1 Liquidity Tokens to provide liquidity to V2](#use-v1-liquidity-tokens-to-provide-liquidity-to-v2)

[stETH Wrapping/Unwrapping](#steth-wrappingunwrapping)
  - [Wrap stEth into wstETH](#wrap-steth-into-wsteth)
  - [Unwrap wstEth into stETH](#unwrap-wsteth-into-steth)




# Introduction

## Converting calls

The Ladle takes calls in an encoded format. In this document I’m using translated calls.

**Using Ladle for Ether, Permit, Cauldron or fyToken actions.**

In the Ladle, all actions will be expressed as:

```
ladle.ladleAction(arg, ...)
```

This can be translated to the following:

```
ladle.batch(
  [ladle.interface.encodeFunctionData('functionName', [arg, ...])],
)
```

**Using Ladle for ROUTE actions.**

The Ladle can also execute calls on arbitrary targets using ROUTE.

```
ladle.batch(
  [ladle.interface.encodeFunctionData(
    'route',
    [
      target,
      target.interface.encodeFunctionData('functionName', [arg, ...]),
    ]
  )],
)
```

# Recipes

## Vault creation, collateral posting, and borrowing
---

### Build a vault

This action can be added before any others where a vault is needed.

```
  await ladle.batch([
      ladle.buildAction(seriesId, ilkId, salt),
  ])
```
|Param  | Description|
|--------------|------------------------------------------------------------------------------------|
| ` seriesId ` | Series, and therefore underlying, that will be used for borrowing with this vault. |
| `  ilkId  `  | Collateral that will be used with this vault.                                      |
| `  salt  `   | Parameter to change the random vaultId created. It can be safely set to zero.      |


### Post ERC20 collateral (Join Approval)

This batch adds an ERC20 as collateral to a vault. It can be combined with previous actions that create vaults.
|Param  | Description|
|--------------|------------------------------------------------------------------------------------|
| ` ilk ` | Contract for the collateral being added to the vault. |
| `  ilkJoin  `  | Contract holding ilk for Yield v2.                                      |
| `  posted  `   | Amount of collateral being deposited.      |
| `  deadline  `   | Validity of the off-chain signature, as an unix time.      |
| `  v, r, s  `   | Off-chain signature.      |
| `  vaultId  `   | Vault to add the collateral to. Set to 0 if the vault was created as part of this same batch.      |
| `  ignored  `   | Receiver of any tokens produced by pour, which is not producing any in this batch.      |
| `  0  `   | Amount of debt to add to the vault, and fyTokens to send to the receiver of pour. None in this case.      |


### Post ERC20 collateral (Ladle Approval)

![Post Flow](/flow-diagrams/depositFlow.png)

This batch adds an ERC20 as collateral to a vault. If the ladle already has the permission to move ilk for the user it would be cheaper in gas terms. It can be combined with previous actions that create vaults.

```
  await ladle.batch([
    ladle.forwardPermitAction(ilk, ladle, posted, deadline, v, r, s),
    ladle.transfer(ilk, ilkJoin, posted),
    ladle.pourAction(vaultId, ignored, posted, 0),
  ])
```

|Param  | Description|
|--------------|------------------------------------------------------------------------------------|
| ` ilk ` | Contract for the collateral being added to the vault. |
| `  ladle  `  | Ladle for Yield v2.                                      |
| `  posted  `   | Amount of collateral being deposited.      |
| `  deadline  `   | Validity of the off-chain signature, as an unix time.      |
| `  v, r, s  `   | Off-chain signature.      |
| `  ilkJoin  `  | Contract holding ilk for Yield v2.                                      |
| `  vaultId  `   | Vault to add the collateral to. Set to 0 if the vault was created as part of this same batch.      |
| `  ignored  `   | Receiver of any tokens produced by pour, which is not producing any in this batch.      |
| `  0  `   | Amount of debt to add to the vault, and fyTokens to send to the receiver of pour. None in this case.      |

### Post ERC1155 collateral (Ladle Approval)

This batch adds a token within an ERC1155 contract as collateral to a vault, using a Ladle module. Off-chain signatures are not available for ERC1155 and a previous transaction is required to approve the Ladle. It can be combined with previous actions that create vaults.

```
  await ladle.batch([
    ladle.moduleCall(transfer1155Module, transfer(ilk, id, ilkJoin, posted)),
    ladle.pourAction(vaultId, ignored, posted, 0),
  ])
```
|Param  | Description|
|--------------|------------------------------------------------------------------------------------|
| ` ilk ` | Contract for the collateral being added to the vault. |
| ` id ` | ERC1155 id for the collateral being added to the vault. |
| `  ladle  `  | Ladle for Yield v2.                                      |
| `  transfer1155Module  `  | Ladle Module with ERC1155 transferring capabilities.                                      |
| `  posted  `   | Amount of collateral being deposited.      |
| `  ilkJoin  `  | Contract holding ilk for Yield v2.                                      |
| `  vaultId  `   | Vault to add the collateral to. Set to 0 if the vault was created as part of this same batch.      |
| `  ignored  `   | Receiver of any tokens produced by pour, which is not producing any in this batch.      |
| `  0  `   | Amount of debt to add to the vault, and fyTokens to send to the receiver of pour. None in this case.      |


**Note:** Approval for an ERC1155 is executed as `erc1155.setApprovalForAll(spender, true)` and gives permission to spender to take any amount of any token inside `erc1155` from the caller.

### Withdraw ERC20 collateral

This batch removes an amount of an ERC20 collateral from a vault. Destroying the vault at the end is optional and possible only if the vault holds no collateral and no debt.

```
  await ladle.batch([
    ladle.pourAction(vaultId, receiver, withdrawn.mul(-1), 0),
    ladle.destroy(vaultId),
  ])

```
|Param  | Description|
|--------------|------------------------------------------------------------------------------------|
| `  vaultId  `   | Vault to add the collateral to. Set to 0 if the vault was created as part of this same batch.      |
| `  receiver  `   | Receiver of the collateral.      |
| `  withdrawn  `   | Collateral withdrawn. Note it is a negative.      |
| `  0  `   | Amount of debt to add to the vault, and fyTokens to send to the receiver of pour. None in this case.      |


**Limits:** The collateral token balance of the related Join.

### Post Ether as collateral

This batch adds Ether as collateral to a vault. It can be combined with previous actions that create vaults.

```
  await ladle.batch([
    ladle.joinEtherAction(ethId),
    ladle.pourAction(vaultId, ignored, posted, 0),
  ])
```

|Param  | Description|
|--------------|------------------------------------------------------------------------------------|
| `  ethId  `   | Yield v2 identifier for Ether. Probably `ETH` converted to bytes6.  |
| `  vaultId  `   | Vault to add the collateral to. Set to 0 if the vault was created as part of this same batch.  |
| `  posted  `   | Amount of collateral being deposited.  |
| `  ignored  `   | Receiver of any tokens produced by pour, which is not producing any in this batch.  |
| `  0  `   | Amount of debt to add to the vault, and fyTokens to send to the receiver of pour. None in this case.  |


### Withdraw Ether collateral

This batch removes an amount of Ether collateral from a vault. Destroying the vault at the end is optional and possible only if the vault holds no collateral and no debt.

The Ether withdrawn will be temporarily held by the Ladle until the end of the transaction.

```
  await ladle.batch([
    ladle.pourAction(vaultId, ladle, withdrawn.mul(-1), 0),
    ladle.exitEtherAction(ethId, receiver),
    ladle.destroy(vaultId),
  ])
```

|Param  | Description|
|--------------|------------------------------------------------------------------------------------|
| `  vaultId  `   | Vault to add the collateral to. Set to 0 if the vault was created as part of this same batch.      |
| `  ladle  `   | Ladle for Yield v2.      |
| `  withdrawn  `   | Collateral withdrawn. Note it is a negative.      |
| `  0  `   | Amount of debt to add to the vault, and fyTokens to send to the receiver of pour. None in this case.      |
| `  ethId  `   | Yield v2 identifier for Ether. Probably `ETH` converted to bytes6.      |
| `  receiver  `   | Receiver of the collateral.      |

**Limits:** The WETH balance of the related Join.

### Borrow fyToken

This action borrows fyToken from an existing vault. It can be combined with previous actions that create vaults and post collateral, among others. Borrowing fyToken is frequently done as part of larger batches.

```
  await ladle.batch([
    ladle.pourAction(vaultId, receiver, 0, borrowed),
  ])
```
|Param  | Description|
|--------------|------------------------------------------------------------------------------------|
| `  vaultId  `   | Vault to add the collateral to. Set to 0 if the vault was created as part of this same batch.      |
| `  receiver  `   | Receiver of the collateral.      |
| `  0  `   | Collateral change, zero in this case.      |
| `  ladle  `   | Ladle for Yield v2.      |
| `  borrowed  `   | Amount of debt to add to the vault, and fyTokens to send to the receiver.      |


### Borrow underlying

This action borrows fyToken from an existing vault, which is then exchanged for underlying in a YieldSpace pool. The amount of underlying obtained is an exact number provided as a parameter, and the debt incurred in the vault is variable but within provided limits. It can be combined with previous actions that create vaults and post collateral, among others.

```
  await ladle.batch([
    ladle.serveAction(vaultId, receiver, 0, borrowed, maximumDebt),
  ])
```

|Param  | Description|
|--------------|------------------------------------------------------------------------------------|
| `  vaultId  `   | Vault to add the collateral to. Set to 0 if the vault was created as part of this same batch.      |
| `  receiver  `   | Receiver of the collateral.      |
| `  0  `   | Collateral change, zero in this case      |
| `  borrowed  `   | Amount of debt to add to the vault, and fyTokens to send to the receiver.      |
| `  ladle  `   | Maximum debt to accept for the vault in fyToken terms.      |


### Post ERC20 collateral and borrow underlying

This batch is the simplest and most efficient manner for new users to borrow underlying with their collateral.

```
  await ladle.batch([
    ladle.buildAction(seriesId, ilkId, 0),
    ladle.forwardPermitAction(ilk, ilkJoin, allowance, deadline, v, r, s),
    ladle.serveAction(0, receiver, posted, borrowed, maximumDebt),
  ])
```
|Param  | Description|
|--------------|------------------------------------------------------------------------------------|
| ` seriesId ` | Series, and therefore underlying, that will be used for borrowing with this vault. |
| `  ilkId  `  | Collateral that will be used with this vault.                                      |
| `  0  `   | Amount of debt to add to the vault, and fyTokens to send to the receiver of pour. None in this case.      |
| ` ilk ` | Contract for the collateral being added to the vault. |
| `  ilkJoin  `  | Contract holding ilk for Yield v2.                                      |
| `  allowance  `  | Allowance for transfer.                                      |
| `  deadline  `   | Validity of the off-chain signature, as an unix time.      |
| `  v, r, s  `   | Off-chain signature.      |
| `  0  `   | Collateral change, zero in this case      |
| `  receiver  `   | Receiver of the collateral.      |
| `  posted  `   | Amount of collateral being deposited.      |
| `  borrowed  `   | Amount of debt to add to the vault, and fyTokens to send to the receiver.      |
| `  maximumDebt  `   | Maximum amount of debt      |


## Debt Repayment

### Repay with underlying before maturity

This batch will use a precise amount of underlying to repay debt in a vault. All the underlying provided will be converted into fyToken at market rates, and used to repay debt. If there isn’t enough debt to repay, the function will revert. If the user intends to repay all his debt, use “Repay a whole vault with underlying before maturity”.

Combine with a base permit for the ladle if not present.

```
  await ladle.batch([
    ladle.transferAction(base, pool, debtRepaidInBase),
    ladle.repayAction(vaultId, ignored, 0, minimumFYTokenDebtRepaid),
  ])
```

|Param  | Description|
|--------------|------------------------------------------------------------------------------------|
| `  base  `   | Contract for the underlying tokens.      |
| `  ladle  `   | Ladle for Yield v2.      |
| `  pool  `   | Contract YieldSpace pool trading base and the fyToken for the series.      |
| `  debtRepaidInBase  `   | Amount of underlying that the user will spend repaying debt.      |
| `  vaultId  `   | Vault to repay debt from.      |
| `  ignored  `   | Receiver of the underlying tokens. None in this case..      |
| `  0  `   | Collateral change, zero in this case.      |
| `  minimumFYTokenDebtRepaid  `   | Minimum debt repayment to be accepted, in fyToken terms.      |

**Limits:** The real fyToken reserves of the related pool.

### Repay a whole vault with underlying before maturity

This batch will use a maximum amount of underlying to repay all the debt in a vault. The underlying will be converted into fyToken at market rates.

Combine with a base permit for the ladle if not present.

```
  await ladle.batch([
    ladle.transferAction(base, pool, maxBasePaid),
    ladle.repayVaultAction(vaultId, ignored, 0, maxBasePaid),
  ])
```
|Param  | Description|
|--------------|------------------------------------------------------------------------------------|
| `  pool  `   | Contract YieldSpace pool trading base and the fyToken for the series.      |
| `  maxBasePaid  `   | Maximum amount of underlying that the user will spend repaying debt.      |
| `  vaultId  `   | Vault to repay debt from.      |
| `  ignored  `   | Receiver of the underlying tokens. None in this case..      |
| `  0  `   | Collateral change, zero in this case.      |

**Limits:** The real fyToken reserves of the related pool.

### Repay with underlying after maturity

This action will use underlying to repay debt in a vault after maturity. The underlying won’t be exchanged at market rates, but the debt grows every second according to the appropriate rate oracle. If using to repay a whole vault, the amount of underlying needed won’t be exactly known but it can be estimated to be very close over a current reading.

Combine with a base permit for the base join if not present.

```
  await ladle.batch([
    ladle.closeAction(vaultId, ignored, 0, debtRepaidInFYToken),
  ])
```
|Param  | Description|
|--------------|------------------------------------------------------------------------------------|
| `  vaultId  `   | Vault to repay debt from.      |
| `  ignored  `   | Receiver of the underlying tokens. None in this case..      |
| `  0  `   | Collateral change, zero in this case.      |
| `  debtRepaidInFYToken  `   | Debt to be repaid in fyToken terms. Please do the conversion off-chain using the rate oracle.      |


### Redeem

```
  await fyToken.redeem()

```

- No approval is necessary

## Vault Management

### Destroy a vault

This action will destroy a vault, provided it has no debt or collateral. Combine with any batch that repays debt and withdraws collateral.

```
  await ladle.batch([
      ladle.destroyAction(vaultId),
  ])
```

`vaultId`: Vault to destroy.

### Merge two vaults into one

This batch will combine two vaults of the same series and ilk into one, adding their debt and collateral.

```
  await ladle.batch([
      ladle.stirAction(vaultId1, vaultId2, collateral, debt),
      ladle.destroyAction(vaultId1),
  ])
```
|Param  | Description|
|--------------|------------------------------------------------------------------------------------|
| `  vaultId1  `   | First vault to merge. This vault will be destroyed.      |
| `  vaultId2  `   | Second vault to merge.       |
| ` collateral  `   | Collateral amount in the first vault      |
| `  debt  `   | Debt amount in the first vault in fyToken terms.      |


### Split a vault into two

This batch will split part of the debt and collateral of one vault into a new vault.

```
  await ladle.batch([
      ladle.buildAction(seriesId, ilkId, 0),
      ladle.stirAction(vaultId, 0, collateral, debt),
  ])
```

|Param  | Description|
|--------------|------------------------------------------------------------------------------------|
| `  seriesId  `   | Series for the vault we are splitting debt from.      |
| `  ilkId  `   | Collateral for the vault that we are splitting collateral from.      |
| `  vaultId  `   | Vault to split debt and collateral from.      |
| `  0  `   | Indicates the second vault will be built as a result of this batch.       |
| ` collateral  `   | Collateral amount in the first vault      |
| `  debt  `   | Debt amount in the first vault in fyToken terms.      |

### Roll debt before maturity

This action changes the debt in a vault, and the vault itself, from one series to another. This action uses YieldSpace pools for the conversion.

```
  await ladle.batch([
    ladle.rollAction(vaultId, newSeriesId, 2, maxNewDebt),
  ])
```
|Param  | Description|
|--------------|------------------------------------------------------------------------------------|
| `  vaultId  `   | Vault to roll.      |
| `  newSeriesId  `   | Series to roll the debt into.       |
| ` 2  `   | Multiplier applied to the vault debt in base terms, in order to get an fyToken flash loan to cover the roll.      |
| `  maxNewDebt  `   | Maximum amount of debt, in fyToken terms, that will be accepted after the rolling.      |


**Limits:** The base reserves of the related pool.

## Lending

### Lend

Lending is selling underlying for fyToken in a YieldSpace pool. The pool won’t pull tokens from the user, so we get the Ladle to move them.

```
  await ladle.batch([
    ladle.forwardPermitAction(
      base, ladle, baseSold, deadline, v, r, s
    ),
    ladle.transferAction(base, pool, baseSold),
    ladle.routeAction(pool, ['sellBase', [receiver, minimumFYTokenReceived]),
  ])
```
|Param  | Description|
|--------------|------------------------------------------------------------------------------------|
| `  base  `   | Contract for the underlying tokens.      |
| `  ladle  `   | Ladle for Yield v2.      |
| ` pool  `   | Contract YieldSpace pool trading base and the fyToken for the series.      |
| `  baseSold  `   | Amount of underlying that the user will lend.      |
| `  receiver  `   | Receiver for the fyToken representing the lending position.      |
| `  minimumFYTokenReceived  `   | Minimum fyToken to be accepted.      |


**Limits:** The virtual fyToken reserves, minus the base reserves, divided by two.

### Close lending before maturity

Closing a lending position before maturity is the inverse of lending, meaning selling fyToken for underlying in a YieldSpace pool.

```
  await ladle.batch([
    ladle.forwardPermitAction(
      fyToken, ladle, fyTokenSold, deadline, v, r, s
    ),
    ladle.transferAction(fyToken, pool, fyTokenSold),
    ladle.routeAction(pool, ['sellFYToken', [receiver, minimumBaseTokenReceived]),
  ])
```
|Param  | Description|
|--------------|------------------------------------------------------------------------------------|
| `  fyToken  `   | Contract for the fyToken sold.      |
| `  ladle  `   | Ladle for Yield v2.      |
| ` pool  `   | Contract YieldSpace pool trading base and the fyToken for the series.      |
| `  fyTokenSold  `   | Amount of fyToken that the user will sell.      |
| `  receiver  `   | Receiver for the underlying produced on ending the lending position.      |
| `  minimumBaseTokenReceived  `   | Minimum underlying to be accepted.      |


**Limits:** The base reserves of the related pool.

### Close lending after maturity

Closing a lending position after maturity is achieved by redeeming the fyToken representing the lending position. No approval is required when the user calls the fyToken contract directly.

```
  await fyToken.redeem(receiver, fyTokenToRedeem)
```

|Param  | Description|
|--------------|------------------------------------------------------------------------------------|
| `  receiver  `   | Receiver for the underlying produced on redemption.      |
| `  fyTokenToRedeem  `   | Amount of fyToken to redeem.      |

### Roll lending before maturity

Rolling lending before maturity means selling fyToken for underlying, which is deposited into another pool and sold for fyToken of a second series, but sharing the underlying denomination with the first one.

```
  await ladle.batch([
    ladle.forwardPermitAction(
      fyToken, ladle, fyTokenRolled, deadline, v, r, s
    ),
    ladle.transferAction(fyToken, pool1, fyTokenRolled),
    ladle.routeAction(pool1, ['sellFYToken', [pool2, 0]),
    ladle.routeAction(pool2, ['sellBase', [receiver, minimumFYTokenReceived]),
  ])
```
|Param  | Description|
|--------------|------------------------------------------------------------------------------------|
| `  fyToken  `   | Contract for the fyToken sold.     |
| `  ladle  `   | Ladle for Yield v2.     |
| ` fyTokenRolled  `   | Amount of fyToken that the user will roll.     |
| `  pool1  `   | Contract YieldSpace pool trading base and the fyToken for the series to be rolled from.     |
| `  pool2  `   | Contract YieldSpace pool trading base and the fyToken for the series to be rolled into.     |
| `  0  `   | We don’t need to check for slippage on both trades, only on the last one.     |
| `  receiver  `   | Receiver of the fyToken of the new series being obtained.     |
| `  minimumFYTokenReceived  `   | Minimum fyToken of the series rolling into to be accepted.     |

<p style="text-align: right">
<strong>Limits:</strong> The base reserves of the first pool. The virtual fyToken reserves, minus the base reserves, divided by two, of the second pool.</p>

### Roll lending after maturity

Rolling lending after maturity means redeeming fyToken for underlying, which is deposited into another pool and sold for fyToken of a second series, but sharing the underlying denomination with the first one.

```
  await ladle.batch([
    ladle.forwardPermitAction(
      fyToken, ladle, fyTokenRolled, deadline, v, r, s
    ),
    ladle.transferAction(fyToken, fyToken, fyTokenToRoll),
    ladle.redeemAction(seriesId, pool2, fyTokenToRoll),
    ladle.routeAction(pool2, ['sellBase', [receiver, minimumFYTokenReceived]),
  ])
```
|Param  | Description|
|--------------|------------------------------------------------------------------------------------|
| `  fyToken  `   |  Contract for the fyToken sold.   |
| `  ladle  `   |  Ladle for Yield v2.   |
| ` fyTokenToRoll  `   |  Amount of fyToken that the user will roll.   |
| `  seriesId  `   |  Yield v2 id for the series.   |
| `  pool2  `   |  Contract YieldSpace pool trading base and the fyToken for the series to be rolled into.   |
| `  receiver  `   |  Receiver of the fyToken of the new series being obtained.   |
| `  minimumFYTokenReceived  `   |  Minimum fyToken of the series rolling into to be accepted.   |

**Limits:** The virtual fyToken reserves, minus the base reserves, divided by two, of the second pool.

## Liquidity Providing

### Provide liquidity by borrowing

When providing liquidity by borrowing, the user borrows an amount of fyToken to provide to the pool, along with underlying in the same proportion as the pool reserves.

Prepend this batch with actions to create a vault or provide collateral if necessary.

An option can be shown to the user where an amount of underlying is taken to provide liquidity. That amount is then split into the same proportions as the pool reserves, and the portion in the same proportion as the pool fyToken reserves put as collateral in a vault, to borrow fyToken into the pool.

```
  await ladle.batch([
    ladle.forwardPermitAction(
      base, ladle, baseToPool, deadline, v, r, s
    ),
    ladle.transferAction(base, pool, baseToPool),
    ladle.pourAction(vaultId, pool, 0, fyTokenBorrowed),
    ladle.routeAction(pool, ['mint', [receiver, receiver, minRatio, maxRatio]),
  ])
```
|Param  | Description|
|--------------|------------------------------------------------------------------------------------|
| `  base  `   | Contract for the underlying tokens.      |
| `  ladle  `   | Ladle for Yield v2.      |
| ` pool  `   | Contract YieldSpace pool trading base and the fyToken for the series.      |
| `  baseToPool  `   | Amount of underlying that the user will provide liquidity with.      |
| `  vaultId  `   | Vault to add the debt to. Set to 0 if the vault was created as part of this same batch.      |
| `  0  `   | Collateral change, zero in this case.      |
| `  fyTokenBorrowed  `   | Amount of fyToken that the user will borrow and provide liquidity with.      |
| ` receiver  `   | Receiver for the LP tokens.      |
| `  true  `   | Make any rounding surplus to be fyToken, left in the pool.      |
| `  minRatio  `   | Minimum base/fyToken ratio accepted in the pool reserves.      |
| `  maxRatio  `   | Maximum base/fyToken ratio accepted in the pool reserves.      |


### Provide liquidity by borrowing, using only underlying

This batch relies on creating a vault where the underlying is used as collateral to borrow the fyToken of the same underlying.

With this vault built, an amount of underlying is used to provide liquidity. That amount is split into the same proportions as the pool reserves, and the portion in the same proportion as the pool fyToken reserves put as collateral in a vault, to borrow fyToken into the pool.

```
  await ladle.batch([
    ladle.buildAction(seriesId, baseId, 0),
    ladle.forwardPermitAction(
      base, ladle, totalBase, deadline, v, r, s
    ),
    ladle.transferAction(base, baseJoin, baseToFYToken),
    ladle.transferAction(base, pool, baseToPool),
    ladle.pourAction(0, pool, baseToFYToken, baseToFYToken),
    ladle.routeAction(pool, ['mint', [receiver, receiver, minRatio, maxRatio]),
  ])
```

|Param  | Description|
|--------------|------------------------------------------------------------------------------------|
| `  seriesId  `   | Series, and therefore underlying, that will be used for borrowing with this vault.      |
| `  ilkId  `   | Collateral that will be used with this vault.      |
| ` base  `   | Contract for the underlying tokens.      |
| `  baseJoin  `   | Contract holding base for Yield v2.      |
| `  ladle  `   | Ladle for Yield v2.      |
| `  totalBase  `   | Amount of underlying that the user will provide liquidity with.      |
| `  pool  `   | Contract YieldSpace pool trading base and the fyToken for the series.      |
| ` baseToPool  `   | Portion of the underlying supplied that will be directly sent to the pool.      |
| `  baseToFYtoken  `   | Portion of the underlying supplied that will be used to borrow fyToken, sent to the pool.      |
| `  0  `   | Vault to add the debt to, set to 0 as the vault was created as part of this same batch.      |
| `  receiver  `   | Receiver for the LP tokens.      |
| `  true  `   | Make any rounding surplus to be fyToken, left in the pool.      |
| `  minRatio  `   | Minimum base/fyToken ratio accepted in the pool reserves.      |
| `  maxRatio  `   | Maximum base/fyToken ratio accepted in the pool reserves.      |

### Provide liquidity by buying

When providing liquidity by buying, the user buys an amount of fyToken from the pool. The amount of fyToken to buy would be calculated iteratively on the frontend, since there isn’t a closed form formula to find it.

The maximum amount of base to use will be transferred to the pool, and any surplus will be sent back to the user.

```
  await ladle.batch([
    ladle.forwardPermitAction(
      base, ladle, baseWithSlippage, deadline, v, r, s
    ),
    ladle.transferAction(base, pool, baseWithSlippage),
    ladle.routeAction(pool, ['mintWithBase', [receiver, receiver, fyTokenToBuy, minRatio, maxRatio]),
  ])
```

|Param  | Description|
|--------------|------------------------------------------------------------------------------------|
| `  base  `   | Contract for the underlying tokens.      |
| `  ladle  `   | Ladle for Yield v2.      |
| `  pool  `   | Contract YieldSpace pool trading base and the fyToken for the series.      |
| ` baseWithSlippage  `   | Maximum amount of underlying that the user will provide liquidity with.      |
| `  fyTokenToBuy  `   | FYToken that the user will buy using part of the underlying, to provide liquidity with.      |
| `  receiver  `   | Receiver for the LP tokens.      |
| `  minRatio  `   | Minimum base/fyToken ratio accepted in the pool reserves.      |
| `  maxRatio  `   | Maximum base/fyToken ratio accepted in the pool reserves.      |


**Limits:** The real fyToken reserves of the pool, minus the base reserves, divided by two, must be below `fyTokenToBuy`.

**Remove Liquidity set: **

### Remove liquidity and repay

The reverse of borrowing to provide liquidity. It is possible to estimate in the frontend whether using underlying to repay debt will be necessary, and if not the base can be sent to `receiver` in `burn`, and the last action omitted. Any surplus is sent to the `receiver`.

```
  await ladle.batch([
    ladle.forwardPermitAction(
      pool, ladle, lpTokensBurnt, deadline, v, r, s
    ),
    ladle.transferAction(pool, pool, lpTokensBurnt),
    ladle.routeAction(pool, ['burn', [ladle, ladle, minRatio, minRatio]),
    ladle.repayFromLadleAction(vaultId, receiver),
    ladle.closeFromLadleAction(vaultId, receiver),
  ])
```
|Param  | Description|
|--------------|------------------------------------------------------------------------------------|
| `  pool  `   | Contract YieldSpace pool trading base and the fyToken for the series.`   |
| `  ladle  `   | Ladle for Yield v2.   |
| ` lpTokensBurn  `   | `Amount of LP tokens that the user will burn.   |
| `  minRatio  `   | Minimum base/fyToken ratio accepted in the pool reserves.   |
| `  maxRatio  `   | Maximum base/fyToken ratio accepted in the pool reserves.   |
| `  vaultId  `   | Vault to repay debt from.   |
| `  receiver  `   | Receiver for the LP tokens.   |

**Usage:** Use before maturity if borrow and pool was used, and if debt is above `minFYTokenReceived`.

### Remove liquidity, repay and sell

If there is a small amount of debt to repay, it might be best for the user to repay it with fyToken from the burn, and then receive the fyToken surplus.

```
  await router.batch([
    ladle.forwardPermitAction(
      pool, ladle, LPTokensBurnt, deadline, v, r, s
    ),
    ladle.transferAction(pool, pool, LPTokensBurnt),
    ladle.routeAction(pool, ['burn', [receiver, ladle, 0, 0]),
    ladle.repayFromLadleAction(vaultId, receiver),
  ])
```
|Param  | Description|
|--------------|------------------------------------------------------------------------------------|
| `  ladle  `   | Ladle for Yield v2. |
| `  LPTokensBurnt  `   | Amount of LP tokens burnt. |
| ` pool  `   | Contract YieldSpace pool trading base and the fyToken for the series. |
| `  receiver  `   | Receiver for the resulting tokens. |
| `  vaultId  `   | Vault to repay debt from. |

**Usage:** Use before maturity if borrow and pool was used, and if debt is below fyToken received.

**Limits:** The debt of the user plus the base reserves of the pool must be lower than the fyToken received.

**Note**: If repayFromLadle is refactored to send collateral and remainder to separate addresses, the surplus fyToken could be sold.

**Note**: Cheaper than “Remove liquidity and repay”. Sometimes might make sense to leave vaults with debt instead of spending the gas to repay them.

### Remove liquidity and redeem

After maturity, fyToken can be redeemed by sending it to the fyToken contract.

```
  await ladle.batch([
    ladle.forwardPermitAction(
      pool, ladle, lpTokensBurnt, deadline, v, r, s
    ),
    ladle.transferAction(pool, pool, lpTokensBurnt),
    ladle.routeAction(pool, ['burn', [receiver, fyToken, minRatio, maxRatio]),
    ladle.redeemAction(seriesId, receiver, 0),
  ])
```

|Param  | Description|
|--------------|------------------------------------------------------------------------------------|
| `  pool  `   | Contract YieldSpace pool trading base and the fyToken for the series.  |
| `  ladle  `   | Ladle for Yield v2.  |
| ` lpTokensBurn  `   | `Amount of LP tokens that the user will burn.  |
| `  fyToken  `   | FYToken contract for the pool.  |
| `  minRatio  `   | Minimum base/fyToken ratio accepted in the pool reserves.  |
| `  maxRatio  `   | Maximum base/fyToken ratio accepted in the pool reserves.  |
| `  seriesId  `   | SeriesId for the fyToken contract.  |
| ` receiver  `   | Receiver for the LP tokens.  |
| `  0  `   | The amount of fyToken to redeem is whatever was sent to the fyToken contract.  |



**Usage:** Use always after maturity, if allowed by accounting. The vault can be forgotten.

### Remove liquidity and sell

Before maturity, the fyToken resulting from removing liquidity can be sold within the pool. This is best if there isn’t any debt to repay, and the `receiver` doesn’t want to keep the fyToken until redemption.

```
  await router.batch([
    ladle.forwardPermitAction(
      pool, ladle, lpTokensBurnt, deadline, v, r, s
    ),
    ladle.transferAction(pool, pool, lpTokensBurnt),
    ladle.routeAction(pool, ['burnForBase', [receiver, minRatio, maxRatio]),
  ])
```
|Param  | Description|
|--------------|------------------------------------------------------------------------------------|
| `  pool  `   | Contract YieldSpace pool trading base and the fyToken for the series.     |
| `  ladle  `   | Ladle for Yield v2.     |
| ` lpTokensBurn  `   | `Amount of LP tokens that the user will burn.     |
| `  minRatio  `   | Minimum base/fyToken ratio accepted in the pool reserves.     |
| `  maxRatio  `   | Maximum base/fyToken ratio accepted in the pool reserves.     |
| `  receiver  `   | Receiver for the LP tokens.     |

**Limits:** The fyToken plus base received must be lower than the base reserves of the pool.

**Usage:** Use before maturity if buy and pool was used.

**Note:** Can also be used close to maturity in “borrow and pool” to save gas .

### Remove liquidity, redeem and close

When removing liquidity after maturity, all the proceeds can be converted into base to repay without rolling the debt in the vault.

```
  await ladle.batch([
    ladle.forwardPermitAction(
      pool, ladle, LPTokensBurnt, deadline, v, r, s
    ),
    ladle.transferAction(pool, pool, LPTokensBurnt),
    ladle.routeAction(pool, ['burn', [ladle, fyToken, minRatio, maxRatio]),
    ladle.redeemAction(seriesId, ladle, 0),
    ladle.closeFromLadleAction(vaultId, receiver),
  ])
```

|Param  | Description|
|--------------|------------------------------------------------------------------------------------|
| `  ladle  `   |  Ladle for Yield v2.      |
| `  LPTokensBurnt  `   |  Amount of LP tokens burnt.      |
| ` pool  `   |  Contract YieldSpace pool trading base and the fyToken for the series.      |
| `  fyToken  `   |  FYToken contract for the pool.      |
| `  minRatio  `   |  Minimum base/fyToken ratio accepted in the pool reserves.      |
| `  maxRatio  `   |  Maximum base/fyToken ratio accepted in the pool reserves.      |
| `  seriesId  `   |  Series for the fyToken.      |
| ` vaultId  `   |  Vault to repay debt from.      |


**Usage:** Don’t use, unless forced to repay vaults.

### Roll liquidity before maturity

To roll liquidity before maturity, the simplest option is to use the pools themselves to sell and buy fyToken of the two involved series at market rates. The LP tokens of the pool we are rolling out from are converted into underlying using the pool itself, and then split into underlying and fyToken in the proportions of the second pool also using that second pool itself.

As with “Provide liquidity by buying”, the frontend needs to calculate the amount of underlying to be received from burning the pool tokens in the first pool, the proportions of the second pool, and the proportion of the underlying proceeds that needs to be converted into fyToken of the second pool.

```
  await router.batch([
    ladle.forwardPermitAction(
      pool1, ladle, poolTokens, deadline, v, r, s
    ),
    ladle.transferAction(pool1, pool1, poolTokens),
    ladle.routeAction(pool1, ['burnForBase', [pool2, 0]),
    ladle.routeAction(pool2, ['mintWithBase', [receiver, receiver, fyTokenToBuy, minRatio, maxRatio]),
  ])
```
|Param  | Description|
|--------------|------------------------------------------------------------------------------------|
| `  ladle  `   | Ladle for Yield v2.     |
| `  pool1  `   | Contract YieldSpace pool trading base and the fyToken for the series we are rolling out from.     |
| ` pool2  `   | Contract YieldSpace pool trading base and the fyToken for the series we are rolling into.     |
| `  poolTokens  `   | Amount of LP tokens of the first pool we are rolling into the second pool.     |
| `  receiver  `   | Receiver for the LP tokens of the second pool.     |
| `  fyTokenToBuy  `   | FYToken that the user will buy using part of the underlying, to provide liquidity with.     |
| `  minRatio  `   | Minimum base/fyToken ratio accepted in the pool reserves.     |
| ` maxRatio  `   | Maximum base/fyToken ratio accepted in the pool reserves.     |


**Limits:** Base reserves of the first pool, the virtual fyToken reserves, minus the base reserves, divided by two, of the second pool.

### Provide liquidity to strategy by borrowing

Providing liquidity to a strategy is identical to providing liquidity to a pool, with an added action at the end to convert from LP tokens to strategy tokens.

```
  await ladle.batch([
    ladle.forwardPermitAction(
      base, ladle, baseToFYToken + baseToPool, deadline, v, r, s
    ),
    ladle.transferAction(base, baseJoin, baseToFYToken),
    ladle.transferAction(base, pool, baseToPool),
    ladle.pourAction(0, pool, baseToFYToken, baseToFYToken),
    ladle.routeAction(pool, ['mint', [strategy, receiver, minRatio, maxRatio]),
    ladle.routeAction(strategy, ['mint', [receiver]),
  ])
```
|Param  | Description|
|--------------|------------------------------------------------------------------------------------|
| `  base  `   | Contract for the underlying tokens.    |
| `  baseJoin  `   | Contract holding base for Yield v2.    |
| ` baseToPool  `   | Portion of the underlying supplied that will be directly sent to the pool.    |
| `  baseToFYtoken  `   | Portion of the underlying supplied that will be used to borrow fyToken, sent to the pool.    |
| `  0  `   | Vault to add the debt to, set to 0 as the vault was created as part of this same batch.    |
| `  pool  `   | Contract YieldSpace pool trading base and the fyToken for the series.    |
| `  strategy  `   | Contract for investing in Yield v2 tokens.    |
| ` true  `   | Make any rounding surplus to be fyToken, left in the pool.    |
| `  minRatio  `   | Minimum base/fyToken ratio accepted in the pool reserves.    |
| `  maxRatio  `   | Maximum base/fyToken ratio accepted in the pool reserves.    |
| `  receiver  `   | Receiver for the LP tokens.    |


### Provide liquidity to strategy by buying

Providing liquidity to a strategy is identical to providing liquidity to a pool, with an added action at the end to convert from LP tokens to strategy tokens. Prepend this batch with actions to provide permits as necessary. The amount of fyToken to buy would be calculated iteratively on the frontend, since there isn’t a closed form formula to find it.

```
  await ladle.batch([
    ladle.transferAction(base, pool, baseWithSlippage),
    ladle.routeAction(pool, ['mintWithBase', [strategy, receiver, fyTokenToBuy, minRatio, maxRatio]),
    ladle.routeAction(strategy, ['mint', [receiver]),
  ])
```
|Param  | Description|
|--------------|------------------------------------------------------------------------------------|
| `  base  `   | Contract for the underlying tokens.     |
| `  ladle  `   | Ladle for Yield v2.     |
| ` pool  `   | Contract YieldSpace pool trading base and the fyToken for the series.     |
| `  baseWithSlippage  `   | Maximum amount of underlying that the user will provide liquidity with.     |
| `  fyTokenToBuy  `   | FYToken that the user will buy using part of the underlying, to provide liquidity with.     |
| `  receiver  `   | Receiver for the LP tokens.     |
| `  minRatio  `   | Minimum base/fyToken ratio accepted in the pool reserves.     |
| ` maxRatio  `   | Maximum base/fyToken ratio accepted in the pool reserves.     |
| `  strategy  `   | Contract for investing in Yield v2 tokens.     |
| `  receiver  `   | Receiver for the LP tokens.     |

### Remove liquidity from strategy

Removing liquidity from a strategy has an initial two steps in which the strategy tokens are burnt for LP tokens deposited in the appropriate pool, and then continues like a normal batch to remove liquidity. Note that the vault debt could be in a different fyToken than received, if the strategy rolled pools. The debt in the vault would need to be rolled for the batches that repay with fyToken to work. Remember that if there are several actions with slippage protection, we only need to set a value in the last one.

```
  await router.batch([
    ladle.forwardPermitAction(
      strategy, ladle, strategyTokensBurnt, deadline, v, r, s
    ),
    ladle.transferAction(strategy, strategy, strategyTokensBurnt),
    ladle.routeAction(strategy, ['burn', [pool, 0]),
    … (follow with any of the 5 remove liquidity batches for removing liquidity)
    … (without the permit or the transfer, the pool tokens are in the pool already)
  ])
```

|Param  | Description|
|--------------|------------------------------------------------------------------------------------|
| `  strategy  `   | Contract for investing in Yield v2 tokens.   |
| `  ladle  `   | Ladle for Yield v2.   |
| ` strategyTokensBurnt  `   | Amount of strategy tokens burnt.   |
| `  pool  `   | Contract YieldSpace pool trading base and the fyToken for the series.   |
| `  minBaseReceive  `   | Minimum amount of base that will be accepted.   |
| `  minFYTokenReceive  `   | `Minimum amount of fyToken that will be accepted.   |


**Usage:** Use burn and sell for both ‘borrow and pool’ and ‘buy and pool’ if possible. Defined as the user not having a vault of the matching series with the underlying as collateral.

**Limits:** If there is too much fyToken received to be sold in the pool, the fyToken received will need to be held until it can be sold or redeemed.

**Note:** Unlikely to remove liquidity before maturity with strategies. Unless sunsetting strategy.

## V1 Liquidity Migration

### Use V1 Liquidity Tokens to provide liquidity to V2

To migrate v1 liquidity to v2, we start by converting the v1 Liquidity Tokens into Dai, which then can be used later in the same batch to become v2 liquidity, either by borrowing or by buying.

For an easier split, the user wallet is used as a holding place for the Dai.

Once the Dai is in the user’s wallet, proceed by appending any of the other liquidity providing batches.

```
  await ladle.batch([
    ladle.forwardPermitAction(
      v1Pool, ladle, poolTokens, deadline, v, r, s
    ),
    ladle.transferAction(v1Pool, ladle, poolTokens),
    ladle.moduleCallAction(v1Module, [
      'migrateLiquidity',
      [v1Pool, receiver, poolTokens, minimumFYDaiPrice]),
    ...
  ])
```
|Param  | Description|
|--------------|------------------------------------------------------------------------------------|
| `  v1Pool  `   | V1 YieldSpace Pool matching the tokens to be used.    |
| `  ladle  `   | Ladle for Yield v2.    |
| ` poolTokens  `   | Amount of v1 liquidity tokens that the user will provide liquidity with.    |
| `  receiver  `   | Receiver for the LP tokens. If using buy and pool, it would be the v2 pool.    |
| `  minimumFYDaiPrice  `   | Minimum FYDai price to be accepted.    |

## stETH Wrapping/Unwrapping

### Wrap stEth into wstETH

Users can provide stEth as collateral, which we wrap into WstEth when sending it to the Join.

```
  await ladle.batch([
    ladle.forwardPermitAction(
      lidoWrapper, ladle, stEthTokens, deadline, v, r, s
    ),
    ladle.transferAction(stEth, lidoWrapper, stEthTokens),
    ladle.routeAction(lidoWrapper, [
      'wrap',
      [wstEthJoin]),
    ...
  ])
```

|Param  | Description|
|--------------|------------------------------------------------------------------------------------|
| `  lidoWrapper  `   |  LidoWrapperHandler that wraps/unwraps stEth in a batch.  |
| `  stEthTokens  `   |  Amount of v1 liquidity tokens that the user will provide liquidity with.  |
| ` wstEthJoin  `   |  Join for wstEther.  |

**Note:** Calculate the amount of wstEth obtained from the wstEth contract by calling wstEth.getWstEthByStEth.

### Unwrap wstEth into stETH

When users remove wstEth from the platform, we unwrap it to stETH before giving it to them. Drop the wstETH in the lidoWrapper and append this to an appropriate batch.

```
  await ladle.batch([
    ...
    ladle.routeAction(lidoWrapper, [
      'unwrap',
      [receiver]),
  ])
```
|Param  | Description|
|--------------|------------------------------------------------------------------------------------|
| `  receiver  `   |  Receiver for the stEth.  |

**Note:** If necessary, calculate the amount of stEth obtained from the wstEth contract by calling wstEth.getStEthBywstEth.
