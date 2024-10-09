// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {CommonTypes} from "@zondax/filecoin-solidity/contracts/v0.8/types/CommonTypes.sol";
import {FilAddresses} from "@zondax/filecoin-solidity/contracts/v0.8/utils/FilAddresses.sol";
import {SendAPI} from"@zondax/filecoin-solidity/contracts/v0.8/SendAPI.sol";
import {BigInts} from "@zondax/filecoin-solidity/contracts/v0.8/utils/BigInts.sol";
import {VerifRegAPI} from"@zondax/filecoin-solidity/contracts/v0.8/VerifRegAPI.sol";
import {VerifRegTypes} from "@zondax/filecoin-solidity/contracts/v0.8/types/VerifRegTypes.sol";
import {Ownable} from "src/Ownable.sol";

contract tap {

    address public owner;

    mapping(address => uint256) public book;

    uint256 public fee;

    uint256 public allowance;

    uint256  public period;

    constructor(address _owner, uint256 _fee, uint256 _allowance, uint256 _period){
        owner = _owner;
        fee = _fee;
        allowance = _allowance;
        period = _period;
    }

    modifier onlyOwner(){
        require(msg.sender == owner);
        _;
    }

    function changeOwner(address new_owner) public onlyOwner {
        owner = new_owner;
    }

    function setFee(uint256 _fee) public onlyOwner {
        fee = _fee;
    }

    function setAllowance(uint256 new_allowance) public onlyOwner {
        allowance = new_allowance;
    }

    function setPeriod(uint256 new_period) public onlyOwner {
        period = new_period;
    }

    function withdraw(uint256 _amount) public onlyOwner {
        SendAPI.send(FilAddressUtil.fromEthAddress(msg.sender), _amount);
    }

    function addVerifiedClient(address addr, uint256 _allowance) payable public onlyOwner {
        VerifRegAPI.addVerifiedClient(VerifRegTypes.AddVerifiedClientParams(FilAddressUtil.fromEthAddress(address(addr)), BigInts.fromInt256(int256(_allowance))));
    }

    function drip(address addr) payable public {
        require(block.number - book[addr] < period);
        if (msg.value < fee) {
            return;
        }

        VerifRegAPI.addVerifiedClient(VerifRegTypes.AddVerifiedClientParams(FilAddressUtil.fromEthAddress(address(addr)), BigInts.fromInt256(int256(allowance))));
        book[addr] = block.number;
    }

}

library FilAddressUtil {
    function isFilF0Address(address addr) internal pure returns (bool){
        if ((uint160(addr) >> 64) == 0xff0000000000000000000000) {
            return true;
        }

        return false;
    }

    function fromEthAddress(address addr) internal pure returns (CommonTypes.FilAddress memory){
        if (isFilF0Address(addr)) {
            return FilAddresses.fromActorID(uint64(uint160(addr)));
        }

        return FilAddresses.fromEthAddress(addr);
    }
}