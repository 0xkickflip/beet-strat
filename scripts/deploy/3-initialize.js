async function main() {
  const vaultAddress = '0x796bC693dFa118220224F03a1F5a9eE7112d773e';
  const strategyAddress = '0xDb986d1E2b90AeeF43428F869aF8064F60143d44';

  const Vault = await ethers.getContractFactory('ReaperVaultv1_4');
  const vault = Vault.attach(vaultAddress);
  const options = {gasPrice: 130000000000, gasLimit: 9000000};

  await vault.initialize(strategyAddress, options);
  console.log('Vault initialized');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
