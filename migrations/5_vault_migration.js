
const ThopVault = artifacts.require("ThopVault");

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
  const readActorsTitle = "./information/" + chainId.toString() + "_3_actors_migration.json";
  const actorsAddrRaw = await fs.readFileSync(readActorsTitle);
  const actorsAddr = JSON.parse(actorsAddrRaw);
  const readMasterTitle = "./information/" + chainId.toString() + "_4_master_migration.json";
  const masterAddrRaw = await fs.readFileSync(readMasterTitle);
  const masterAddr = JSON.parse(masterAddrRaw);
  // Deploy Vault
  console.log("Deploying Automcompounding Vault...")
  const vault = await deployer.deploy(ThopVault, actorsAddr.ThoP, masterAddr.ChronoMaster, dev, actorsAddr.ChronoDev, {from: dev});
  //Saving addresses
  console.log("Saving addresses...")
  const title = "./information/" + chainId.toString() + "_5_vault_migration.json"
  let infos = {
    'ThopVault': vault.address,
  };
  let data = JSON.stringify(infos, null, 2);
  fs.writeFile(title, data, 'utf-8');
};
