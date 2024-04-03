// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IUniswapV2Router02} from "src/interfaces/IUniswapV2Router02.sol";
import {IUniswapV2Factory} from "src/interfaces/IUniswapV2Factory.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ICondo} from "src/interfaces/ICondo.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Condo is ICondo, ERC20, Ownable, ReentrancyGuard {
    // The Uniswap V2 Router used for executing swaps.
    // It's a central piece for interacting with the Uniswap protocol.
    IUniswapV2Router02 public uniswapV2Router;

    // The Uniswap V2 Pair address for this token and WETH.
    // It's essential for enabling decentralized exchanges of this token.
    address public uniswapV2Pair;

    // Address of the treasury wallet where certain fees collected by the contract are sent.
    // as determined by the token's governance or development team.
    address public treasuryWallet;

    // Fee percentage charged on buy transactions.
    // It's expressed as a percentage of the transaction amount.
    uint256 public constant buyFee = 3;

    // Fee percentage charged on sell transactions. Similar to `buyFee`.
    // It's also expressed as a percentage of the transaction amount.
    uint256 public constant sellFee = 3;

    // The threshold amount. When the token balance
    // of the contract reaches this threshold, a swap transaction can be initiated to convert tokens to ETH,
    // supporting liquidity and potentially providing ETH to the treasury wallet.
    uint256 private threshold;

    // Mapping to track addresses that are excluded from fees. This can include the contract address itself,
    // the treasury wallet, or other addresses that should not be subject to transaction fees.
    // Useful for reducing the friction in certain operations or for privileged accounts.
    mapping(address => bool) private _isExcludedFromFees;

    // A public mapping to track which addresses are considered automated market maker pairs. This is important
    // for determining whether a transaction should incur a buy or sell fee based on whether it interacts
    // with a liquidity pool. It's a dynamic way to adjust the contract's interaction with different DEXes.
    mapping(address => bool) public automatedMarketMakerPairs;

    /**
     * @dev initializes the Uniswap V2 router,
     * creates a CONDO/WETH pair on Uniswap, and excludes the contract and owner from fees.
     * @param _uniswapV2Router The address of the Uniswap V2 router.
     * @param _treasuryWallet The address of the treasury wallet.
     * @param _threshold The token amount threshold for auto-swapping tokens to ETH.
     */
    constructor(
        address _uniswapV2Router,
        address _treasuryWallet,
        uint256 _threshold
    ) ERC20("CONDO", "CONDO") Ownable(msg.sender) {
        require(
            _uniswapV2Router != address(0),
            "Condo: Invalid uniswapV2 router address"
        );
        require(
            _treasuryWallet != address(0),
            "Condo: Invalid treasury wallet address"
        );

        require(_threshold != 0, "Condo: Invalid threshold amount");

        uniswapV2Router = IUniswapV2Router02(_uniswapV2Router);

        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(
                address(this),
                uniswapV2Router.WETH()
            );

        _setAutomatedMarketMakerPair(address(uniswapV2Pair), true);

        // exclude from paying fees or having max transaction amount
        excludeFromFees(owner(), true);
        excludeFromFees(address(this), true);

        threshold = _threshold;
        treasuryWallet = _treasuryWallet;

        uint256 totalSupply = 10_000_000_000 * 1e18;

        _mint(msg.sender, totalSupply);
    }

    /**
     * @dev Private function to set a pair as an automated market maker pair.
     * @param pair The address of the pair to set.
     * @param value A boolean indicating whether it is an AMM pair.
     */
    function _setAutomatedMarketMakerPair(address pair, bool value) private {
        automatedMarketMakerPairs[pair] = value;

        emit SetAutomatedMarketMakerPair(pair, value);
    }

    /**
     * @dev Overridden implementation of the internal {ERC20-_update} function to include fee processing.
     * Fees are deducted and sent to this contract for buy/sell transactions.
     *
     * @param from The address sending the tokens.
     * @param to The address receiving the tokens.
     * @param amount The amount of tokens to send.
     */
    function _update(
        address from,
        address to,
        uint256 amount
    ) internal override {
        // require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        if (
            // !automatedMarketMakerPairs[from] &&
            // !automatedMarketMakerPairs[to] &&
            _reachedThreshold()
        ) {
            _swapTokensForEth(balanceOf(address(this))); // Swap threshold when we reach threshold
        }

        // Optimize fee application and token swap logic
        uint256 fees = _calculateFees(from, to, amount);

        if (fees != 0) {
            super._update(from, to, amount - fees);
            super._update(from, address(this), fees);
        } else {
            super._update(from, to, amount);
        }
    }

    /**
     * @dev Swaps tokens for ETH and sends it to the treasury wallet.
     * @param tokenAmount The amount of tokens to swap.
     */
    function _swapTokensForEth(uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), type(uint256).max);

        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            treasuryWallet,
            block.timestamp
        );
    }

    /**
     * @dev Excludes an account from fees.
     * @param account The account to exclude from fees.
     * @param excluded Whether the account is excluded from fees.
     */
    function excludeFromFees(address account, bool excluded) private {
        _isExcludedFromFees[account] = excluded;
        emit ExcludeFromFees(account, excluded);
    }

    /**
     * @dev Determines if the contract's balance has reached the defined threshold for swapping tokens.
     * @return bool True if the contract's balance is equal to or greater than the threshold.
     */
    function _reachedThreshold() private view returns (bool) {
        return balanceOf(address(this)) >= threshold;
    }

    /**
     * @dev Calculates the fees for a transfer.
     * @param from The address sending the tokens.
     * @param to The address receiving the tokens.
     * @param amount The amount of tokens to be transferred.
     * @return uint256 The fee amount.
     */
    function _calculateFees(
        address from,
        address to,
        uint256 amount
    ) private view returns (uint256) {
        if (_isExcludedFromFees[from] || _isExcludedFromFees[to]) {
            return 0;
        }

        if (automatedMarketMakerPairs[to] && sellFee > 0) {
            return (amount * sellFee) / 100;
        } else if (automatedMarketMakerPairs[from] && buyFee > 0) {
            return (amount * buyFee) / 100;
        }

        return 0;
    }
}
