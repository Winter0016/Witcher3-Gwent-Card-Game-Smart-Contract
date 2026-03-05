// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { FunctionsClient } from
    "chainlink-brownie-contracts/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import { FunctionsRequest } from
    "chainlink-brownie-contracts/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";
import { ConfirmedOwner } from
    "chainlink-brownie-contracts/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";

contract GwentCardConsumerTest is FunctionsClient, ConfirmedOwner {
    using FunctionsRequest for FunctionsRequest.Request;

    uint64 immutable private subscriptionId;
    bytes32 immutable private donID;

    bytes32 public lastRequestId;
    bytes public lastError;

    error UnexpectedRequestID(bytes32 requestId);

    event CardDataReceived(
        bytes32 indexed requestId,
        string name,
        string cardType,
        string image,
        string effect,
        uint256 power,
        string faction,
        string rarity
    );

    constructor(
        address router,
        uint64 _subscriptionId,
        bytes32 _donID
    )
        FunctionsClient(router)
        ConfirmedOwner(msg.sender)
    {
        subscriptionId = _subscriptionId;
        donID = _donID;
    }

    // =======================
    // JS SOURCE (NULL-SEPARATED)
    // =======================
    string private constant SOURCE_CODE =
        "const res = await Functions.makeHttpRequest({"
        "  url: 'https://winter0016.github.io/gwent-card/json-file/66.json',"
        "  responseType: 'json'"
        "});"
        "if (res.error) { throw Error('Request failed'); }"
        "const d = res.data;"
        "const sep = new Uint8Array([0]);"
        "const Name = Functions.encodeString(d.name);"
        "const Type = Functions.encodeString(d.type);"
        "const Image = Functions.encodeString(d.image);"
        "const Effect = d.effect ? Functions.encodeString(d.effect) : new Uint8Array([]);"
        "const Power = Functions.encodeString(d.power.toString());"
        "const Faction = Functions.encodeString(d.faction);"
        "const Rarity = Functions.encodeString(d.rarity);"
        "const out = new Uint8Array("
        "  Name.length + Type.length + Image.length + Effect.length + "
        "  Power.length + Faction.length + Rarity.length + 6"
        ");"
        "let o = 0;"
        "out.set(Name, o);    o += Name.length;    out[o++] = 0;"
        "out.set(Type, o);    o += Type.length;    out[o++] = 0;"
        "out.set(Image, o);   o += Image.length;   out[o++] = 0;"
        "out.set(Effect, o);  o += Effect.length;  out[o++] = 0;"
        "out.set(Power, o);   o += Power.length;   out[o++] = 0;"
        "out.set(Faction, o); o += Faction.length; out[o++] = 0;"
        "out.set(Rarity, o);"
        "return out;";

    // =======================
    // REQUEST
    // =======================
    function requestCardData(uint32 gasLimit)
        external
        onlyOwner
        returns (bytes32)
    {
        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(SOURCE_CODE);

        lastRequestId = _sendRequest(
            req.encodeCBOR(),
            subscriptionId,
            gasLimit,
            donID
        );

        return lastRequestId;
    }

    // =======================
    // FULFILL (MEMORY ONLY)
    // =======================
    function fulfillRequest(
        bytes32 requestId,
        bytes memory response,
        bytes memory err
    ) 
        internal
        override
    {
        if (requestId != lastRequestId) {
            revert UnexpectedRequestID(requestId);
        }

        if (err.length > 0) {
            lastError = err;
            return;
        }

        uint256 ptr = 0;

        string memory name;
        string memory cardType;
        string memory image;
        string memory effect;
        string memory powerStr;
        string memory faction;
        string memory rarity;

        (name, ptr)     = _readString(response, ptr);
        (cardType, ptr) = _readString(response, ptr);
        (image, ptr)    = _readString(response, ptr);
        (effect, ptr)   = _readString(response, ptr);
        (powerStr, ptr) = _readString(response, ptr);
        (faction, ptr)  = _readString(response, ptr);
        (rarity, )      = _readString(response, ptr);

        uint256 power = _parseUint(powerStr);

        emit CardDataReceived(
            requestId,
            name,
            cardType,
            image,
            effect,
            power,
            faction,
            rarity
        );
    }


    function fulfillRequestTesting(
        bytes memory response
    ) 
        public
        returns(string memory, string memory, string memory, string memory, uint256, string memory, string memory)
    {


        uint256 ptr = 0;

        string memory name;
        string memory cardType;
        string memory image;
        string memory effect;
        string memory powerStr;
        string memory faction;
        string memory rarity;

        (name, ptr)     = _readString(response, ptr);
        (cardType, ptr) = _readString(response, ptr);
        (image, ptr)    = _readString(response, ptr);
        (effect, ptr)   = _readString(response, ptr);
        (powerStr, ptr) = _readString(response, ptr);
        (faction, ptr)  = _readString(response, ptr);
        (rarity, )      = _readString(response, ptr);

        uint256 power = _parseUint(powerStr);

        return (name, cardType, image, effect, power, faction, rarity);
    }

    // =======================
    // HELPERS
    // =======================
    function _readString(bytes memory data, uint256 start)
        internal
        pure
        returns (string memory value, uint256 next)
    {
        uint256 end = start;
        while (end < data.length && data[end] != 0) end++;

        uint256 len = end - start;

        assembly {
            value := mload(0x40)
            mstore(value, len)

            let src := add(add(data, 32), start)
            let dst := add(value, 32)

            for { let i := 0 } lt(i, len) { i := add(i, 32) } {
                mstore(add(dst, i), mload(add(src, i)))
            }

            mstore(0x40, add(dst, and(add(len, 31), not(31))))
        }

        next = end + 1;
    }

    function _parseUint(string memory s)
        internal
        pure
        returns (uint256)
    {
        bytes memory b = bytes(s);
        uint256 n;

        for (uint256 i; i < b.length; i++) {
            n = n * 10 + (uint8(b[i]) - 48);
        }
        return n;
    }
}
