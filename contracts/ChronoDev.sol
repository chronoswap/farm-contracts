// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import './dependencies/Context.sol';
import './dependencies/SafeMath.sol';
import './dependencies/BEP20.sol';

// ChronoDev is the develper of the Galaxy. He will make good use of the tokens
// received from the fees.
//
// Note that it's ownable and the owner wields tremendous power (not like
// Chronomaster though).
//
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract ChronoDev is Context {
    using SafeMath for uint256;
    // Events
    event ExecuteTransaction(
      address indexed target,
      uint value,
      string signature,
      bytes data,
      uint eta
    );
    // Struct: Fund destination structure
    struct Dest {
      string name;
      address addr;
      uint256 rate;
      bool isFixed;
    }
    // Owners of the ChronoDev
    mapping (address => bool) public owners;
    address[] ownerList;
    // Tokens in contract so ChronoDev will know how to handle them
    BEP20[] public tokens;
    // Fund destionation array
    Dest[] public destinations;
    // Transactions to be accepted by all owners
    mapping (bytes32 => mapping (address => bool)) transactions;
    // Last Payday
    uint256 lastPayDay;
    // Delay between paydays
    uint256 MINIMUM_PAY_DELAY = 604800;
    // Payday stuff
    uint256 totalAcc = 10000;
    uint256 fixedAcc = 0;

    modifier onlyOwner() {
        require(owners[_msgSender()], 'Ownable: caller is not the owner');
        _;
    }

    constructor(
      address[] memory _owners,
      address _contracts,
      address _partnership,
      address _marketing,
      address _treasury,
      address _charity,
      address _treasuryBNB,
      address _other,
      address _thop
      ) public {
        destinations.push(Dest({
          name: "other",
          addr: _other,
          rate: 1,
          isFixed: false
        }));
        uint16 i;
        for (i = 0; i < _owners.length; i++) {
          owners[_owners[i]] = true;
          ownerList.push(_owners[i]);
          destinations.push(Dest({
            name: "owner",
            addr: _owners[i],
            rate: 1111,
            isFixed: false
          }));
        }
        destinations.push(Dest({
          name: "contracts",
          addr: _contracts,
          rate: 1111,
          isFixed: false
        }));
        destinations.push(Dest({
          name: "partnership",
          addr: _partnership,
          rate: 1111,
          isFixed: false
        }));
        destinations.push(Dest({
          name: "marketing",
          addr: _marketing,
          rate: 1111,
          isFixed: false
        }));
        destinations.push(Dest({
          name: "treasury",
          addr: _treasury,
          rate: 1111,
          isFixed: false
        }));
        destinations.push(Dest({
          name: "treasuryBNB",
          addr: _treasuryBNB,
          rate: 1111,
          isFixed: false
        }));
        destinations.push(Dest({
          name: "charity",
          addr: _charity,
          rate: 1111,
          isFixed: false
        }));
        lastPayDay = block.timestamp;
        tokens.push(BEP20(_thop));
    }
    // Function to add a new owner. All owners must call it to be effective
    // Return codes:
    // true -> executed
    // false -> wait for other owners
    function addOwner(address _newOwner, bool benefitiary) public onlyOwner returns(bool){
        bool checkAddress = isContract(_newOwner);
        require(!checkAddress, 'ChronoDev: Address is a contract.');
        bytes32 _txHash = keccak256(abi.encode("owner", _newOwner, benefitiary));
        bool isOkForEveryone = checkStatus(_msgSender(), _txHash);
        if (isOkForEveryone) {
          owners[_newOwner] = true;
          if (benefitiary) {
            destinations.push(Dest({
              name: "owner",
              addr: _newOwner,
              rate: 0,
              isFixed: false
            }));
            update();
          }
          return true;
        }
        return false;
    }
    // Function to add a new destination. All owners must call it to be effective
    // Return codes:
    // true -> executed
    // false -> wait for other owners
    function addDestination(string calldata _name, address _addr, uint256 _rate) public onlyOwner returns(bool) {
        bool checkAddress = isContract(_addr);
        require(!checkAddress, 'ChronoDev: Address is a contract.');
        require(_rate <= totalAcc.sub(fixedAcc) , 'ChronoDev: rate too high.');
        require(keccak256(abi.encodePacked(_name)) != keccak256(abi.encodePacked("owner")), "ChronoDev: Call addOwnerFunction.");
        require(keccak256(abi.encodePacked(_name)) != keccak256(abi.encodePacked("other")), "ChronoDev: Invalid keyword.");
        bytes32 _txHash = keccak256(abi.encode("add", _name, _addr, _rate));
        bool isOkForEveryone = checkStatus(_msgSender(), _txHash);
        if (isOkForEveryone) {
          bool _fixed = false;
          if (_rate > 0) {
            _fixed = true;
          }
          destinations.push(Dest({
            name: _name,
            addr: _addr,
            rate: _rate,
            isFixed: _fixed
          }));
          update();

          return true;
        }
        return false;
    }
    // Function to set an existing destination. All owners must call it to be effective.
    // Return codes:
    // true -> executed
    // false -> wait for other owners
    function setDestination(uint256 _id, string calldata _name, address _addr, uint256 _rate) public onlyOwner returns(bool){
        require(_id < getDestinations(), "ChronoDev: Invalid destination.");
        bool checkAddress = isContract(_addr);
        require(!checkAddress, 'ChronoDev: Address is a contract.');
        require(_rate <= totalAcc.sub(fixedAcc) , 'ChronoDev: rate too high.');
        require(keccak256(abi.encodePacked(_name)) != keccak256(abi.encodePacked("owner")), "ChronoDev: Call addOwnerFunction.");
        require(keccak256(abi.encodePacked(_name)) != keccak256(abi.encodePacked("other")), "ChronoDev: Invalid keyword.");
        bytes32 _txHash = keccak256(abi.encode("set", _name, _addr, _rate));
        bool isOkForEveryone = checkStatus(_msgSender(), _txHash);
        if (isOkForEveryone) {
          bool _fixed = false;
          if (_rate > 0) {
            _fixed = true;
          }
          destinations[_id].name = _name;
          destinations[_id].addr = _addr;
          destinations[_id].rate = _rate;
          destinations[_id].isFixed = _fixed;
          update();

          return true;
        }
        return false;

    }
    // Funtion to update after adding new destination
    function update() private {
        uint16 i;
        uint256 _fixedNum = 0;
        uint256 _fixedAcc = 0;
        for (i = 1; i < destinations.length; i++) {
          if (destinations[i].isFixed) {
            _fixedAcc = _fixedAcc.add(destinations[i].rate);
            _fixedNum = _fixedNum.add(1);
          }
        }
        fixedAcc = _fixedAcc;
        uint256 _dynamicAcc = totalAcc.sub(_fixedAcc);
        uint256 _dynamicNum = destinations.length.sub(_fixedNum).sub(1);
        uint256 _dynamicUsed = 0;
        for (i = 1; i < destinations.length; i++) {
          if (!destinations[i].isFixed) {
            destinations[i].rate = _dynamicAcc.div(_dynamicNum);
            _dynamicUsed = _dynamicUsed.add(destinations[i].rate);
          }
        }
        destinations[0].rate = _dynamicAcc.sub(_dynamicUsed);
    }
    // Payday. Must be called by one of the owners. Once every week
    function payDay() public onlyOwner {
        uint256 delay = block.timestamp.sub(lastPayDay);
        require(delay >= MINIMUM_PAY_DELAY, "ChronoDev: Not yet, my friend.");
        uint16 i;
        uint16 j;
        uint256 balance;
        for (i = 0; i < tokens.length; i++) {
          balance = tokens[i].balanceOf(address(this));
          for (j = 0; j < destinations.length; j++) {
            tokens[i].transfer(destinations[j].addr, balance.mul(destinations[j].rate).div(totalAcc));
          }
        }
    }
    // Function to add a token so the contract can work with it
    function addToken(address tokenAddr, string calldata symbol) public onlyOwner {
        BEP20 _token = BEP20(tokenAddr);
        require(keccak256(abi.encodePacked(_token.symbol())) == keccak256(abi.encodePacked(symbol)), "ChronoDev: This is not the token you are looking for.");
        tokens.push(_token);
    }
    // Function to check if an address is a contract
    function isContract(address _addr) private view returns (bool){
        uint32 size;
        assembly {
          size := extcodesize(_addr)
        }
        return (size > 0);
    }
    // Function to execute any transaction. It must be accepted by all owners
    function executeTransaction(
      address target,
      uint value,
      string memory signature,
      bytes memory data, uint eta
      ) public payable onlyOwner returns (bytes memory) {
        bytes32 _txHash = keccak256(abi.encode(target, value, signature, data, eta));
        bool isOkForEveryone = checkStatus(_msgSender(), _txHash);
        require(isOkForEveryone, 'ChronoDev: Wait for the other owners');
        bytes memory callData;
        if (bytes(signature).length == 0) {
            callData = data;
        } else {
            callData = abi.encodePacked(bytes4(keccak256(bytes(signature))), data);
        }

        // solium-disable-next-line security/no-call-value
        (bool success, bytes memory returnData) = target.call{value: value}(callData);
        require(success, "Timelock::executeTransaction: Transaction execution reverted.");

        emit ExecuteTransaction(target, value, signature, data, eta);

        return returnData;
    }
    // Function to check the voting status of pending Transaction
    function checkStatus(address _owner, bytes32 txHash) private returns(bool) {
      transactions[txHash][_owner] = true;
      bool isOk = true;
      uint16 i;
      for (i = 0; i < ownerList.length; i++) {
        if (!transactions[txHash][ownerList[i]]) {
          isOk = false;
        }
      }
      return isOk;
    }
    // Getter funcitons
    function getDestinations() public view returns(uint256) {
        return destinations.length;
    }
    function getLastPayday() public view onlyOwner returns(uint256) {
        return lastPayDay;
    }
}
