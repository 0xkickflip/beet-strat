async function main() {
  const vaultAddress = '0xd0945276c20a3eC47449DEc6816b921E00342d97';
  const strategyAddress = '0xef6D65a2fb2d8130A06B89CF424FC06Ec9C45A95';

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
