const OneKProjectsToken = artifacts.require("OneKProjectsToken");
const ChronoToken = artifacts.require("ChronoToken");

module.exports = async (deployer) => {
  // Where are we?
  const chainId = await web3.eth.getChainId();
  console.log(chainId.toString());
  // Getting addresses
  const fs = require('file-system');
  const readTitle = "./information/1_addresses.json";
  const addrRaw = await fs.readFileSync(readTitle);
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
  // Deploy ThoP
  console.log("Deploying ThoP...")
  const thop = await deployer.deploy(OneKProjectsToken, {from: addr.dev});
  // Deploy Chro
  console.log("Deploying CHRO...")
  const chro = await deployer.deploy(ChronoToken, {from: addr.dev});
  // Mint Some Thop to people
  console.log("Minting some ThoP...")
  await thop.mint(addr.owner1, web3.utils.toBN('1000000000000000000000'), {from: addr.dev});
  await thop.mint(addr.owner2, web3.utils.toBN('1000000000000000000000'), {from: addr.dev});
  await thop.mint(addr.owner3, web3.utils.toBN('1000000000000000000000'), {from: addr.dev});
  // Mint Some Chro to people
  console.log("Minting some Chro...")
  await chro.mint(web3.utils.toBN('3000000000000000000000'), {from: addr.dev});
  await chro.transfer(addr.owner1, web3.utils.toBN('1000000000000000000000'), {from: addr.dev});
  await chro.transfer(addr.owner2, web3.utils.toBN('1000000000000000000000'), {from: addr.dev});
  await chro.transfer(addr.owner3, web3.utils.toBN('1000000000000000000000'), {from: addr.dev});
  //Saving addresses
  console.log("Saving addresses...")
  const title = "./information/" + chainId.toString() + "_2_token_migration.json"
  let infos = {
    'ThoP': thop.address,
    'CHRO': chro.address,
  };
  let data = JSON.stringify(infos, null, 2);
  fs.writeFile(title, data, 'utf-8');
};
