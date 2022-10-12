async function main() {
  const vaultAddress = '0x5a8d1919647C4de929664bCB442afbF94279B913';
  const strategyAddress = '0x8Bb2945cBDd5EC18D50A34c761e1d225f800b624';

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
