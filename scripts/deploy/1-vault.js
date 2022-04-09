async function main() {
  const Vault = await ethers.getContractFactory('ReaperVaultv1_4');

  const wantAddress = '0x3bd4c3d1f6F40d77B2e9d0007D6f76E4F183A46d';
  const tokenName = 'A Beefy Tale Of Two Fantom Sisters Beethoven-X Crypt';
  const tokenSymbol = 'rf-BPT_beFTM';
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
