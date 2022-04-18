async function main() {
  const vaultAddress = '0xd70257272b108677B017A942cA80fD2b8Fc9251A';
  const strategyAddress = '0x74d57A0C700Aaf9ec23F2A3b133933ebfe2Df23E';
  const options = {gasPrice: 900000000000, gasLimit: 9000000};

  const Vault = await ethers.getContractFactory('ReaperVaultv1_4');
  const vault = Vault.attach(vaultAddress, options);

  await vault.initialize(strategyAddress);
  console.log('Vault initialized');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
