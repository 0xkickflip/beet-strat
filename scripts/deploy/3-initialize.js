async function main() {
  const vaultAddress = '0xCA55757854222d8232a19EC8Aae336594eE3b5E5';
  const strategyAddress = '0xc2f81876ed0075A6ebD99e0faCeCf5E90C210A0F';

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
