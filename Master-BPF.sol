pragma solidity ^0.4.22;

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

contract Blueprint {

    //passed in from BlueprintFactory, these parameters can't be changed once blueprint is deployed, even if admin changes these parameters in BlueprintFactory
    uint256 public creatorID;
    uint256 public blueprintID;
    address public oracleAddress;
    uint256 public purchasePrice;
    uint256 public creationPrice;
    RublixToken public rblxToken;

    //generated in BlueprintFactory from transaction submitted by creator
    address public source; //BlueprintFactory address 
    address public creatorAddress;
    uint public creationTimestamp;
    
    //specified by creator when submitting transaction 
    string public ticker;
    uint256 internal entryTkrPrice;
    uint256 internal exitTkrPrice;
    uint public expirationTimestamp;
    
    //states calculated internally
    enum predictionStates{unconfirmed, entryMet, confirmedTrue, confirmedFalse}
    predictionStates predictionState;

    //determine if the blueprint is taking a short position or long position on the specified ticker
    bool internal short;

    //only the oracle address that was specified by the BlueprintFactory can set these values
    uint256 internal periodHigh;
    uint internal highTimestamp;
    uint256 internal periodLow;
    uint internal lowTimestamp;
    //NOTE*: these can be used to gauge how close a blueprint actually was to being true

    //define class of buyers and map it addresses to quickly verify buyer stakes and refunds, as well as their chronological spot in buyer lineup for this blueprint
    struct buyer {
        address buyerAddress;
        uint256 amountStaked;
        uint256 amountRefunded;
    }

    //access buyers by buyerID 
    mapping (uint256 => buyer) public buyers;

    //access buyer ID from an address
    mapping (address => uint256) public buyerID;
    
    //keeps track of total number of buyers of this blueprint
    uint256 public lastBuyerID;

    //can specify the number of buyers that get a fraction of the creationPrice staked by the creator if the blueprint is confirmedFalse
    uint256 constant N_SHORT_POSITIONS = 10;
        //if a buyer is one of the first to purchase this prediction and the prediction is determined to be false, they get a bonus refunded to them
    uint256 private buyerShortReward; 
    //actual prices of asset during active time period to determine if prediction is true or not

    //temp variables
    uint256 buyerID_;
    uint256 refund_;

    //event that is emitted when prediction move from one state and into a new one
    //both old and new states are emitted in order to allow for verification of blueprint authenticity 
    event StateChange(predictionStates Previous, predictionStates New);
    event RefundClaimed(address receipiant, address blueprint, uint256 amountRefunded);
    event BlueprintEmptied(address blueprint, uint256 amount);
        
    constructor (address _creatorAddress,
            uint256 _creatorID,
            uint256 _blueprintID,
            uint256 _purchasePrice,
            uint256 _creationPrice,
            string _ticker,
            uint256 _entryTkrPrice,
            uint256 _exitTkrPrice,
            uint _creationTimestamp,
            uint _expirationTimestamp,
            address _oracleAddress,
            RublixToken _rblxToken) public {

        //can't make a prediction of a 0% market move
        require (_entryTkrPrice != _exitTkrPrice);
        //can't make a prediction of previous market activity
        require (_expirationTimestamp > now);
        //NOTE1: these checks are performed in BlueprintFactory when createBlueprint function is called, so this might just be redundant with no upside
        
        //passed in by BlueprintFactory 
        creationTimestamp = _creationTimestamp;
        source = msg.sender;
        creatorAddress =  _creatorAddress; 
        creatorID = _creatorID;
        blueprintID = _blueprintID;
        //the only address that can confirm a prediction state change and transfer RBLX to creator if true
        oracleAddress = _oracleAddress;
        //amount of RBLX required to have created the blueprint and to view it
        purchasePrice = _purchasePrice;
        creationPrice = _creationPrice;
        //token that is utilized for this blueprint market
        rblxToken = _rblxToken;

        //calculate the reward a buyer gets if they are among the first to buy it and the blueprint is confirmedFalse
        buyerShortReward = _creationPrice/N_SHORT_POSITIONS;
        
        //passed in directly by creator
        ticker = _ticker;
        entryTkrPrice = _entryTkrPrice;
        exitTkrPrice = _exitTkrPrice;
        expirationTimestamp = _expirationTimestamp;
        
        //iniate blueprint internal states
        predictionState = predictionStates.unconfirmed;
        lastBuyerID = 0;

        //determine if the blueprint is taking a short or long position on the ticker
        if (_exitTkrPrice > _entryTkrPrice) {
            short = false;
        } else {
            short = true;
        }
    }

    function addBuyer (address _buyerAddress) public {
        
        //temp ID variable
        buyerID_ = lastBuyerID + 1;
        //buyers are recorded for refund-claiming and viewing access only if they buy the blueprint through BlueprintFactory
        require (msg.sender == source);
        //can't by purchase blueprint if it expired, see NOTE1 for similar redudancy issue
        require (expirationTimestamp > now);
        //buyer can only purchase blueprint once
        require (buyers[buyerID_].amountStaked == 0);
   
        //record how much was paid and initalize refund amount to 0
        buyers[buyerID_].buyerAddress = _buyerAddress;
        buyers[buyerID_].amountStaked = purchasePrice;
        buyers[buyerID_].amountRefunded = 0;
        
        //keep track of each address's id number     
        buyerID[_buyerAddress] = buyerID_;
        
        lastBuyerID = buyerID_;
    }

    function refundPurchase () public {
        //temp ID variable
        buyerID_ = lastBuyerID + 1;
        
        //refunds can only be claimed after oracle address has determine that the blueprint has expired and did not meet entryTkrPrice and/or exitTkrPrice
        require (predictionState == predictionStates.confirmedFalse);
        //check if msg.sender has bought the blueprint through BlueprintFactory
        require (buyers[buyerID_].amountStaked != 0);
        //check that the msg.sender has not obtained a refund already
        require (buyers[buyerID_].amountRefunded == 0);

        //base refund amount for the msg.sender, equal to the amount they bought the blueprint for
        refund_ = buyers[buyerID_].amountStaked;
        
        //if the buyer was one of the first N to buy the prediction and it didn't come true, they can receive a bonus paid from the amount staked by the creator
        if (buyerID_ <= N_SHORT_POSITIONS) {
            refund_ += buyerShortReward;
        }
        
        //record how much the buyer was able to refund...
        buyers[buyerID_].amountRefunded = refund_;
        //...then transfer those tokens to buyer
        rblxToken.transfer(msg.sender, refund_);

        emit RefundClaimed(msg.sender, this, refund_);
    }

    function viewPrediction () public returns (uint256 entryTkrPrice_, uint256 exitTkrPrice_) {
                
        buyerID_ = buyerID[msg.sender];
        //the msg.sender must have staked RBLX tokens through BlueprintFactory in order to call this function, OR
        //the expiration has passed (similarly to NOTE1, an if statement might be a better alternative the require statement to check expiration date), OR
        //the blueprint was verified to be true before it expired
        require ((buyers[buyerID_].amountStaked != 0) || (now > expirationTimestamp) || (predictionState == predictionStates.confirmedTrue));
        
        //entryTkrPrice and exitTkrPrice are set as internal variables in this contract, readily accessible only through this function
        return (entryTkrPrice, exitTkrPrice);
    }

    //ORACLE ONLY FUNCTIONS BELOW------------------------------------------------------------------------------------------------------
    function confirmPrediction (uint256 _periodHigh, 
            uint _highTimestamp, 
            uint256 _periodLow, 
            uint _lowTimestamp) public {

        //check if specified oracle is msg.sender 
        require (msg.sender == oracleAddress);

        //make sure states can't be updated after a blueprint is confirmed to be true or false
        require (predictionState != predictionStates.confirmedTrue);
        require (predictionState != predictionStates.confirmedFalse);
        
        //double checking to sure the numbers provided by oracle are within the contracts active periods
        require (expirationTimestamp > _highTimestamp);
        require (expirationTimestamp > _lowTimestamp);
        require (_highTimestamp > creationTimestamp);
        require (_lowTimestamp > creationTimestamp);


        //if the state is unconfirmed, check if the entryTkrPrice was met
        if (predictionState == predictionStates.unconfirmed) {
            //record the price point that potentially meets entryTkrPrice
            if (short == false) {
                periodLow = _periodLow;
                lowTimestamp = _lowTimestamp;
            } else {
                periodHigh = _periodHigh;
                highTimestamp = _highTimestamp;
            }
            //check if the price point does in fact meet the entryTkrPrice
            checkEntry(_periodHigh, _periodLow);
        }
        
        //if the entryTkrPrice was met, check if the exitTkrPrice was met /after/ the entryTkrPrice was met
        if (predictionState == predictionStates.entryMet) {
            //record the price point that potentially meets exitTkrPrice...
            //only if the corresponding timestamp is greater then the timestamp corresponding to price event that where entryTkrPrice was met
            if ((short == false) && (_highTimestamp > lowTimestamp)) {
                periodHigh = _periodHigh;
                highTimestamp = _highTimestamp;
            } else if ((short == true) && (_lowTimestamp > highTimestamp)) {
                periodHigh = _periodHigh;
                highTimestamp = _highTimestamp;
            } else {
                //return before checking if exitTkrPrice is met if the timestamps are not in the proper order 
                return;
            }

            //check if the price point does in fact meet the exitTkrPrice
            //only if the corresponding timestamps are in the right order as specified above
            checkExit(_periodHigh, _periodLow);
        }
        
        //if the exitTkrPrice was met after the entryTkrPrice was met, then transfer all staked RBLX tokens to creator
        //this if statement can only ever be ran once since after exiting the function with a confirmed prediction state, the function can't be called again
        if (predictionState == predictionStates.confirmedTrue) {
            rblxToken.transfer(creatorAddress, rblxToken.balanceOf(this));
        }
        //if expiration time has passed and the contract is still not confirmed to be true by the functions above, then declare the prediction is confirmedFalse
        if ((now > expirationTimestamp) && (predictionState != predictionStates.confirmedTrue)){
            emit StateChange(predictionState, predictionStates.confirmedFalse);
            predictionState = predictionStates.confirmedFalse;
        }
    }
    
    //internal function that can be called only by the confirmedPrediction function
    function checkEntry (uint256 _periodHigh, uint256 _periodLow) internal {

        //double check that the predictionState is still unconfirmed, 
        require (predictionState == predictionStates.unconfirmed);
        //NOTE2: this might just be redundant with no upside, already check in confirmedPrediction function
        
        //if the blueprint is taking a long position, check if the low is below entryTkrPrice, OR 
        //if the blueprint is taking a short position, check if the high is above the entryTkrPrice
        if (((!short) && (entryTkrPrice >= _periodLow)) || ((short == true) && (_periodHigh >= entryTkrPrice))) {
            
            //change states from previous state (should be unconfirmed) to entryMet, create an event with previous and new states
            emit StateChange(predictionState, predictionStates.entryMet);
            predictionState = predictionStates.entryMet;
        } 
    }
    
    //internal function that can be called only by the confirmedPrediction function
    function checkExit (uint256 _periodHigh, uint256 _periodLow) internal {
        
        //double check that the prediction has met entryTkrPrice but hasn't been verified if exitTkrPrice was met
        require (predictionState == predictionStates.entryMet);
        //see NOTE2 for similar potential redudancy issue
        
        //if the blueprint is taking a long position, check if the high is above exitTkrPrice, OR 
        //if the blueprint is taking a short position, check if the low is below the exitTkrPrice
        if (((short == false) && (_periodHigh >= exitTkrPrice)) || ((short == true) && (exitTkrPrice >= _periodLow))) {

            //change states from previous state (should be entryMet) to confirmedTrue (both entry and exit are met)
            //create an event with previous and new states
            emit StateChange(predictionState, predictionStates.confirmedTrue);
            predictionState = predictionStates.entryMet;
        }
    }


    //this function should be called after blueprint expired for a while to allow buyers to refund their purchases
    function emptyUnclaimedTokens() public {     
        require (msg.sender == oracleAddress);
        //make sure the blueprint expired
        require (now > expirationTimestamp);
        //NOTE3: can add a buffer for refunding purchases by using: require(now > (expirationTimestamp + mult((expirationTimestamp-now),PERCENT_OF_ACTIVE_PERIOD_AS_REFUND_BUFFER)))
        
        //transfer all remaining tokens in blueprint contract to oracle address
        emit BlueprintEmptied(this, rblxToken.balanceOf(this));
        rblxToken.transfer(oracleAddress, rblxToken.balanceOf(this));
    }
}
//-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

