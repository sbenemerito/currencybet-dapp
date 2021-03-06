pragma solidity ^0.4.24;


contract ERC1203 {
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

    enum CurrencyClass {
        bronze, // 0.01 ETH
        silver, // 0.05 ETH | convertible to 5 bronze per silver
        gold // 0.1 ETH | convertible to 2 silver per gold
    }

    struct Player {
        uint256 amountBet;
        uint256 amountClass;
        uint8 numberSelected;
    }

    address private owner;
    address[] public players;
    uint8 public betCount;
    uint8 public constant BET_COUNT_LIMIT = 10;

    mapping(uint256 => uint256) private _supplies;
    mapping(address => Player) private _playerInfo;
    mapping(uint256 => mapping(uint256 => uint256)) private _bets;
    mapping(address => mapping(uint256 => uint256)) private _balances;
    mapping(address => mapping(address => mapping(uint256 => uint256))) private _allowances;

    function() public payable {}

    constructor() public {
        owner = msg.sender;
        betCount = 0;
        for (uint256 x = 0; x < 6; x++) {
            _bets[x][0] = 0;
            _bets[x][1] = 0;
            _bets[x][2] = 0;
        }
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
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
        uint256 _bronzeSupply = _supplies[uint256(CurrencyClass.bronze)];
        uint256 _silverSupply = _supplies[uint256(CurrencyClass.silver)];
        uint256 _goldSupply = _supplies[uint256(CurrencyClass.gold)];

        return fullyDilute(_bronzeSupply, _silverSupply, _goldSupply);
    }

    function fullyDilutedBalanceOf(address _owner) public view returns (uint256) {
        uint256 _bronzeBalance = _balances[_owner][uint256(CurrencyClass.bronze)];
        uint256 _silverBalance = _balances[_owner][uint256(CurrencyClass.silver)];
        uint256 _goldBalance = _balances[_owner][uint256(CurrencyClass.gold)];

        return fullyDilute(_bronzeBalance, _silverBalance, _goldBalance);
    }

    function fullyDilutedAllowance(address _owner, address _spender) public view returns (uint256) {
        uint256 _bronzeAllowance = _allowances[_owner][_spender][uint256(CurrencyClass.bronze)];
        uint256 _silverAllowance = _allowances[_owner][_spender][uint256(CurrencyClass.silver)];
        uint256 _goldAllowance = _allowances[_owner][_spender][uint256(CurrencyClass.gold)];

        return fullyDilute(_bronzeAllowance, _silverAllowance, _goldAllowance);
    }

    function convert(uint256 _fromClass, uint256 _toClass, uint256 _value) public returns (bool) {
        require(_fromClass != _toClass);
        require(_value <= _balances[msg.sender][_fromClass]);

        uint256 _convertedValue;
        if (_fromClass == uint256(CurrencyClass.gold) && _toClass == uint256(CurrencyClass.silver)) {
            _convertedValue = goldToSilver(_value);
        } else if (_fromClass == uint256(CurrencyClass.silver) && _toClass == uint256(CurrencyClass.bronze)) {
            _convertedValue = silverToBronze(_value);
        } else if (_fromClass == uint256(CurrencyClass.gold) && _toClass == uint256(CurrencyClass.bronze)) {
            _convertedValue = silverToBronze(goldToSilver(_value));
        } else if (_fromClass == uint256(CurrencyClass.bronze) && _toClass == uint256(CurrencyClass.silver)) {
            _convertedValue = bronzeToSilver(_value);
        } else if (_fromClass == uint256(CurrencyClass.bronze) && _toClass == uint256(CurrencyClass.gold)) {
            _convertedValue = silverToGold(bronzeToSilver(_value));
        } else if (_fromClass == uint256(CurrencyClass.silver) && _toClass == uint256(CurrencyClass.gold)) {
            _convertedValue = silverToGold(_value);
        } else {
            revert();
        }

        _balances[msg.sender][_fromClass] = _balances[msg.sender][_fromClass].safeSub(_value);
        _balances[msg.sender][_toClass] = _balances[msg.sender][_toClass].safeAdd(_convertedValue);
        _supplies[_fromClass] = _supplies[_fromClass].safeSub(_value);
        _supplies[_toClass] = _supplies[_toClass].safeAdd(_convertedValue);

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

    function bronzeToSilver(uint256 _value) private pure returns (uint256) {
        return _value.safeDiv(5);
    }

    function silverToGold(uint256 _value) private pure returns (uint256) {
        return _value.safeDiv(2);
    }

    function fullyDilute(uint256 _bronzeValue, uint256 _silverValue, uint256 _goldValue) private pure returns (uint256) {
        uint256 _silverDilution = goldToSilver(_goldValue);
        uint256 _bronzeDilution = silverToBronze(_silverValue.safeAdd(_silverDilution));

        return _bronzeValue.safeAdd(_bronzeDilution);
    }

    // Betting functions
    function withdrawBalance(uint256 _amount) public onlyOwner {
        require(_amount <= address(this).balance);
        if (_amount > 0) {
            owner.transfer(_amount);
        } else {
            owner.transfer(address(this).balance);
        }
    }

    function playerAlreadyBet(address _address) public view returns(bool) {
        return _playerInfo[_address].amountBet > 0;
    }

    function _resetBetData() private {
        players.length = 0;
        betCount = 0;
        for (uint256 x = 0; x < 6; x++) {
            _bets[x][0] = 0;
            _bets[x][1] = 0;
            _bets[x][2] = 0;
        }
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

        uint256 prizeInBronze = 0;
        uint256 winningPoolInBronze = 0;
        for (uint256 x = 0; x < 6; x++) {
            if (x == winningNumber) {
                winningPoolInBronze = winningPoolInBronze.safeAdd(fullyDilute(_bets[x][0], _bets[x][1], _bets[x][2]));
            } else if (x > 0) {
                prizeInBronze = prizeInBronze.safeAdd(fullyDilute(_bets[x][0], _bets[x][1], _bets[x][2]));
                _supplies[0] = _supplies[0].safeAdd(fullyDilute(0, _bets[x][1], _bets[x][2]));
                _supplies[1] = _supplies[1].safeSub(_bets[x][1]);
                _supplies[2] = _supplies[2].safeSub(_bets[x][2]);
            }
        }

        for (uint8 i = 0; i < players.length; i++) {
            address playerAddress = players[i];

            if (_playerInfo[playerAddress].numberSelected == winningNumber) {
                winners[winnerCounter] = playerAddress;
                winnerCounter++;
            }
            delete _playerInfo[playerAddress];
        }

        if (winnerCounter > 0) {
            for (uint8 y = 0; y < winners.length; y++) {
                if (winners[y] != address(0)) {
                    uint256 winningAmount = 0;
                    if (_playerInfo[winners[y]].amountClass == 2) {
                        winningAmount = (silverToBronze(goldToSilver(_playerInfo[winners[y]].amountBet)).safeDiv(winningPoolInBronze)).safeMul(prizeInBronze);
                    } else if (_playerInfo[winners[y]].amountClass == 1) {
                        winningAmount = (silverToBronze(_playerInfo[winners[y]].amountBet).safeDiv(winningPoolInBronze)).safeMul(prizeInBronze);
                    } else {
                        winningAmount = (_playerInfo[winners[y]].amountBet.safeDiv(winningPoolInBronze)).safeMul(prizeInBronze);
                    }

                    _balances[winners[y]][0] = _balances[winners[y]][0].safeAdd(winningAmount);
                    _balances[winners[y]][_playerInfo[winners[y]].amountClass] = _balances[winners[y]][_playerInfo[winners[y]].amountClass].safeAdd(_playerInfo[winners[y]].amountBet);
                }
            }
        } else {
            _supplies[0] = _supplies[0].safeSub(prizeInBronze);
        }

        _resetBetData();
    }

    function bet(uint8 _number, uint256 _value, uint256 _betClass) public {
        require(!playerAlreadyBet(msg.sender));  // player cannot bet on the same category twice
        require(_value > 0);
        require(_betClass >= 0 && _betClass <= 2);  // Currency class can only be 0-2
        require(_number >= 1 && _number <= 5);  // only numbers 1-5 can be numberSelected

        _balances[msg.sender][_betClass] = _balances[msg.sender][_betClass].safeSub(_value);
        _playerInfo[msg.sender] = Player(_value, _betClass, _number);
        players.push(msg.sender);
        _bets[0][_betClass] = _bets[0][_betClass].safeAdd(_value);
        _bets[_number][_betClass] = _bets[_number][_betClass].safeAdd(_value);
        betCount++;

        if (betCount == BET_COUNT_LIMIT) _rewardWinners();
    }

    function buyCoin(uint256 _value, uint256 _buyingClass) public payable {
        require(_value > 0);
        require(_buyingClass >= 0 && _buyingClass <= 2);  // Currency class can only be 0-2

        uint256 _multiplier = 0.01 ether;
        if (_buyingClass == 1) {
            _multiplier = 0.05 ether;
        } else if (_buyingClass == 2) {
            _multiplier = 0.1 ether;
        }
        uint256 _shouldPay = _multiplier * _value;
        require(msg.value >= _shouldPay);

        if (msg.value > _shouldPay) {
            msg.sender.transfer(_shouldPay-msg.value);
        }

        _balances[msg.sender][_buyingClass] = _balances[msg.sender][_buyingClass].safeAdd(_value);
        _supplies[_buyingClass] = _supplies[_buyingClass].safeAdd(_value);
    }

    function cashOut(uint256 _value, uint256 _coinClass) public {
        require(_value > 0);
        require(_coinClass >= 0 && _coinClass <= 2);  // Currency class can only be 0-2

        _balances[msg.sender][_coinClass] = _balances[msg.sender][_coinClass].safeAdd(_value);
        _supplies[_coinClass] = _supplies[_coinClass].safeAdd(_value);
    }

    function totalBet() public view returns (uint256, uint256, uint256) {
        return (_bets[0][0], _bets[0][1], _bets[0][2]);
    }

    function dillutedTotalBet() public view returns (uint256) {
        return fullyDilute(_bets[0][0], _bets[0][1], _bets[0][2]);
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
