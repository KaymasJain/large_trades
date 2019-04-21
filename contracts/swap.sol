pragma solidity ^0.5.0;

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

    uint public ethToDaiRate = 200;

    // address public daiAddr = 0x89d24A6b4CcB1B6fAA2625fE562bDD9a23260359;
    address public daiAddr = 0xaD6D458402F60fD3Bd25163575031ACDce07538D; // Ropsten

    struct OrderObject {
        bytes32 head;
        address payable user;
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

    function _addEthOrder(uint ETHQty) internal returns (uint) {
        OrderObject memory order = OrderObject(ETHTail, msg.sender, ETHQty, 0);
        bytes32 id = keccak256(abi.encodePacked(order.user, now));
        if (ETHHead == 0) {
            ETHHead = id;
        } else {
            ETHOrders[ETHTail].tail = id;
        }
        ETHTail = id;
        ETHOrders[id] = order;
        ETHTotal = ETHTotal + ETHQty;
        return ETHTotal;
    }

    function _addDaiOrder(uint DAIQty) internal returns (uint) {
        OrderObject memory order = OrderObject(DAITail, msg.sender, DAIQty, 0);
        bytes32 id = keccak256(abi.encodePacked(order.user, now));
        if (DAIHead == 0) {
            DAIHead = id;
        } else {
            DAIOrders[DAITail].tail = id;
        }
        DAITail = id;
        DAIOrders[id] = order;
        DAITotal = DAITotal + DAIQty;
        return DAITotal;
    }

    function _ETHToDAIFillLess(uint DAIQty) internal {
        OrderObject storage selectOrder = DAIOrders[DAIHead];
        if (selectOrder.tokenQty > DAIQty) {
            selectOrder.tokenQty = selectOrder.tokenQty - DAIQty;
            DAITotal = DAITotal - DAIQty;
            uint ETHToTransfer = DAIQty/ethToDaiRate;
            selectOrder.user.transfer(ETHToTransfer);
            IERC20(daiAddr).transfer(msg.sender, DAIQty);
        } else if (selectOrder.tokenQty == DAIQty) {
            DAIHead = selectOrder.tail;
            DAIOrders[selectOrder.tail].head = 0;
            DAITotal = DAITotal - DAIQty;
            uint ETHToTransfer = DAIQty/ethToDaiRate;
            selectOrder.user.transfer(ETHToTransfer);
            IERC20(daiAddr).transfer(msg.sender, DAIQty);
            if (DAIHead == 0) {
                DAITail = 0;
            }
        } else {
            DAIHead = selectOrder.tail;
            DAITotal = DAITotal - selectOrder.tokenQty;
            uint ETHToTransfer = selectOrder.tokenQty/ethToDaiRate;
            selectOrder.user.transfer(ETHToTransfer);
            IERC20(daiAddr).transfer(msg.sender, selectOrder.tokenQty);
            _ETHToDAIFillLess(DAIQty - selectOrder.tokenQty);
        }
    }

    function _ETHToDAIFillFull(uint DAIQty) internal {
        if (DAIHead == 0) {
            uint ETHQty = DAIQty/ethToDaiRate;
            _addEthOrder(ETHQty);
        } else {
            OrderObject memory selectOrder = DAIOrders[DAIHead];
            DAIHead = selectOrder.tail;
            DAITotal = DAITotal - selectOrder.tokenQty;
            uint ETHToTransfer = selectOrder.tokenQty/ethToDaiRate;
            selectOrder.user.transfer(ETHToTransfer);
            IERC20(daiAddr).transfer(msg.sender, selectOrder.tokenQty);
            _ETHToDAIFillFull(DAIQty - selectOrder.tokenQty);
        }
    }

    function _DAIToETHFillLess(uint ETHQty) internal {
        OrderObject storage selectOrder = ETHOrders[ETHHead];
        if (selectOrder.tokenQty > ETHQty) {
            selectOrder.tokenQty = selectOrder.tokenQty - ETHQty;
            ETHTotal = ETHTotal - ETHQty;
            uint DAIToTransfer = ETHQty*ethToDaiRate;
            msg.sender.transfer(ETHQty);
            IERC20(daiAddr).transfer(selectOrder.user, DAIToTransfer);
        } else if (selectOrder.tokenQty == ETHQty) {
            ETHHead = selectOrder.tail;
            ETHOrders[selectOrder.tail].head = 0;
            ETHTotal = ETHTotal - ETHQty;
            uint DAIToTransfer = ETHQty*ethToDaiRate;
            msg.sender.transfer(ETHQty);
            IERC20(daiAddr).transfer(selectOrder.user, DAIToTransfer);
            if (ETHHead == 0) {
                ETHTail = 0;
            }
        } else {
            ETHHead = selectOrder.tail;
            ETHTotal = ETHTotal - selectOrder.tokenQty;
            uint DAIToTransfer = selectOrder.tokenQty*ethToDaiRate;
            msg.sender.transfer(selectOrder.tokenQty);
            IERC20(daiAddr).transfer(selectOrder.user, DAIToTransfer);
            _DAIToETHFillLess(ETHQty - selectOrder.tokenQty);
        }
    }

    function _DAIToETHFillFull(uint ETHQty) internal {
        if (ETHHead == 0) {
            uint DAIQty = ETHQty*ethToDaiRate;
            _addDaiOrder(DAIQty);
        } else {
            OrderObject memory selectOrder = ETHOrders[ETHHead];
            ETHHead = selectOrder.tail;
            ETHTotal = ETHTotal - selectOrder.tokenQty;
            uint DAIToTransfer = selectOrder.tokenQty*ethToDaiRate;
            msg.sender.transfer(selectOrder.tokenQty);
            IERC20(daiAddr).transfer(selectOrder.user, DAIToTransfer);
            _DAIToETHFillFull(ETHQty - selectOrder.tokenQty);
        }
    }

    function transferETH() public payable {
        msg.sender.transfer(address(this).balance);
        emit LogTransferETH(msg.sender, address(this).balance);
    }

    function transferDAI() public {
        IERC20 tkn = IERC20(daiAddr);
        uint tknBal = tkn.balanceOf(address(this));
        tkn.transfer(msg.sender, tknBal);
        emit LogTransferERC20(daiAddr, msg.sender, tknBal);
    }

}

contract Swap is OTCTrade {

    function swapETHToDAI() public payable returns (uint DAIQty) {
        DAIQty = msg.value * ethToDaiRate;
        if (ETHTotal > 0) {
            _addEthOrder(msg.value);
        } else if (DAITotal >= DAIQty) {
            _ETHToDAIFillLess(DAIQty);
        } else {
            _ETHToDAIFillFull(DAIQty);
        }
    }

    function swapDAIToETH(uint DAIQty) public returns (uint ETHQty) {
        IERC20(daiAddr).transferFrom(msg.sender, address(this), DAIQty);
        ETHQty = DAIQty/ethToDaiRate;
        if (DAITotal > 0) {
            _addDaiOrder(DAIQty);
        } else if (ETHTotal >= ETHQty) {
            _DAIToETHFillLess(ETHQty);
        } else {
            _DAIToETHFillFull(ETHQty);
        }
    }

    function clear() public {
        ETHHead = 0;
        ETHTail = 0;
        DAIHead = 0;
        DAITail = 0;
        ETHTotal = 0;
        DAITotal = 0;
    }

    function() external payable {}

}