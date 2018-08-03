require('babel-register')({
    // Important to have zeppelin-solidity working on
    ignore: /node_modules\/(?!zeppelin-solidity)/
});

require('babel-polyfill');

module.exports = {
    networks: {
        development: {
            host: "127.0.0.1",
            port: 8545,
            network_id: "*",
            gas: 15000000,
        }
    }
};
