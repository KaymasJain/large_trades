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

    uint public ethToDaiRate = 150;

    // address public daiAddr = 0x89d24a6b4ccb1b6faa2625fe562bdd9a23260359;
    address public daiAddr = 0xad6d458402f60fd3bd25163575031acdce07538d; // Ropsten

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

    function _addEthOrder(uint ETHQty) private returns (uint) {
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

    function _addDaiOrder(uint DAIQty) private returns (uint) {
        OrderObject memory order = OrderObject(DAITail, msg.sender, DAIQty, 0);
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

    function _ETHToDAIFillLess(uint DAIQty) private {
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

    function _ETHToDAIFillFull(uint DAIQty) private {
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

    function _DAIToETHFillLess(uint ETHQty) private {
        OrderObject storage selectOrder = ETHOrders[ETHHead];
        if (selectOrder.tokenQty > ETHQty) {
            selectOrder.tokenQty = selectOrder.tokenQty - ETHQty;
            ETHTotal = ETHTotal - ETHQty;
            uint DAIToTransfer = ETHQty*ethToDaiRate;
            selectOrder.user.transfer(ETHQty);
            IERC20(daiAddr).transfer(msg.sender, DAIToTransfer);
        } else if (selectOrder.tokenQty == ETHQty) {
            ETHHead = selectOrder.tail;
            ETHOrders[selectOrder.tail].head = 0;
            ETHTotal = ETHTotal - ETHQty;
            uint DAIToTransfer = ETHQty*ethToDaiRate;
            selectOrder.user.transfer(ETHQty);
            IERC20(daiAddr).transfer(msg.sender, DAIToTransfer);
            if (DAIHead == 0) {
                DAITail = 0;
            }
        } else {
            ETHHead = selectOrder.tail;
            ETHTotal = ETHTotal - selectOrder.tokenQty;
            uint DAIToTransfer = selectOrder.tokenQty*ethToDaiRate;
            selectOrder.user.transfer(selectOrder.tokenQty);
            IERC20(daiAddr).transfer(msg.sender, DAIToTransfer);
            _DAIToETHFillLess(ETHQty - selectOrder.tokenQty);
        }
    }

    function _DAIToETHFillFull(uint ETHQty) private {
        if (DAIHead == 0) {
            uint DAIQty = ETHQty*ethToDaiRate;
            _addDaiOrder(DAIQty);
        } else {
            OrderObject memory selectOrder = ETHOrders[ETHHead];
            ETHHead = selectOrder.tail;
            ETHTotal = ETHTotal - selectOrder.tokenQty;
            uint DAIToTransfer = selectOrder.tokenQty*ethToDaiRate;
            selectOrder.user.transfer(selectOrder.tokenQty);
            IERC20(daiAddr).transfer(msg.sender, DAIToTransfer);
            _DAIToETHFillFull(ETHQty - selectOrder.tokenQty);
        }
    }

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
        if (ETHTotal > 0) {
            _addDaiOrder(msg.value);
        } else if (DAITotal >= DAIQty) {
            _DAIToETHFillLess(DAIQty);
        } else {
            _DAIToETHFillFull(DAIQty);
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

contract MainContract is OTCTrade {

    function() external payable {}

}