async function main() {
  const Vault = await ethers.getContractFactory('ReaperVaultv1_4');

  const wantAddress = '0xDFc65c1F15AD3507754EF0fd4BA67060C108db7E';
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
