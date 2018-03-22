pragma solidity ^0.4.18;

import "github.com/oraclize/ethereum-api/oraclizeAPI.sol";
import "github.com/Arachnid/solidity-stringutils/strings.sol";

/**
 * @title ERC20Basic
 * @dev Simpler version of ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/179
 */
contract ERC20Basic {
  uint256 public totalSupply;
  function balanceOf(address who) public constant returns (uint256);
  function transfer(address to, uint256 value) public returns (bool);
  event Transfer(address indexed from, address indexed to, uint256 value);
}
/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {
  address public owner;
  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
  /**
   * @dev The Ownable constructor sets the original `owner` of the contract to the sender
   * account.
   */
  function Ownable() {
    owner = msg.sender;
  }
  /**
   * @dev Throws if called by any account other than the owner.
   */
  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }
  /**
   * @dev Allows the current owner to transfer control of the contract to a newOwner.
   * @param newOwner The address to transfer ownership to.
   */
  function transferOwnership(address newOwner) onlyOwner public {
    require(newOwner != address(0));
    OwnershipTransferred(owner, newOwner);
    owner = newOwner;
  }
}
/**
 * @title Basic token
 * @dev Basic version of StandardToken, with no allowances.
 */
contract BasicToken is ERC20Basic {
  using SafeMath for uint256;
  mapping(address => uint256) balances;
  /**
  * @dev transfer token for a specified address
  * @param _to The address to transfer to.
  * @param _value The amount to be transferred.
  */
  function transfer(address _to, uint256 _value) public returns (bool) {
    require(_to != address(0));
    // SafeMath.sub will throw if there is not enough balance.
    balances[msg.sender] = balances[msg.sender].sub(_value);
    balances[_to] = balances[_to].add(_value);
    Transfer(msg.sender, _to, _value);
    return true;
  }
  /**
  * @dev Gets the balance of the specified address.
  * @param _owner The address to query the the balance of.
  * @return An uint256 representing the amount owned by the passed address.
  */
  function balanceOf(address _owner) public constant returns (uint256 balance) {
    return balances[_owner];
  }
}
/**
 * @title ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/20
 */
contract ERC20 is ERC20Basic {
  function allowance(address owner, address spender) public constant returns (uint256);
  function transferFrom(address from, address to, uint256 value) public returns (bool);
  function approve(address spender, uint256 value) public returns (bool);
  event Approval(address indexed owner, address indexed spender, uint256 value);
}
/**
 * @title Standard ERC20 token
 *
 * @dev Implementation of the basic standard token.
 * @dev https://github.com/ethereum/EIPs/issues/20
 * @dev Based on code by FirstBlood: https://github.com/Firstbloodio/token/blob/master/smart_contract/FirstBloodToken.sol
 */
contract StandardToken is ERC20, BasicToken {
  mapping (address => mapping (address => uint256)) allowed;
  /**
   * @dev Transfer tokens from one address to another
   * @param _from address The address which you want to send tokens from
   * @param _to address The address which you want to transfer to
   * @param _value uint256 the amount of tokens to be transferred
   */
  function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
    require(_to != address(0));
    uint256 _allowance = allowed[_from][msg.sender];
    // Check is not needed because sub(_allowance, _value) will already throw if this condition is not met
    // require (_value <= _allowance);
    balances[_from] = balances[_from].sub(_value);
    balances[_to] = balances[_to].add(_value);
    allowed[_from][msg.sender] = _allowance.sub(_value);
    Transfer(_from, _to, _value);
    return true;
  }
  /**
   * @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
   *
   * Beware that changing an allowance with this method brings the risk that someone may use both the old
   * and the new allowance by unfortunate transaction ordering. One possible solution to mitigate this
   * race condition is to first reduce the spender's allowance to 0 and set the desired value afterwards:
   * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
   * @param _spender The address which will spend the funds.
   * @param _value The amount of tokens to be spent.
   */
  function approve(address _spender, uint256 _value) public returns (bool) {
    allowed[msg.sender][_spender] = _value;
    Approval(msg.sender, _spender, _value);
    return true;
  }
  /**
   * @dev Function to check the amount of tokens that an owner allowed to a spender.
   * @param _owner address The address which owns the funds.
   * @param _spender address The address which will spend the funds.
   * @return A uint256 specifying the amount of tokens still available for the spender.
   */
  function allowance(address _owner, address _spender) public constant returns (uint256 remaining) {
    return allowed[_owner][_spender];
  }
  /**
   * approve should be called when allowed[_spender] == 0. To increment
   * allowed value is better to use this function to avoid 2 calls (and wait until
   * the first transaction is mined)
   * From MonolithDAO Token.sol
   */
  function increaseApproval (address _spender, uint _addedValue)
    returns (bool success) {
    allowed[msg.sender][_spender] = allowed[msg.sender][_spender].add(_addedValue);
    Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
    return true;
  }
  function decreaseApproval (address _spender, uint _subtractedValue)
    returns (bool success) {
    uint oldValue = allowed[msg.sender][_spender];
    if (_subtractedValue > oldValue) {
      allowed[msg.sender][_spender] = 0;
    } else {
      allowed[msg.sender][_spender] = oldValue.sub(_subtractedValue);
    }
    Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
    return true;
  }
}