contract BlueprintFactory {

    //admin can change blueprint purchase price, blueprint creation price, and add update valid userID-walletAddress list
    address public admin;
    //oracle is only address that can update the prediction status of a blueprint and empty it out from unclaimed tokens
    address public rblxOracleAddress;

    //set at creation but can be changed by admin 
    uint256 public creationPrice;
    uint256 public purchasePrice;
    RublixToken public rblxToken;

    //internal counters that start at 0 increments before a new ID is assigned (ie the first ID will be 1, second ID will be 2, etc.)
    //also keeps track of number of created blueprints and validated users 
    uint256 internal lastBlueprintID;
    uint256 internal lastUserID;
  
    //structure used in blueprint structure to keep track of the creator and buyers of the blueprint and how much they have/had staked in that particular blueprint
    struct userStk{
        uint256 userID;
        address userAddress;
        uint256 amountStaked;
    }

    //BlueprintFactory stores meta-data of each blueprint it creates, but not the actual predicted values    
    struct blueprint{
        
        address blueprintAddress;
        
        //set by BlueprintFactory
        uint creationTimestamp;
        address oracle; 
        //NOTE4: once oracle is defined for a blueprint, only that address can transfer RBLX out of contract, even if rblxOracleAddress is changed in BlueprintFactory
        
        //set by creator
        string ticker;
        uint expirationTimestamp;
 
        //each blueprint has one creator with userAddress, userID, and amountStaked
        //this role and ownership cannot transfer to another user after being initalized 
        userStk creator;
        
        //internal counter that starts at 0 and increments before a new ID is assigned
        uint256 lastBuyerID;
        //NOTE5: purchases (and creations) of blueprints occurs exclusivly through the BlueprintFactory contract
        //NOTE5: withdrawls, refunds, and deposits occur directly from interacting with the blueprint contract itself 
        //NOTE5: therefore BlueprintFactory doesn't keep track of those occurances directly

        //map buyers by a buyerID unique to each blueprint, buyerID also keeps track of the sequential order in which each buyer purchases the blueprint
        mapping (uint256 => userStk) buyers;
    }

    //array of blueprints referenced by blueprintID 
    //this allows a third party to query all blueprints without prior knowledge of blueprint addresses 
    mapping (uint256 => blueprint) HedgeBlueprint;

    //BlueprintFactory stores meta-data of each user that is validated for ranking purposes, but not the actual performance of their blueprints directly, see NOTE5 for clarifications
    struct user{
        address userAddress;
        
        //track total amount of RBLX spent on hedge platform, as well as number of blueprints created and purchased
        uint256 totalAmountSpent;
        uint256 noOfBlueprintsCreated;
        uint256 noOfBlueprintsPurchased;
    }

    //array of users referenced by userID
    //this allows a third party to query all blueprints without prior knowledge of user addresses
    mapping(uint256 => user) HedgeUser;

    //allow a reverse lookup on ID from address
    mapping (address => uint256) public userID;
    mapping (address => uint256) public blueprintID;
    
    //temp variables
    uint256 creatorUserID_;
    uint256 buyerUserID_;
    uint256 blueprintID_;
    uint256 buyerID_;
    uint256 userID_;
    //events emitted every time a creation or purchase is made, ie any time a transfer of RBLX into a blueprint is made
    //events to indicate prediction resolution, expiration, or refund of a blueprint have to exist in the blueprint contract itself, see NOTE5 for clarifications
    event BlueprintCreated(address creator, address blueprint);
    event BlueprintPurchased(address buyer, address blueprint);
    
    constructor (address _rblxTokenAddress,
            address _rblxOracleAddress, 
            uint256 _creationPrice, 
            uint256 _purchasePrice) public {

        //admin account is creator of BlueprintFactory, currently there is no functionality for transfer of ownership
        admin = msg.sender;
        //NOTE6: possible upside of functionality doesn't really justify possible security concerns over transfering ownership of admin role   

        //specify deployed/minted token, this can be hard coded after we determine which network we're deploying on
        rblxToken =  RublixToken(_rblxTokenAddress);

        //specify the only account that can resolve blueprint prediction states and transfer RBLX tokens from a blueprint contract to buyer, creator, or fee collection 
        //admin can change address of oracle to be used for blueprints created thereafter, see NOTE5 for clarifications
        rblxOracleAddress = _rblxOracleAddress;

        //admin can change these values after being BlueprintFactory is deployed, but will only affect blueprints created after the change, see ntoe5 for clarifications
        purchasePrice = _purchasePrice;
        creationPrice = _creationPrice;
        //NOTE7: currently these prices are fixed, but in near future, there will be a degree of flexibility to price amount to account for creator rank, no of buyers, etc.

        //initialize blueprintID and userID
        lastBlueprintID = 0;
        lastUserID = 0;
    }

    //function called by user that wants to create a contract, however the user must be validated by admin before they can call this function
    //the user must have also approved BlueprintFactory for spending RBLX on their behalf of an amount greater than the cost of creating a blueprint
    function createBlueprint (string _ticker,
            uint256 _entryTkrPrice,
            uint256 _exitTkrPrice,
            uint _expirationTimestamp) public payable {

        //can't create a blueprint that predicts a 0% market shift
        require (_entryTkrPrice != _exitTkrPrice);
        //can't create a blueprint that predicts prior market activity 
        require (_expirationTimestamp > now);
        //can't create a blueprint if creator has not been validated by admin
        require (userID[msg.sender] > 0);
        //NOTE8: admin can revoke this validation, which reverses the sign of their ID 
        //NOTE8: this is to allow easy tracking of unvalidated user activity while they were active and to allow admin to easily revalidate the user with their original ID
        //NOTE8: ex. if previous userID is 5, after unvalidation, their userID becomes -5, and after revalidation, their userID is reset to 5
        
        //temp ID variables
        creatorUserID_ = userID[msg.sender];
        blueprintID_ = lastBlueprintID + 1;

        //a new instance of a blueprint contract (code specified above) is created with parameters passed in by both user and by BlueprintFactory
        Blueprint blueprint_ = new Blueprint(msg.sender,
            creatorUserID_,
            blueprintID_,
            purchasePrice,
            creationPrice,
            _ticker,
            _entryTkrPrice,
            _exitTkrPrice,
            now,
            _expirationTimestamp,
            rblxOracleAddress,
            rblxToken);
        
        //transfer tokens from creator address to the contract they just created, 
        rblxToken.transferFrom(msg.sender, address(blueprint_), creationPrice);
        //NOTE9:this requires the creator to approve spending by BlueprintFactory on their behalf before creating (or purchasing) anything on Hedge

        //update metadata of user list
        HedgeUser[creatorUserID_].totalAmountSpent += creationPrice;
        HedgeUser[creatorUserID_].noOfBlueprintsCreated += 1;

        //update metadata of blueprint list
        HedgeBlueprint[blueprintID_].ticker = _ticker;
        HedgeBlueprint[blueprintID_].expirationTimestamp = _expirationTimestamp;
        HedgeBlueprint[blueprintID_].creationTimestamp = now;
        HedgeBlueprint[blueprintID_].blueprintAddress = address(blueprint_);
        HedgeBlueprint[blueprintID_].lastBuyerID = 0;
        HedgeBlueprint[blueprintID_].creator.userID = creatorUserID_;
        HedgeBlueprint[blueprintID_].creator.userAddress = msg.sender;
        HedgeBlueprint[blueprintID_].creator.amountStaked = creationPrice;

        blueprintID[address(blueprint_)] = blueprintID_;

        //update last blueprintID 
        lastBlueprintID = blueprintID_;

        emit BlueprintCreated(msg.sender, address(blueprint_));  
    }


    function purchaseBlueprint (address _blueprintAddress) public payable {
        
        //access deployed blueprint contract at specified address 
        Blueprint blueprint_ =  Blueprint(_blueprintAddress);
        
        //can't purchase blueprint if the prediction expiration date has passed
        require (blueprint_.expirationTimestamp() > now);
        //can't purchase a blueprint if user has not been validated by admin
        require (userID[msg.sender] > 0);
        //see NOTE8
        
        //temp ID variables
        buyerUserID_ = userID[msg.sender];
        buyerID_ = HedgeBlueprint[blueprintID_].lastBuyerID + 1;
        
        //transfer tokens from buyer address to contract they want to purchase
        rblxToken.transferFrom(msg.sender, _blueprintAddress, blueprint_.purchasePrice());
        //see NOTE9

        //call function in blueprint that updates it's internal buyers list
        blueprint_.addBuyer(msg.sender);
        
        //update metadata of user list
        HedgeUser[buyerUserID_].totalAmountSpent += purchasePrice;
        HedgeUser[buyerUserID_].noOfBlueprintsPurchased += 1;
        
        //update metadata of blueprint list
        HedgeBlueprint[blueprintID_].buyers[buyerID_].userID = buyerUserID_;
        HedgeBlueprint[blueprintID_].buyers[buyerID_].userAddress = msg.sender;
        HedgeBlueprint[blueprintID_].buyers[buyerID_].amountStaked =  blueprint_.purchasePrice();

        //update last buyerID
        HedgeBlueprint[blueprintID_].lastBuyerID = buyerID_;

        emit BlueprintPurchased(msg.sender, _blueprintAddress);
    }
    
    //function for a third party to access user metadata
    function lookupUserMeta (uint256 _userID) public view returns (address userAddress, 
            uint256 totalAmountSpent, 
            uint256 noOfBlueprintsCreated, 
            uint256 noOfBlueprintsPurchased) {
        return (HedgeUser[_userID].userAddress, 
            HedgeUser[_userID].totalAmountSpent, 
            HedgeUser[_userID].noOfBlueprintsCreated, 
            HedgeUser[_userID].noOfBlueprintsPurchased);
    }
    
    //function for a third party to access blueprint metadata    
    function lookupBlueprintMeta (uint256 _blueprintID) public view returns (string ticker,
            uint creationTimestamp, 
            uint expirationTimestamp, 
            address blueprintAddress,
            uint256 creatorID,
            address creatorAddress,
            uint256 noOfBuyers) {
        return (HedgeBlueprint[_blueprintID].ticker, 
            HedgeBlueprint[_blueprintID].creationTimestamp, 
            HedgeBlueprint[_blueprintID].expirationTimestamp, 
            HedgeBlueprint[_blueprintID].blueprintAddress, 
            HedgeBlueprint[_blueprintID].creator.userID, 
            HedgeBlueprint[_blueprintID].creator.userAddress,  
            HedgeBlueprint[_blueprintID].lastBuyerID);
    }

    //ADMIN ONLY FUNCTIONS BELOW------------------------------------------------------------------------------------------------------

    
    //admin needs to validate a user before they can create or purchase a blueprint on Hedge, see NOTE8
    //can apply validations in batches to save gas and time 
    function addValidatedUsers (address[] _walletAddresses) public {
        require (msg.sender == admin);    
         
        for(uint256 i = 0; i < _walletAddresses.length; i++ ) {
            require (userID[_walletAddresses[i]] == 0);
            userID_ = lastUserID + 1;
            userID[_walletAddresses[i]] = userID_;
            HedgeUser[userID_].userAddress = _walletAddresses[i];
            lastUserID = userID_;
        }
    }
    
    
    //removing a user from the validated user list changes their ID from positive to negative, but the scalar value remains the same
    //this maintains a record of all users and their original IDs after being unvalidated to prevent/identify tampering
    function removeValidatedUsers (address[] _walletAddresses) public {
        require (msg.sender == admin);    
         
        for(uint256 i = 0; i < _walletAddresses.length; i++ ) {
            require (userID[_walletAddresses[i]] > 0);
            //users removed from the validated user list will still have their ID number, but the sign changed to ensure immutability
            userID[_walletAddresses[i]] = -userID[_walletAddresses[i]];
        }
    }

    //in case an error occurs and a user is accidently removed from validated user list, they can be revalidated with their old ID
    function reValidateUsers (address[] _walletAddresses) public {
        require (msg.sender == admin);    
         
        for(uint256 i = 0; i < _walletAddresses.length; i++ ) {
            require (userID[_walletAddresses[i]] < 0);
            //users removed from the validated user list will still have their ID number, but the sign changed to ensure immutability
            userID[_walletAddresses[i]] = -userID[_walletAddresses[i]];
        }
    }

    //functions to change global parameters in BlueprintFactory after deployment

    function changePurchasePrice (uint256 _purchasePrice) public {
        require (msg.sender == admin);
        purchasePrice = _purchasePrice;
    }

    function changeCreationPrice (uint256 _creationPrice) public {
        require (msg.sender == admin);
        creationPrice = _creationPrice;
    }

    function changeOracleAddress (address _rblxOracleAddress) public {
        require (msg.sender == admin);
        rblxOracleAddress = _rblxOracleAddress;
    }
}
