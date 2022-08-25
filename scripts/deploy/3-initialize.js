async function main() {
  const vaultAddress = '0xD3455C05CB1c0F15596dCe5b43680D4908f64a9C';
  const strategyAddress = '0xBc0E513Def7604463456106Ed9c6dc66808aA643';

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
