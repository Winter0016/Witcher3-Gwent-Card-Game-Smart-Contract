// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ERC1155 } from
    "openzeppelin-contracts/contracts/token/ERC1155/ERC1155.sol";
import { Ownable } from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {AccessControl} from
    "openzeppelin-contracts/contracts/access/AccessControl.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract GwentCardToken is ERC1155,AccessControl {

    uint256 public constant GAME_CURRENCY_ID = 0;
    uint256 public constant CARD_ID_START = 1;

    string public name = "Gwent Game Token";
    string public symbol = "GWENT";

    mapping(address => uint256) public currencyBalances;

    uint256 public tokenPrice = 5e15; // 0.000005 WETH per token = ~$1/pack

    IERC20 public wethToken;
    address public treasuryWallet;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    event TokensPurchased(address indexed buyer, uint256 wethAmount, uint256 tokenAmount);
    event PriceUpdated(uint256 oldPrice, uint256 newPrice);
    event WethTokenSet(address indexed wethToken);

    constructor() ERC1155("") {
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(BURNER_ROLE, msg.sender);
        treasuryWallet = msg.sender;
    }

    function setWethToken(address _wethToken) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_wethToken != address(0), "Invalid address");
        wethToken = IERC20(_wethToken);
        emit WethTokenSet(_wethToken);
    }

    function setTreasuryWallet(address wallet) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(wallet != address(0), "Invalid address");
        treasuryWallet = wallet;
    }

    function setTokenPrice(uint256 _tokenPrice) external onlyRole(DEFAULT_ADMIN_ROLE) { // 5e15; // 0.000005 WETH per token = ~$1/pack
        emit PriceUpdated(tokenPrice, _tokenPrice);
        tokenPrice = _tokenPrice;
    }

    function buyTokens(uint256 tokenAmount, uint256 maxWethToPay) external {
        require(address(wethToken) != address(0), "WETH not set");
        require(tokenAmount > 0, "Cannot buy 0 tokens");
        
        uint256 wethRequired = tokenAmount * tokenPrice;
        require(maxWethToPay >= wethRequired, "Insufficient WETH");
        
        uint256 userBalance = wethToken.balanceOf(msg.sender);
        require(userBalance >= wethRequired, "Insufficient WETH balance");

        require(wethToken.transferFrom(msg.sender, treasuryWallet, wethRequired), "Transfer failed");

        _mint(msg.sender, GAME_CURRENCY_ID, tokenAmount, "");
        currencyBalances[msg.sender] += tokenAmount;

        emit TokensPurchased(msg.sender, wethRequired, tokenAmount);
    }

    function grantBurnerRole(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(BURNER_ROLE, account);
    }

    function grantMinterRole(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(MINTER_ROLE, account);
    }

    uint256 public constant MAX_AIRDROP_BATCH = 50;

    function airdropCurrency(address[] calldata recipients, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(recipients.length <= MAX_AIRDROP_BATCH, "Batch too large");
        for (uint256 i = 0; i < recipients.length; i++) {
            _mint(recipients[i], GAME_CURRENCY_ID, amount, "");
            currencyBalances[recipients[i]] += amount;
        }
    }

    function airdropCurrencySingle(address recipient, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _mint(recipient, GAME_CURRENCY_ID, amount, "");
        currencyBalances[recipient] += amount;
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
        currencyBalances[to] += amount;
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
        require(currencyBalances[from] >= amount, "Insufficient currency");
        _burn(from, GAME_CURRENCY_ID, amount);
        currencyBalances[from] -= amount;
    }

    function burnFrom(
        address from,
        uint256 cardId,
        uint256 amount
    ) external onlyRole(BURNER_ROLE) {
        _burn(from, cardId, amount);
    }

    function getCurrencyBalance(address account) external view returns (uint256) {
        return currencyBalances[account];
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

}
