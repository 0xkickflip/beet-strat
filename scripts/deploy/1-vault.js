async function main() {
  const Vault = await ethers.getContractFactory('ReaperVaultv1_4');

  const wantAddress = '0x2Ba4953C75860e70Cd70f15a2D5Fe07DE832Bcd1';
  const tokenName = 'Exploding Shrapnel Beethoven-X Crypt';
  const tokenSymbol = 'rf-BPT-SHRAP';
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
