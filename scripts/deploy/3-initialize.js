async function main() {
  const vaultAddress = '0x6cD2852371Fb10bB606c1c65930926c47a62f8CD';
  const strategyAddress = '0x8177Dd406E12F70fECcF71753a4bCF7589965486';

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
