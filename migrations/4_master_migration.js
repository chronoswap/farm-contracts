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
    if (chainId.toString() === "56") {
      console.log("Please, keep calm")
    }
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
  const buybackaddr = dev
  const master = await deployer.deploy(ChronoMaster, thop.address, developer.address, hole.address, buybackaddr, {from: dev});
  // Creating the farms
  if (chainId.toString() === "56" || chainId.toString() === "97") {
    await master.add(web3.utils.toBN('2000'), thop.address, web3.utils.toBN('0'), true, {from: dev});
    // await master.add(web3.utils.toBN('2000'), thop.address, web3.utils.toBN('0'), true, {from: dev}); // Autocompound
    // await master.add(web3.utils.toBN('4000'), "", web3.utils.toBN('0'), true, {from: dev}); // TODO thop-bnb Update address with the pair generated
    await master.add(web3.utils.toBN('2500'), "0x58F876857a02D6762E0101bb5C46A8c1ED44Dc16", web3.utils.toBN('3'), true, {from: dev}); // bnb-busd Update address with BNB-BUSD LP
    // await master.add(web3.utils.toBN('500'), "", web3.utils.toBN('0'), true, {from: dev}); // TODO thop-eth Update address with the pair generated
    // await master.add(web3.utils.toBN('1000'), "", web3.utils.toBN('0'), true, {from: dev});  // TODO thop-cake Update address with the pair generated
    // await master.add(web3.utils.toBN('1000'), "", web3.utils.toBN('0'), true, {from: dev});  // TODO thop-ada Update address with the pair generated
    await master.add(web3.utils.toBN('150'), "0x66FDB2eCCfB58cF098eaa419e5EfDe841368e489", web3.utils.toBN('3'), true, {from: dev}); // dai-busd Update address with DAI-BUSD LP
    await master.add(web3.utils.toBN('500'), "0x0eD7e52944161450477ee417DE9Cd3a859b14fD0", web3.utils.toBN('3'), true, {from: dev}); // cake-bnb Update address with CAKE-BNB LP
    await master.add(web3.utils.toBN('200'), "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c", web3.utils.toBN('3'), true, {from: dev}); // BNB staking
    await master.add(web3.utils.toBN('200'), "0x0e09fabb73bd3ade0a17ecc321fd13a19e81ce82", web3.utils.toBN('3'), true, {from: dev}); // CAKE staking
    await master.add(web3.utils.toBN('100'), "0xe9e7cea3dedca5984780bafc599bd69add087d56", web3.utils.toBN('3'), true, {from: dev}); // BUSD staking
    await master.add(web3.utils.toBN('100'), "0x1AF3F329e8BE154074D8769D1FFa4eE058B1DBc3", web3.utils.toBN('3'), true, {from: dev}); // DAI staking
    await master.add(web3.utils.toBN('100'), "0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c", web3.utils.toBN('3'), true, {from: dev}); // BTCB staking
    await master.add(web3.utils.toBN('100'), "0x3ee2200efb3400fabb9aacf31297cbdd1d435d47", web3.utils.toBN('3'), true, {from: dev}); // ADA staking
    await master.add(web3.utils.toBN('100'), "0x2170ed0880ac9a755fd29b2688956bd959f933f8", web3.utils.toBN('3'), true, {from: dev}); // ETH staking
    await master.add(web3.utils.toBN('100'), "0xd944f1d1e9d5f9bb90b62f9d45e447d989580782", web3.utils.toBN('3'), true, {from: dev}); // IOTA staking
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
