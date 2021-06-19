const OneKProjectsToken = artifacts.require("OneKProjectsToken");
const Timelock = artifacts.require("Timelock");
const ChronoDev = artifacts.require("ChronoDev");
const BlackHole = artifacts.require("BlackHole");

module.exports = async (deployer) => {
  // Where are we?
  const chainId = await web3.eth.getChainId();
  console.log(chainId.toString());
  // Getting addresses
  const fs = require('file-system');
  const addrTitle = "./information/1_addresses.json";
  const addrRaw = await fs.readFileSync(addrTitle);
  let addr = JSON.parse(addrRaw);
  if (chainId.toString() === "56" || chainId.toString() === "97") {
    console.log("We are in BSC!")
    accounts = await web3.eth.getAccounts();
    addr["dev"] = accounts[0];
  } else {
    console.log("We are in a test network")
    accounts = await web3.eth.getAccounts();
    addr = {
      owner1: accounts[0],
      owner2: accounts[1],
      owner3: accounts[2],
      contracts: accounts[3],
      partnership: accounts[4],
      marketing: accounts[5],
      treasury: accounts[6],
      charity: accounts[7],
      treasuryBNB: accounts[8],
      dev: accounts[9],
      other: addr.other,
      burn: addr.burn
    }
  }
  // Get token addresses
  const readTitle = "./information/" + chainId.toString() + "_2_token_migration.json";
  const tokenAddrRaw = await fs.readFileSync(readTitle);
  const tokenAddr = JSON.parse(tokenAddrRaw);
  // Getting ThoP
  const thop = await OneKProjectsToken.at(tokenAddr.ThoP);
  // Deploying The Black Hole
  console.log("Deploying the Black Hole...")
  const hole = await deployer.deploy(BlackHole, thop.address, addr.burn, {from: addr.dev});
  // Deploying ChronoDev
  console.log("Deploying ChronoDev...")
  const developer = await deployer.deploy(
    ChronoDev, [addr.owner1, addr.owner2, addr.owner3],
    addr.contracts, addr.partnership, addr.marketing,
    addr.treasury, addr.charity, addr.treasuryBNB,
    addr.other, thop.address, {from: addr.dev});
  // Deploying  timelock
  console.log("Deploying Timelock...")
  let delay = 3700  // 1h Testnet -> 24h Mainnet
  if (chainId.toString() === "56") {
    delay = 86400
  }
  const timelock = await deployer.deploy(Timelock, addr.dev, delay);
  //Saving addresses
  console.log("Saving addresses...")
  const title = "./information/" + chainId.toString() + "_3_actors_migration.json"
  let infos = {
    'ThoP': thop.address,
    'Timelock': timelock.address,
    'ChronoDev': developer.address,
    'BlackHole': hole.address,
  };
  let data = JSON.stringify(infos, null, 2);
  fs.writeFile(title, data, 'utf-8');
};
