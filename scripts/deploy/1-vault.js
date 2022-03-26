async function main() {
  const Vault = await ethers.getContractFactory('ReaperVaultv1_4');

  const wantAddress = '0x5ddb92A5340FD0eaD3987D3661AfcD6104c3b757';
  const tokenName = 'Steady Beets, Yearn Boosted Beethoven-X Crypt';
  const tokenSymbol = 'rf-bb-yv-USD';
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
