async function main() {
  const vaultAddress = '0x6536dfFd07C1CD3773f896F0e46962dF7C14A833';
  const strategyAddress = '0x4854c82B12A389051A4Bb55Ab24B1DA3Ce8A2b5b';

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
