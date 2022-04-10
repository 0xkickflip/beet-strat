async function main() {
  const vaultAddress = '0x56607b9AB2aB1783bCb8D8F62135c4EA11655A4C';
  const strategyAddress = '0xf733c7D08e58337eE4483417a7C46e080D9e5D10';

  const Vault = await ethers.getContractFactory('ReaperVaultv1_4');
  const vault = Vault.attach(vaultAddress);
  // const options = {gasPrice: 1500000000000, gasLimit: 9000000};

  await vault.initialize(strategyAddress);
  console.log('Vault initialized');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
