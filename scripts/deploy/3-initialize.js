async function main() {
  const vaultAddress = '0xbaf206951d1D4Fd0112b79f3eC53688EaCe83598';
  const strategyAddress = '0x60FEbdD9826b79584e9aDA6B632Ec0686d0a045C';

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
