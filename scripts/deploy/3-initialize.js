async function main() {
  const vaultAddress = '0xa855a9Af07C15E49c8827bA93B0e3F9350ceFF4F';
  const strategyAddress = '0x049eb610b59feEC46E0bBf58C4A721d81bDa2a27';

  const Vault = await ethers.getContractFactory('ReaperVaultv1_4');
  const vault = Vault.attach(vaultAddress);
  const options = {gasPrice: 1500000000000, gasLimit: 9000000};

  await vault.initialize(strategyAddress, options);
  console.log('Vault initialized');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
