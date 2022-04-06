async function main() {
  const vaultAddress = '0x5Ea58d248E6634932EAB927bBDf03829a1C0bC3B';
  const strategyAddress = '0xdDAFC7B2e102Bc9bAa52cc95A69170eA83d4573C';

  const Vault = await ethers.getContractFactory('ReaperVaultv1_4');
  const vault = Vault.attach(vaultAddress);
  const options = {gasPrice: 450000000000, gasLimit: 9000000};

  await vault.initialize(strategyAddress, options);
  console.log('Vault initialized');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
