def storage:
  stor0 is uint256 at storage 0
  tokenAddress is addr at storage 1
  walletAddress is addr at storage 2
  rate is uint256 at storage 3
  weiRaised is uint256 at storage 4
  openingTime is uint256 at storage 5
  closingTime is uint256 at storage 6
  finalized is uint8 at storage 7
  goal is uint256 at storage 8
  stor9 is addr at storage 9
  balanceOf is mapping of uint256 at storage 10
  stor11 is addr at storage 11
  cap is uint256 at storage 12
  owner is addr at storage 13

def rate(): # not payable
  return rate

def cap(): # not payable
  return cap

def goal(): # not payable
  return goal

def weiRaised(): # not payable
  return weiRaised

def closingTime(): # not payable
  return closingTime

def wallet(): # not payable
  return walletAddress

def balanceOf(address _owner): # not payable
  require calldata.size - 4 >= 32
  return balanceOf[addr(_owner)]

def owner(): # not payable
  return owner

def finalized(): # not payable
  return bool(finalized)

def openingTime(): # not payable
  return openingTime

def token(): # not payable
  return tokenAddress

#
#  Regular functions
#

def isOwner(): # not payable
  return (caller == owner)

def capReached(): # not payable
  return weiRaised >= cap

def goalReached(): # not payable
  return weiRaised >= goal

def hasClosed(): # not payable
  return (block.timestamp > closingTime)

def isOpen(): # not payable
  if block.timestamp < openingTime:
      return block.timestamp >= openingTime
  return block.timestamp <= closingTime

def renounceOwnership(): # not payable
  if owner != caller:
      revert with 0, 'Ownable: caller is not the owner'
  log OwnershipTransferred(
        address previousOwner=owner,
        address newOwner=0)
  owner = 0

def transferOwnership(address _newOwner): # not payable
  require calldata.size - 4 >= 32
  if owner != caller:
      revert with 0, 'Ownable: caller is not the owner'
  if not _newOwner:
      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, 'Ownable: new owner is the zero address'
  log OwnershipTransferred(
        address previousOwner=owner,
        address newOwner=_newOwner)
  owner = _newOwner

def claimRefund(address _token): # not payable
  require calldata.size - 4 >= 32
  if not finalized:
      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, 'RefundableCrowdsale: not finalized'
  if weiRaised >= goal:
      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, 'RefundableCrowdsale: goal reached'
  require ext_code.size(stor9)
  call stor9.withdraw(address recipient) with:
       gas gas_remaining wei
      args _token
  if not ext_call.success:
      revert with ext_call.return_data[0 len return_data.size]

def finalize(): # not payable
  if finalized:
      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, 'FinalizableCrowdsale: already finalized'
  if block.timestamp <= closingTime:
      revert with 0, 'FinalizableCrowdsale: not closed'
  finalized = 1
  require ext_code.size(stor9)
  if weiRaised < goal:
      call stor9.enableRefunds() with:
           gas gas_remaining wei
  else:
      call stor9.close() with:
           gas gas_remaining wei
      if not ext_call.success:
          revert with ext_call.return_data[0 len return_data.size]
      require ext_code.size(stor9)
      call stor9.beneficiaryWithdraw() with:
           gas gas_remaining wei
  if not ext_call.success:
      revert with ext_call.return_data[0 len return_data.size]
  log CrowdsaleFinalized()

def withdrawTokens(address _addr): # not payable
  require calldata.size - 4 >= 32
  if not finalized:
      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, 'RefundablePostDeliveryCrowdsale: not finalized'
  if weiRaised < goal:
      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, 'RefundablePostDeliveryCrowdsale: goal not reached'
  if block.timestamp <= closingTime:
      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, 'PostDeliveryCrowdsale: not closed'
  if balanceOf[addr(_addr)] <= 0:
      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, 
                  'PostDeliveryCrowdsale: beneficiary is not due any tokens'
  balanceOf[addr(_addr)] = 0
  require ext_code.size(stor11)
  call stor11.transfer(address tokenAddress, address to, uint256 amount) with:
       gas gas_remaining wei
      args tokenAddress, addr(_addr), balanceOf[addr(_addr)]
  if not ext_call.success:
      revert with ext_call.return_data[0 len return_data.size]

