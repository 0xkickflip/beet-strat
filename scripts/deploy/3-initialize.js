async function main() {
  const vaultAddress = '0xc99c96e761afEb6454f3Bf3163668d599110305a';
  const strategyAddress = '0xbFAC229d495C057C9f5Ee0f0fD294319FC2223e5';

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
