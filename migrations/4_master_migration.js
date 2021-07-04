const OneKProjectsToken = artifacts.require("OneKProjectsToken");
const ChronoToken = artifacts.require("ChronoToken");
const ChronoMaster = artifacts.require("ChronoMaster");
const Timelock = artifacts.require("Timelock");
const ChronoDev = artifacts.require("ChronoDev");
const BlackHole = artifacts.require("BlackHole");

module.exports = async (deployer) => {
  const chainId = await web3.eth.getChainId();
  let dev = "";
  if (chainId.toString() === "56" || chainId.toString() === "97") {
    console.log("We are in BSC!")
    accounts = await web3.eth.getAccounts();
    dev = accounts[0];
  } else {
    console.log("We are in a test network")
    accounts = await web3.eth.getAccounts();
    dev = accounts[9];
  }
  // Get addresses
  const fs = require('file-system');
  const readTitle = "./information/" + chainId.toString() + "_3_actors_migration.json";
  const actorsAddrRaw = await fs.readFileSync(readTitle);
  const actorsAddr = JSON.parse(actorsAddrRaw);
  // Recruiting the guys
  const thop = await OneKProjectsToken.at(actorsAddr.ThoP);
  const developer = await ChronoDev.at(actorsAddr.ChronoDev);
  const hole = await BlackHole.at(actorsAddr.BlackHole);
  const timelock = await Timelock.at(actorsAddr.Timelock);
  // Deploy ChronoMaster
  console.log("Deploying Master of Time...")
  const master = await deployer.deploy(ChronoMaster, thop.address, developer.address, hole.address, {from: dev});
  // Creating the farms
  if (chainId.toString() === "56" || chainId.toString() === "97") {
    await master.add(web3.utils.toBN('2000'), thop.address, web3.utils.toBN('0'), true, {from: dev});
    await master.add(web3.utils.toBN('2000'), thop.address, web3.utils.toBN('0'), true, {from: dev}); // Autocompound
    await master.add(web3.utils.toBN('4000'), "0xbbe838cfc0a79caf780c9b70c5d41bbd1254a983", web3.utils.toBN('0'), true, {from: dev});  // TODO thop-bnb Update address with the pair generated
    await master.add(web3.utils.toBN('2500'), "0xaf5e8aa68dd1b61376ac4f6fa4d06a5a4ab6cafd", web3.utils.toBN('0'), true, {from: dev});  // TODO bnb-busd Update address with BNB-BUSD LP
    await master.add(web3.utils.toBN('500'), "0xf2bdfcfc607c7eb7c4b448e4020a5d481055f72a", web3.utils.toBN('0'), true, {from: dev});  // TODO thop-eth Update address with BNB-BUSD LP
    // await master.add(web3.utils.toBN('1000'), "", web3.utils.toBN('0'), true, {from: dev});  // TODO thop-cake Update address with BNB-BUSD LP
    // await master.add(web3.utils.toBN('1000'), "", web3.utils.toBN('0'), true, {from: dev});  // TODO thop-ada Update address with BNB-BUSD LP
    await master.add(web3.utils.toBN('150'), "0xb263d019550d10f058017f0a1019e8984c7b9804", web3.utils.toBN('3'), true, {from: dev});  // TODO dai-busd Update address with BNB-BUSD LP
    // await master.add(web3.utils.toBN('500'), "", web3.utils.toBN('3'), true, {from: dev});  // TODO cake-bnb Update address with BNB-BUSD LP
    await master.add(web3.utils.toBN('200'), "0x094616F0BdFB0b526bD735Bf66Eca0Ad254ca81F", web3.utils.toBN('3'), true, {from: dev}); // TODO BNB staking
    await master.add(web3.utils.toBN('200'), "0xa35062141Fa33BCA92Ce69FeD37D0E8908868AAe", web3.utils.toBN('3'), true, {from: dev}); // TODO CAKE staking
    await master.add(web3.utils.toBN('100'), "0xeD24FC36d5Ee211Ea25A80239Fb8C4Cfd80f12Ee", web3.utils.toBN('3'), true, {from: dev}); // TODO BUSD staking
    await master.add(web3.utils.toBN('100'), "0xec5dcb5dbf4b114c9d0f65bccab49ec54f6a0867", web3.utils.toBN('3'), true, {from: dev}); // TODO DAI staking
    await master.add(web3.utils.toBN('100'), "0xE02dF9e3e622DeBdD69fb838bB799E3F168902c5", web3.utils.toBN('3'), true, {from: dev}); // TODO BTCB staking
  } else {
    await master.add(web3.utils.toBN('2000'), thop.address, web3.utils.toBN('0'), true, {from: dev});
    await master.add(web3.utils.toBN('2000'), thop.address, web3.utils.toBN('0'), true, {from: dev});
  }
  // Transfer ownership of native tokens
  console.log("Transfering ThoP ownership...")
  await thop.transferOwnership(master.address, {from: dev});
  // Transfer ownership of ChronoMaster
  console.log("Transfering Chronomaster ownership...")
  await master.transferOwnership(timelock.address, {from: dev});
  //Saving addresses
  console.log("Saving addresses...")
  const title = "./information/" + chainId.toString() + "_4_master_migration.json"
  let infos = {
    'ChronoMaster': master.address,
  };
  let data = JSON.stringify(infos, null, 2);
  fs.writeFile(title, data, 'utf-8');
};
