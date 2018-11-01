const path = require('path');
const webpack = require('webpack');

module.exports = {
  entry: path.join(__dirname, 'src/js/index.js'), // Our frontend will be inside the src folder,
  output: {
    path: path.join(__dirname, 'dist/'),
    filename: 'build.js' // The final file will be created in dist/build.js
  },
  devServer: {
    contentBase: path.join(__dirname, 'dist/'),
    hot: true
  },
  module: {
    rules: [{
        test: /\.css$/, // To load the css in react
        loader: ['style-loader', 'css-loader'],
        include: /src/
    }, {
        test: /\.jsx?$/, // To load the js and jsx files
        loader: 'babel-loader',
        exclude: /node_modules/
    }]
  },
  plugins: [
    new webpack.HotModuleReplacementPlugin()
  ],
  watch: true,
  watchOptions: {
    poll: 500 // Check for changes every second
  }
}