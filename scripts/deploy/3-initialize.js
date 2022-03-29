async function main() {
  const vaultAddress = '0x592458eeDF2c2586092aEbb6CeA5a9E49AdD777b';
  const strategyAddress = '0xA2c38eB053c0b348799960d224f90afC745b0818';

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
