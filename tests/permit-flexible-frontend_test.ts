import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.5.4/index.ts';
import { assertEquals } from 'https://deno.land/std@0.170.0/testing/asserts.ts';

Clarinet.test({
  name: "Verify permit creation and management",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const user1 = accounts.get('wallet_1')!;
    const user2 = accounts.get('wallet_2')!;

    // Test permit creation
    let block = chain.mineBlock([
      Tx.contractCall('permit-flexible-frontend', 'create-flexible-permit', [
        types.principal(user1.address),
        types.list([types.utf8('read'), types.utf8('write')]),
        types.uint(chain.blockHeight),
        types.uint(chain.blockHeight + 10),
        types.bool(true)
      ], deployer.address)
    ]);

    // Verify permit creation result
    assertEquals(block.receipts[0].result.type, 'ok');
    const permitId = block.receipts[0].result.value;

    // Check permissions
    block = chain.mineBlock([
      Tx.contractCall('permit-flexible-frontend', 'has-permission', [
        types.principal(user1.address), 
        types.utf8('read')
      ], deployer.address)
    ]);

    assertEquals(block.receipts[0].result, '(ok true)');

    // Test permit revocation
    block = chain.mineBlock([
      Tx.contractCall('permit-flexible-frontend', 'revoke-permit', [
        types.uint(permitId)
      ], deployer.address)
    ]);

    assertEquals(block.receipts[0].result, '(ok true)');
  }
});

Clarinet.test({
  name: "Validate permit constraints and edge cases",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const user1 = accounts.get('wallet_1')!;

    // Test invalid permit configuration
    let block = chain.mineBlock([
      Tx.contractCall('permit-flexible-frontend', 'create-flexible-permit', [
        types.principal(user1.address),
        types.list([]),  // Empty permissions list
        types.uint(chain.blockHeight + 10),
        types.uint(chain.blockHeight), // Invalid time range
        types.bool(true)
      ], deployer.address)
    ]);

    assertEquals(block.receipts[0].result, '(err u1004)');
  }
});