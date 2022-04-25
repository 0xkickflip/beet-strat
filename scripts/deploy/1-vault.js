async function main() {
  const Vault = await ethers.getContractFactory('ReaperVaultv1_4');

  const wantAddress = '0xc0064b291bd3D4ba0E44ccFc81bF8E7f7a579cD2';
  const tokenName = 'Lock, Staked And Two Smoking Fantoms Beethoven-X Crypt';
  const tokenSymbol = 'rfBPT-sFTMx';
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