def _fallback() payable: # default function
  stor0++
  if block.timestamp < openingTime:
      revert with 0, 'TimedCrowdsale: not open'
  else:
      if block.timestamp > closingTime:
          revert with 0, 'TimedCrowdsale: not open'
      else:
          if not caller:
              revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, 'Crowdsale: beneficiary is the zero address'
          else:
              if not call.value:
                  revert with 0, 'Crowdsale: weiAmount is 0'
              else:
                  if weiRaised + call.value < weiRaised:
                      revert with 0, 'SafeMath: addition overflow'
                  else:
                      if weiRaised + call.value > cap:
                          revert with 0, 'CappedCrowdsale: cap exceeded'
                      else:
                          if call.value:
                              require call.value
                              if call.value * rate / call.value != rate:
                                  revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, 'SafeMath: multiplication overflow'
                              else:
                                  if weiRaised + call.value < weiRaised:
                                      revert with 0, 'SafeMath: addition overflow'
                                  else:
                                      weiRaised += call.value
                                      if balanceOf[caller] + (call.value * rate) < balanceOf[caller]:
                                          revert with 0, 'SafeMath: addition overflow'
                                      else:
                                          balanceOf[caller] += call.value * rate
                                          require ext_code.size(tokenAddress)
                                          call tokenAddress.mint(address to, uint256 amount) with:
                                               gas gas_remaining wei
                                              args stor11, call.value * rate
                                          if not ext_call.success:
                                              revert with ext_call.return_data[0 len return_data.size]
                                          else:
                                              require return_data.size >= 32
                                              if not ext_call.return_data[0]:
                                                  revert with 0, 'MintedCrowdsale: minting failed'
                                              else:
                                                  log TokensPurchased(
                                                        address purchaser=call.value,
                                                        address beneficiary=call.value * rate,
                                                        uint256 value=caller,
                                                        uint256 amount=caller)
                                                  require ext_code.size(stor9)
                                                  call stor9.deposit(address addr) with:
                                                     value call.value wei
                                                       gas gas_remaining wei
                                                      args caller
                                                  if not ext_call.success:
                                                      revert with ext_call.return_data[0 len return_data.size]
                                                  else:
                                                      if stor0 != stor0:
                                                          revert with 0, 'ReentrancyGuard: reentrant call'
                                                      else:
                                                          stop
                          else:
                              if weiRaised + call.value < weiRaised:
                                  revert with 0, 'SafeMath: addition overflow'
                              else:
                                  weiRaised += call.value
                                  if balanceOf[caller] < balanceOf[caller]:
                                      revert with 0, 'SafeMath: addition overflow'
                                  else:
                                      require ext_code.size(tokenAddress)
                                      call tokenAddress.mint(address to, uint256 amount) with:
                                           gas gas_remaining wei
                                          args stor11, 0
                                      if not ext_call.success:
                                          revert with ext_call.return_data[0 len return_data.size]
                                      else:
                                          require return_data.size >= 32
                                          if not ext_call.return_data[0]:
                                              revert with 0, 'MintedCrowdsale: minting failed'
                                          else:
                                              log TokensPurchased(
                                                    address purchaser=call.value,
                                                    address beneficiary=0,
                                                    uint256 value=caller,
                                                    uint256 amount=caller)
                                              require ext_code.size(stor9)
                                              call stor9.deposit(address addr) with:
                                                 value call.value wei
                                                   gas gas_remaining wei
                                                  args caller
                                              if not ext_call.success:
                                                  revert with ext_call.return_data[0 len return_data.size]
                                              else:
                                                  if stor0 != stor0:
                                                      revert with 0, 'ReentrancyGuard: reentrant call'
                                                  else:
                                                      stop

