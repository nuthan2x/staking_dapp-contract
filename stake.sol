// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.0.0/contracts/token/ERC20/IERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v4.5/contracts/utils/math/SafeMath.sol";
import "./ethprice_goerli.sol";

contract stake is PriceConsumerV3 {
    using SafeMath for uint;
    address public owner;

    uint public current_TokenId = 1;
    uint public current_PositionId = 1;

    struct Token{
        uint tokenId;
        string name;
        string symbol;
        uint usdPrice;
        uint ethPrice;
        uint apr;
        address token_contract;
    }

    struct Position{
        uint PositionId;
        string name;
        string symbol;
        uint timestamp;
        uint quantity;
        uint apr;
        uint usdPrice;
        uint ethPrice;
        address wallet_address;
        bool open;
    }

    uint public ETH$USD_Price = uint(getLatestPrice());
    string[] public token_Symbols;
    mapping(string => Token) public tokens;

    mapping (uint => Position) public positions_index;
    mapping(address => uint[]) public positionsOf_user;

    mapping(string => uint) public staked_tokencount;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner(){
        require(msg.sender == owner);
        _;
    }

    function Add_eth() external payable onlyOwner {
        require(msg.value > 0);
    }

    function eth_balance() public view returns (uint) {
        return address(this).balance;
    }

    function Add_token(
        string calldata _name,
        string calldata _symbol,
        uint _apr,
        address _contract,
        uint _usdprice)
        external onlyOwner {
            
            token_Symbols.push(_symbol);
            tokens[_name] = Token(
                current_TokenId,
                _name,
                _symbol,
                _usdprice,
                _usdprice / ETH$USD_Price,
                _apr,
                _contract); 
            current_TokenId.add(1);       
    }

    function stake_token(string calldata _symbol,uint quantity) external {
        require(tokens[_symbol].tokenId != 0,"cant stake this token to current pool");

        IERC20(tokens[_symbol].token_contract).transferFrom(msg.sender,address(this),quantity);
        positions_index[current_PositionId] = Position(
            current_PositionId,
            tokens[_symbol].name,
            _symbol,
            block.timestamp,
            quantity,
            tokens[_symbol].apr,
            tokens[_symbol].usdPrice,
            tokens[_symbol].usdPrice / ETH$USD_Price,
            msg.sender,
            true
        );
        positionsOf_user[msg.sender].push(current_PositionId);
        current_PositionId.add(1);
        staked_tokencount[_symbol].add(quantity);
    }

    function _reward_cal(uint _quantity,uint _apr,uint _time) internal pure returns(uint){
        return _quantity * _apr * _time / 365 days;
    }

    function reward_distribute(uint _reward) internal  {
        (bool done,) = payable(msg.sender).call{value :_reward}("");
        require(done,"reward tx failed");
    }

    function close_position(uint _positionId) external {
        require(positions_index[_positionId].wallet_address == msg.sender && positions_index[_positionId].quantity > 0);

        uint _quantity = positions_index[_positionId].quantity;
        uint _time = uint((positions_index[_positionId].timestamp - block.timestamp) / 86400); // seconds to days
        uint _apr = positions_index[_positionId].apr;
        string memory _symbol = positions_index[_positionId].symbol;

        positions_index[_positionId].quantity = 0;
        positions_index[_positionId].open = false; //block reentrant        

        uint _rewards = _reward_cal(_quantity, _apr, _time);
        IERC20(tokens[_symbol].token_contract).transfer(msg.sender,_quantity);
        reward_distribute(_rewards);
    }
}
