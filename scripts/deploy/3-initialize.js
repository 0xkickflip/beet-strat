async function main() {
  const vaultAddress = '0x22D3316C21C512f9B4f22B9FA09dac0Ad39c0314';
  const strategyAddress = '0x90d87Ee39E27AC5130165C4AFD113Ef1CAF7890D';

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
