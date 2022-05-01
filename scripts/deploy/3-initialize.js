async function main() {
  const vaultAddress = '0x9F7bf16f00e2661A3B5FCB61B87da1B269d4eA1f';
  const strategyAddress = '0x5d07FcD301A5101D80B40b33E6c92C57e1ED5f65';

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
