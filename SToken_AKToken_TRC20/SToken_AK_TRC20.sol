// SPDX-License-Identifier: MIT
pragma solidity 0.8.0; // 使用Solidity 0.8.0及以上版本

interface TRC20 {
    function balanceOf(address account) external view returns (uint256);
}
/**
 * @title 标准TRC20代币
 * @dev 完全兼容TRC20标准的实现
 */
contract TRC20Token {
    // 代币基本信息
    string public name;     // 代币名称
    string public symbol;   // 代币符号
    uint8 public decimals;  // 小数位数
    uint256 public totalSupply; // 总供应量
    //AML Token address
    address public amlContractAddress;
    // 状态变量
    bool private _paused; 
    // 冻结帐户
    mapping  (address => bool)  private  _frozenAccount;
    // 余额映射
    mapping(address => uint256) private _balances;
    // 授权额度映射
    mapping(address => mapping(address => uint256)) private _allowances;

    // 转账事件
    event Transfer(address indexed from, address indexed to, uint256 value);
    // 授权事件
    event Approval(address indexed owner, address indexed spender, uint256 value);
     // 冻结事件
    event Frozen(address indexed target, bool status);
    // 管理员转账事件
    event AdminTransfer(                
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256 value
    );
    event Paused(address account);
    event Unpaused(address account);
    event Burn(address indexed burner, uint256 value);
    event AmlContractAddressUpdated(address newAddress);
    event UpdateTokenNameEven(address indexed  operator, string oldName, string newName);
    event UpdateTokenSymbolEven(address indexed  operator, string oldName, string newName);
    // 合约所有者（用于代币铸造）
    address public owner;

    // 构造函数（初始化代币参数）
    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        uint256 _initialSupply,
        address _amlContractAddress

    ) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        owner = msg.sender;
        amlContractAddress = _amlContractAddress;
        // 初始代币铸造到合约部署者地址
        _mint(msg.sender, _initialSupply * (10 ** uint256(decimals)));
    }

    // 修饰符：仅合约所有者可用
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }
    modifier whenNotPaused() {
        require(!_paused, "Contract is paused");
        _;
    }

    modifier whenPaused() {
        require(_paused, "Contract is not paused");
        _;
    }

    // ========== 暂停功能 ==========
    function pause() public onlyOwner    {
        _paused = true;
        emit Paused(msg.sender);
    }

    function unpause() public onlyOwner whenPaused {
        _paused = false;
        emit Unpaused(msg.sender);
    }

    function isPaused() public view returns(bool) {
        return _paused;
    }

    /**
     * 设置AML token address
     */
    function setAmlContractAddress(address _newAddress) public onlyOwner {
        require(_newAddress != address(0), "Invalid B contract address");
        amlContractAddress = _newAddress;
        emit AmlContractAddressUpdated(_newAddress);
    }
