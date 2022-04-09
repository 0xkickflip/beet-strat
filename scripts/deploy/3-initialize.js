async function main() {
  const vaultAddress = '0xbE8D7Cf166B240BCa4D31ee0C6e58E86F61D1bB2';
  const strategyAddress = '0x4408801F5E7b0e5a63a3B4473CdeFFF90c8f81C7';

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
