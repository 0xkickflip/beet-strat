async function main() {
  const vaultAddress = '0x9CF36ffC181fc70882EC8c05eBfeB4Bd45fb4B67';
  const strategyAddress = '0x01DD9C3054303C26c576cb27BF75e1b16C505f3a';

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
