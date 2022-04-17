async function main() {
  const vaultAddress = '0x1034315f065F331a9b82Bd9b5039a22c1d78aa9f';
  const strategyAddress = '0x42b199c9104798733a9E779d5310a2Cd0e9caB77';

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
