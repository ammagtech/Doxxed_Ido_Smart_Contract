// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./Ownable.sol";
import "./SafeMath.sol";
import "./IERC20.sol";
import "./Address.sol";

contract DoxxedIDO is Ownable {
    using SafeMath for uint256;
    using Address for address;

    enum PoolStatus {
        Pending,
        Live,
        Ended,
        ReadyForRewardClam
    }

    struct Staker {
        bool IsRewardsClaim;
        bool IsAllowForStaking;
        bool IsLimitAllow;
        uint256 Staking;
        uint256 Reward;
        uint256 MinLimitAllow;
        uint256 MaxLimitAllow;
    }

    struct AddStaker {
        address Address;
        bool IsLimitAllow;
        bool IsAllowForStaking;
        uint256 MinLimitAllow;
        uint256 MaxLimitAllow;
    }

    IERC20 public _rewardsToken;

    string private _name;

    uint256 private _rewardsTokenRate;
    uint256 private _rewardsTokenTotalSupply;
    uint256 private _rewardsTokenReminingSupply;
    uint256 private _stakingTotalRecived;

    address payable private _stakingDestinationAddress;

    PoolStatus private _status;

    bool private _isRewardsTokenSupplyAdded;
    bool private _isStakingSupplySendToDestinationAddress;

    mapping(address => Staker) private _stakeholders;

    modifier beforeStakingEnd() {
        require(
            _status == PoolStatus.Pending || _status == PoolStatus.Live,
            "Staking status must be Pending or Live"
        );
        _;
    }

    constructor(
        string memory name,
        address rewardsTokenAddress,
        address payable stakingDestinationAddress,
        uint256 rewardsTokenRate
    ) {
        _name = name;

        _stakingDestinationAddress = stakingDestinationAddress;

        _rewardsToken = IERC20(rewardsTokenAddress);

        _isRewardsTokenSupplyAdded = false;
        _isStakingSupplySendToDestinationAddress = false;

        if (rewardsTokenRate <= 0) {
            revert("rewards token rate should be grater then 0");
        }

        _rewardsTokenRate = rewardsTokenRate;

        _status = PoolStatus.Pending;
    }

    function getName() external view returns (string memory) {
        return _name;
    }

    function getStakeholder(address account)
        external
        view
        returns (Staker memory)
    {
        return _stakeholders[account];
    }

    function getStakingTokenTotalRecived() external view returns (uint256) {
        return _stakingTotalRecived;
    }

    function getRewardsTokenReminingSupply() external view returns (uint256) {
        return _rewardsTokenReminingSupply;
    }

    function getRewardsTokenTotalSupply() external view returns (uint256) {
        return _rewardsTokenTotalSupply;
    }

    function getRewardsTokenRate() external view returns (uint256) {
        return _rewardsTokenRate;
    }

    function getIsRewardsTokenSupplyAdded() external view returns (bool) {
        return _isRewardsTokenSupplyAdded;
    }

    function getIsStakingTokenSupplySendToDestinationAddress()
        external
        view
        returns (bool)
    {
        return _isStakingSupplySendToDestinationAddress;
    }

    function getPoolStatus() external view returns (PoolStatus) {
        return _status;
    }

    function getStakingTokenDestinationAddress()
        external
        view
        returns (address)
    {
        return _stakingDestinationAddress;
    }

    function setName(string memory name) external onlyOwner {
        _name = name;
    }

    function setRewardsTokenRate(uint256 rewardsTokenRate)
        external
        onlyOwner
        beforeStakingEnd
    {
        if (rewardsTokenRate <= 0) {
            revert("rewards token rate should be grater then 0");
        }
        _rewardsTokenRate = rewardsTokenRate;
    }

    function setStakingDestinationAddress(
        address payable stakingDestinationAddress
    ) external onlyOwner beforeStakingEnd {
        _stakingDestinationAddress = stakingDestinationAddress;
    }

    function addRewardsTokenSupply(uint256 rewardsTokenSupply)
        external
        onlyOwner
        beforeStakingEnd
    {
        if (rewardsTokenSupply <= 0) {
            revert("rewards token supply should be grater then 0");
        }

        bool transferFromStatus = _rewardsToken.transferFrom(
            msg.sender,
            address(this),
            rewardsTokenSupply
        );

        if (transferFromStatus) {
            _isRewardsTokenSupplyAdded = true;
            _rewardsTokenTotalSupply = _rewardsTokenTotalSupply.add(
                rewardsTokenSupply
            );
            _rewardsTokenReminingSupply = _rewardsTokenReminingSupply.add(
                rewardsTokenSupply
            );
        }
    }

    function addStakeholders(AddStaker[] memory stakers)
        external
        onlyOwner
        beforeStakingEnd
    {
        if (stakers.length > 0) {
            for (uint256 index = 0; index < stakers.length; index++) {
                if (stakers[index].IsLimitAllow) {
                    if (stakers[index].MinLimitAllow <= 0) {
                        revert("minimal allow limit should be grater then 0");
                    }

                    if (
                        stakers[index].MaxLimitAllow <= 0 ||
                        stakers[index].MaxLimitAllow <
                        stakers[index].MinLimitAllow
                    ) {
                        revert("maximal allow limit should be grater then 0");
                    }
                }
            }

            for (uint256 index = 0; index < stakers.length; index++) {
                _stakeholders[stakers[index].Address].IsLimitAllow = stakers[
                    index
                ].IsLimitAllow;
                _stakeholders[stakers[index].Address]
                    .IsAllowForStaking = stakers[index].IsAllowForStaking;
                _stakeholders[stakers[index].Address].MinLimitAllow = stakers[
                    index
                ].MinLimitAllow;
                _stakeholders[stakers[index].Address].MaxLimitAllow = stakers[
                    index
                ].MaxLimitAllow;
            }
        }
    }

    function setLive() external onlyOwner returns (bool) {
        if (_isRewardsTokenSupplyAdded) {
            revert("rewards token supply already added");
        }

        if (_status == PoolStatus.Live) {
            revert("Staking already live");
        }

        if (
            _status == PoolStatus.Pending &&
            _status != PoolStatus.Ended &&
            _status != PoolStatus.ReadyForRewardClam &&
            _status != PoolStatus.Live
        ) {
            _status = PoolStatus.Live;
        } else {
            revert("Staking can not live");
        }

        return false;
    }

    function setEnd() external onlyOwner {
        if (_status == PoolStatus.Ended) {
            revert("Staking already Ended");
        }

        if (
            _status == PoolStatus.Live &&
            _status != PoolStatus.Ended &&
            _status != PoolStatus.ReadyForRewardClam &&
            _status != PoolStatus.Pending
        ) {
            if (_rewardsTokenReminingSupply > 0) {
                bool transferStatus = _rewardsToken.transfer(
                    owner(),
                    _rewardsTokenReminingSupply
                );

                if (transferStatus) {
                    _rewardsTokenReminingSupply = _rewardsTokenReminingSupply
                        .sub(_rewardsTokenReminingSupply);
                    _status = PoolStatus.Ended;
                }
            } else {
                _status = PoolStatus.Ended;
            }
        } else {
            revert("Staking can not Ended");
        }
    }

    function setReadyForRewardClam() external onlyOwner {
        if (_status == PoolStatus.ReadyForRewardClam) {
            revert("Staking already Ready For Reward Clam");
        }

        if (
            _status == PoolStatus.Ended &&
            _status != PoolStatus.Live &&
            _status != PoolStatus.ReadyForRewardClam &&
            _status != PoolStatus.Pending
        ) {
            _status = PoolStatus.ReadyForRewardClam;
        } else {
            revert("Staking can not Ready For Reward Clam");
        }
    }

    function sendStaking() external payable onlyOwner {
        if (_isStakingSupplySendToDestinationAddress) {
            revert("Staking token already sended");
        }

        if (_status != PoolStatus.Live && _status != PoolStatus.Pending) {
            _stakingDestinationAddress.transfer(_stakingTotalRecived);

            _isStakingSupplySendToDestinationAddress = true;
        } else {
            revert("Staking token can not sended");
        }
    }

    function stake() external payable {
        if (_status != PoolStatus.Live) {
            revert("Staking is ended");
        }

        if (!_stakeholders[msg.sender].IsAllowForStaking) {
            revert("Not allow to stake");
        }

        if (msg.value <= 0) {
            revert("stake amount should be grater then 0");
        }

        uint256 checkamount = _stakeholders[msg.sender].Staking.add(msg.value);

        if (
            _stakeholders[msg.sender].IsLimitAllow &&
            ((_stakeholders[msg.sender].MinLimitAllow > checkamount) ||
                (_stakeholders[msg.sender].MaxLimitAllow < checkamount))
        ) {
            revert("staking limit not meet");
        }

        uint256 rewards = msg.value.div(_rewardsTokenRate);
        rewards = rewards.mul(1000000000000000000);

        if (_rewardsTokenReminingSupply < rewards) {
            revert("Amount is excced the staking");
        }

        _stakeholders[msg.sender].Staking = _stakeholders[msg.sender]
            .Staking
            .add(msg.value);
        _stakeholders[msg.sender].Reward = _stakeholders[msg.sender].Reward.add(
            rewards
        );
        _stakingTotalRecived = _stakingTotalRecived.add(msg.value);
        _rewardsTokenReminingSupply = _rewardsTokenReminingSupply.sub(rewards);
    }

    function stakeCal(uint256 amount) external view returns (uint256) {
        if (_status != PoolStatus.Live) {
            revert("Staking is ended");
        }

        if (!_stakeholders[msg.sender].IsAllowForStaking) {
            revert("Not allow to stake");
        }

        if (amount <= 0) {
            revert("stake amount should be grater then 0");
        }

        uint256 checkamount = _stakeholders[msg.sender].Staking.add(amount);

        if (
            _stakeholders[msg.sender].IsLimitAllow &&
            ((_stakeholders[msg.sender].MinLimitAllow > checkamount) ||
                (_stakeholders[msg.sender].MaxLimitAllow < checkamount))
        ) {
            revert("staking limit not meet");
        }

        uint256 rewards = amount.div(_rewardsTokenRate);
        rewards = rewards.mul(1000000000000000000);

        if (_rewardsTokenReminingSupply < rewards) {
            revert("Amount is excced the staking");
        }

        return rewards;
    }

    function claimRewards() external {
        if (_status == PoolStatus.ReadyForRewardClam) {
            if (_stakeholders[msg.sender].IsRewardsClaim) {
                revert("rewards already claim");
            }

            if (_stakeholders[msg.sender].Reward > 0) {
                bool transferStatus = _rewardsToken.transfer(
                    msg.sender,
                    _stakeholders[msg.sender].Reward
                );

                if (transferStatus) {
                    _stakeholders[msg.sender].IsRewardsClaim = true;
                }
            }
        } else {
            revert("can not claim rewards");
        }
    }
}
