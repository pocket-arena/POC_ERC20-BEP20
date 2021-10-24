// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";

contract BEP20POC is ERC20 {
  uint256 constant INIT_SUPPLY_POC = 1000000000;  // 1,000,000,000
    
  address _owner;
  uint256 _unlocked_POC_total;
  uint256 _fee_rate;
  uint256 _fee_income;
    
  struct bridge_staff {
    address user;
    uint256 quota;
  }
  bridge_staff[] private arr_staff;
  
  struct pegin_data {
    uint256 reg_date;
    bytes32 id;
    address user;
    uint256 amount;
    uint256 fee;
    address staff;
    bool deleted;
  }
  pegin_data[] private arr_pegin_reserve;
  
  struct pegout_data {
    uint256 reg_date;
    bytes32 id;
    address user;
    uint256 amount;
    uint256 fee;
    bool deleted;
  }
  pegout_data[] private arr_pegout_submit;
  
  constructor(uint256 fee_rate, uint256 unlocking_POC, address new_staff, uint256 new_staff_unlocked_POC) ERC20("PocketArena", "POC") {
    _owner = msg.sender;
    _mint(_owner, (INIT_SUPPLY_POC * (10 ** uint256(decimals()))));
    _unlocked_POC_total = unlocking_POC;
    _fee_income = 0;
    staff_add(new_staff, new_staff_unlocked_POC);
    _fee_rate_set(fee_rate);
  }
  
  modifier onlyOwner() {
    require(msg.sender == _owner, "only owner is possible");
    _;
  }
  modifier onlyStaff() {
    (bool is_staff, uint256 quota) = staff_check(msg.sender);
    require(is_staff == true, "only staff is possible");
    _;
  }
  
  
  
  function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
    if (msg.sender == _owner) {
      require(balanceOf(_owner) - (_unlocked_POC_total - staff_quota_total()) >= amount, "sendable POC is not enough");
    }
    else {
      (bool is_staff, ) = staff_check(msg.sender);
      if (is_staff == true) {
        require(recipient == _owner, "staff can transfer POC to the owner only");
      }
      else {
        (is_staff, ) = staff_check(recipient);
        require(is_staff == false, "you can't transfer POC to the staff");
      }
    }
    _transfer(_msgSender(), recipient, amount);
    return true;
  }
  
  function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
    if (sender == _owner) {
      require(balanceOf(_owner) - (_unlocked_POC_total - staff_quota_total()) >= amount, "sendable POC is not enough");
    }
    else {
      (bool is_staff, uint256 quota) = staff_check(msg.sender);
      if (is_staff == true) {
        require(quota >= amount, "staff can transferFrom POC within quota");
      }
    }
    _transfer(sender, recipient, amount);
    uint256 currentAllowance = allowance(sender, _msgSender());
    require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
    unchecked {
      _approve(sender, _msgSender(), currentAllowance - amount);
    }
    return true;
  }
  


  function staff_list() onlyOwner public view returns (bridge_staff[] memory) {
    return arr_staff;
  }
  
  function staff_add(address new_staff, uint256 new_staff_unlocked_POC) onlyOwner public returns (bool) {
    require(arr_staff.length < 5, "it allows max 5 staffs only");
    require(new_staff != _owner, "owner can't be staff");
    (bool is_staff, ) = staff_check(new_staff);
    require(is_staff != true, "it's already added as staff");
    transfer(new_staff, new_staff_unlocked_POC);
    arr_staff.push(bridge_staff(new_staff, new_staff_unlocked_POC));
    return true;
  }
    
  function staff_del() onlyStaff public returns (bool) {
    uint256 del_index = arr_staff.length + 1;
    for (uint256 i=0; i<arr_staff.length; i++) {
      if (arr_staff[i].user == msg.sender) {
        transfer(_owner, balanceOf(msg.sender));
        delete arr_staff[i];
        del_index = i;
        break;
      }
    }
    if (del_index >= (arr_staff.length + 1)) {
      return false;
    }
    else {
      for (uint256 i=del_index; i<arr_staff.length-1; i++){
        arr_staff[i] = arr_staff[i+1];
      }
      arr_staff.pop();
      return true;
    }
  }
  
  function staff_check(address user) public view returns (bool, uint256) {
    bool is_staff = false;
    uint256 quota = 0;
    for (uint256 i=0; i<arr_staff.length; i++) {
      if (arr_staff[i].user == user) {
          is_staff = true;
          quota = arr_staff[i].quota;
          break;
      }
    }
    return (is_staff, quota);
  }
  
  function staff_quota_add(address staff, uint256 increased) onlyOwner public returns (bool) {
    (bool is_staff, ) = staff_check(staff);
    require(is_staff == true, "you can add quota for existed staff only");
    require(_unlocked_POC_total - staff_quota_total() > increased, "you can add within your unlocked_POC");
    for (uint256 i=0; i<arr_staff.length; i++) {
      if (arr_staff[i].user == staff) {
        _transfer(msg.sender, staff, increased);
        arr_staff[i].quota += increased;
        break;
      }
    }
    return true;
  }
  
  function staff_quota_minus(uint256 decreased) onlyStaff public returns (bool) {
    (, uint256 quota) = staff_check(msg.sender);
    require(quota >= decreased, "you can minus within your unlocked_POC");
    for (uint256 i=0; i<arr_staff.length; i++) {
      if (arr_staff[i].user == msg.sender) {
        transfer(_owner, decreased);
        arr_staff[i].quota -= decreased;
        break;
      }
    }
    return true;
  }
  
  function staff_quota_total() onlyOwner public view returns (uint256) {
    uint256 total = 0;
    for (uint256 i=0; i<arr_staff.length; i++) {
      total += arr_staff[i].quota;  
    }
    return total;
  }

  
  
  function _fee_rate_get() onlyOwner public view returns (uint256) {
    return _fee_rate;
  }
  
  function _fee_rate_set(uint256 new_fee_rate) onlyOwner public returns (uint256) {
    require(new_fee_rate <= 1000000, "rate should be 1000000 or less");
    _fee_rate = new_fee_rate;
    return _fee_rate;
  }
  
  function fee_get(uint256 amount) public view returns (uint256) {
    return amount * _fee_rate / 10000 / 100;
  }
  
  function fee_income() public view returns (uint256) {
    return _fee_income;
  }
  
  function unlocked_POC_total() public view returns (uint256) {
    return _unlocked_POC_total;
  }
  
  function unlocked_POC_total_add(uint256 amount) onlyOwner public returns (uint256) {
    require((balanceOf(_owner) - _unlocked_POC_total) >= amount, "unlockable POC is not enough");
    _unlocked_POC_total += amount;
    return _unlocked_POC_total;
  }
  
  function unlocked_POC_total_minus(uint256 amount) onlyOwner public returns (uint256) {
      require((_unlocked_POC_total - staff_quota_total()) >= amount, "unlockable POC is not enough");
      _unlocked_POC_total -= amount;
      return _unlocked_POC_total;
  }
  
  
  
  function pegout_submit(uint256 amount) public returns (pegout_data memory) {
    uint256 calc_fee = fee_get(amount);
    require(balanceOf(msg.sender) >= (amount + calc_fee), "your balance is not enough");
    transfer(_owner, (amount + calc_fee));
    _unlocked_POC_total += amount;
    _fee_income += calc_fee;
    pegout_data memory temp = pegout_data(block.timestamp, keccak256(abi.encodePacked(block.timestamp)), msg.sender, amount, calc_fee, false);
    arr_pegout_submit.push(temp);
    return temp;
  }
  
  function pegout_submit_list() public view returns (pegout_data[] memory) {
    return arr_pegout_submit;
  }
  
  function pegout_submit_complete(bytes32[] memory complete_id) onlyStaff public returns (bytes32[] memory) {
    uint256 len = complete_id.length;
    bytes32[] memory arr_temp = new bytes32[](len);
    uint256 temp_index = 0;
    for (uint256 i=0; i<len; i++) {
      for (uint256 j=0; j<arr_pegout_submit.length; j++) {
        if (arr_pegout_submit[j].id == complete_id[i]) {
          arr_pegout_submit[j].deleted = true;
          arr_temp[temp_index] = complete_id[i];
          temp_index += 1;
          break;
        }
      }
    }
    return arr_temp;
  }
  
  function pegout_submit_delete(bytes32[] memory del_id) onlyStaff public returns (bytes32[] memory) {
    uint256 len = del_id.length;
    bytes32[] memory arr_temp = new bytes32[](len);
    uint256 temp_index = 0;
    for (uint256 i=0; i<len; i++) {
      for (uint256 j=0; j<arr_pegout_submit.length; j++) {
        if (arr_pegout_submit[j].id == del_id[i]) {
          remove_arr_pegout_submit(j);
          arr_temp[temp_index] = del_id[i];
          temp_index += 1;
          break;
        }
      }
    }
    return arr_temp;
  }
  
  function pegout_submit_cancel(bytes32 del_id) onlyOwner public returns (bool) {
    for (uint256 j=0; j<arr_pegout_submit.length; j++) {
      if (arr_pegout_submit[j].id == del_id) {
        transfer(arr_pegout_submit[j].user, (arr_pegout_submit[j].amount + arr_pegout_submit[j].fee));
        _unlocked_POC_total -= arr_pegout_submit[j].amount;
        _fee_income -= arr_pegout_submit[j].fee;
        remove_arr_pegout_submit(j);
        break;
      }
    }
    return true;
  }
  
  function remove_arr_pegout_submit(uint256 index) private {
    delete arr_pegout_submit[index];
    if (index >= arr_pegout_submit.length) return;
    for (uint256 i = index; i<arr_pegout_submit.length-1; i++){
      arr_pegout_submit[i] = arr_pegout_submit[i+1];
    }
    arr_pegout_submit.pop();
  }

  
  
  function pegin_reserve(uint256[] memory reg_date, bytes32[] memory id, address[] memory user, uint256[] memory amount, uint256[] memory fee) onlyStaff public returns (bool) {
    uint256 len = reg_date.length;
    require(len == id.length, "2nd parameter is missed");
    require(len == user.length, "3rd parameter is missed");
    require(len == amount.length, "4th parameter is missed");
    require(len == fee.length, "5th parameter is missed");
    (, uint256 quota) = staff_check(msg.sender);
    bool is_exist;
    uint256 total_amount = 0;
    for (uint256 i=0; i<len; i++) {
      is_exist = false;
      for (uint256 j=0; j<arr_pegin_reserve.length; j++) {
        if (arr_pegin_reserve[j].id == id[i]) {
          is_exist = true;
          break;
        }
      }
      require(is_exist == false, "it's already reserved");
      total_amount += amount[i];
    }
    require(quota >= total_amount, "your unlocked_POC balance is not enough");
    for (uint256 i=0; i<len; i++) {
      increaseAllowance(user[i], amount[i]);
      arr_pegin_reserve.push(pegin_data(reg_date[i], id[i], user[i], amount[i], fee[i], msg.sender, false));
    }
    return true;
  }
  
  function pegin_reserve_cancel(bytes32 del_id) onlyStaff public returns (bool) {
    for (uint256 i=0; i<arr_pegin_reserve.length; i++) {
      if ( (arr_pegin_reserve[i].id == del_id) && (arr_pegin_reserve[i].staff == msg.sender) ) {
        decreaseAllowance(arr_pegin_reserve[i].user, arr_pegin_reserve[i].amount);
        remove_arr_pegin_reserve(i);
        return true;
      }
    }
    return false;
  }
  
  function pegin_reserve_list() public view returns (pegin_data[] memory) {
    return arr_pegin_reserve;
  }
  
  function pegin_reserve_list(address user) public view returns (pegin_data[] memory) {
    uint256 count = 0;
    for (uint256 i=0; i<arr_pegin_reserve.length; i++) {
      if ( (arr_pegin_reserve[i].user == user) && (arr_pegin_reserve[i].deleted == false) ) {
          count += 1;
      }
    }
    pegin_data[] memory arr_temp = new pegin_data[](count);
    uint256 temp_index = 0;
    for (uint256 i=0; i<arr_pegin_reserve.length; i++) {
      if ( (arr_pegin_reserve[i].user == user) && (arr_pegin_reserve[i].deleted == false) ) {
        arr_temp[temp_index] = arr_pegin_reserve[i];
        temp_index += 1;
      }
    }
    return arr_temp;
  }  
  
  function pegin_run(bytes32[] memory id) public returns (bytes32[] memory) {
    uint256 len = id.length;
    bytes32[] memory arr_temp = new bytes32[](len);
    uint256 temp_index = 0;
    for (uint256 i=0; i<len; i++) {
      for (uint256 j=0; j<arr_pegin_reserve.length; j++) {
        if ( (arr_pegin_reserve[j].id == id[i]) && (arr_pegin_reserve[j].user == msg.sender) && (arr_pegin_reserve[j].deleted == false) ) {
          bool result = transferFrom(arr_pegin_reserve[j].staff, msg.sender, arr_pegin_reserve[j].amount);
          if (result) {
            arr_pegin_reserve[j].deleted = true;
            _unlocked_POC_total += arr_pegin_reserve[j].amount;
            _fee_income += arr_pegin_reserve[j].fee;
			arr_temp[temp_index] = arr_pegin_reserve[i].id;
			temp_index += 1;
          }
        }
      }
    }
    return arr_temp;
  }
  
  function remove_arr_pegin_reserve(uint256 index) private {
    delete arr_pegin_reserve[index];
    if (index >= arr_pegin_reserve.length) return;
    for (uint256 i = index; i<arr_pegin_reserve.length-1; i++){
      arr_pegin_reserve[i] = arr_pegin_reserve[i+1];
    }
    arr_pegin_reserve.pop();
  }  
}
