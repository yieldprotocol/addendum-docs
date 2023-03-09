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

[Vault Management](#vault-management)

- [Build a vault](#build-a-vault)
- [Destroy a vault](#destroy-a-vault)
- [Merge two vaults into one](#merge-two-vaults-into-one)
- [Split a vault into two](#split-a-vault-into-two)

[Collateral and Borrowing](#collateral-and-borrowing)

- [Post ERC20 collateral (Join Approval)](#post-erc20-collateral-join-approval)
- [Post ERC20 collateral (Ladle Approval)](#post-erc20-collateral-ladle-approval)
- [Withdraw ERC20 collateral](#withdraw-erc20-collateral)
- [Post ERC20 collateral and borrow underlying](#post-erc20-collateral-and-borrow-underlying)

[Debt Repayment](#debt-repayment)

- [Repay with underlying](#repay-with-underlying)
- [Repay a whole vault with underlying](#repay-a-whole-vault-with-underlying)

[Lending](#lending)

- [Lend](#lend)

[Ether](#ether)

- [Post Ether as collateral](#post-ether-as-collateral)
- [Withdraw Ether collateral](#withdraw-ether-collateral)

# Introduction

## Converting calls

The Ladle takes calls in an encoded format. In this document I’m using translated calls.

**Using Ladle for Ether, Permit, Cauldron actions.**

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

## Vault Management

### Build a vault

This action can be added before any others where a vault is needed.

```
  await ladle.batch([
      ladle.buildAction(baseId, ilkId, salt),
  ])
```

| Param    | Description                                                                   |
| -------- | ----------------------------------------------------------------------------- |
| `baseId` | Base that will be used for borrowing with this vault.                         |
| `ilkId`  | Collateral that will be used with this vault.                                 |
| `salt`   | Parameter to change the random vaultId created. It can be safely set to zero. |

### Destroy a vault

This action will destroy a vault, provided it has no debt or collateral. Combine with any batch that repays debt and withdraws collateral.

```
  await ladle.batch([
      ladle.destroyAction(vaultId),
  ])
```

`vaultId`: Vault to destroy.

### Merge two vaults into one

This batch will combine two vaults of the same base and ilk into one, adding their debt and collateral.

```
  await ladle.batch([
      ladle.stirAction(vaultId1, vaultId2, collateral, debt),
      ladle.destroyAction(vaultId1),
  ])
```

| Param         | Description                                         |
| ------------- | --------------------------------------------------- |
| `vaultId1`    | First vault to merge. This vault will be destroyed. |
| `vaultId2`    | Second vault to merge.                              |
| `collateral ` | Collateral amount in the first vault                |
| `debt`        | Debt amount in the first vault in base terms.       |

### Split a vault into two

This batch will split part of the debt and collateral of one vault into a new vault.

```
  await ladle.batch([
      ladle.buildAction(baseId, ilkId, 0),
      ladle.stirAction(vaultId, 0, collateral, debt),
  ])
```

| Param         | Description                                                         |
| ------------- | ------------------------------------------------------------------- |
| `baseId`      | Base for the vault we are splitting debt from.                      |
| `ilkId`       | Collateral for the vault that we are splitting collateral from.     |
| `vaultId`     | Vault to split debt and collateral from.                            |
| `0`           | Indicates the second vault will be built as a result of this batch. |
| `collateral ` | Collateral amount in the first vault                                |
| `debt`        | Debt amount in the first vault in base terms.                       |

## Collateral and borrowing

---

### Post ERC20 collateral (Join Approval)

This batch adds an ERC20 as collateral to a vault. It can be combined with previous actions that create vaults.
|Param | Description|
|--------------|------------------------------------------------------------------------------------|
| `ilk` | Contract for the collateral being added to the vault. |
| `ilkJoin` | Contract holding ilk for Yield v2. |
| `posted` | Amount of collateral being deposited. |
| `deadline` | Validity of the off-chain signature, as an unix time. |
| `v, r, s` | Off-chain signature. |
| `vaultId` | Vault to add the collateral to. Set to 0 if the vault was created as part of this same batch. |
| `ignored` | Receiver of any tokens produced by pour, which is not producing any in this batch. |
| `0` | Amount of debt to add to the vault, and base to send to the receiver of pour. None in this case. |

### Post ERC20 collateral (Ladle Approval)

This batch adds an ERC20 as collateral to a vault. If the ladle already has the permission to move ilk for the user it would be cheaper in gas terms. It can be combined with previous actions that create vaults.

```
  await ladle.batch([
    ladle.forwardPermitAction(ilk, ladle, posted, deadline, v, r, s),
    ladle.transfer(ilk, ilkJoin, posted),
    ladle.pourAction(vaultId, ignored, posted, 0),
  ])
```

| Param      | Description                                                                                      |
| ---------- | ------------------------------------------------------------------------------------------------ |
| `ilk`      | Contract for the collateral being added to the vault.                                            |
| `ladle`    | Ladle for Yield v2.                                                                              |
| `posted`   | Amount of collateral being deposited.                                                            |
| `deadline` | Validity of the off-chain signature, as an unix time.                                            |
| `v, r, s`  | Off-chain signature.                                                                             |
| `ilkJoin`  | Contract holding ilk for Yield v2.                                                               |
| `vaultId`  | Vault to add the collateral to. Set to 0 if the vault was created as part of this same batch.    |
| `ignored`  | Receiver of any tokens produced by pour, which is not producing any in this batch.               |
| `0`        | Amount of debt to add to the vault, and base to send to the receiver of pour. None in this case. |

### Withdraw ERC20 collateral

This batch removes an amount of an ERC20 collateral from a vault. Destroying the vault at the end is optional and possible only if the vault holds no collateral and no debt.

```
  await ladle.batch([
    ladle.pourAction(vaultId, receiver, withdrawn.mul(-1), 0),
    ladle.destroy(vaultId),
  ])

```

| Param       | Description                                                                                      |
| ----------- | ------------------------------------------------------------------------------------------------ |
| `vaultId`   | Vault to add the collateral to. Set to 0 if the vault was created as part of this same batch.    |
| `receiver`  | Receiver of the collateral.                                                                      |
| `withdrawn` | Collateral withdrawn. Note it is a negative.                                                     |
| `0`         | Amount of debt to add to the vault, and base to send to the receiver of pour. None in this case. |

**Limits:** The collateral token balance of the related Join.

## Debt Repayment

### Repay with underlying

This batch will use a precise amount of base to repay debt in a vault. If there isn’t enough debt to repay, the function will revert.

Combine with a base permit for the ladle if not present.

```
  await ladle.batch([
    ladle.transferAction(base, join, debtRepaidInBase),
    ladle.repayAction(vaultId, inkTo, refundTo, ink),
  ])
```

| Param              | Description                                            |
| ------------------ | ------------------------------------------------------ |
| `base`             | Contract for the underlying tokens.                    |
| `ladle`            | Ladle for Variable rate.                               |
| `join`             | Join for the base.                                     |
| `debtRepaidInBase` | Amount of base that the user will spend repaying debt. |
| `vaultId`          | Vault to repay debt from.                              |
| `inkTo`            | Receiver of the collateral                             |
| `refundTo`         | Receiver of the refund if any.                         |
| `ink`              | Amount of collateral to be returned.                   |

### Repay a whole vault with base

This batch will use a maximum amount of base to repay all the debt in a vault.

Combine with a base permit for the ladle if not present.

```
  await ladle.batch([
    ladle.transferAction(base, pool, maxBasePaid),
    ladle.repayVaultAction(vaultId, inkTo, refundTo, ink),
  ])
```

| Param         | Description                                                    |
| ------------- | -------------------------------------------------------------- |
| `join`        | Join for the base.                                             |
| `maxBasePaid` | Maximum amount of base that the user will spend repaying debt. |
| `vaultId`     | Vault to repay debt from.                                      |
| `inkTo`       | Receiver of the collateral                                     |
| `refundTo`    | Receiver of the refund if any.                                 |
| `ink`         | Amount of collateral to be returned.                           |

## Lending

### Lend

Lending is depositing base into joins for vyTokens. The user will receive vyTokens in exchange. The join of the base will pull the token from the user or the user could deposit it before.

```
  await ladle.batch([
    ladle.transferAction(base, join, amount),
    ladle.routeAction(vyToken,['deposit', receiver, underlyingAmount]),
  ])
```

## Ether

### Post Ether as collateral

This batch adds Ether as collateral to a vault. It can be combined with previous actions that create vaults.

```
  await ladle.batch([
    ladle.joinEtherAction(ethId),
    ladle.pourAction(vaultId, ignored, posted, 0),
  ],
  { value: etherUsed }
  )
```

| Param     | Description                                                                                      |
| --------- | ------------------------------------------------------------------------------------------------ |
| `ethId`   | Yield v2 identifier for Ether. Probably `ETH` converted to bytes6.                               |
| `vaultId` | Vault to add the collateral to. Set to 0 if the vault was created as part of this same batch.    |
| `posted`  | Amount of collateral being deposited.                                                            |
| `ignored` | Receiver of any tokens produced by pour, which is not producing any in this batch.               |
| `0`       | Amount of debt to add to the vault, and base to send to the receiver of pour. None in this case. |

### Withdraw Ether collateral

This batch removes an amount of Ether collateral from a vault. Destroying the vault at the end is optional and possible only if the vault holds no collateral and no debt.

The Ether withdrawn will be temporarily held by the Ladle until the end of the transaction.

```
  await ladle.batch([
    ladle.pourAction(vaultId, ladle, withdrawn.mul(-1), 0),
    ladle.exitEtherAction(receiver),
    ladle.destroy(vaultId),
  ])
```

| Param       | Description                                                                                      |
| ----------- | ------------------------------------------------------------------------------------------------ |
| `vaultId`   | Vault to add the collateral to. Set to 0 if the vault was created as part of this same batch.    |
| `ladle`     | Ladle for Variable Rate.                                                                         |
| `withdrawn` | Collateral withdrawn. Note it is a negative.                                                     |
| `0`         | Amount of debt to add to the vault, and base to send to the receiver of pour. None in this case. |
| `receiver`  | Receiver of the collateral.                                                                      |

**Limits:** The WETH balance of the related Join.
