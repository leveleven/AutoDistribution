// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Checker {
    mapping(address => bool[]) public checkNode;       // 节点检查

    // 获取以太坊签名信息哈希
    function getEthSignedMessageHash(bytes32 messageHash) public pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
    }

    // 验证签名地址
    function verify(
        address signer,
        bytes32 messageHash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public pure returns (bool) {
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);
        return ecrecover(ethSignedMessageHash, v, r, s) == signer;
    }

    // 验证签名
    function checkOnline(
        bytes32 messageHash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {
        // require(authorizedAddress[msg.sender], "No authorized address");
        require(verify(msg.sender, messageHash, v, r, s), "Invalid signer");
        checkNode[msg.sender].push(true);
    }

    function checkPass(address _address) public view returns (uint) {
        return checkNode[_address].length;
    }

    function resetChecker(address _address) public {
        delete checkNode[_address];
    }
}