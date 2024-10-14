// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

struct InstallData {
    uint256 threshold;
    uint256 renewalDuration;
    string[] allowlist;
    string[] denylist;
}

struct Config {
    uint256 threshold;
    uint256 renewalDuration;
    uint256 iteration;
    bool allowlistEnabled;
    bool denylistEnabled;
}
