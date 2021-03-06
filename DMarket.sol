pragma solidity ^0.5.0;

import './IERC20.sol';
import './IERC1155.sol';
import './IConditionalTokens.sol';

contract DMarket is IERC1155TokenReceiver {
  IERC20 dai;
  IConditionalTokens conditionalTokens;
  address public oracle;
  address public admin;
  mapping(bytes32 => mapping(uint => uint)) public tokenBalance; //balance of conditional tokens, indexed by questionId and indexSet 

  constructor(address _dai, address _conditionalTokens, address _oracle) public {
    dai = IERC20(_dai);
    conditionalTokens = IConditionalTokens(_conditionalTokens);
    oracle = _oracle;
    admin = msg.sender;
  }

  function createBet(bytes32 questionId, uint amount) external {
    //Create a bet
    conditionalTokens.prepareCondition(
      oracle,     //Will provide outcome  
      questionId, //identify the bet 
      3           //There are 3 outcomes;
    );

    bytes32 conditionId = conditionalTokens.getConditionId(
      oracle, 
      questionId, 
      3
    );

    uint[] memory partition = new uint[](2);
    partition[0] = 1; //0b001
    partition[1] = 2; //0b110
    dai.approve(address(conditionalTokens), amount);
    conditionalTokens.splitPosition(
      dai,         //collateralToken 
      bytes32(0),  //parentCollectionId
      conditionId, 
      partition,
      amount       //Amount of dai to transfer as collateral
    );
    
    tokenBalance[questionId][0] = amount;
    tokenBalance[questionId][1] = amount;
  }

  function transferTokens(
    bytes32 questionId, 
    uint indexSet,
    address to, 
    uint amount) external {
    require(msg.sender == admin, 'only admin');
    require(tokenBalance[questionId][indexSet] >=  amount, 'not enough tokens');
    tokenBalance[questionId][indexSet] -= amount;

    bytes32 conditionId = conditionalTokens.getConditionId(
      oracle, 
      questionId, 
      2
    );

    bytes32 collectionId = conditionalTokens.getCollectionId(
      bytes32(0), //parentCollectionId
      conditionId, 
      indexSet
    );

    uint positionId = conditionalTokens.getPositionId(
      dai, //collateral Token, 
      collectionId
    );

    conditionalTokens.safeTransferFrom(
      address(this), //from
      to,            //to need to implement ERC1155ReceiverInterface if is a smart contract 
      positionId, 
      amount,
      ""
    );
  }
}