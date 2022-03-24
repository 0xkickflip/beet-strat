async function main() {
  const Vault = await ethers.getContractFactory('ReaperVaultv1_4');

  const wantAddress = '0xC9Ba718A71bFA34cedEa910AC37B879e5913c14e';
  const tokenName = 'The Vaults Of The Lonely Mountain Beethoven-X Crypt';
  const tokenSymbol = 'rfBPT-RING';
  const depositFee = 0;
  const tvlCap = ethers.constants.MaxUint256;
  const options = {gasPrice: 320000000000, gasLimit: 9000000};

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
