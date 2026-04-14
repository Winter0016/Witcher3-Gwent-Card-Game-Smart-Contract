// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {
    ERC1155
} from "openzeppelin-contracts/contracts/token/ERC1155/ERC1155.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {
    AccessControl
} from "openzeppelin-contracts/contracts/access/AccessControl.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {
    ReentrancyGuard
} from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {
    Votes
} from "openzeppelin-contracts/contracts/governance/utils/Votes.sol";
import {
    EIP712
} from "openzeppelin-contracts/contracts/utils/cryptography/EIP712.sol";

contract GwentCardToken is ERC1155, AccessControl, ReentrancyGuard, Votes {
    uint256 public constant GAME_CURRENCY_ID = 0;
    uint256 public constant CARD_ID_START = 1;

    string public name = "Gwent Game Token";
    string public symbol = "GWENT";

    uint256 public tokenPrice = 5e15; // 0.000005 WETH per token = ~$1/pack

    IERC20 public wethToken;
    address public treasuryWallet;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant LOCKER_ROLE = keccak256("LOCKER_ROLE");

    mapping(address => bool) public isTransferLocked;

    uint256 public redemptionFeeBps = 500; // 5% fee
    uint256 public constant MAX_BPS = 10000;

    event TransferLockUpdated(address indexed account, bool locked);

    event TokensPurchased(
        address indexed buyer,
        uint256 payAmount,
        uint256 tokenAmount,
        bool isNative
    );
    event TokensRedeemed(
        address indexed seller,
        uint256 tokenAmount,
        uint256 payoutAmount,
        bool isNative
    );
    event PriceUpdated(uint256 oldPrice, uint256 newPrice);
    event WethTokenSet(address indexed wethToken);
    event RedemptionFeeUpdated(uint256 oldFee, uint256 newFee);

    constructor() ERC1155("") EIP712("GwentCardToken", "1") {
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(BURNER_ROLE, msg.sender);
        _grantRole(LOCKER_ROLE, msg.sender);
        treasuryWallet = msg.sender;
    }

    function setWethToken(
        address _wethToken
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_wethToken != address(0), "Invalid address");
        wethToken = IERC20(_wethToken);
        emit WethTokenSet(_wethToken);
    }

    function setTreasuryWallet(
        address wallet
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(wallet != address(0), "Invalid address");
        treasuryWallet = wallet;
    }

    function setTokenPrice(
        uint256 _tokenPrice
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        // 5e15; // 0.000005 WETH per token = ~$1/pack
        emit PriceUpdated(tokenPrice, _tokenPrice);
        tokenPrice = _tokenPrice;
    }

    function buyTokensWithWeth(
        uint256 tokenAmount,
        uint256 maxWethToPay
    ) external nonReentrant {
        require(address(wethToken) != address(0), "WETH not set");
        require(tokenAmount > 0, "Cannot buy 0 tokens");

        uint256 wethRequired = tokenAmount * tokenPrice;
        require(maxWethToPay >= wethRequired, "Insufficient WETH allowance");

        require(
            wethToken.transferFrom(msg.sender, address(this), wethRequired),
            "Transfer failed"
        );

        _mint(msg.sender, GAME_CURRENCY_ID, tokenAmount, "");

        emit TokensPurchased(msg.sender, wethRequired, tokenAmount, false);
    }

    function buyTokensWithNativeEth(
        uint256 tokenAmount
    ) external payable nonReentrant {
        require(tokenAmount > 0, "Cannot buy 0 tokens");
        uint256 ethRequired = tokenAmount * tokenPrice;
        require(msg.value >= ethRequired, "Insufficient ETH sent");

        _mint(msg.sender, GAME_CURRENCY_ID, tokenAmount, "");

        // Refund excess ETH
        if (msg.value > ethRequired) {
            (bool success, ) = payable(msg.sender).call{
                value: msg.value - ethRequired
            }("");
            require(success, "Refund failed");
        }

        emit TokensPurchased(msg.sender, ethRequired, tokenAmount, true);
    }

    function WithDrawTokenToWeth(uint256 tokenAmount) external nonReentrant {
        require(tokenAmount > 0, "Cannot withdraw 0");
        require(
            balanceOf(msg.sender, GAME_CURRENCY_ID) >= tokenAmount,
            "Insufficient tokens"
        );

        uint256 grossWeth = tokenAmount * tokenPrice;
        uint256 netWeth = (grossWeth * (MAX_BPS - redemptionFeeBps)) / MAX_BPS;

        _burn(msg.sender, GAME_CURRENCY_ID, tokenAmount);

        require(wethToken.balanceOf(address(this)) >= netWeth, "Low reserves");
        require(wethToken.transfer(msg.sender, netWeth), "Payload failed");

        emit TokensRedeemed(msg.sender, tokenAmount, netWeth, false);
    }

    function WithDrawTokenToNativeEth(
        uint256 tokenAmount
    ) external nonReentrant {
        require(tokenAmount > 0, "Cannot withdraw 0");
        require(
            balanceOf(msg.sender, GAME_CURRENCY_ID) >= tokenAmount,
            "Insufficient tokens"
        );

        uint256 grossEth = tokenAmount * tokenPrice;
        uint256 netEth = (grossEth * (MAX_BPS - redemptionFeeBps)) / MAX_BPS;

        _burn(msg.sender, GAME_CURRENCY_ID, tokenAmount);

        require(address(this).balance >= netEth, "Low reserves");
        (bool success, ) = payable(msg.sender).call{value: netEth}("");
        require(success, "ETH transfer failed");

        emit TokensRedeemed(msg.sender, tokenAmount, netEth, true);
    }

    function setRedemptionFeeBps(
        uint256 _bps
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        emit RedemptionFeeUpdated(redemptionFeeBps, _bps);
        redemptionFeeBps = _bps;
    }

    function withdrawReserves() external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 ethBalance = address(this).balance;
        if (ethBalance > 0) {
            (bool success, ) = payable(treasuryWallet).call{value: ethBalance}(
                ""
            );
            require(success, "ETH sweep failed");
        }

        uint256 wethBalance = wethToken.balanceOf(address(this));
        if (wethBalance > 0) {
            require(
                wethToken.transfer(treasuryWallet, wethBalance),
                "WETH sweep failed"
            );
        }
    }

    receive() external payable {}

    function grantBurnerRole(
        address account
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(BURNER_ROLE, account);
    }

    function grantMinterRole(
        address account
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(MINTER_ROLE, account);
    }

    function grantLockerRole(
        address account
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(LOCKER_ROLE, account);
    }

    function setTransferLock(
        address account,
        bool locked
    ) external onlyRole(LOCKER_ROLE) {
        isTransferLocked[account] = locked;
        emit TransferLockUpdated(account, locked);
    }

    uint256 public constant MAX_AIRDROP_BATCH = 50;

    function airdropCurrency(
        address[] calldata recipients,
        uint256 amount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(recipients.length <= MAX_AIRDROP_BATCH, "Batch too large");
        for (uint256 i = 0; i < recipients.length; i++) {
            _mint(recipients[i], GAME_CURRENCY_ID, amount, "");
        }
    }

    function airdropCurrencySingle(
        address recipient,
        uint256 amount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _mint(recipient, GAME_CURRENCY_ID, amount, "");
    }

    function mint(
        address to,
        uint256 cardId,
        uint256 amount
    ) external onlyRole(MINTER_ROLE) {
        require(cardId >= CARD_ID_START, "Cannot mint currency via mint");
        _mint(to, cardId, amount, "");
    }

    function mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data // Don't forget this!
    ) external onlyRole(MINTER_ROLE) {
        _mintBatch(to, ids, amounts, data);
    }

    function mintGameCurrency(
        address to,
        uint256 amount
    ) external onlyRole(MINTER_ROLE) {
        _mint(to, GAME_CURRENCY_ID, amount, "");
    }

    function burn(
        address from,
        uint256 cardId,
        uint256 amount
    ) external onlyRole(BURNER_ROLE) {
        _burn(from, cardId, amount);
    }

    function burnGameCurrency(
        address from,
        uint256 amount
    ) external onlyRole(BURNER_ROLE) {
        require(
            balanceOf(from, GAME_CURRENCY_ID) >= amount,
            "Insufficient currency"
        );
        _burn(from, GAME_CURRENCY_ID, amount);
    }

    function burnFrom(
        address from,
        uint256 cardId,
        uint256 amount
    ) external onlyRole(BURNER_ROLE) {
        _burn(from, cardId, amount);
    }

    function getCurrencyBalance(
        address account
    ) external view returns (uint256) {
        return balanceOf(account, GAME_CURRENCY_ID);
    }

    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    ) internal override {
        if (from != address(0) && isTransferLocked[from]) {
            for (uint256 i = 0; i < ids.length; i++) {
                if (ids[i] != GAME_CURRENCY_ID) {
                    revert("Wallet is locked by Protocol (Cards only)");
                }
            }
        }
        super._update(from, to, ids, values);

        // Governance Logic: Track voting power for Game Currency (ID 0)
        for (uint256 i = 0; i < ids.length; i++) {
            if (ids[i] == GAME_CURRENCY_ID) {
                _transferVotingUnits(from, to, values[i]);
            }
        }
    }

    function _getVotingUnits(
        address account
    ) internal view virtual override returns (uint256) {
        return balanceOf(account, GAME_CURRENCY_ID);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC1155, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
