var CurrencyBet = artifacts.require("./CurrencyBet.sol");

module.exports = (deployer) => {
  deployer.deploy(CurrencyBet);
};
