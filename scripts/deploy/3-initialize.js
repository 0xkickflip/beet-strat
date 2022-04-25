async function main() {
  const vaultAddress = '0x783967b305B9C54325DD33ED943Bb49EFa31adF5';
  const strategyAddress = '0x2C02c3C70324a162bB0572488eA6317A45443059';

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
