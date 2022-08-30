async function main() {
  const vaultAddress = '0xCE1a9cF9266b03404c43C8B0Da1ae833A6F922c7';
  const strategyAddress = '0x29060f43b53865E6Eb1279573c99f9dA22bB2F97';

  const Vault = await ethers.getContractFactory('ReaperVaultv1_4');
  const vault = Vault.attach(vaultAddress);

  await vault.initialize(strategyAddress);
  console.log('Vault initialized');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
