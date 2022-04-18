async function main() {
  const Vault = await ethers.getContractFactory('ReaperVaultv1_4');

  const wantAddress = '0xD74519dA8842176305022cAB361327E0098fc1f5';
  const tokenName = 'Bee-Thoven And The Bears Beethoven-X Crypt';
  const tokenSymbol = 'rf-BPT-BEEBEAR';
  const depositFee = 0;
  const tvlCap = ethers.constants.MaxUint256;
  const options = {gasPrice: 1000000000000};

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
