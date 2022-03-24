async function main() {
  const Vault = await ethers.getContractFactory('ReaperVaultv1_4');

  const wantAddress = '0x1577Eb091D3933A89BE62130484e090bb8BD0E58';
  const tokenName = 'In The Hall Of The Mountain King';
  const tokenSymbol = 'rfBPT-SUMMIT';
  const depositFee = 0;
  const tvlCap = ethers.constants.MaxUint256;
  const options = {gasPrice: 200000000000, gasLimit: 9000000};

  const vault = await Vault.deploy(wantAddress, tokenName, tokenSymbol, depositFee, tvlCap, options);

  await vault.deployed();
  console.log('Vault deployed to:', vault.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
