async function main() {
  const vaultAddress = '0x1ac58322863e77BDD41Cfca419344ad81b9fD38A';
  const strategyAddress = '0x0310b9979BcC17fa2DB4cEC4417FCebabc405F1D';

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
