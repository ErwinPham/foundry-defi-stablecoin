# 💵 Decentralized Stablecoin Protocol (DSC)

A simplified, fully on-chain DeFi stablecoin protocol inspired by MakerDAO's DAI, using ETH and BTC as exogenous collateral and maintaining a soft peg to USD.

> Built using Solidity, Chainlink Price Feeds, and Foundry framework.

---

## 🔧 Features

- ✅ **Exogenous Collateral**: Supports WETH and WBTC
- ✅ **Overcollateralized Minting**: Users mint DSC tokens by depositing collateral
- ✅ **Health Factor & Liquidation**: Ensures protocol safety
- ✅ **Chainlink Price Feed Integration**
- ✅ **CEI Pattern (Check-Effects-Interactions)**
- ✅ **Fully Tested**: Unit, integration, and fuzz tests using Foundry
- ✅ **Inspired by MakerDAO**, but no governance or fees

---

## 🛠️ Contracts Overview

### 1. `DecentralizedStableCoin.sol`
- Standard ERC20 token (DSC)
- Mintable and burnable (only by `DSCEngine`)
- Pegged to USD

### 2. `DSCEngine.sol`
- Core logic of the protocol
- Handles:
  - Collateral deposit/withdraw
  - Minting and burning DSC
  - Liquidation logic
  - Health factor calculation

---

## 🧪 Testing

> All tests written using **Foundry** (`forge-std`) with high code coverage and logic simulation.

Run tests:

```bash
forge test -vv
```

Test coverage includes:

- ✅ Collateral Deposit / Mint
- ✅ Health Factor Enforcement
- ✅ Liquidation logic
- ✅ Burn & Redeem
- ✅ Oracle price manipulation simulation
- ✅ Fuzz testing scenarios

---

## ⚙️ Deployment

### Script: `script/DeployDSC.s.sol`

Deploy with:

```bash
forge script script/DeployDSC.s.sol:DeployDSC --rpc-url <RPC_URL> --broadcast --private-key <KEY>
```

What it does:

- Deploys `DecentralizedStableCoin` and `DSCEngine`
- Sets up price feeds from Chainlink (or mocks locally)
- Transfers minting rights to `DSCEngine`

---

## 🧩 Directory Structure

```
src/
├── DecentralizedStableCoin.sol   # ERC20 token
├── DSCEngine.sol                 # Core logic contract

script/
├── DeployDSC.s.sol              # Deployment script
├── HelperConfig.s.sol           # Handles config/mocks per network

test/
├── DSCEngine.t.sol              # Full coverage test suite
├── mocks/
│   └── MockV3Aggregator.sol     # Price feed mocks
```

---

## 🔐 Security Practices

- CEI pattern applied
- ReentrancyGuard used
- No reentrancy on external calls
- Input validation & revert reasons
- Fuzz testing & invariant checks

---

## 📚 Inspired By

- MakerDAO (DAI)
- Chainlink Oracle Design Patterns
- Foundry Clean Architecture

---

## 🧑‍💻 Author

**Huy Pham**  
Passionate Smart Contract Developer

---

## 📝 License

MIT
