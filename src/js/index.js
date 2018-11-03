import React from 'react'
import ReactDOM from 'react-dom'
import Web3 from 'web3'
import { CONTRACT_ABI, CONTRACT_ADDRESS } from './../contractMeta.js'
import './../css/index.css'


class App extends React.Component {
  constructor(props) {
    super(props);
    this.state = {
      betCount: 0,
      totalBet: 0,
      userBronze: 0,
      userSilver: 0,
      userGold: 0
    };

    if (typeof web3 != 'undefined') {
      console.log("Using web3 detected from external source like MetaMask");
      this.web3 = new Web3(web3.currentProvider);
    } else {
      this.web3 = new Web3(new Web3.providers.HttpProvider("http://localhost:8545"))
    }

    const MyContract = web3.eth.contract(CONTRACT_ABI);
    this.state.ContractInstance = MyContract.at(CONTRACT_ADDRESS);
    this.buyCoin = this.buyCoin.bind(this);
    this.convertCoin = this.convertCoin.bind(this);
  }

  componentDidMount() {
    this.updateState();
    this.setupListeners();

    setInterval(this.updateState.bind(this), 10e3);
  }

  updateState() {
    this.state.ContractInstance.totalBet((err, result) => {
      if (result != null) {
        this.setState({
          totalBet: parseFloat(result)
        });
      }
    });
    this.state.ContractInstance.betCount((err, result) => {
      if (result != null) {
        this.setState({
          betCount: parseInt(result)
        });
      }
    });
    this.state.ContractInstance.balanceOf(web3.eth.accounts[0], 0, (err, result) => {
      if (result != null) {
        this.setState({
          userBronze: parseInt(result)
        });
      }
    });
    this.state.ContractInstance.balanceOf(web3.eth.accounts[0], 1, (err, result) => {
      if (result != null) {
        this.setState({
          userSilver: parseInt(result)
        });
      }
    });
    this.state.ContractInstance.balanceOf(web3.eth.accounts[0], 2, (err, result) => {
      if (result != null) {
        this.setState({
          userGold: parseInt(result)
        });
      }
    });
  }

  setupListeners() {
    let liNodes = this.refs.numbers.querySelectorAll('li');
    liNodes.forEach(number => {
      number.addEventListener('click', event => {
        event.target.className = 'number-selected';
        this.betNumber(parseInt(event.target.innerHTML), done => {
          for(let i = 0; i < liNodes.length; i++){
            liNodes[i].className = '';
          }
        })
      });
    });
  }

  betNumber(number, callBack) {
    let betType = document.getElementById('betType');
    let betAmount = document.getElementById('betAmount');

    if (betType && betAmount) {
      betType = betType.value;
      betAmount = betAmount.value;

      this.state.ContractInstance.bet(number, betAmount, betType, {
        gas: 300000,
        from: web3.eth.accounts[0]
      }, (err, result) => {
        callBack()
      })
    }
  }

  convertCoin() {
    let convertFromType = document.getElementById('convertFromType');
    let convertToType = document.getElementById('convertToType');
    let convertAmount = document.getElementById('convertAmount');

    if (convertFromType && convertToType && convertAmount) {
      convertFromType = convertFromType.value;
      convertToType = convertToType.value;
      convertAmount = convertAmount.value;

      this.state.ContractInstance.convert(convertFromType, convertToType, convertAmount, {
        gas: 300000,
        from: web3.eth.accounts[0]
      }, (err, result) => {
        callBack()
      })
    }
  }

  buyCoin() {
    let buyType = document.getElementById('buyType');
    let buyAmount = document.getElementById('buyAmount');

    if (buyType && buyAmount) {
      buyType = buyType.value;
      buyAmount = buyAmount.value;

      let multiplier = 0.01;
      if (buyType == 1) multiplier = 0.05;
      else if (buyType == 2) multiplier = 0.1;

      let toPay = multiplier * buyAmount;

      this.state.ContractInstance.buyCoin(buyAmount, buyType, {
        gas: 300000,
        from: web3.eth.accounts[0],
        value: web3.toWei(toPay, 'ether')
      }, (err, result) => {
        callBack()
      })
    }
  }

  render() {
    return (
      <div className="main-container">
        <h1>Currency + Bet</h1>
        <div className="block">
          <b>Number of bets:</b> &nbsp;
          <span>{this.state.betCount} / 10</span>
        </div>
        <div className="block">
          <b>Total bet:</b> &nbsp;
          <span>{this.state.totalBet} Bronze (~ {this.state.totalBet * 0.01} ETH)</span>
        </div>
        <br/>
        <div className="block">
          <b>You currently own:</b><br/>
        </div>
        <div className="block">
          <p>{this.state.userBronze} Bronze | {this.state.userSilver} Silver | {this.state.userGold} Gold</p>
        </div>
        <hr/>
        <h2>Choose your lucky number</h2>
        <label>
          <b>How much do you want to bet?
          <br/>
          <input className="bet-input" id="betAmount" ref="ether-bet" type="number" placeholder={this.state.minimumBet}/></b>
          <select class="bet-type-input" id="betType">
            <option value={0}>Bronze</option>
            <option value={1}>Silver</option>
            <option value={2}>Gold</option>
          </select>
          <br/>
        </label>
        <ul ref="numbers">
          <li>1</li>
          <li>2</li>
          <li>3</li>
          <li>4</li>
          <li>5</li>
        </ul>
        <hr/>
        <h2>Buy our currency:</h2>
        <label>
          <b>Join the fun and buy our coins at the following rates:</b>
          <br/>
          <ul class="normal-ul">
            <li class="normal-li">Bronze: 0.01 ETH each</li>
            <li class="normal-li">Silver: 0.05 ETH each</li>
            <li class="normal-li">Gold: 0.1 ETH each</li>
          </ul>
          <br/>
          <input className="bet-input" ref="ether-bet" type="number" placeholder={0} id="buyAmount"/>
          <select id="buyType" class="bet-type-input">
            <option value={0}>Bronze</option>
            <option value={1}>Silver</option>
            <option value={2}>Gold</option>
          </select>
          <br/>
        </label>
        <button onClick={this.buyCoin}>Buy</button>
        <hr/>
        <h2>Convert currency you own:</h2>
        <label>
          <ul class="normal-ul">
            <li class="normal-li">Bronze: <i>Base currency</i></li>
            <li class="normal-li">Silver: convertible to 5 Bronze</li>
            <li class="normal-li">Gold: convertible to 2 Silver or 10 Bronze</li>
          </ul>
          <br/>
          <div className="block">
            <b>You currently own:</b><br/>
          </div>
          <div className="block">
            <p>{this.state.userBronze} Bronze | {this.state.userSilver} Silver | {this.state.userGold} Gold</p>
          </div>
          <input className="bet-input" ref="ether-bet" type="number" placeholder={0} id="convertAmount"/>
          <select id="convertFromType" class="bet-type-input">
            <option value={0}>Bronze</option>
            <option value={1}>Silver</option>
            <option value={2} selected>Gold</option>
          </select>
          <span><b>To</b></span>
          <select id="convertToType" class="bet-type-input">
            <option value={0}>Bronze</option>
            <option value={1}>Silver</option>
            <option value={2}>Gold</option>
          </select>
          <br/>
        </label>
        <button className="currencyButton" onClick={this.convertCoin}>Convert</button>
      </div>
    )
  }
}

ReactDOM.render(<App/>, document.getElementById('root'));
