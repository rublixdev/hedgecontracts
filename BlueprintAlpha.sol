//Rublix Bluprint Factory
//version 3.0
//author Adrian Radulescu
//updated May 29, 2018
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
pragma solidity ^0.4.23;

//-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
library SafeMath {
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;}
        uint256 c = a * b;
        assert(c / a == b);
        return c;}
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a / b;
        return c;}
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);
        return a - b;}
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        assert(c >= a);
        return c;}
}
//-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
contract ERC20Basic {
    uint256 public totalSupply;
    function balanceOf(address who) public constant returns (uint256);
    function transfer(address to, uint256 value) public returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
}
//-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
contract BasicToken is ERC20Basic {
    using SafeMath for uint256;
    mapping(address => uint256) balances;

    function transfer(address _to, uint256 _value) public returns (bool) {
        require(_to != address(0));
        require(_value <= balances[msg.sender]);
        
        balances[msg.sender] = balances[msg.sender].sub(_value);
        balances[_to] = balances[_to].add(_value);
        
        emit Transfer(msg.sender, _to, _value);
        return true;}
    
    function balanceOf(address _owner) public constant returns (uint256 balance) {
        return balances[_owner];}
}
//-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
contract ERC20 is ERC20Basic {
    function allowance(address owner, address spender) public constant returns (uint256);
    function transferFrom(address from, address to, uint256 value) public returns (bool);
    function approve(address spender, uint256 value) public returns (bool);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}
