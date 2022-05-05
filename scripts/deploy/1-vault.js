async function main() {
  const Vault = await ethers.getContractFactory('ReaperVaultv1_4');

  const wantAddress = '0xA55318E5d8B7584b8c0e5d3636545310Bf9eEb8f';
  const tokenName = 'From Gods, Boosted And Blessed Beethoven-X Crypt';
  const tokenSymbol = 'rf-bb-yv-deiusd';
  const depositFee = 0;
  const tvlCap = ethers.constants.MaxUint256;

  const vault = await Vault.deploy(wantAddress, tokenName, tokenSymbol, depositFee, tvlCap, {gasPrice: 2000000000000});

  await vault.deployed();
  console.log('Vault deployed to:', vault.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
