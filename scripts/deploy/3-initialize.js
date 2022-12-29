async function main() {
  const vaultAddress = '0xc450F8f521D2D7e94E5f71C54eF7d72dc19F5824';
  const strategyAddress = '0xed6e02fba69ce941Dc51c19458cde643e3542Cf1';

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
