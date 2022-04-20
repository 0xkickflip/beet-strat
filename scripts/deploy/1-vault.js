async function main() {
  const Vault = await ethers.getContractFactory('ReaperVaultv1_4');

  const wantAddress = '0xD5E946b5619fFf054c40D38c976f1d06C1e2fA82';
  const tokenName = 'A Dai-Abolical Balance Beethoven-X Crypt';
  const tokenSymbol = 'rf-BPT_USDB-DAI';
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