contract RBLXToken is StandardToken {
  using SafeMath for uint256;

  // RBLX Token parameters
  string public name = 'Rublix Token';
  string public symbol = 'RBLX';
  uint8 public constant decimals = 18;
  uint256 public constant decimalFactor = 10 ** uint256(decimals);
  uint256 public constant totalSupply = 1000000000 * decimalFactor;



  function RBLXToken(address _owner) public {
    require(_owner != address(0));
    balances[_owner] = totalSupply;
    Transfer(address(0), _owner, totalSupply);
  }

  function sendToken(address receiver, uint amount,address sender) returns(bool successful){
	 require(amount <= balances[sender]);

	       // SafeMath.sub will throw if there is not enough balance.
    balances[sender] = balances[sender].sub(amount);
    balances[receiver] = balances[receiver].add(amount);
		Transfer(sender, receiver, amount);
		return false;
	}

}




contract EscrowVault is Ownable
{

    using SafeMath for uint256;
    address public wallet;
    mapping(address => uint256) balances;

    RBLXToken token;

    mapping (address => bool) public isRefunded;
    event Logrefund(address _useraddress, uint256 _time, uint256 amount);
    event Logvalutclose(address _wallet, uint256 amount, uint256 time);
    /**
     * @param _wallet wallet Address
     * @param _token tokenaddress
    */
    function EscrowVault(address _wallet, RBLXToken _token) public
    {
        require(_wallet != address(0));
        require(_token  != address(0));
        wallet = _wallet;
        token=_token;
    }



    //Investors can claim refunds
    function Refund(address[] _recipient,uint256 _numberOfBetters)onlyOwner  public
    {
        require(token.balanceOf(this) >0);

        uint256 balance = token.balanceOf(this);
        if(_recipient.length==0)
        {
                require(token.transfer(wallet, balance));
        }
        else
        {
            balance=balance.div(_numberOfBetters);

            for(uint256 i = 0; i< _recipient.length; i++)
            {
                if (!isRefunded[_recipient[i]])
                {
                    isRefunded[_recipient[i]] = true;
                    require(token.transfer(_recipient[i], balance));
                    Logrefund(_recipient[i],now,balance);

                }

            }
        }
    }


    function close()  onlyOwner public
    {
        require(token.balanceOf(this) >0);

        uint256 balance = token.balanceOf(this);

        require(token.transfer(wallet, balance));

        Logvalutclose(wallet,balance,now);

    }

}




