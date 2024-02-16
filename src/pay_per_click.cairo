use core::traits::Into;
use starknet::ContractAddress;

#[starknet::interface]
trait IPayPerClick<TContractState> {
    fn createPartnership(
        ref self: TContractState,
        creator: ContractAddress,
        paymentToken: u8,
        CPM: u256,
        totalAmount: u256
    );
    fn payCreator(
        ref self: TContractState, advertiser: ContractAddress, creator: ContractAddress, index: u32
    );
    fn endPartnership(
        ref self: TContractState, advertiser: ContractAddress, creator: ContractAddress, index: u32
    );
    fn isAnnouncementActive(
        self: @TContractState, advertiser: ContractAddress, creator: ContractAddress, index: u32
    ) -> bool;
    fn getAnnouncement(
        self: @TContractState, advertiser: ContractAddress, creator: ContractAddress, index: u32
    ) -> (u256, u256, u256, bool);
    fn getRemainingAmount(
        self: @TContractState, advertiser: ContractAddress, creator: ContractAddress, index: u32
    ) -> u256;
    fn getCurrentIndex(
        self: @TContractState, advertiser: ContractAddress, creator: ContractAddress
    ) -> u32;
    fn getCurrent_BTC_USD(self: @TContractState) -> u256;
    fn getCurrent_ETH_USD(self: @TContractState) -> u256;
}

#[starknet::contract]
mod PayPerClick {
    use core::traits::Into;
    use starknet::{get_caller_address, get_contract_address};
    use starknet::ContractAddress;
    use openzeppelin::token::erc20::interface::IERC20Dispatcher;
    use openzeppelin::token::erc20::interface::IERC20DispatcherTrait;
    use openzeppelin::token::erc20::interface::IERC20;
    use pragma_lib::abi::{
        IPragmaABIDispatcher, IPragmaABIDispatcherTrait, ISummaryStatsABIDispatcher,
        ISummaryStatsABIDispatcherTrait
    };
    use pragma_lib::types::{DataType, AggregationMode, PragmaPricesResponse};


    #[constructor]
    fn constructor(
        ref self: ContractState,
        _BTC_ADDRESS: ContractAddress,
        _ETH_ADDRESS: ContractAddress,
        _USDT_ADDRESS: ContractAddress,
        pragma_address: ContractAddress
    ) {
        self.tokenAddress.write('BTC', _BTC_ADDRESS);
        self.tokenAddress.write('ETH', _ETH_ADDRESS);
        self.tokenAddress.write('BTC', _USDT_ADDRESS);
        self.pragma_contract.write(pragma_address);
    }

    const ETH_USD: felt252 = 19514442401534788; //ETH/USD to felt252, can be used as asset_id
    const BTC_USD: felt252 = 18669995996566340; //BTC/USD

    #[storage]
    struct Storage {
        announcements: LegacyMap<((ContractAddress, ContractAddress), u32), Announcement>,
        index: LegacyMap<(ContractAddress, ContractAddress), u32>,
        tokenAddress: LegacyMap<felt252, ContractAddress>,
        pragma_contract: ContractAddress
    }

    #[derive(Copy, Drop, Hash, starknet::Store)]
    struct Announcement {
        partnership: Partnership,
        paymentToken: u8,
        CPM: u256,
        totalAmount: u256,
        paidAmount: u256,
        active: bool
    }

    #[derive(Copy, Drop, Hash, starknet::Store)]
    struct Partnership {
        advertiser: ContractAddress,
        creator: ContractAddress
    }

    #[derive(Drop, PartialEq)]
    enum Token {
        USDT,
        BTC,
        ETH
    }

    fn transfer(self: @ContractState, token: Token, recipient: ContractAddress, amount: u256) {
        let token_address = tokenToAddress(self, token);
        IERC20Dispatcher { contract_address: token_address }.transfer(recipient, amount);
    }

    fn transferFrom(
        self: @ContractState,
        token: Token,
        sender: ContractAddress,
        recipient: ContractAddress,
        amount: u256
    ) {
        let token_address = tokenToAddress(self, token);
        IERC20Dispatcher { contract_address: token_address }
            .transfer_from(sender, recipient, amount);
    }

    //PRIVATE FUNCTIONS
    fn increaseIndex(
        ref self: ContractState, advertiser: ContractAddress, creator: ContractAddress
    ) -> u32 {
        let currentIndex = self.index.read((advertiser, creator));
        self.index.write((advertiser, creator), currentIndex + 1);
        (currentIndex + 1)
    }

    fn pow(base: u256, exponent: u256) -> u256 {
        if exponent == 0 {
            return 1;
        }
        base * pow(base, exponent - 1)
    }

    fn get_asset_price(self: @ContractState, asset_id: felt252) -> u256 {
        let oracle_dispatcher = IPragmaABIDispatcher {
            contract_address: self.pragma_contract.read()
        };
        let output: PragmaPricesResponse = oracle_dispatcher
            .get_data_median(DataType::SpotEntry(asset_id));
        return output.price.into();
    }

    fn convertUSDToBTC(self: @ContractState, amount: u256) -> u256 {
        (amount * pow(10, 24)) / get_asset_price(self, BTC_USD)
    }

    fn convertUSDToETH(self: @ContractState, amount: u256) -> u256 {
        (amount * pow(10, 24)) / get_asset_price(self, ETH_USD)
    }

    fn convertUSDToUSDT(amount: u256) -> u256 {
        amount * pow(10, 16)
    }

