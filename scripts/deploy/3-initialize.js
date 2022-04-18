async function main() {
  const vaultAddress = '0xDF84Ffdb38aA544175a04310f7c9391AA23f7b9C';
  const strategyAddress = '0xc78fA18763e81D3446050f85d98791C69BFBb923';

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
