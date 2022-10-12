async function main() {
  const vaultAddress = '0xfb86E03bF6F73DAb782B36B62EE3Ef235b2bE4d0';
  const strategyAddress = '0x2bcd57c497d5a6DBFFD98F0FaD67CD9440Ae0620';

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
