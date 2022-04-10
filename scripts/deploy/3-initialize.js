async function main() {
  const vaultAddress = '0xaec37AC0172820a441ec241Aa4b116CE8ef11D4e';
  const strategyAddress = '0xaDF7a6763d30bF4ff44fdbb5D47fD4FA22429D3f';

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
