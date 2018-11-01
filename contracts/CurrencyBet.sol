pragma solidity ^0.4.24;


contract ERC20 {
    function totalSupply() public view returns (uint256);
    function balanceOf(address _owner) public view returns (uint256);
    function transfer(address _to, uint256 _value) public returns (bool);
    function approve(address _spender, uint256 _value) public returns (bool);
    function allowance(address _owner, address _spender) public view returns (uint256);
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool);

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
}

contract ERC1203 is ERC20 {
    function totalSupply(uint256 _class) public view returns (uint256);
    function balanceOf(address _owner, uint256 _class) public view returns (uint256);
    function transfer(address _to, uint256 _class, uint256 _value) public returns (bool);
    function approve(address _spender, uint256 _class, uint256 _value) public returns (bool);
    function allowance(address _owner, address _spender, uint256 _class) public view returns (uint256);
    function transferFrom(address _from, address _to, uint256 _class, uint256 _value) public returns (bool);

    function fullyDilutedTotalSupply() public view returns (uint256);
    function fullyDilutedBalanceOf(address _owner) public view returns (uint256);
    function fullyDilutedAllowance(address _owner, address _spender) public view returns (uint256);
    function convert(uint256 _fromClass, uint256 _toClass, uint256 _value) public returns (bool);

    event Transfer(address indexed _from, address indexed _to, uint256 _class, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _class, uint256 _value);
    event Conversion(uint256 indexed _fromClass, uint256 indexed _toClass, uint256 _value);
}

