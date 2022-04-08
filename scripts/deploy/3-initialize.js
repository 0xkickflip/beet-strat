async function main() {
  const vaultAddress = '0xB9a10c323643797e6e73451afCB758b8B10d4FC4';
  const strategyAddress = '0xe853575A1eB11eCD8931b27ad866c7FdC829C381';

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
