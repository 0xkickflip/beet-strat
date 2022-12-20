async function main() {
  const vaultAddress = '0x680E48934352E4BD370c50a3B90789e521E61308';
  const strategyAddress = '0xB7E590f41Cc6D75EAAA3e3173c85a2e7a1Dbe992';

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
