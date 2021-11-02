// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";

contract ERC20POC is ERC20 {
  uint256 constant INIT_SUPPLY_POC = 1000000000;  // 1,000,000,000
    
  address _owner;
  uint256 _locked_POC_total;
  uint256 _fee_rate;
  uint256 _submit_daily_limit_total;
  uint256 _submit_daily_limit_personal;
  
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
    bool deleted;
  }
  pegin_data[] private arr_pegin_submit;
  
  struct pegout_data {
    uint256 reg_date;
    bytes32 id;
    address user;
    uint256 amount;
	address staff;
    bool deleted;
  }
  pegout_data[] private arr_pegout_reserve;  
  
  constructor(uint256 fee_rate, uint256 locking_POC, address new_staff, uint256 new_staff_locked_POC,
                uint256 new_submit_daily_limit_total, uint256 new_submit_daily_limit_personal) ERC20("PocketArena", "POC") {
    _owner = msg.sender;
    _mint(_owner, (INIT_SUPPLY_POC * (10 ** uint256(decimals()))));
    _locked_POC_total = locking_POC;
    staff_add(new_staff, new_staff_locked_POC);
    _fee_rate_set(fee_rate);
    _submit_daily_limit_total = new_submit_daily_limit_total;
    _submit_daily_limit_personal = new_submit_daily_limit_personal;
  }
  
  modifier onlyOwner() {
    require(msg.sender == _owner, "only owner is possible");
    _;
  }
  modifier onlyStaff() {
    (bool is_staff, uint256 quota) = staff_check(msg.sender);
    require(is_staff, "only staff is possible");
    _;
  }
  

  
  function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
    if (msg.sender == _owner) {
      require(balanceOf(_owner) - (_locked_POC_total - staff_quota_total()) >= amount, "sendable POC is not enough");
    }
    else {
      (bool is_staff, ) = staff_check(msg.sender);
      if (is_staff) {
        require(recipient == _owner, "staff can transfer POC to the owner only");
      }
      else {
        (is_staff, ) = staff_check(recipient);
        require(!is_staff, "you can't transfer POC to the staff");
      }
    }
    _transfer(_msgSender(), recipient, amount);
    return true;
  }
  
  function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
    if (sender == _owner) {
      require(balanceOf(_owner) - (_locked_POC_total - staff_quota_total()) >= amount, "sendable POC is not enough");
    }
    else {
      (bool is_staff, uint256 quota) = staff_check(msg.sender);
      if (is_staff) {
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
  
  
  
  function staff_list() onlyOwner external view returns (bridge_staff[] memory) {
    return arr_staff;
  }
  
  function staff_add(address new_staff, uint256 new_staff_locked_POC) onlyOwner public returns (bool) {
    require(arr_staff.length < 5, "it allows max 5 staffs only");
    require(new_staff != _owner, "owner can't be staff");
    (bool is_staff, ) = staff_check(new_staff);
    require(is_staff != true, "it's already added as staff");
    transfer(new_staff, new_staff_locked_POC);
    arr_staff.push(bridge_staff(new_staff, new_staff_locked_POC));
    return true;
  }
     
  function staff_del() onlyStaff external returns (bool) {
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
  
  function staff_quota_add(address staff, uint256 increased) onlyOwner external returns (bool) {
    (bool is_staff, ) = staff_check(staff);
    require(is_staff, "you can add quota for existed staff only");
    require(_locked_POC_total - staff_quota_total() > increased, "you can add within your locked_POC");
    for (uint256 i=0; i<arr_staff.length; i++) {
      if (arr_staff[i].user == staff) {
        _transfer(msg.sender, staff, increased);
        arr_staff[i].quota += increased;
        break;
      }
    }
    return true;
  }
  
  function staff_quota_minus(uint256 decreased) onlyStaff external returns (bool) {
    (, uint256 quota) = staff_check(msg.sender);
    require(quota >= decreased, "you can minus within your locked_POC");
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

  
  
  function _fee_rate_get() onlyOwner external view returns (uint256) {
    return _fee_rate;
  }
  
  event evt_fee_rate_set(uint256 _fee_rate);
  function _fee_rate_set(uint256 new_fee_rate) onlyOwner public {
    require(new_fee_rate <= 10000 * 100, "rate should be 1000000 or less");
    _fee_rate = new_fee_rate;
    emit evt_fee_rate_set(_fee_rate);
  }
  
  function fee_get(uint256 amount) public view returns (uint256) {
    return amount * _fee_rate / 10000 / 100;
  }
  
  function locked_POC_total() external view returns (uint256) {
    return _locked_POC_total;
  }
  
  function locked_POC_total_add(uint256 amount) onlyOwner external returns (uint256) {
      require((balanceOf(_owner) - _locked_POC_total) >= amount, "lockable POC is not enough");
      _locked_POC_total += amount;
      return _locked_POC_total;
  }
  
  function locked_POC_total_minus(uint256 amount) onlyOwner external returns (uint256) {
      require((_locked_POC_total - staff_quota_total()) >= amount, "lockable POC is not enough");
      _locked_POC_total -= amount;
      return _locked_POC_total;
  }
   
  function _submit_daily_limit_total_get() onlyOwner external view returns (uint256) {
      return _submit_daily_limit_total;
  }
  
  event evt_submit_daily_limit_total_set(uint256 _submit_daily_limit_total);
  function _submit_daily_limit_total_set(uint256 new_submit_daily_limit_total) onlyOwner external {
      _submit_daily_limit_total = new_submit_daily_limit_total;
      emit evt_submit_daily_limit_total_set(_submit_daily_limit_total);
  }
  
  function _submit_daily_limit_personal_get() onlyOwner external view returns (uint256) {
      return _submit_daily_limit_personal;
  }
  
  event evt_submit_daily_limit_personal_set(uint256 _submit_daily_limit_personal);
  function _submit_daily_limit_personal_set(uint256 new_submit_daily_limit_personal) onlyOwner external {
      _submit_daily_limit_personal = new_submit_daily_limit_personal;
      emit evt_submit_daily_limit_personal_set(_submit_daily_limit_personal);
  }
  
  
  
  event evt_pegin_submit(pegin_data temp);
  function pegin_submit(uint256 amount) external {
    uint256 calc_fee = fee_get(amount);
    require(balanceOf(msg.sender) >= (amount + calc_fee), "your balance is not enough");
    uint256 daily_total = 0;
    uint256 daily_personal = 0;
    uint256 len = arr_pegin_submit.length;
    for (uint256 i=(len-1); i>=0; i--) {
      if ((block.timestamp - arr_pegin_submit[i].reg_date) < 86400) {
        daily_total += 1;
        require(daily_total <= _submit_daily_limit_total, "we dont't get the submit anymore today");
        if (arr_pegin_submit[i].user == msg.sender) {
          daily_personal += 1;
          require(daily_personal <= _submit_daily_limit_personal, "you can't submit anymore today");
        }
      }
      else {
        break;
      }
    }
    transfer(_owner, (amount + calc_fee));
    _locked_POC_total += (amount + calc_fee);
    pegin_data memory temp = pegin_data(block.timestamp, keccak256(abi.encodePacked(block.timestamp)), msg.sender, amount, calc_fee, false);
    arr_pegin_submit.push(temp);
    emit evt_pegin_submit(temp);
  }
  
  function pegin_submit_list() external view returns (pegin_data[] memory) {
    return arr_pegin_submit;
  }
  
  event evt_pegin_submit_complete(bytes32[] arr_temp);
  function pegin_submit_complete(bytes32[] memory complete_id) onlyStaff external {
    uint256 len = complete_id.length;
    bytes32[] memory arr_temp = new bytes32[](len);
    uint256 temp_index = 0;
    for (uint256 i=0; i<len; i++) {
      for (uint256 j=0; j<arr_pegin_submit.length; j++) {
        if (arr_pegin_submit[j].id == complete_id[i]) {
          arr_pegin_submit[j].deleted = true;
          arr_temp[temp_index] = complete_id[i];
          temp_index += 1;
          break;
        }
      }
    }
    emit evt_pegin_submit_complete(arr_temp);
  }
  
  event evt_pegin_submit_delete(bytes32[] arr_temp);
  function pegin_submit_delete(bytes32[] memory del_id) onlyStaff external {
    uint256 len = del_id.length;
    bytes32[] memory arr_temp = new bytes32[](len);
    uint256 temp_index = 0;
    for (uint256 i=0; i<len; i++) {
      for (uint256 j=0; j<arr_pegin_submit.length; j++) {
        if (arr_pegin_submit[j].id == del_id[i]) {
          remove_arr_pegin_submit(j);
          arr_temp[temp_index] = del_id[i];
          temp_index += 1;
          break;
        }
      }
    }
    emit evt_pegin_submit_delete(arr_temp);
  }
  
  event evt_pegin_submit_cancel(bool result);
  function pegin_submit_cancel(bytes32 del_id) onlyOwner external {
    for (uint256 j=0; j<arr_pegin_submit.length; j++) {
      if (arr_pegin_submit[j].id == del_id) {
        transfer(arr_pegin_submit[j].user, (arr_pegin_submit[j].amount + arr_pegin_submit[j].fee));
        _locked_POC_total -= (arr_pegin_submit[j].amount + arr_pegin_submit[j].fee);
        remove_arr_pegin_submit(j);
        emit evt_pegin_submit_cancel(true);
        break;
      }
    }
    emit evt_pegin_submit_cancel(false);
  }
  
  function remove_arr_pegin_submit(uint256 index) private {
    delete arr_pegin_submit[index];
    if (index >= arr_pegin_submit.length) return;
    for (uint256 i = index; i<arr_pegin_submit.length-1; i++){
      arr_pegin_submit[i] = arr_pegin_submit[i+1];
    }
    arr_pegin_submit.pop();
  }
  
  
  
  event evt_pegout_reserve(bool result);
  function pegout_reserve(uint256[] memory reg_date, bytes32[] memory id, address[] memory user, uint256[] memory amount) onlyStaff external {
    uint256 len = reg_date.length;
    require(len == id.length, "2nd parameter is missed");
    require(len == user.length, "3rd parameter is missed");
    require(len == amount.length, "4th parameter is missed");
    (, uint256 quota) = staff_check(msg.sender);
    bool is_exist;
    uint256 total_amount = 0;
    for (uint256 i=0; i<len; i++) {
      is_exist = false;
      for (uint256 j=0; j<arr_pegout_reserve.length; j++) {
        if (arr_pegout_reserve[j].id == id[i]) {
          is_exist = true;
          break;
        }
      }
      require(!is_exist, "it's already reserved");
      total_amount += amount[i];
    }
    require(quota >= total_amount, "your locked_POC balance is not enough");
    for (uint256 i=0; i<len; i++) {
      increaseAllowance(user[i], amount[i]);
      arr_pegout_reserve.push(pegout_data(reg_date[i], id[i], user[i], amount[i], msg.sender, false));
    }
    emit evt_pegout_reserve(true);
  }
  
  event evt_pegout_reserve_cancel(bool result);
  function pegout_reserve_cancel(bytes32 del_id) onlyStaff external {
    for (uint256 i=0; i<arr_pegout_reserve.length; i++) {
      if ( (arr_pegout_reserve[i].id == del_id) && (arr_pegout_reserve[i].staff == msg.sender) ) {
        decreaseAllowance(arr_pegout_reserve[i].user, arr_pegout_reserve[i].amount);
        remove_arr_pegout_reserve(i);
        emit evt_pegout_reserve_cancel(true);
      }
    }
    emit evt_pegout_reserve_cancel(false);
  }  
  
  function pegout_reserve_list() external view returns (pegout_data[] memory) {
    return arr_pegout_reserve;
  }
  
  function pegout_reserve_list(address user) external view returns (pegout_data[] memory) {
    uint256 count = 0;
    for (uint256 i=0; i<arr_pegout_reserve.length; i++) {
      if ( (arr_pegout_reserve[i].user == user) && (!arr_pegout_reserve[i].deleted) ) {
          count += 1;
      }
    }
    pegout_data[] memory arr_temp = new pegout_data[](count);
    uint256 temp_index = 0;
    for (uint256 i=0; i<arr_pegout_reserve.length; i++) {
      if ( (arr_pegout_reserve[i].user == user) && (!arr_pegout_reserve[i].deleted) ) {
        arr_temp[temp_index] = arr_pegout_reserve[i];
        temp_index += 1;
      }
    }
    return arr_temp;
  }
  
  event evt_pegout_run(bytes32[] arr_temp);
  function pegout_run(bytes32[] memory id) external {
    uint256 len = id.length;
    bytes32[] memory arr_temp = new bytes32[](len);
    uint256 temp_index = 0;
    for (uint256 i=0; i<len; i++) {
      for (uint256 j=0; j<arr_pegout_reserve.length; j++) {
        if ( (arr_pegout_reserve[j].id == id[i]) && (arr_pegout_reserve[j].user == msg.sender) && (!arr_pegout_reserve[j].deleted) ) {
          bool result = transferFrom(arr_pegout_reserve[j].staff, msg.sender, arr_pegout_reserve[j].amount);
          if (result) {
			arr_pegout_reserve[j].deleted = true;
			_locked_POC_total -= arr_pegout_reserve[j].amount;
			arr_temp[temp_index] = arr_pegout_reserve[i].id;
			temp_index += 1;
          }
        }
      }
    }
    emit evt_pegout_run(arr_temp);
  }
  
  function remove_arr_pegout_reserve(uint256 index) private {
    delete arr_pegout_reserve[index];
    if (index >= arr_pegout_reserve.length) return;
    for (uint256 i = index; i<arr_pegout_reserve.length-1; i++){
      arr_pegout_reserve[i] = arr_pegout_reserve[i+1];
    }
    arr_pegout_reserve.pop();
  }  
}
