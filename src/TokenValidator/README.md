# TokenValidator

A validator that gates access to the account based on the staked token balance. Supports ERC20, ERC721, and ERC1155. Supports setting custom balance, setting signer threshold (i.e. N-of-M multisig) and limiting access to specific token IDs.

> Staking contract is used to circumvent the storage access restrictions during the validation phase.