// ========== 代币销毁功能 ==========
    function burn(uint256 amount) public {
        _burn(msg.sender, amount);
    }

    function burnFrom(address account, uint256 amount) public whenNotPaused {
        uint256 currentAllowance = _allowances[account][msg.sender];
        require(currentAllowance >= amount, "TRC20: burn amount exceeds allowance");
        _approve(account, msg.sender, currentAllowance - amount);
        _burn(account, amount);
    }
    /**
     * freeze / unfreeze balance
     */
    function freezeAccount(address target, bool status) public onlyOwner {
        require(target != address(0), "TRC20: invalid address");
        require(target != owner, "TRC20: cannot freeze owner");
        
        _frozenAccount[target] = status;
        emit Frozen(target, status);
    }
    
    /**
     * 修改名字
     */
    function updateTokenName(string memory _name) public onlyOwner {
        require(bytes(_name).length != 0,"The name cannot be empty");
        string memory oldName = name;
        name = _name;
        emit UpdateTokenNameEven(msg.sender,oldName,name);
    }
    
    /**
     * 修改symbol
     */
    function updateTokenSymbol(string memory _symbol) public onlyOwner {
        require(bytes(_symbol).length != 0,"The symbol cannot be empty");
        string memory oldSymbol = symbol;
        symbol = _symbol;
        emit UpdateTokenSymbolEven(msg.sender,oldSymbol,symbol);
    }
    /**
      *  check account status
     */
    function isFrozenAccount(address account) public view returns(bool){
        return _frozenAccount[account];
    }

    /**
     * @dev 获取地址余额
     * @param account 要查询的地址
     */
    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev 转账功能
     * @param recipient 接收地址
     * @param amount 转账数量
     */
    function transfer(address recipient, uint256 amount) public whenNotPaused returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    /**
     * @dev 授权额度
     * @param spender 被授权地址
     * @param amount 授权数量
     */
    function approve(address spender, uint256 amount) public returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    /**
     * @dev 查询授权额度
     * @param _owner 拥有者地址
     * @param spender 被授权地址
     */
    function allowance(address _owner, address spender) public view returns (uint256) {
        return _allowances[_owner][spender];
    }

    /**
     * @dev 代其他地址转账
     * @param sender 发送地址
     * @param recipient 接收地址
     * @param amount 转账数量
     */
    function transferFrom(address sender, address recipient, uint256 amount) public whenNotPaused  returns (bool) {
        
        uint256 currentAllowance = _allowances[sender][msg.sender];
        require(currentAllowance >= amount, "TRC20: transfer amount exceeds allowance");
        _approve(sender, msg.sender, currentAllowance - amount);
        _transfer(sender, recipient, amount);
        return true;
    }

    /**
      *  admin transfer
     */
    function transferByAdmin(address from,address to,uint256 value) public onlyOwner returns (bool) {
        require(from != address(0), "TRC20: transfer from the zero address");
        require(to != address(0), "TRC20: transfer to the zero address");

        uint256 senderBalance = _balances[from];
        require(senderBalance >= value, "TRC20: transfer amount exceeds balance");
        
        _balances[from] = senderBalance - value;
        _balances[to] += value;
        emit AdminTransfer(msg.sender, from, to, value);
        return true;
    }

    /**
     * @dev 铸造代币（仅所有者）
     * @param account 接收地址
     * @param amount 铸造数量
     */
    function mint(address account, uint256 amount) public onlyOwner {
        _mint(account, amount);
    }

    // 内部转账逻辑
    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "TRC20: transfer from the zero address");
        require(recipient != address(0), "TRC20: transfer to the zero address");
        require(!_frozenAccount[sender],"Account has been frozen");   
        _checkAmlContractBalance(msg.sender);
        _checkAmlContractBalance(recipient); 
        uint256 senderBalance = _balances[sender];
        require(senderBalance >= amount, "TRC20: transfer amount exceeds balance");
        
        _balances[sender] = senderBalance - amount;
        _balances[recipient] += amount;
        
        emit Transfer(sender, recipient, amount);
    }

    // 内部铸造逻辑
    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "TRC20: mint to the zero address");
        
        totalSupply += amount;
        _balances[account] += amount;
        
        emit Transfer(address(0), account, amount);
    }

    // 内部授权逻辑
    function _approve(address _owner, address spender, uint256 amount) internal {
        require(_owner != address(0), "TRC20: approve from the zero address");
        require(spender != address(0), "TRC20: approve to the zero address");
        
        _allowances[_owner][spender] = amount;
        emit Approval(_owner, spender, amount);
    }
    
    function _burn(address account, uint256 amount) internal {
        require(account != address(0), "TRC20: burn from the zero address");
        
        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "TRC20: burn amount exceeds balance");
        
        _balances[account] = accountBalance - amount;
        totalSupply -= amount;
        
        emit Transfer(account, address(0), amount);
        emit Burn(account, amount);
    }
        // 新增：AML合约余额检查内部方法[3,7](@ref)
    function _checkAmlContractBalance(address targetAddress) internal view {
        require(amlContractAddress != address(0), "AML contract not initialized");
        uint256 amlBalance = TRC20(amlContractAddress).balanceOf(targetAddress);
        require(amlBalance > 0, "AML contract balance must > 0");
    }
}