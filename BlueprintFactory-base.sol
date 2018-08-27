pragma solidity ^0.4.23;

contract Blueprint {

    uint256 public entryPrice;
    uint256 public exitPrice;
    uint256 public expirationTimestamp;

    constructor (uint256 _entryPrice,
        uint256 _exitPrice,
        uint _expirationTimestamp) public {

        expirationTimestamp = _expirationTimestamp;QW
        entryPrice = _entryPrice;
        exitPrice = _exitPrice;
    }
}

contract BlueprintFactory {

    uint64 public noOfBlueprints;

    mapping (address => uint64) public blueprintID;
    mapping (address => address) public blueprintCreator;
    mapping (address => string) public blueprintTradingPair;
    mapping (address => string) public blueprintExchange;

    event BlueprintCreated (address blueprintAddress);

    constructor () public {
        noOfBlueprints = 0;
    }

    function createBlueprint (
        string _trading_pair,
        string _exchage,
        uint256 _entryTkrPrice,
        uint256 _exitTkrPrice,
        uint _expirationTimestamp) public payable {

        Blueprint blueprint_ = new Blueprint(
            _entryTkrPrice,
            _exitTkrPrice,
            _expirationTimestamp
            );

        noOfBlueprints += 1;

        blueprintID[address(blueprint_)] = noOfBlueprints;
        blueprintCreator[address(blueprint_)] = msg.sender;
        blueprintTradingPair[address(blueprint_)] = _trading_pair;
        blueprintExchange[address(blueprint_)] = _exchage;

        emit BlueprintCreated(address(blueprint_));
    }
}
