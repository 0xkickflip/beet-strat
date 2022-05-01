async function main() {
  const stratFactory = await ethers.getContractFactory('ReaperStrategyBeethovenDaiUnderlying');
  const strategyAddress = '0xD94278BE8Fe39Dfb5449204092024ef541187beF';
  await hre.upgrades.upgradeProxy(strategyAddress, stratFactory, {
    timeout: 0,
  });
  console.log('Strategy upgraded!');
  const strategy = stratFactory.attach(strategyAddress);
  await strategy.setPathsPostUpgrade(
    [
      '0xfa1FBb8Ef55A4855E5688C0eE13aC3f202486286',
      '0x8D11eC38a3EB5E956B052f67Da8Bdc9bef8Abf3E',
      '0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83',
    ],
    ['0xfa1FBb8Ef55A4855E5688C0eE13aC3f202486286', '0x8D11eC38a3EB5E956B052f67Da8Bdc9bef8Abf3E'],
  );
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
