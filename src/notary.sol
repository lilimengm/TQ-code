// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {CommonTypes} from "@zondax/filecoin-solidity/contracts/v0.8/types/CommonTypes.sol";
import {FilAddresses} from "@zondax/filecoin-solidity/contracts/v0.8/utils/FilAddresses.sol";
import {SendAPI} from"@zondax/filecoin-solidity/contracts/v0.8/SendAPI.sol";
import {BigInts} from "@zondax/filecoin-solidity/contracts/v0.8/utils/BigInts.sol";
import {VerifRegAPI} from"@zondax/filecoin-solidity/contracts/v0.8/VerifRegAPI.sol";
import {VerifRegTypes} from "@zondax/filecoin-solidity/contracts/v0.8/types/VerifRegTypes.sol";
import {Ownable} from "src/Ownable.sol";

contract notary is Ownable {
    using BigInts for *;

    //the tips the caller needs to pay
    uint256 public tipsPer1GiB;

    //the min datacap that users can apply for each time
    uint256  public minAllowance;

    //the max datacap that users can apply for each time
    uint256 public maxAllowance;

    //the interval between each application
    uint256  public interval;

    //record the epoch of the latest application
    mapping(address => uint256) public historicRecords;

    error InvalidAllowance(uint256);
    error IntervalShort(uint256);

    constructor(address owner, uint256 _tips, uint256 _minAllowance, uint256 _maxAllowance, uint256 _interval) Ownable(owner) {
        tipsPer1GiB = _tips;
        minAllowance = _minAllowance;
        maxAllowance = _maxAllowance;
        interval = _interval;
    }

    function setTips(uint256 new_tips) public onlyOwner {
        tipsPer1GiB = new_tips;
    }

    function setAllowance(uint256 new_min_allowance, uint256 new_max_allowance) public onlyOwner {
        minAllowance = new_min_allowance;
        maxAllowance = new_max_allowance;
    }

    function setInterval(uint256 new_interval) public onlyOwner {
        interval = new_interval;
    }

    function withdraw(uint256 _amount) public onlyOwner {
        SendAPI.send(FilAddressUtil.fromEthAddress(msg.sender), _amount);
    }

    //owner can allocate DC in any case
    function pump2(address addr, uint256 allowance) payable public onlyOwner {
        VerifRegAPI.addVerifiedClient(VerifRegTypes.AddVerifiedClientParams(FilAddressUtil.fromEthAddress(address(addr)), BigInts.fromInt256(int256(allowance))));
    }

    //the clients actively apply for DC
    function pump(address addr) payable public {
        uint256 curInterval = block.number - historicRecords[addr];
        if (curInterval < interval) {
            revert IntervalShort(curInterval);
        }

        uint256 allowance = getAllowance();
        if (allowance == 0){
            return;
        }

        VerifRegAPI.addVerifiedClient(VerifRegTypes.AddVerifiedClientParams(FilAddressUtil.fromEthAddress(address(addr)), BigInts.fromInt256(int256(allowance))));

        historicRecords[addr] = block.number;
    }

    //get valid allowance from value of message
    function getAllowance() internal view returns (uint256){
        uint256 allowance = msg.value / tipsPer1GiB * 1073741824;
        if (allowance < minAllowance) {
            return 0;
        }

        if (allowance > maxAllowance) {
            return maxAllowance;
        }

        return allowance;
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