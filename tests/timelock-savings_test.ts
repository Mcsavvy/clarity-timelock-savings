import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
  name: "Can create a savings account",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet1 = accounts.get('wallet_1')!;
    
    let block = chain.mineBlock([
      Tx.contractCall('timelock-savings', 'create-account', [types.uint(30)], wallet1.address)
    ]);
    
    assertEquals(block.receipts[0].result.expectOk(), true);
  },
});

Clarinet.test({
  name: "Can deposit and withdraw after lock period",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet1 = accounts.get('wallet_1')!;
    
    let block = chain.mineBlock([
      Tx.contractCall('timelock-savings', 'create-account', [types.uint(30)], wallet1.address),
      Tx.contractCall('timelock-savings', 'deposit', [types.uint(1000)], wallet1.address)
    ]);
    
    assertEquals(block.receipts[1].result.expectOk(), true);

    chain.mineEmptyBlockUntil(30);

    block = chain.mineBlock([
      Tx.contractCall('timelock-savings', 'withdraw', [types.uint(1000)], wallet1.address)
    ]);

    assertEquals(block.receipts[0].result.expectOk(), true);
  },
});

Clarinet.test({
  name: "Cannot withdraw before lock period ends",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet1 = accounts.get('wallet_1')!;
    
    let block = chain.mineBlock([
      Tx.contractCall('timelock-savings', 'create-account', [types.uint(30)], wallet1.address),
      Tx.contractCall('timelock-savings', 'deposit', [types.uint(1000)], wallet1.address)
    ]);
    
    block = chain.mineBlock([
      Tx.contractCall('timelock-savings', 'withdraw', [types.uint(1000)], wallet1.address)
    ]);

    assertEquals(block.receipts[0].result.expectErr(), types.uint(103));
  },
});

Clarinet.test({
  name: "Can set interest rate as contract owner",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    
    let block = chain.mineBlock([
      Tx.contractCall('timelock-savings', 'set-interest-rate', [types.uint(30), types.uint(500)], deployer.address)
    ]);
    
    assertEquals(block.receipts[0].result.expectOk(), true);
  },
});

