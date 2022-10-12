const hre = require('hardhat');

async function main() {
  const vaultAddress = '0x5a8d1919647C4de929664bCB442afbF94279B913';
  const Strategy = await ethers.getContractFactory('ReaperStrategyYellowSubmarine');

  const treasuryAddress = '0xeb9C9b785aA7818B2EBC8f9842926c4B9f707e4B';

  const strategist1 = '0x1E71AEE6081f62053123140aacC7a06021D77348';
  const strategist2 = '0x81876677843D00a7D792E1617459aC2E93202576';
  const strategist3 = '0x1A20D7A31e5B3Bc5f02c8A146EF6f394502a10c4';
  const strategist4 = '0x4C3490dF15edFa178333445ce568EC6D99b5d71c';

  const superAdmin = '0x9BC776dBb134Ef9D7014dB1823Cd755Ac5015203';
  const admin = '0xeb9C9b785aA7818B2EBC8f9842926c4B9f707e4B';
  const guardian = '0xb0C9D5851deF8A2Aac4A23031CA2610f8C3483F9';

  const want = '0x981Fb05B738e981aC532a99e77170ECb4Bc27AEF';
  const gauge = '0xbd54c9dbd7B4D82c80759790f8c566C3DeAaD6a5';

  const strategy = await hre.upgrades.deployProxy(
    Strategy,
    [
      vaultAddress,
      treasuryAddress,
      [strategist1, strategist2, strategist3, strategist4],
      [superAdmin, admin, guardian],
      want,
      gauge,
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
