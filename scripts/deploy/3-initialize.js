async function main() {
  const vaultAddress = '0x53D7cc6CF87361c79e5eB3F49bfAafab9Ea20d08';
  const strategyAddress = '0xD94278BE8Fe39Dfb5449204092024ef541187beF';

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
