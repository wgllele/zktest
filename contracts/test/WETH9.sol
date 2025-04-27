// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;
import "./interfaces/IWETH.sol";

contract WETH9 is IWETH{
    string public name     = "Wrapped Ether";
    string public symbol   = "WETH";
    uint8  public decimals = 18;

    event  Approval(address indexed src, address indexed guy, uint wad);
    event  Transfer(address indexed src, address indexed dst, uint wad);
    event  Deposit(address indexed dst, uint wad);
    event  Withdrawal(address indexed src, uint wad);

    mapping (address => uint)                       public  balanceOf;
    mapping (address => mapping (address => uint))  public  allowance;
    receive() external payable {
        deposit();
    }
    fallback() external payable {
        deposit();
    }
    function deposit() public payable {
        balanceOf[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }
    function withdraw(uint wad) public  {
        require(balanceOf[msg.sender] >= wad);
        balanceOf[msg.sender] -= wad;
        _ethTransfer(msg.sender,wad);
        emit Withdrawal(msg.sender, wad);
    }
    function _ethTransfer(address recipient, uint256 amount) internal {
        bool callStatus;
        assembly {
        // Transfer the ETH and store if it succeeded or not.
            callStatus := call(gas(), recipient, amount, 0, 0, 0, 0)
        }
        if (!callStatus) {
            revert EthTransfer(recipient, amount);
        }
    }

    function totalSupply() public view returns (uint) {
        return address(this).balance;
    }

    function approve(address guy, uint wad) public returns (bool) {
        allowance[msg.sender][guy] = wad;
        emit Approval(msg.sender, guy, wad);
        return true;
    }

    function transfer(address dst, uint wad) public returns (bool) {
        return transferFrom(msg.sender, dst, wad);
    }

    function transferFrom(address src, address dst, uint wad)
    public
    returns (bool)
    {
        require(balanceOf[src] >= wad);
        if (src != msg.sender && allowance[src][msg.sender] != type(uint256).max) {
            require(allowance[src][msg.sender] >= wad);
            allowance[src][msg.sender] -= wad;
        }

        balanceOf[src] -= wad;
        balanceOf[dst] += wad;

        emit Transfer(src, dst, wad);

        return true;
    }
}