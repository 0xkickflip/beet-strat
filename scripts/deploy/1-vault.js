async function main() {
  const Vault = await ethers.getContractFactory('ReaperVaultv1_4');

  const wantAddress = '0x6Da14F5ACD58Dd5c8E486CFa1dC1c550F5c61C1c';
  const tokenName = 'My Beautiful Dark Twisted Decentralized Dollar BeethovenX Crypt';
  const tokenSymbol = 'bb-yv-4pool';
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
