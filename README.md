<p>
<img src="https://rublix.io/images/256x256.png">
</p>

# Blueprint Contract Base for Hedge Platform
### Includes basic ERC20 token creation, escrow vault and oraclize API verification.
Learn more at: https://rublix.io

#### Description

This contract allows the creator to submit a "Blueprint" to the Ethereum network in the form of a smart contract. Other individuals may places "bets" on this contract by sending their ERC20 tokens to it.

* If the creator is correct with his prediction all of the tokens in the betting pool will be rewarded to the "Blueprint" creator.
* If the creator is incorrect with his prediction all of the tokens in the betting pool will be returned to the participants.

The contract can be modified to have contract creator put in token stake to even out the playfield.
