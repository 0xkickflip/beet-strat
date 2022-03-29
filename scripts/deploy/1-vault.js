async function main() {
  const Vault = await ethers.getContractFactory('ReaperVaultv1_4');

  const wantAddress = '0x64b301E21d640F9bef90458B0987d81fb4cf1B9e';
  const tokenName = 'Fantom of the Opera, Yearn Boosted Beethoven-X Crypt';
  const tokenSymbol = 'rf-bb-yv-FTMUSD';
  const depositFee = 0;
  const tvlCap = ethers.constants.MaxUint256;

  const vault = await Vault.deploy(wantAddress, tokenName, tokenSymbol, depositFee, tvlCap);

  await vault.deployed();
  console.log('Vault deployed to:', vault.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
