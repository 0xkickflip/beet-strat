async function main() {
  const vaultAddress = '0x1820f9d0BA5cC038B9983660885eD09E59231aD6';
  const strategyAddress = '0xA0afdA43FaD7DC1a31F294dA33BC23b1C0Ef0c4F';

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
