async function main() {
  const vaultAddress = '0xb31966E987468F210e012078413fabCE7A11D8c6';
  const strategyAddress = '0xa4B631456F3b4b8F48fdaED39919002414b1A3a6';

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
