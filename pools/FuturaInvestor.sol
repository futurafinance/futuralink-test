// SPDX-License-Identifier: MIT

pragma solidity 0.8.6;

import "./IInvestor.sol";
import "./IInvestmentPlan.sol";
import "./base/access/AccessControlled.sol";
import "./base/token/BEP20/EmergencyWithdrawable.sol";

contract FuturaInvestor is IInvestor, AccessControlled, EmergencyWithdrawable {
    IInvestmentPlan[] public plans;
    mapping(address => uint256) public planIndices;
    mapping(address => uint256) public allocations;
    mapping(address => uint256) public totalAmountsSent;
    uint256 public totalAllocatedPercentage;

    constructor() {
        
    }

    receive() external payable { }

    function allocateFunds() external override onlyAdmins {
        for(uint i = 0; i < plans.length; i++) {
            uint256 allocation = allocations[address(plans[i])];
            if (allocation == 0) {
                continue;
            }

            uint256 funds = address(this).balance * allocation / 1000;
            plans[i].deposit{value: funds}();
            totalAmountsSent[address(plans[i])] += funds;
        }
    }

    function addPlan(address planAddress) external onlyOwner {
        require(!planExists(planAddress), "Investor: Plan already exists");

        planIndices[planAddress] = plans.length;
        plans.push(IInvestmentPlan(planAddress));
    }

    function setAllocation(address planAddress, uint256 allocation) external onlyOwner {
        require(planExists(planAddress), "Investor: Plan does not exist");

        uint256 currentAllocation = allocations[planAddress];

        if (currentAllocation > allocation) {
            totalAllocatedPercentage -= (currentAllocation - allocation);
        } else {
            totalAllocatedPercentage += (allocation - currentAllocation);
        }

        require(totalAllocatedPercentage <= 1000, "Investor: Invalid allocation values");

        allocations[planAddress] = allocation;
    }

    function planExists(address plan) public view returns(bool) {
        uint256 index = planIndices[plan];
        if (index >= plans.length) {
            return false;
        }

        return address(plans[index]) == plan;
    }

    function removePlan(address planAddress) external onlyOwner {
        require(planExists(planAddress), "Investor: Plan does not exist");

        uint256 index = planIndices[planAddress];

        // Replace current index with the last one
        if (index != plans.length - 1) {
            IInvestmentPlan lastPlan = plans[plans.length - 1];
            plans[index] = lastPlan;
            planIndices[address(lastPlan)] = index;
        }
       
        delete planIndices[planAddress];
        plans.pop();
    }
}