async function main() {
  const vaultAddress = '0x7e66050192E5D74f311DEf92471394A2232a90f9';
  const strategyAddress = '0xf9D0771d83856Be7Ab6209D28055f76C5Df16bD7';

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
