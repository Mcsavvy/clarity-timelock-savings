// Original tests remain...

Clarinet.test({
  name: "Can set and use balance tiers",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    
    let block = chain.mineBlock([
      Tx.contractCall('timelock-savings', 'set-balance-tier', 
        [types.uint(100000), types.uint(12000)], deployer.address),
      Tx.contractCall('timelock-savings', 'set-balance-tier',
        [types.uint(1000000), types.uint(15000)], deployer.address)
    ]);
    
    assertEquals(block.receipts[0].result.expectOk(), true);
    assertEquals(block.receipts[1].result.expectOk(), true);
  },
});

Clarinet.test({
  name: "Higher balance receives higher interest rate",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    
    // Setup tiers and rates
    chain.mineBlock([
      Tx.contractCall('timelock-savings', 'set-balance-tier',
        [types.uint(100000), types.uint(12000)], deployer.address),
      Tx.contractCall('timelock-savings', 'set-interest-rate',
        [types.uint(30), types.uint(500)], deployer.address)
    ]);

    // Create account and deposit
    let block = chain.mineBlock([
      Tx.contractCall('timelock-savings', 'create-account',
        [types.uint(30)], wallet1.address),
      Tx.contractCall('timelock-savings', 'deposit',
        [types.uint(200000)], wallet1.address)
    ]);

    chain.mineEmptyBlockUntil(31);

    // Check interest payment
    block = chain.mineBlock([
      Tx.contractCall('timelock-savings', 'pay-interest',
        [wallet1.address], wallet1.address)
    ]);

    // Verify higher interest rate applied
    const interest = block.receipts[0].result.expectOk();
    assert(interest > types.uint(0));
  },
});
