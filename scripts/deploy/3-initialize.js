async function main() {
  const vaultAddress = '0x3356fDA38c6d3D132E15318E249f153C0924adaC';
  const strategyAddress = '0x4216aBcEAEBB5FEf30A7A9c6749FDe84C6b2C76f';
  const options = {gasPrice: 1000000000000};

  const Vault = await ethers.getContractFactory('ReaperVaultv1_4');
  const vault = Vault.attach(vaultAddress);

  await vault.initialize(strategyAddress, options);
  console.log('Vault initialized');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
