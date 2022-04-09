async function main() {
  const vaultAddress = '0x28f3E4d658ad166bB4bB6DAB60072225d4664E15';
  const strategyAddress = '0x734e8e7e7e664F3AE9b1CB9c32Ad4E0766D0Eb2A';

  const Vault = await ethers.getContractFactory('ReaperVaultv1_4');
  const vault = Vault.attach(vaultAddress);
  // const options = {gasPrice: 1500000000000, gasLimit: 9000000};

  await vault.initialize(strategyAddress);
  console.log('Vault initialized');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
