async function main() {
  const vaultAddress = '0xD466d54Dac31668eCd6F77f2fe29614007f673FB';
  const strategyAddress = '0x1d4f5677FC58734f2011b6FB7AfEbAe2b04F269e';

  const Vault = await ethers.getContractFactory('ReaperVaultv1_4');
  const vault = Vault.attach(vaultAddress);

  await vault.initialize(strategyAddress, {gasPrice: 2000000000000});
  console.log('Vault initialized');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
