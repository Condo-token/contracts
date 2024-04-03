// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title ICondo interface
 * @dev Interface for the CONDO ERC20 Token Contract.
 * Includes external functions and events.
 */
interface ICondo is IERC20 {
    /**
     * @dev Emitted when an account is excluded from or included in fees.
     * @param account The account that is being excluded or included.
     * @param isExcluded Whether the account is excluded (`true`) from fees or not (`false`).
     */
    event ExcludeFromFees(address indexed account, bool isExcluded);

    /**
     * @dev Emitted when an automated market maker pair is set.
     * This typically signifies liquidity pool pairs used for trading the token.
     * @param pair The address of the pair that is being set as an automated market maker pair.
     * @param value value Indicates whether the pair is enabled (`true`) or disabled (`false`) as an AMM pair.
     */
    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);
}
