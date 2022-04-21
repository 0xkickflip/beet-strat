async function main() {
  const vaultAddress = '0xDB8CCF91b3c94D15832FAb079E73FbC76B5f0A02';
  const strategyAddress = '0x78f6F7A99846accEcCD33Aef1bd4CcC249262Fd1';

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