def buyTokens(address _beneficiary) payable: 
  require calldata.size - 4 >= 32
  stor0++
  if block.timestamp < openingTime:
      revert with 0, 'TimedCrowdsale: not open'
  else:
      if block.timestamp > closingTime:
          revert with 0, 'TimedCrowdsale: not open'
      else:
          if not _beneficiary:
              revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, 'Crowdsale: beneficiary is the zero address'
          else:
              if not call.value:
                  revert with 0, 'Crowdsale: weiAmount is 0'
              else:
                  if weiRaised + call.value < weiRaised:
                      revert with 0, 'SafeMath: addition overflow'
                  else:
                      if weiRaised + call.value > cap:
                          revert with 0, 'CappedCrowdsale: cap exceeded'
                      else:
                          if call.value:
                              require call.value
                              if call.value * rate / call.value != rate:
                                  revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, 'SafeMath: multiplication overflow'
                              else:
                                  if weiRaised + call.value < weiRaised:
                                      revert with 0, 'SafeMath: addition overflow'
                                  else:
                                      weiRaised += call.value
                                      if balanceOf[addr(_beneficiary)] + (call.value * rate) < balanceOf[addr(_beneficiary)]:
                                          revert with 0, 'SafeMath: addition overflow'
                                      else:
                                          balanceOf[addr(_beneficiary)] += call.value * rate
                                          require ext_code.size(tokenAddress)
                                          call tokenAddress.mint(address to, uint256 amount) with:
                                               gas gas_remaining wei
                                              args stor11, call.value * rate
                                          if not ext_call.success:
                                              revert with ext_call.return_data[0 len return_data.size]
                                          else:
                                              require return_data.size >= 32
                                              if not ext_call.return_data[0]:
                                                  revert with 0, 'MintedCrowdsale: minting failed'
                                              else:
                                                  log TokensPurchased(
                                                        address purchaser=call.value,
                                                        address beneficiary=call.value * rate,
                                                        uint256 value=caller,
                                                        uint256 amount=_beneficiary)
                                                  require ext_code.size(stor9)
                                                  call stor9.deposit(address addr) with:
                                                     value call.value wei
                                                       gas gas_remaining wei
                                                      args caller
                                                  if not ext_call.success:
                                                      revert with ext_call.return_data[0 len return_data.size]
                                                  else:
                                                      if stor0 != stor0:
                                                          revert with 0, 'ReentrancyGuard: reentrant call'
                                                      else:
                                                          stop
                          else:
                              if weiRaised + call.value < weiRaised:
                                  revert with 0, 'SafeMath: addition overflow'
                              else:
                                  weiRaised += call.value
                                  if balanceOf[addr(_beneficiary)] < balanceOf[addr(_beneficiary)]:
                                      revert with 0, 'SafeMath: addition overflow'
                                  else:
                                      require ext_code.size(tokenAddress)
                                      call tokenAddress.mint(address to, uint256 amount) with:
                                           gas gas_remaining wei
                                          args stor11, 0
                                      if not ext_call.success:
                                          revert with ext_call.return_data[0 len return_data.size]
                                      else:
                                          require return_data.size >= 32
                                          if not ext_call.return_data[0]:
                                              revert with 0, 'MintedCrowdsale: minting failed'
                                          else:
                                              log TokensPurchased(
                                                    address purchaser=call.value,
                                                    address beneficiary=0,
                                                    uint256 value=caller,
                                                    uint256 amount=_beneficiary)
                                              require ext_code.size(stor9)
                                              call stor9.deposit(address addr) with:
                                                 value call.value wei
                                                   gas gas_remaining wei
                                                  args caller
                                              if not ext_call.success:
                                                  revert with ext_call.return_data[0 len return_data.size]
                                              else:
                                                  if stor0 != stor0:
                                                      revert with 0, 'ReentrancyGuard: reentrant call'
                                                  else:
                                                      stop

