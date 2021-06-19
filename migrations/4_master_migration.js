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
  await master.add(web3.utils.toBN('1000'), "0xb667f7c1102dcfbbcec342497fa7da8aee52ac4a", web3.utils.toBN('0'), true, {from: dev});  // TODO Update address with the pair generated
  await master.add(web3.utils.toBN('1000'), "0xAf5e8AA68dd1b61376aC4F6fa4D06A5A4AB6cafD", web3.utils.toBN('0'), true, {from: dev});  // TODO Update address with BNB-BUSD LP
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
