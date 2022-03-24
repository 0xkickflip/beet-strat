async function main() {
  const vaultAddress = '0x9AdA860dd52697764DE9212a86847cFC14094199';
  const strategyAddress = '0x09376fd525c9a98cC446fdad6367F202d0C5eD9A';
  const options = {gasPrice: 320000000000, gasLimit: 9000000};

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
