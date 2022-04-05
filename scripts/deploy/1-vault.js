async function main() {
  const Vault = await ethers.getContractFactory('ReaperVaultv1_4');

  const wantAddress = '0x5Bb2DeE206C2bCc5768B9B2865eA971Bd9c0fF19';
  const tokenName = 'Fresh Statera Maxi Duet BeethovenX Crypt';
  const tokenSymbol = 'rf-BPT-FSMD';
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
