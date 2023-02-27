async function main() {
  const vaultAddress = '0xD57Ef3583f8b04A67cD49d54Fa2556460dFC47B6';
  const strategyAddress = '0x55bF533E08634aFD7bFe3F89eAb1A464a8119Bcd';

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