    fn indexToToken(value: u8) -> Token {
        if value == 0 {
            return Token::BTC;
        } else if value == 1 {
            return Token::ETH;
        } else {
            return Token::USDT;
        }
    }

    fn tokenToAddress(self: @ContractState, token: Token) -> ContractAddress {
        if token == Token::BTC {
            return self.tokenAddress.read('BTC');
        } else if token == Token::ETH {
            return self.tokenAddress.read('ETH');
        } else {
            return self.tokenAddress.read('USDT');
        }
    }

    fn tokenAmount(self: @ContractState, token: Token, amount: u256) -> u256 {
        if token == Token::BTC {
            return convertUSDToBTC(self, amount);
        } else if token == Token::ETH {
            return convertUSDToETH(self, amount);
        } else {
            return convertUSDToUSDT(amount);
        }
    }


    //EXTERNAL FUNCTIONS
    #[abi(embed_v0)]
    impl PayPerClick of super::IPayPerClick<ContractState> {
        fn createPartnership(
            ref self: ContractState,
            creator: ContractAddress,
            paymentToken: u8,
            CPM: u256,
            totalAmount: u256
        ) {
            let index = increaseIndex(
                ref :self, advertiser: get_caller_address(), creator: creator
            );
            let partnership = Partnership { advertiser: get_caller_address(), creator: creator };
            let announcement = Announcement {
                partnership: partnership,
                paymentToken: paymentToken,
                CPM: CPM,
                totalAmount: totalAmount,
                paidAmount: 0,
                active: true
            };
            self
                .announcements
                .write(((partnership.advertiser, partnership.creator), index), announcement);
        // transferFrom(
        //     @self,
        //     token: indexToToken(paymentToken),
        //     sender: get_caller_address(),
        //     recipient: get_contract_address(),
        //     amount: totalAmount
        // );
        }
        fn payCreator(
            ref self: ContractState,
            advertiser: ContractAddress,
            creator: ContractAddress,
            index: u32
        ) {
            let partnership = Partnership { advertiser: advertiser, creator: creator };
            let announcement = self
                .announcements
                .read(((partnership.advertiser, partnership.creator), index));
            let newPaidAmount = announcement.paidAmount + announcement.CPM;

            self
                .announcements
                .write(
                    ((partnership.advertiser, partnership.creator), index),
                    Announcement {
                        partnership: announcement.partnership,
                        paymentToken: announcement.paymentToken,
                        CPM: announcement.CPM,
                        totalAmount: announcement.totalAmount,
                        paidAmount: newPaidAmount,
                        active: announcement.active
                    }
                );
        // transfer(
        //     @self,
        //     token: indexToToken(announcement.paymentToken),
        //     recipient: creator,
        //     amount: tokenAmount(
        //         @self, indexToToken(announcement.paymentToken), announcement.CPM
        //     )
        // );
        }

        fn endPartnership(
            ref self: ContractState,
            advertiser: ContractAddress,
            creator: ContractAddress,
            index: u32
        ) {
            let partnership = Partnership { advertiser: advertiser, creator: creator };
            let announcement = self
                .announcements
                .read(((partnership.advertiser, partnership.creator), index));
            self
                .announcements
                .write(
                    ((partnership.advertiser, partnership.creator), index),
                    Announcement {
                        partnership: announcement.partnership,
                        paymentToken: announcement.paymentToken,
                        CPM: announcement.CPM,
                        totalAmount: announcement.totalAmount,
                        paidAmount: announcement.paidAmount,
                        active: false
                    }
                );
        // let remainingAmount = announcement.totalAmount - announcement.paidAmount;
        // transfer(
        //     @self,
        //     token: indexToToken(announcement.paymentToken),
        //     recipient: advertiser,
        //     amount: tokenAmount(@self, indexToToken(announcement.paymentToken), remainingAmount)
        // );
        }

        fn isAnnouncementActive(
            self: @ContractState, advertiser: ContractAddress, creator: ContractAddress, index: u32
        ) -> bool {
            let partnership = Partnership { advertiser: advertiser, creator: creator };
            let announcement = self
                .announcements
                .read(((partnership.advertiser, partnership.creator), index));
            announcement.active
        }

        fn getAnnouncement(
            self: @ContractState, advertiser: ContractAddress, creator: ContractAddress, index: u32
        ) -> (u256, u256, u256, bool) {
            let partnership = Partnership { advertiser: advertiser, creator: creator };
            let announcement = self
                .announcements
                .read(((partnership.advertiser, partnership.creator), index));
            return (
                announcement.CPM,
                announcement.totalAmount,
                announcement.paidAmount,
                announcement.active
            );
        }

        fn getRemainingAmount(
            self: @ContractState, advertiser: ContractAddress, creator: ContractAddress, index: u32
        ) -> u256 {
            let partnership = Partnership { advertiser: advertiser, creator: creator };
            let announcement = self
                .announcements
                .read(((partnership.advertiser, partnership.creator), index));
            announcement.totalAmount - announcement.paidAmount
        }

        fn getCurrentIndex(
            self: @ContractState, advertiser: ContractAddress, creator: ContractAddress
        ) -> u32 {
            let currentIndex = self.index.read((advertiser, creator));
            currentIndex
        }

        fn getCurrent_BTC_USD(self: @ContractState) -> u256 {
            get_asset_price(self, BTC_USD)
        }

        fn getCurrent_ETH_USD(self: @ContractState) -> u256 {
            get_asset_price(self, ETH_USD)
        }
    }
}
