async function main() {
  const vaultAddress = '0x5247aAcb77C16D47cEAeA42Dc68f764e94FEa3ae';
  const strategyAddress = '0x670eC7b8F69a8016899B98288Fc0112173e4dABc';

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
