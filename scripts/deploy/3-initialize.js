async function main() {
  const vaultAddress = '0xEcf4061d571AcFf3EE52A0d4815dDcda6879e777';
  const strategyAddress = '0xEA0C2774488553a3088F34172Df2177937cF52F7';

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
