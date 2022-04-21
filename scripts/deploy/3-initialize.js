async function main() {
  const vaultAddress = '0x98de53e7C7FE5DF05EF7092acF596a1281180697';
  const strategyAddress = '0xC2784545d15cB94fda3E01E2dfa318539d1D2450';

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
