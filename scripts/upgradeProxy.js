async function main() {
  const stratFactory = await ethers.getContractFactory('ReaperStrategyBeethovenWftmUnderlying');
  const stratContract = await hre.upgrades.upgradeProxy('0xa9ca7185c0D3D71dF19C71Af6Bb007E2a773BFfD', stratFactory, {
    timeout: 0,
  });
  console.log('Strategy upgraded!');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
