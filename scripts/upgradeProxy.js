async function main() {
  const stratFactory = await ethers.getContractFactory('ReaperStrategyPuff');
  const stratContract = await hre.upgrades.upgradeProxy('0xc2f81876ed0075A6ebD99e0faCeCf5E90C210A0F', stratFactory);
  console.log('Strategy upgraded!');
  // const stratContract = await stratFactory.attach('0xc2f81876ed0075A6ebD99e0faCeCf5E90C210A0F');

  // await stratContract.pause();
  // await stratContract.addSwapStep(deusAddress, daiAddress, 1 /* total fee */, 0);
  // await stratContract.addChargeFeesStep(daiAddress, 0 /* absolute */, 10_000);
  // await stratContract.unpause();
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
