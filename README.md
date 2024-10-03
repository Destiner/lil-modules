# lil modules

A collection of ERC-7579 modules.

> Unaudited, experimental, don't use in prod.

## Using this repo

To install the dependencies, run:

```bash
pnpm install
```

To build the project, run:

```bash
forge build
```

To run the tests, run:

```bash
forge test
```

## Modules

### TokenValidator

A validator that gates access to the account based on the staked token balance. Supports ERC20, ERC721, and ERC1155. Supports setting custom balance, setting signer threshold (i.e. N-of-M multisig) and limiting access to specific token IDs.

> Staking contract is used to circumvent the storage access restrictions during the validation phase.
