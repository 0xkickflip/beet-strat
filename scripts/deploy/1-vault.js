async function main() {
  const Vault = await ethers.getContractFactory('ReaperVaultv1_4');

  const wantAddress = '0xEAdCFa1F34308b144E96FcD7A07145E027A8467d';
  const tokenName = 'Pirate In C BeethovenX Crypt';
  const tokenSymbol = 'rf-BPT-cLQDR';
  const depositFee = 0;
  const tvlCap = ethers.constants.MaxUint256;
  const options = {gasPrice: 500000000000, gasLimit: 9000000};

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
