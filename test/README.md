# RECIPE HARNESS

### Basic Testing

In order to run the recipe harness, simply do the following:

```
bash test/testHarness.sh
```

To run specific tests or add traces simply add `--match-test <test_name>` or `-vvvv` respectively to the above command. 

This will run all the tests in the harness with whatever series and ilk pairings have been selected and can be commented-out or uncommented as needed. 

### Harness config

The harness operates as a double for-loop whereby `forge test` is run for all selected ilks for all selected series.

The series config will include whichever two series are currently offered. (At the time of writing this is the March and June series)

For each entry in `SERIES_STRATEGIES` there are four parameters per series. 
    - the seriesId of each borrowable asset
    - the seriesId for the opposite series (used for rolling liquidity from one series to the other)
    - the address for the respective series' strategy
    - the pool for the opposite strategy (used for migrating deprecated strategies)

### Rolling liquidity

Several tests serve to test liquidity rolling procedures. It is for this reason we need to incorporate the opposite series. 

For example, in the lend rolling tests we need to transfer liquidity to a different pool from the series own. So we use the opposite series' pool to do so. 

At the time of writing, both the March and June series are live so when testing the March series, we'll migrate liquidity to the June series' pool.

It is by using the other currently live series that we can avoid having to mock a new pool. And we cannot use older pools whose series has already matured. 

Additionally, for those tests that roll liquidity **after maturity**, the opposite series' maturity must be **after** the maturity of the series being tested
since we cannot add debt to a vault for a series that has matured for example. 

So we can only test say rolling lending after maturity with the March series since the June series has a later expiration date and once we expire the March
series, it will not affect the June series. 

### Strategies

The currently live March series uses the now deprecated V1 strategies. With the exception of USDT. 

This means that testing for rolling liquidity from a deprecated strategy can only be done for those series still using 
V1 strategies such as ETH, DAI, USDC, and FRAX for the March series.