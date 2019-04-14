pragma solidity ^0.5.2;

interface IERC20 {
    function transfer(address to, uint256 value) external returns (bool);
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function balanceOf(address who) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
}

contract OTCTrade {

    event LogTransferETH(address dest, uint amount);
    event LogTransferERC20(address token, address dest, uint amount);

    uint public ethToDai = 150;

    address public daiAddr = 0x89d24a6b4ccb1b6faa2625fe562bdd9a23260359;
    // address public daiAddr = 0xad6d458402f60fd3bd25163575031acdce07538d; // Ropsten

    struct OrderObject {
        bytes32 head;
        address user;
        uint tokenQty;
        bytes32 tail;
    }

    bytes32 public ETHHead = 0;
    bytes32 public ETHTail = 0;
    bytes32 public DAIHead = 0;
    bytes32 public DAITail = 0;

    uint public ETHTotal = 0;
    uint public DAITotal = 0;

    mapping (bytes32 => OrderObject) public ETHOrders;
    mapping (bytes32 => OrderObject) public DAIOrders;

    function _addEthOrder() public payable returns (uint) {
        OrderObject memory order = OrderObject(ETHTail, msg.sender, msg.value, 0);
        bytes32 id = keccak256(abi.encodePacked(order.user, now));
        if (ETHHead == 0) {
            ETHHead = id;
        } else {
            ETHOrders[ETHTail].tail = id;
        }
        ETHTail = id;
        ETHOrders[id] = order;
        ETHTotal = ETHTotal + msg.value;
        return ETHTotal;
    }

    function _addDaiOrder(uint tokensQty) public returns (uint) {
        IERC20(daiAddr).transferFrom(msg.sender, address(this), tokensQty);
        OrderObject memory order = OrderObject(DAITail, msg.sender, tokensQty, 0);
        bytes32 id = keccak256(abi.encodePacked(order.user, now));
        if (DAIHead == 0) {
            DAIHead = id;
        } else {
            DAIOrders[DAITail].tail = id;
        }
        DAITail = id;
        DAIOrders[id] = order;
        DAITotal = DAITotal + msg.value;
        return DAITotal;
    }

    function transferETH() public payable {
        msg.sender.transfer(address(this).balance);
        emit LogTransferETH(msg.sender, address(this).balance);
    }

    function transferERC20(address tokenAddr) public {
        IERC20 tkn = IERC20(tokenAddr);
        uint tknBal = tkn.balanceOf(address(this));
        tkn.transfer(msg.sender, tknBal);
        emit LogTransferERC20(tokenAddr, msg.sender, tknBal);
    }

}

contract MainContract is OTCTrade {

    function() external payable {}

}