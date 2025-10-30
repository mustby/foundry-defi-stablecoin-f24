# WE ARE CREATING A DECENTRALIZED STABLECOIN #

1. (relative stabilitiy) Anchored or Pegged --> $1 USD (floating is better but harder)
   1. Chainlink price feed
   2. Set a function to exchange ETH & BTC --> $$$
2. Stability Mechanism (minting): Algorithmic (Decentralized)
   1. People can only mint the stablecoin with enough collateral (coded)
3. Collateral: Exogenous (Crypto)
   1. wETH (erc20 version)
   2. wBTC (erc20 version)

- calculate health factor function
- set health factor if debt is 0
- Added a bunch of view functions

1. What are our invariants/properties? (To write stateful and stateless fuzz tests)

What's Next?
1. Some proper oracle use
2. Write more tests (on me to do)
3. Smart Contract Audit Preparation
4. Get coverage about 90%+ 