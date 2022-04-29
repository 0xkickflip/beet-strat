async function main() {
  const vaultAddress = '0x48c46349c7819099B34b730168CA40F42BB120c8';
  const strategyAddress = '0x1dbd4d8EB5F5FB710364Af0c727f90c0b3050d27';

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
