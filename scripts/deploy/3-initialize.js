async function main() {
  const vaultAddress = '0x80918ADfe35491D92825863aB2766A0Fe5161f30';
  const strategyAddress = '0x3dA2DeCE625fAeB285e0c3658d4029b9b346fEb5';

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