contract Blueprint is Ownable, usingOraclize
{

    using SafeMath for uint256;

    // start and end timestamps where investments are allowed (both inclusive)
    uint256 public startTime;
    uint256 public endTime;

    //ERC20 Token declarations
    RBLXToken public token;

    // decimalFactor
    uint256 private constant decimalFactor = 10**uint256(18);

   // vault used to hold tokens while Blueprint is running
    EscrowVault public vault;

   //owner amount of token to bet
    uint256 public price;

    //stores users list
    address[] recipient;

    //users count
    uint256 numberOfBetters = 0;

    struct better{
	  RBLXToken token;
		address sender;
		uint256 amount;

	}
	//maintain users details
	mapping(uint => better) betters;



    mapping(address => bool) public userExist;
    mapping(bytes32 => bool) validIds;

    using strings for *;
    uint256 public highValue;
    uint256 public predictedValue;
    uint256 public lowValue;

    event LogPriceUpdated(string price, uint256 time);
    event LogNewOraclizeQuery(string description);
    event LogUserinfo(address userAddress, uint256 aomunt, uint256 time);

     /**

     * @param _tokenaddress is the address of the token
     * @param _wallet for when contract owner Reached goal sending tokens to wallet
     * @param _price for how many token to owner to bet
     * @param _predictedValue is predicted value
     * @param _endTime is in how many seconds will the blueprint expire from now
     */

    function Blueprint(address _tokenaddress, address _wallet, uint256 _price, uint256 _predictedValue, uint256 _endTime)public
    payable
     {
        require(_tokenaddress != address(0));
        require(_wallet != address(0));
        require(_price != 0);
        require(_predictedValue != 0);
        require(_endTime >= now);

        oraclize_setCustomGasPrice(5000000000 wei);
        oraclize_setProof(proofType_TLSNotary | proofStorage_IPFS);

        token = RBLXToken(_tokenaddress);
        assert(token.balanceOf(msg.sender)>=_price);
        vault = new EscrowVault(_wallet,token);
        price = _price;
        predictedValue = _predictedValue;
        startTime = now;
        endTime = _endTime;
        token.sendToken(vault,_price*decimalFactor,msg.sender);
        getPrices();
    }
     /**

      * @param amount Number of Tokens to Bet
     */
	function sendCoin(uint amount) public returns(bool)
	{
	    require(price == amount);
	    assert(owner != msg.sender);
	  	assert(endTime >= now);
	    assert(userExist[msg.sender] == false);


	    userExist[msg.sender]=true;
	   	better bet = betters[numberOfBetters]; //Creates a reference bet
        bet.token = RBLXToken(token);
	    recipient.push(msg.sender);
		bet.sender = msg.sender;
	    bet.amount=amount.mul(decimalFactor);
		bet.token.sendToken(vault, bet.amount, bet.sender);
	    LogUserinfo(msg.sender,bet.amount,now);
		numberOfBetters++;
		return true;

	}

   // @return true
    function hasEnded() public view returns (bool) {
        return now > endTime;
    }
    // @return true
     function ownergoalReached() public view returns (bool) {
         return highValue>=predictedValue &&lowValue<=predictedValue;
    }


    function __callback(bytes32 myid, string result, bytes proof)
    {
        if(msg.sender != oraclize_cbAddress()) throw;

        LogPriceUpdated(result,now);
        setPrices(result);

        if(ownergoalReached()){
             vault.close();
        } else if(hasEnded()){
             vault.Refund(recipient,numberOfBetters);

        } else {

             if(endTime.sub(now)>86400){
                getPrices();
            } else {
                getupdatedPrices(endTime.sub(now));
            }

        }

    }


    function setPrices(string _result)
    {
        var s = _result.toSlice();
        var delim = ",".toSlice();
        var parts = new string[](s.count(delim) + 1);
        for(uint i = 0; i < parts.length; i++) {
            parts[i] = s.split(delim).toString();
            }
            // highvalue conver to uint256
             highValue = parseInt(parts[1],2);
             //lowvalue conver to uint256
             lowValue = parseInt(parts[2],2);
             highValue = highValue.div(100);
             lowValue = lowValue.div(100);
    }


    function getPrices() payable
    {
        if (oraclize_getPrice("URL") > this.balance) {
             LogNewOraclizeQuery("Oraclize query was NOT sent, please add some ETH to cover for the query fee");
        } else {


             bytes32 queryId =oraclize_query(86400,"URL", "BACwdQwK0DRrTxTZj83+5gsF/R4RQIlHwRd84MkH3Dh3uxPnNsBBWegEnCq8nw/+705Fr91prJ65tsgmQttVCmniw16KxIKYp7U0xS4ZCRuOAO+dce//7n6jJblzK10o3WwAhNz8/incFhFxwgVkC37GQfJ2aJlm/jtgNj9oHiMPtoxC43S7RTJXE57GnvqFU7pLbdCRjJRt0QPrLHYn6Ak57Scbh/ACIw8bB5QpqntRPSys5jkkK+RM0mLRFM8=",500000);
             validIds[queryId] = true;

        }
    }


    function getupdatedPrices(uint256 _delay) payable
    {
        if (oraclize_getPrice("URL") > this.balance) {
             LogNewOraclizeQuery("Oraclize query was NOT sent, please add some ETH to cover for the query fee");
        } else {


             bytes32 queryId = oraclize_query(_delay,"URL", "BACwdQwK0DRrTxTZj83+5gsF/R4RQIlHwRd84MkH3Dh3uxPnNsBBWegEnCq8nw/+705Fr91prJ65tsgmQttVCmniw16KxIKYp7U0xS4ZCRuOAO+dce//7n6jJblzK10o3WwAhNz8/incFhFxwgVkC37GQfJ2aJlm/jtgNj9oHiMPtoxC43S7RTJXE57GnvqFU7pLbdCRjJRt0QPrLHYn6Ak57Scbh/ACIw8bB5QpqntRPSys5jkkK+RM0mLRFM8=",500000);
             validIds[queryId] = true;

        }
    }


}