contract Currency is ERC1203 {
    using SafeMath for uint256;

    enum Class {
        bronze, // 0.01 ETH
        silver, // 0.05 ETH | convertible to 5 bronze per silver
        gold // 0.1 ETH | convertible to 2 silver per gold
    }

    uint256 private constant BASE_CLASS = uint256(Class.bronze);

    mapping(uint256 => uint256) private _supplies;
    mapping(address => mapping(uint256 => uint256)) private _balances;
    mapping(address => mapping(address => mapping(uint256 => uint256))) private _allowances;

    //ERC-20 functions
    function totalSupply() public view returns (uint256) {
        return totalSupply(BASE_CLASS);
    }

    function balanceOf(address _owner) public view returns (uint256) {
        return balanceOf(_owner, BASE_CLASS);
    }

    function transfer(address _to, uint256 _value) public returns (bool) {
        require(transfer(_to, BASE_CLASS, _value));

        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function approve(address _spender, uint256 _value) public returns (bool) {
        require(approve(_spender, BASE_CLASS, _value));

        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) public view returns (uint256) {
        return allowance(_owner, _spender, BASE_CLASS);
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
        require(transferFrom(_from, _to, BASE_CLASS, _value));

        emit Transfer(_from, _to, _value);
        return true;
    }

    //ERC1203 functions
    function totalSupply(uint256 _class) public view returns (uint256) {
        return _supplies[_class];
    }

    function balanceOf(address _owner, uint256 _class) public view returns (uint256) {
        return _balances[_owner][_class];
    }

    function transfer(address _to, uint256 _class, uint256 _value) public returns (bool) {
        require(_value <= _balances[msg.sender][_class]);
        
        _balances[msg.sender][_class] = _balances[msg.sender][_class].safeSub(_value);
        _balances[_to][_class] = _balances[_to][_class].safeAdd(_value);

        emit Transfer(msg.sender, _to, _class, _value);
        return true;
    }

    function approve(address _spender, uint256 _class, uint256 _value) public returns (bool) {
        _allowances[msg.sender][_spender][_class] = _value;

        emit Approval(msg.sender, _spender, _class, _value);
        return true;
    }

    function allowance(address _owner, address _spender, uint256 _class) public view returns (uint256) {
        return _allowances[_owner][_spender][_class];
    }

    function transferFrom(address _from, address _to, uint256 _class, uint256 _value) public returns (bool) {
        require(_value <= _balances[_from][_class]);
        require(_value <= _allowances[_from][msg.sender][_class]);
        
        _balances[_from][_class] = _balances[_from][_class].safeSub(_value);
        _balances[_to][_class] = _balances[_to][_class].safeAdd(_value);
        _allowances[_from][msg.sender][_class] = _allowances[_from][msg.sender][_class].safeSub(_value);
        
        emit Transfer(_from, _to, _class, _value);
        return true;        
    }

    function fullyDilutedTotalSupply() public view returns (uint256) {
        uint256 _bronzeSupply = _supplies[uint256(Class.bronze)];
        uint256 _silverSupply = _supplies[uint256(Class.silver)];
        uint256 _goldSupply = _supplies[uint256(Class.gold)];

        return fullyDilute(_bronzeSupply, _silverSupply, _goldSupply);
    }

    function fullyDilutedBalanceOf(address _owner) public view returns (uint256) {
        uint256 _bronzeBalance = _balances[_owner][uint256(Class.bronze)];
        uint256 _silverBalance = _balances[_owner][uint256(Class.silver)];
        uint256 _goldBalance = _balances[_owner][uint256(Class.gold)];

        return fullyDilute(_bronzeBalance, _silverBalance, _goldBalance);
    }

    function fullyDilutedAllowance(address _owner, address _spender) public view returns (uint256) {
        uint256 _bronzeAllowance = _allowances[_owner][_spender][uint256(Class.bronze)];
        uint256 _silverAllowance = _allowances[_owner][_spender][uint256(Class.silver)];
        uint256 _goldAllowance = _allowances[_owner][_spender][uint256(Class.gold)];

        return fullyDilute(_bronzeAllowance, _silverAllowance, _goldAllowance);
    }

    function convert(uint256 _fromClass, uint256 _toClass, uint256 _value) public returns (bool) {
        require(_fromClass > _toClass); //must convert from a more expensive class
        require(_value <= _balances[msg.sender][_fromClass]);

        uint256 _convertedValue;
        if (_fromClass == uint256(Class.gold) && _toClass == uint256(Class.silver)) {
            _convertedValue = goldToSilver(_value);
        } else if (_fromClass == uint256(Class.silver) && _toClass == uint256(Class.bronze)) {
            _convertedValue = silverToBronze(_value);
        } else {
            revert();
        }

        _balances[msg.sender][_fromClass] = _balances[msg.sender][_fromClass].safeSub(_value);
        _balances[msg.sender][_toClass] = _balances[msg.sender][_toClass].safeAdd(_convertedValue);

        emit Conversion(_fromClass, _toClass, _value);
        return true;
    }

    //Helper functions
    function goldToSilver(uint256 _value) private pure returns (uint256) {
        return _value.safeMul(2);
    }

    function silverToBronze(uint256 _value) private pure returns (uint256) {
        return _value.safeMul(5);
    }

    function fullyDilute(uint256 _bronzeValue, uint256 _silverValue, uint256 _goldValue) private pure returns (uint256) {
        uint256 _silverDilution = goldToSilver(_goldValue);
        uint256 _bronzeDilution = silverToBronze(_silverValue.safeAdd(_silverDilution));

        return _bronzeValue.safeAdd(_bronzeDilution);
    }
}

contract Betting is Currency {
    address private _owner;
    address[] public players;
    uint8 public betCount;
    uint8 public constant BET_COUNT_LIMIT = 10;
    uint8[] private _selectedNumbers;
    uint256 public totalBet;
    uint256 public minimumBet = 0.001 ether;

    struct Player {
        uint256 amountBet;
        uint8 numberSelected;
    }

    mapping(address => Player) private _bets;

    function() public payable {}

    constructor(uint256 _minimumBet) public {
        _owner = msg.sender;
        betCount = 0;
        if (_minimumBet > 0) {
            minimumBet = _minimumBet;
        }
    }

    function playerAlreadyBet(address _address) public view returns(bool) {
        return _bets[_address].amountBet > 0;
    }

    function _resetData() private {
        players.length = 0;
        _selectedNumbers.length = 0;
        totalBet = 0;
        betCount = 0;
    }

    function _generateNumberWinner() private view returns (uint8) {
        // bad implementation of randomness, just for testing
        uint8 winningNum = uint8(block.number % 10 + 1);
        if (winningNum > 5) {
            winningNum = winningNum - 5;
        }
        return winningNum;
    }

    function _rewardWinners() private {
        uint8 winningNumber = _generateNumberWinner();
        uint8 winnerCounter = 0;
        address[9] memory winners;

        for (uint8 x = 0; x < players.length; x++) {
            address playerAddress = players[x];

            if (_bets[playerAddress].numberSelected == winningNumber) {
                winners[winnerCounter] = playerAddress;
                winnerCounter++;
            }
            delete _bets[playerAddress];
        }

        uint256 winningAmount = totalBet / winnerCounter;

        for (uint8 y = 0; y < winners.length; y++) {
            if (winners[y] != address(0)) winners[y].transfer(winningAmount);
        }

        _resetData();
    }

    function bet(uint8 _number) public payable {
        require(!playerAlreadyBet(msg.sender)); // player cannot bet on the same category twice
        require(msg.value >= minimumBet);
        require(_number >= 1 && _number <= 5);  // only numbers 1-5 can be numberSelected

        _bets[msg.sender] = Player(msg.value, _number);
        players.push(msg.sender);
        totalBet = totalBet.safeAdd(msg.value);
        betCount++;
        _selectedNumbers.push(_number);

        if (betCount == BET_COUNT_LIMIT && _selectedNumbers.length > 1) _rewardWinners();
    }
}

library SafeMath {
    function safeAdd(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        assert(c >= a);
        return c;
    }

    function safeSub(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    function safeMul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        assert(c / a == b);
        return c;
    }

    function safeDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }
}
