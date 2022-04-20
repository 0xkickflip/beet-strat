async function main() {
  const vaultAddress = '0x1538adBf2855686726784240cDD3b08976E63Fe8';
  const strategyAddress = '0xDEB41C7f012ee4435C989C167c56e2145A956B75';

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