//-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
contract StandardToken is ERC20, BasicToken {
    mapping (address => mapping (address => uint256)) allowed;

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
        require(_to != address(0));
        require(_value <= balances[_from]);
        require(_value <= allowed[_from][msg.sender]);
    
        balances[_from] = balances[_from].sub(_value);
        balances[_to] = balances[_to].add(_value);
        allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
        emit Transfer(_from, _to, _value);
        return true;}
  
    function approve(address _spender, uint256 _value) public returns (bool) {
        allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;}

    function allowance(address _owner, address _spender) public constant returns (uint256 remaining) {
        return allowed[_owner][_spender];}

    function increaseApproval (address _spender, uint _addedValue) public returns (bool success) {
        allowed[msg.sender][_spender] = allowed[msg.sender][_spender].add(_addedValue);
        emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
        return true;}
        
    function decreaseApproval (address _spender, uint _subtractedValue) public returns (bool success) {
        uint oldValue = allowed[msg.sender][_spender];
        
        if (_subtractedValue > oldValue) {
            allowed[msg.sender][_spender] = 0;} 
        else {
            allowed[msg.sender][_spender] = oldValue.sub(_subtractedValue);}
        
        emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
        return true;}
}
//-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
contract RublixToken is StandardToken {

    string public name;
    string public symbol;
    uint256 public decimals = 18;
    address public creator;
     
    event Burn(address indexed from, uint256 value);

    constructor (uint256 initialSupply, address _creator) public {
        require (msg.sender == _creator);
            
        creator=_creator;
        balances[msg.sender] = initialSupply * 10**decimals;
        totalSupply = initialSupply * 10**decimals;                        
        name = "Rublix";                                          
        symbol = "RBLX";
        
        emit Transfer(0x0, msg.sender, totalSupply);}

    function transferMulti(address[] _to, uint256[] _value) public returns (bool success) {
        require (_value.length==_to.length);
                 
        for(uint256 i = 0; i < _to.length; i++) {
            require (balances[msg.sender] >= _value[i]); 
            require (_to[i] != 0x0);       
            super.transfer(_to[i], _value[i]);}
            
        return true;}

    function burnFrom(uint256 _value) public returns (bool success) {
        require(balances[msg.sender] >= _value); 
        require (msg.sender == creator);
    
        address burner = msg.sender;
       
        balances[msg.sender] -= _value;                
        totalSupply -= _value; 
        emit Transfer(burner, address(0), _value);
        emit Burn(burner, _value);
       
        return true;}
}
//-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
contract Blueprint {

    RublixToken private rblxToken;

    address public source;

    uint256 public internalFee;
    uint256 public purchaseStake;
    uint256 public rblxShortPool;

    uint64 public maxNoOfShorts;

    string public ticker;

    uint public expirationTimestamp;
    uint public creationTimestamp;

    uint256 public margin;    

    struct creatorStake {
        address userAddress;
        uint256 rblxStaked;
        uint256 rblxReturned;
    }
    creatorStake public creator;

    struct buyerStake {
        address userAddress;
        uint256 rblxStaked;
        uint256 rblxReturned;
        uint256 rblxShorted;
    }
    mapping (uint64 => buyerStake) public buyers;
    mapping (address => uint64) public buyerID;
    uint64 public noOfBuyers;

    struct predictionState {
        bool entryLevelMet;
        bool exitLevelMet;
        bool sequenceCorrect;
        bool confirmed;
    }
    predictionState public state;

    struct predictionPrices {
        uint256 entryPrice;
        uint256 exitPrice;
    }
    predictionPrices internal prediction;  

    struct pricePoint {
        uint256 value;
        uint timestamp;
    }
    pricePoint public entryPrice_actual;
    pricePoint public exitPrice_actual;

    event blueprintResolved(bool predictionCorrect);

    constructor (

            address _creatorAddress,
            uint256 _purchaseStake,
            uint256 _internalFee,
            uint64 _maxShortPositions,
            uint256 _creationStake,
            string _ticker,
            uint256 _entryTkrPrice,
            uint256 _exitTkrPrice,
            uint _expirationTimestamp,
            RublixToken _rblxToken) public {


        require (_entryTkrPrice != _exitTkrPrice);
        require (_expirationTimestamp > now);


        source = msg.sender;
        rblxToken = _rblxToken;

        internalFee = _internalFee;
        purchaseStake = _purchaseStake;

        creator.userAddress = _creatorAddress; 
        creator.rblxStaked = _creationStake;

        ticker = _ticker;

        expirationTimestamp = _expirationTimestamp;
        creationTimestamp = now;

        prediction.entryPrice = _entryTkrPrice;
        prediction.exitPrice = _exitTkrPrice;

 
        if (_exitTkrPrice > _entryTkrPrice) {
            margin = (100*(_exitTkrPrice-_entryTkrPrice))/_entryTkrPrice;
        } else {
            margin = (100*(_entryTkrPrice-_exitTkrPrice))/_entryTkrPrice;
        }

        maxNoOfShorts = _maxShortPositions;
        rblxShortPool = _creationStake - ((uint256(maxNoOfShorts)*purchaseStake) + internalFee);

    }


    function addBuyer (address _userAddress) public returns (uint256 entry, uint256 exit) {
        
        require (msg.sender == source);
        require (buyerID[_userAddress] == 0);
        require (state.confirmed == false);
        require (expirationTimestamp > now);
        require (_userAddress != creator.userAddress);

        noOfBuyers += 1;
        buyerID[_userAddress] = noOfBuyers;

        buyers[noOfBuyers].userAddress = _userAddress;
        buyers[noOfBuyers].rblxStaked = purchaseStake;

        if (noOfBuyers <= maxNoOfShorts) {
            buyers[noOfBuyers].rblxShorted = purchaseStake;
        }

        return (prediction.entryPrice, prediction.exitPrice);
    }


    function shortBlueprint (address _userAddress, uint256 _rblxShort) external {

        uint64 ID_ = buyerID[_userAddress];

        require (msg.sender == source);
        require (ID_ != 0);
        require (ID_ <= maxNoOfShorts);
        require (expirationTimestamp > now);
        require (state.confirmed == false);
        require (rblxShortPool >= _rblxShort);

        rblxShortPool -= _rblxShort;
        buyers[ID_].rblxShorted += _rblxShort;

    }

    function verifyPrediction (
            uint256 _high, 
            uint _highTime,
            uint256 _low, 
            uint _lowTime) external returns (
            bool entryMet,
            bool exitMet,
            bool correctOrder,
            bool resolved) {

        require (msg.sender == source);
        require (state.confirmed == false);
        require (_highTime > creationTimestamp);
        require (_lowTime > creationTimestamp);
        require (expirationTimestamp > _highTime);
        require (expirationTimestamp > _lowTime);


        if ((_high == 0) && (_low == 0) && (now > expirationTimestamp)) {           
            confirmState(false);
        } else if (prediction.exitPrice > prediction.entryPrice) {

            if (_highTime > _lowTime) { 
                state.sequenceCorrect = true; 
            }
            if(prediction.entryPrice > _low) { 
                state.entryLevelMet = true; 
                entryPrice_actual = pricePoint(_low, _lowTime);
            }
            if(_high > prediction.exitPrice ) { 
                state.exitLevelMet = true; 
                exitPrice_actual = pricePoint(_high, _highTime);
            }

        } else {

            if (_lowTime > _highTime) { 
                state.sequenceCorrect = true; 
            }
            if(_high > prediction.entryPrice ) { 
                state.entryLevelMet = true; 
                entryPrice_actual = pricePoint(_high, _highTime);
            }
            if(prediction.exitPrice > _low) { 
                state.exitLevelMet = true; 
                exitPrice_actual =  pricePoint(_low, _lowTime);
            }

        }

        if ((state.entryLevelMet == true) && (state.exitLevelMet == true) && (state.sequenceCorrect == true)) {
            confirmState(true);
        }

        return (state.entryLevelMet, state.exitLevelMet, state.sequenceCorrect, state.confirmed);
    } 



    function confirmState(bool _predictionCorrect) internal {

        require (msg.sender == source);

        state.confirmed = true;
        rblxToken.transfer(source, internalFee);

        emit blueprintResolved(_predictionCorrect);

    }

    function resetState() external {

        require (msg.sender == source);

        state.entryLevelMet = false;
        state.exitLevelMet = false;
        state.sequenceCorrect = false;
        state.confirmed = false;

        entryPrice_actual = pricePoint(0, 0);
        exitPrice_actual =  pricePoint(0, 0);

    }

    function returnToBuyer ( address _userAddress) internal {

        uint64 ID_ = buyerID[_userAddress];

        require (ID_ !=  0); 
        require ((state.entryLevelMet == false) || (state.exitLevelMet == false) || (state.sequenceCorrect == false));
        require (state.confirmed == true);
        require (buyers[ID_].rblxReturned == 0);

        buyers[ID_].rblxReturned = buyers[ID_].rblxStaked + buyers[ID_].rblxShorted;
        rblxToken.transfer(_userAddress, buyers[ID_].rblxReturned);
    }

    function returnToCreator (address _userAddress) internal {

        require (_userAddress == creator.userAddress);
        require (state.entryLevelMet == true); 
        require (state.exitLevelMet == true);
        require (state.sequenceCorrect == true);
        require (state.confirmed == true);
        require (creator.rblxReturned == 0);
        
        creator.rblxReturned = rblxToken.balanceOf(this);
        rblxToken.transfer(_userAddress, creator.rblxReturned );
    }

    function returnToSource() internal {  
   
        require (msg.sender == source);
        require (now > expirationTimestamp);
        
        rblxToken.transfer(source, rblxToken.balanceOf(this));
    }


    function claimTokens (address _userAddress) external {
        
        require (msg.sender == source);

        if (_userAddress == source) {
            returnToSource();
        } else if (_userAddress == creator.userAddress) {
            returnToCreator(_userAddress);
        } else {
            returnToBuyer(_userAddress);
        }
    }
}


