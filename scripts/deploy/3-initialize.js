async function main() {
  const vaultAddress = '0xd183b54Ea2C109B76277A021C01Dff77A8D14490';
  const strategyAddress = '0xa9ca7185c0D3D71dF19C71Af6Bb007E2a773BFfD';

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
