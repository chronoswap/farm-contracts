// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import './dependencies/Ownable.sol';
import './dependencies/BEP20.sol';

// BlackHole is the burning contract. It will throw tokens right into the
// singularity, to never be seen again.
//
// Note that it's ownable and the owner wields tremendous power (Well, only to
// burn that power).
//
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract BlackHole is Ownable {
    event burn(address _token, uint256 amount);
    // Mapping of the tokens to destroy
    mapping (address => BEP20) public tokens;
    // Address of the singularity
    address public singularity;

    constructor(address _token, address _singularity) public {
        tokens[_token] = BEP20(_token);
        singularity = _singularity;
    }

    function toHell(address _token) public onlyOwner returns(bool) {
        uint256 balance = tokens[_token].balanceOf(address(this));
        require(balance > 0, "BlackHole: Invalid token");
        tokens[_token].transfer(singularity, balance);
        emit burn(_token, balance);
    }
    // Function to add a token so the contract can work with it
    function addToken(address tokenAddr, string calldata symbol) public onlyOwner {
        BEP20 _token = BEP20(tokenAddr);
        require(keccak256(abi.encodePacked(_token.symbol())) == keccak256(abi.encodePacked(symbol)), "BlackHole: This is not the token you are looking for.");
        tokens[tokenAddr] = _token;
    }
}
