// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract TestToken {
    // 状态变量
    uint public totalSupply;
    string public name;
    string public symbol;
    uint8 public decimals; // 小数位数
    address public owner;
    mapping(address => uint) public balances;
    mapping(address => mapping(address => uint)) public allowed;

    // 事件
    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    // 构造函数
    constructor(uint _initialSupply, string memory _name, string memory _symbol, uint8 _decimals) {
        totalSupply = _initialSupply;
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        owner = msg.sender;

        balances[msg.sender] = _initialSupply;
    }

    // 转账函数
    function transfer(address _to, uint _value) public returns (bool) {
        require(balances[msg.sender] >= _value, "Insufficient balance");
        require(_to != address(0), "Invalid address");

        balances[msg.sender] -= _value;
        balances[_to] += _value;

        emit Transfer(msg.sender, _to, _value); // 触发转账事件
        return true;
    }

    // 许可额度
    function approve(address _spender, uint _value) public returns (bool) {
        require(_spender != address(0), "Invalid address");
        
        allowed[_spender][msg.sender] = _value;
        emit Approval(msg.sender, _spender, _value); // 触发授权事件
        return true;
    }

    // 获取许可额度
    function allowance(address _owner, address _spender) public view returns (uint) {
        return allowed[_owner][_spender];
    }

    // 增发代币
    function mintToken(uint _token) public {
        balances[msg.sender] += _token;
        totalSupply += _token;
    }

    // 查询余额
    function balanceOf(address _owner) public view returns (uint) {
        return balances[_owner];
    }

    // 通过授权的支出转账
    function transferFrom(address _from, address _to, uint _value) public returns (bool) {
        require(balances[_from] >= _value, "Insufficient balance");
        require(allowed[_from][msg.sender] >= _value, "Allowance exceeded");
        require(_to != address(0), "Invalid address");

        balances[_from] -= _value;
        balances[_to] += _value;
        allowed[_from][msg.sender] -= _value;

        emit Transfer(_from, _to, _value); // 触发转账事件
        return true;
    }

}