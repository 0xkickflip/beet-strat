async function main() {
  const vaultAddress = '0x333DABAE8787f5d5DB15ddfB8F65F80A3203000B';
  const strategyAddress = '0xc5713dbde5D85648465091f4e33624fd2E598962';

  const Vault = await ethers.getContractFactory('ReaperVaultv1_4');
  const vault = Vault.attach(vaultAddress);
  const options = {gasPrice: 290000000000, gasLimit: 9000000};

  await vault.initialize(strategyAddress, options);
  console.log('Vault initialized');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
