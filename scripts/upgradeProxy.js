async function main() {
  const stratFactory = await ethers.getContractFactory('ReaperStrategyTwoGodsOnePool');
  // const stratContract = await hre.upgrades.upgradeProxy('0x0310b9979BcC17fa2DB4cEC4417FCebabc405F1D', stratFactory);
  // console.log('Strategy upgraded!');
  const stratContract = await stratFactory.attach('0x0310b9979BcC17fa2DB4cEC4417FCebabc405F1D');

  const daiAddress = '0x8D11eC38a3EB5E956B052f67Da8Bdc9bef8Abf3E';
  const deusAddress = '0xDE5ed76E7c05eC5e4572CfC88d1ACEA165109E44';

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
