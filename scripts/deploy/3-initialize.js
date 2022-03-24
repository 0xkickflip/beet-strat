async function main() {
  const vaultAddress = '0xa7b36223e0DAB40fD520D71C9fD48a98475F64c5';
  const strategyAddress = '0x660f139561E068FC25dCee9436F7764356c6d0f0';
  const options = {gasPrice: 350000000000, gasLimit: 9000000};

  const Vault = await ethers.getContractFactory('ReaperVaultv1_4');
  const vault = Vault.attach(vaultAddress);

  await vault.initialize(strategyAddress, options);
  console.log('Vault initialized');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
