async function main() {
  const vaultAddress = '0xD60eA5c4aB52665E9681445Fa29FB9e7895Fea60';
  const strategyAddress = '0x0e5C651687452c25BA5D7441521e40e0560d754A';

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
