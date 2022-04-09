async function main() {
  const vaultAddress = '0xcb40625713F76356E2B8C8862dbD01c22Fa1C53B';
  const strategyAddress = '0xDD4163e6f31B000207Aed12ab07D00d41E07a7E3';

  const Vault = await ethers.getContractFactory('ReaperVaultv1_4');
  const vault = Vault.attach(vaultAddress);
  // const options = {gasPrice: 1500000000000, gasLimit: 9000000};

  await vault.initialize(strategyAddress);
  console.log('Vault initialized');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
