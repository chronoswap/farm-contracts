// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import './dependencies/SafeBEP20.sol';
import './OneKProjectsToken.sol';

// ChronoMaster is the master of ThoP. He can make ThoP and he is a fair guy.
//
// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once ThoP is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract ChronoMaster is Ownable {
    using SafeMath for uint256;
    using SafeBEP20 for IBEP20;

    // Info of each user.
    struct UserInfo {
        uint256 amount;     // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of ThoPs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accCakePerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accCakePerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IBEP20 lpToken;           // Address of LP token contract.
        uint256 allocPoint;       // How many allocation points assigned to this pool. ThoPs to distribute per block.
        uint256 lastRewardBlock;  // Last block number that ThoPs distribution occurs.
        uint256 accCakePerShare;  // Accumulated ThoPs per share, times 1e12. See below.
        uint16 depositFee;       // Deposit fee in percentage.
    }

    // The ThoP TOKEN!
    OneKProjectsToken public thop;
    // Dev address.
    address public devaddr;
    // Burn address. All balance in this account will be burned weekly.
    address public burnaddr;
    // Dev ratio.
    uint256 public devRate;
    // Burn ratio.
    uint256 public burnRate;
    // ThoP tokens created per block.
    uint256 public cakePerBlock;
    // Reduction time for ThoP tokens created per block.
    uint256 public reductionDelta;
    // Bonus muliplier for early ThoP makers.
    uint256 public BONUS_MULTIPLIER = 1;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;
    // Amounts of each pool.
    mapping (uint256 => uint256) internal lpTokenAmount;
    // Total allocation poitns. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The point in time when ThoP mining starts.
    uint256 public startTime;
    // The block number when ThoP mining starts.
    uint256 public startBlock;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);

    constructor(
        OneKProjectsToken _thop,
        address _devaddr,
        address _burnaddr
    ) public {
        thop = OneKProjectsToken(_thop);
        devaddr = _devaddr;
        devRate = 909;
        burnaddr = _burnaddr;
        burnRate = 50;
        cakePerBlock = 3472223077864510000;
        reductionDelta = 604800;
        startBlock = block.number;
        startTime = block.timestamp;

        // staking pool
        poolInfo.push(PoolInfo({
            lpToken: _thop,
            allocPoint: 1000,
            lastRewardBlock: startBlock,
            accCakePerShare: 0,
            depositFee: 0
        }));

        totalAllocPoint = 1000;

    }

    function updateMultiplier(uint256 multiplierNumber) public onlyOwner {
        BONUS_MULTIPLIER = multiplierNumber;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(uint256 _allocPoint, address _lpToken, uint16 _depositFee, bool _withUpdate) public onlyOwner {
        require(_depositFee < 100, "add: invalid deposit fee percentage");
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(PoolInfo({
            lpToken: IBEP20(_lpToken),
            allocPoint: _allocPoint,
            lastRewardBlock: lastRewardBlock,
            accCakePerShare: 0,
            depositFee: _depositFee
        }));
        updateStakingPool();
    }

    // Update the given pool's THOP allocation point. Can only be called by the owner.
    function set(uint256 _pid, uint256 _allocPoint, uint16 _depositFee, bool _withUpdate) public onlyOwner {
        require(_depositFee < 100, "set: invalid deposit fee percentage");
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
        uint256 prevAllocPoint = poolInfo[_pid].allocPoint;
        poolInfo[_pid].allocPoint = _allocPoint;
        poolInfo[_pid].depositFee = _depositFee;
        if (prevAllocPoint != _allocPoint) {
            updateStakingPool();
        }
    }

    function updateStakingPool() internal {
        uint256 length = poolInfo.length;
        uint256 points = 0;
        for (uint256 pid = 1; pid < length; ++pid) {
            points = points.add(poolInfo[pid].allocPoint);
        }
        if (points != 0) {
            points = points.div(3);
            totalAllocPoint = totalAllocPoint.sub(poolInfo[0].allocPoint).add(points);
            poolInfo[0].allocPoint = points;
        }
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {
        return _to.sub(_from).mul(BONUS_MULTIPLIER);
    }

    // View function to see pending ThoPs on frontend.
    function pendingCake(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accCakePerShare = pool.accCakePerShare;
        uint256 lpSupply = lpTokenAmount[_pid];;
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);

            uint256[] memory _stats = getCurrentRates();

            uint256 cakeReward = multiplier.mul(_stats[2]).mul(pool.allocPoint).div(totalAllocPoint);
            accCakePerShare = accCakePerShare.add(cakeReward.mul(1e12).div(lpSupply));
        }
        return user.amount.mul(accCakePerShare).div(1e12).sub(user.rewardDebt);
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }


    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = lpTokenAmount[_pid];
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);

        uint256[] memory _stats = getCurrentRates();

        uint256 cakeToBurn = multiplier.mul(_stats[0]).mul(pool.allocPoint).div(totalAllocPoint);
        uint256 cakeToDev = multiplier.mul(_stats[1]).mul(pool.allocPoint).div(totalAllocPoint);
        uint256 cakeReward = multiplier.mul(_stats[2]).mul(pool.allocPoint).div(totalAllocPoint);
        thop.mint(burnaddr, cakeToBurn);
        thop.mint(devaddr, cakeToDev);
        thop.mint(address(this), cakeReward);
        pool.accCakePerShare = pool.accCakePerShare.add(cakeReward.mul(1e12).div(lpSupply));
        pool.lastRewardBlock = block.number;
    }

    // Deposit LP tokens to MasterChef for ThoP allocation.
    function deposit(uint256 _pid, uint256 _amount) public {

        require (_pid != 0, 'deposit ThoP by staking');

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accCakePerShare).div(1e12).sub(user.rewardDebt);
            if(pending > 0) {
                safeCakeTransfer(msg.sender, pending);
            }
        }
        if (_amount > 0) {
            pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            if(pool.depositFee > 0){
                uint256 depositFee = _amount.mul(pool.depositFee).div(100);
                pool.lpToken.safeTransfer(burnaddr, depositFee.div(2));
                pool.lpToken.safeTransfer(devaddr, depositFee.div(2));
                user.amount = user.amount.add(_amount).sub(depositFee);
            }else{
                user.amount = user.amount.add(_amount);
            }
            lpTokenAmount[_pid] += user.amount;
        }
        user.rewardDebt = user.amount.mul(pool.accCakePerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) public {

        require (_pid != 0, 'withdraw ThoP by unstaking');

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accCakePerShare).div(1e12).sub(user.rewardDebt);
        if(pending > 0) {
            safeCakeTransfer(msg.sender, pending);
        }
        if(_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
            lpTokenAmount[_pid] -= _amount;
        }
        user.rewardDebt = user.amount.mul(pool.accCakePerShare).div(1e12);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Stake THOP tokens to MasterChef
    function enterStaking(uint256 _amount) public {
        PoolInfo storage pool = poolInfo[0];
        UserInfo storage user = userInfo[0][msg.sender];
        updatePool(0);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accCakePerShare).div(1e12).sub(user.rewardDebt);
            if(pending > 0) {
                safeCakeTransfer(msg.sender, pending);
            }
        }
        if(_amount > 0) {
            pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            user.amount = user.amount.add(_amount);
            lpTokenAmount[_pid] += _amount;
        }
        user.rewardDebt = user.amount.mul(pool.accCakePerShare).div(1e12);

        emit Deposit(msg.sender, 0, _amount);
    }

    // Withdraw THOP tokens from STAKING.
    function leaveStaking(uint256 _amount) public {
        PoolInfo storage pool = poolInfo[0];
        UserInfo storage user = userInfo[0][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(0);
        uint256 pending = user.amount.mul(pool.accCakePerShare).div(1e12).sub(user.rewardDebt);
        if(pending > 0) {
            safeCakeTransfer(msg.sender, pending);
        }
        if(_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
            lpTokenAmount[0] -= _amount;
        }
        user.rewardDebt = user.amount.mul(pool.accCakePerShare).div(1e12);

        emit Withdraw(msg.sender, 0, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        pool.lpToken.safeTransfer(address(msg.sender), user.amount);
        lpTokenAmount[_pid] -= user.amount;
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
    }

    // Safe Thop transfer function, just in case if rounding error causes pool to not have enough ThoPs.
    function safeCakeTransfer(address _to, uint256 _amount) internal {
        uint256 cakeBal = thop.balanceOf(address(this));
        if (_amount > cakeBal) {
            thop.transfer(_to, cakeBal);
        } else {
            thop.transfer(_to, _amount);
        }
    }

    // Update dev address by the previous dev.
    function dev(address _devaddr) public {
        require(msg.sender == devaddr, "dev: wut?");
        devaddr = _devaddr;
    }

    function getCurrentRates() private view returns (uint256[] memory) { // TODO Check this
        uint16 i;
        uint256 calcblocks = cakePerBlock;
        uint256 _burnRate = burnRate;
        uint256 duration = block.timestamp - startTime;
        uint256 mulNum = duration.div(reductionDelta);

        for (i = 1; i < mulNum; i++) {
            calcblocks = calcblocks.div(100).mul(99);
            _burnRate = _burnRate.div(100).mul(99);
        }
        uint256[] memory stats = new uint256[](3);
        uint256 toBurn = calcblocks.div(100).mul(_burnRate);
        uint256 toDev = calcblocks.div(10000).mul(devRate);
        uint256 toPools = calcblocks.sub(toBurn).sub(toDev);
        stats[0] = toBurn;
        stats[1] = toDev;
        stats[2] = toPools;

        return stats;
    }

    function getCurrentPerBlock() public view returns (uint256) {
        uint16 i;
        uint256 calcblocks = cakePerBlock;
        uint256 duration = block.timestamp - startTime;
        uint256 mulNum = duration.div(reductionDelta);

        for (i = 1; i < mulNum; i++) {
            calcblocks = calcblocks.div(100).mul(99);
        }

        return calcblocks;
    }
}
