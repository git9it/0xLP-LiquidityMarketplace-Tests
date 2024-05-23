// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

contract LiqudityLockerMock {

bool isSuccessfulPath = true;

function setUnsuccessfulPath() external{
  isSuccessfulPath = false;
}

function setSuccessfulPath() external{
  isSuccessfulPath = true;
}

  function getUserLockForTokenAtIndex (address _user, address _lpToken, uint256 _index) external view 
  returns (uint256, uint256, uint256, uint256, uint256, address) {

uint256 lockID = _index;
address owner = _user;

if (!isSuccessfulPath){
lockID = 999;
owner = address(0);
}

    return (0, 0, 0, 0, lockID, owner);
  }

  function transferLockOwnership (address _lpToken, uint256 _index, uint256 _lockID, address payable _newOwner) external {}

}