contract BlueprintFactory {

    RublixToken public rblxToken;
    uint constant TOKEN_DECIMALS = 10**18;

    address public oracle;
    address public admin;

    uint256 public purchaseStake;
    uint256 public minCreationStake;
    uint256 public maxCreationStake;
    uint256 public internalFee;
    uint256 public verificationFee;

    uint public minHorizon;

    uint64 public maxShortPositions;

    struct userMeta{
        address userAddress;
        bool userVerified;
        uint64 noOfBlueprintsCreated;
        uint64 noOfBlueprintsPurchased;
        uint64 noOfBlueprintsShorted;
    }
    mapping (uint64 => userMeta) public users;
    uint64 public noOfUsers;
    mapping (address => uint64) public userID;

    struct blueprintMeta{
        address contractAddress;
        bool active;
        bool correct;
        bool verificationPrompted;
    }
    mapping (uint64 => blueprintMeta) public blueprints;
    uint64 public noOfBlueprints;
    mapping (address => uint64) public blueprintID;

    mapping (uint64 => mapping (uint64 => uint64)) public blueprintsPurchasedbyUser;
    mapping (uint64 => mapping (uint64 => uint64)) public blueprintsCreatedByUser;
    mapping (uint64 => mapping (uint64 => uint64)) public blueprintsShortedByUser;
    
    struct predictionPrices {
        uint256 entryPrice;
        uint256 exitPrice;
    }
    mapping (uint64 => mapping (uint64 => predictionPrices)) public predictionsAvailableToUser;

    event BlueprintCreated (uint64 blueprintID);
    event VerificationPrompted (uint64 blueprintID);
    event BlueprintResolved (uint64 blueprintID);    

    constructor (
            address _rblxTokenAddress,
            address _rblxOracleAddress) public {

        rblxToken =  RublixToken(_rblxTokenAddress);

        admin = msg.sender;
        oracle = _rblxOracleAddress;

        internalFee = 1 * TOKEN_DECIMALS;
        verificationFee = 1 * TOKEN_DECIMALS;
        purchaseStake = 1 * TOKEN_DECIMALS;

        maxShortPositions = 9;

        setMinCreationStake();

    }

    function createBlueprint (
            uint256 _stake,
            string _ticker,
            uint256 _entryTkrPrice,
            uint256 _exitTkrPrice,
            uint _expirationTimestamp) public payable {


        uint256 creationStake_ = _stake * TOKEN_DECIMALS;
        uint64 ID_ = userID[msg.sender];

        require (users[ID_].userVerified == true);
        require (_entryTkrPrice != _exitTkrPrice);
        require (_expirationTimestamp >= now + minHorizon);
        require (creationStake_ >= minCreationStake);

        noOfBlueprints += 1;

        Blueprint blueprint_ = new Blueprint(
            msg.sender,
            purchaseStake, 
            internalFee,
            maxShortPositions,
            creationStake_,
            _ticker,
            _entryTkrPrice,
            _exitTkrPrice,
            _expirationTimestamp,
            rblxToken);

        rblxToken.transferFrom(msg.sender, address(blueprint_), creationStake_ );

        blueprintID[address(blueprint_)] = noOfBlueprints;

        blueprints[noOfBlueprints].contractAddress = address(blueprint_);
        blueprints[noOfBlueprints].active = true;

        users[ID_].noOfBlueprintsCreated += 1;
        uint64 count_ = users[ID_].noOfBlueprintsCreated;
        blueprintsCreatedByUser[ID_][count_] = noOfBlueprints;

        predictionsAvailableToUser[ID_][noOfBlueprints].entryPrice = _entryTkrPrice;
        predictionsAvailableToUser[ID_][noOfBlueprints].exitPrice = _exitTkrPrice;

        emit BlueprintCreated(noOfBlueprints);
    }


    function purchaseBlueprint (uint64 _blueprintID) public payable {
        
        uint64 ID_ = userID[msg.sender];
        address blueprintAddress_ = blueprints[_blueprintID].contractAddress;
        Blueprint blueprint_ = Blueprint(blueprintAddress_);
        uint256 entry_;
        uint256 exit_;

        require (users[ID_].userVerified == true);
        require (blueprints[_blueprintID].active == true);

        (entry_, exit_) = blueprint_.addBuyer(msg.sender);
        
        uint256 stake_ = blueprint_.purchaseStake();

        rblxToken.transferFrom(msg.sender, blueprintAddress_, stake_);

        users[ID_].noOfBlueprintsPurchased += 1;
        uint64 count_ = users[ID_].noOfBlueprintsPurchased;
        blueprintsPurchasedbyUser[ID_][count_] = _blueprintID;

        predictionsAvailableToUser[ID_][_blueprintID].entryPrice = entry_;
        predictionsAvailableToUser[ID_][_blueprintID].exitPrice = exit_;

    }

    function shortBlueprint (uint64 _blueprintID, uint256 _amountShort) public payable {
        
        uint64 ID_ = userID[msg.sender];
        address blueprintAddress_ = blueprints[_blueprintID].contractAddress;
        Blueprint blueprint_ = Blueprint(blueprintAddress_);
        uint256 stake_ = _amountShort*TOKEN_DECIMALS;

        require (users[ID_].userVerified == true);
        require (blueprints[_blueprintID].active == true);

        blueprint_.shortBlueprint(msg.sender, stake_);

        rblxToken.transferFrom(msg.sender, blueprintAddress_, stake_ );
         
        users[ID_].noOfBlueprintsShorted += 1;
        uint64 count_ = users[ID_].noOfBlueprintsShorted;
        blueprintsShortedByUser[ID_][count_] = _blueprintID;
    }

    function promptVerification (uint64 _blueprintID) public payable {

        require (users[userID[msg.sender]].userVerified == true);
        require (blueprints[_blueprintID].active == true);
        require (blueprints[_blueprintID].verificationPrompted == false);

        blueprints[_blueprintID].verificationPrompted = true;

        rblxToken.transferFrom(msg.sender, this, verificationFee);

        emit VerificationPrompted(_blueprintID);
    }

    function changePurchaseStake (uint256 _parameterValue) public {
        require (msg.sender == admin);
        purchaseStake = _parameterValue * TOKEN_DECIMALS;
        setMinCreationStake();
    }

    function changeInternalFee (uint256 _parameterValue) public {
        require (msg.sender == admin);
        internalFee = _parameterValue * TOKEN_DECIMALS;
        setMinCreationStake();
    }

    function changeVerificationFee (uint256 _parameterValue) public {
        require (msg.sender == admin);
        verificationFee = _parameterValue * TOKEN_DECIMALS;
     }

    function changeMinHorizon (uint _parameterValue) public {
        require (msg.sender == admin);
        minHorizon = _parameterValue;
    }

    function changeMaxShortPositions (uint64 _parameterValue) public {
        require (msg.sender == admin);
        maxShortPositions = _parameterValue;
        setMinCreationStake();
    }

    function changeOracleAddress (address _rblxOracleAddress) public {
        require (msg.sender == admin);
        oracle = _rblxOracleAddress;
    }

    function setMinCreationStake () internal {
        require (msg.sender == admin);
        minCreationStake = (uint256(maxShortPositions)*purchaseStake)+internalFee;
    }

    function userValidation (address[] _walletAddresses) public {
        require (msg.sender == admin);

        for(uint64 i = 0; i < _walletAddresses.length; i++ ) {
            require (userID[_walletAddresses[i]] == 0);

            noOfUsers += 1;
            userID[_walletAddresses[i]] = noOfUsers;
            users[noOfUsers].userAddress = _walletAddresses[i];
            users[noOfUsers].userVerified = true;
        }
    }   

    function userValidationRevoked (address _walletAddress) public {
        require (msg.sender == admin);
        require (userID[_walletAddress] > 0);
 
        users[userID[_walletAddress]].userVerified = false;
    }   

    function userRevalidation (address _walletAddress) public {
        require (msg.sender == admin);
        require (userID[_walletAddress] > 0);
 
        users[userID[_walletAddress]].userVerified = true;
    }



    function verifyBlueprint(
            uint64 _blueprintID, 
            uint256 _high, 
            uint _highTime,
            uint256 _low, 
            uint _lowTime) public {

        require (msg.sender == oracle);
        require (blueprints[_blueprintID].active == true);

        Blueprint blueprint_ =  Blueprint(blueprints[_blueprintID].contractAddress);

        bool entryMet_;
        bool exitMet_;
        bool correctOrder_;
        bool confirmed_;

        (entryMet_, exitMet_, correctOrder_, confirmed_) = blueprint_.verifyPrediction(_high, _highTime, _low, _lowTime);
 
        if (confirmed_ == true) {
            blueprints[_blueprintID].active = false;

            if ((entryMet_ == true) && (exitMet_== true) && (correctOrder_== true)){
                blueprints[_blueprintID].correct = true;
            } 
            
            emit BlueprintResolved(_blueprintID);
        }

        blueprints[_blueprintID].verificationPrompted = false;
    }

    function resetBlueprint(uint64 _blueprintID) public {

        require (msg.sender == oracle);
        require (blueprints[_blueprintID].active == false);

        address blueprintAddress_ = blueprints[_blueprintID].contractAddress;
        Blueprint blueprint_ =  Blueprint(blueprintAddress_);
        uint256 internalFee_ = blueprint_.internalFee();


        blueprints[_blueprintID].active = true;
        blueprints[_blueprintID].correct = false;

        rblxToken.transferFrom(msg.sender, blueprintAddress_, internalFee_);

        blueprint_.resetState();

    }

    function claimTokens (uint64 _blueprintID) public {
        
        uint64 ID_ = userID[msg.sender];

        require (users[ID_].userVerified == true);
        require (blueprints[_blueprintID].active == false);

        Blueprint blueprint_ =  Blueprint(blueprints[_blueprintID].contractAddress);

        if (msg.sender == admin) {

            if(_blueprintID == 0) {
                rblxToken.transfer(admin, rblxToken.balanceOf(this));
            } else {
                blueprint_.claimTokens(this);
            }
            
        } else {
            blueprint_.claimTokens(msg.sender);
        }
    }


}
