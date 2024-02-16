use starknet::ContractAddress;

#[starknet::interface]
trait CoinPriceABI<TContractState> {
    fn get_asset_price(self: @TContractState, asset_id: felt252) -> u128;
}


#[starknet::contract]
mod CoinPrice {
    use super::{ContractAddress, CoinPriceABI};
    use pragma_lib::abi::{
        IPragmaABIDispatcher, IPragmaABIDispatcherTrait, ISummaryStatsABIDispatcher,
        ISummaryStatsABIDispatcherTrait
    };
    use pragma_lib::types::{DataType, AggregationMode, PragmaPricesResponse};
    use starknet::get_block_timestamp;

    const ETH_USD: felt252 = 19514442401534788; //ETH/USD to felt252, can be used as asset_id
    const BTC_USD: felt252 = 18669995996566340; //BTC/USD


    #[storage]
    struct Storage {
        pragma_contract: ContractAddress
    }

    #[constructor]
    fn constructor(ref self: ContractState, pragma_address: ContractAddress,) {
        self.pragma_contract.write(pragma_address);
    }
    #[abi(embed_v0)]
    impl CoinPriceABIImpl of CoinPriceABI<ContractState> {
        fn get_asset_price(self: @ContractState, asset_id: felt252) -> u128 {
            let oracle_dispatcher = IPragmaABIDispatcher {
                contract_address: self.pragma_contract.read()
            };
            let output: PragmaPricesResponse = oracle_dispatcher
                .get_data_median(DataType::SpotEntry(asset_id));
            return output.price;
        }
    }
}

