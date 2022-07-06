const hre = require('hardhat');

async function main() {
  const vaultAddress = '0x22D3316C21C512f9B4f22B9FA09dac0Ad39c0314';
  const want = '0xd6E5824b54f64CE6f1161210bc17eeBfFC77E031';
  const joinErc = '0xFE8B128bA8C78aabC59d4c64cEE7fF28e9379921'; // BAL
  const gauge = '0x47a063Ae87c3c8c9BFbd81D55eEfa6683543148A'; 
  const rewardUsdcPool = '0x7ef99013e446ddce2486b8e04735b7019a115e6f000100000000000000000005'; // 8 track
  const rewardJoinErcPool = '0xd6e5824b54f64ce6f1161210bc17eebffc77e031000100000000000000000006'; // Same as the beets pool (need love)

  const Strategy = await ethers.getContractFactory('ReaperStrategyLove');

  const treasuryAddress = '0xeb9C9b785aA7818B2EBC8f9842926c4B9f707e4B';
  const paymentSplitterAddress = '0x2b394b228908fb7DAcafF5F340f1b442a39B056C';

  const strategist1 = '0x1E71AEE6081f62053123140aacC7a06021D77348';
  const strategist2 = '0x81876677843D00a7D792E1617459aC2E93202576';
  const strategist3 = '0x1A20D7A31e5B3Bc5f02c8A146EF6f394502a10c4';

  const superAdmin = '0x9BC776dBb134Ef9D7014dB1823Cd755Ac5015203';
  const admin = '0xeb9C9b785aA7818B2EBC8f9842926c4B9f707e4B';
  const guardian = '0xb0C9D5851deF8A2Aac4A23031CA2610f8C3483F9';

  const strategy = await hre.upgrades.deployProxy(
    Strategy,
    [
      vaultAddress,
      [treasuryAddress, paymentSplitterAddress],
      [strategist1, strategist2, strategist3],
      [superAdmin, admin, guardian],
      want,
      joinErc,
      gauge,
      rewardUsdcPool,
      rewardJoinErcPool
    ],
    {kind: 'uups', timeout: 0},
  );

  await strategy.deployed();
  console.log('Strategy deployed to:', strategy.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });