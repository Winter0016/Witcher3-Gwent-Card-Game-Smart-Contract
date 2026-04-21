// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IGwentCardToken {
    function mint(address to, uint256 id, uint256 amount) external;
    function mintGameCurrency(address to, uint256 amount) external;
    function burn(address from, uint256 id, uint256 amount) external;
    function burnGameCurrency(address from, uint256 amount) external;
    function burnFrom(address from, uint256 id, uint256 amount) external;
    function mintBatch(
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes memory data
    ) external;
    function getCurrencyBalance(
        address account
    ) external view returns (uint256);
    function balanceOf(
        address account,
        uint256 id
    ) external view returns (uint256);
    function balanceOfBatch(
        address[] calldata accounts,
        uint256[] calldata ids
    ) external view returns (uint256[] memory);
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) external;
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external;
    function GAME_CURRENCY_ID() external view returns (uint256);
    function tokenPrice() external view returns (uint256);
    function buyTokens(uint256 tokenAmount, uint256 maxWethToPay) external;
    function wethToken() external view returns (address);
    function setWethToken(address _wethToken) external;
    function setTransferLock(address account, bool locked) external;
}
