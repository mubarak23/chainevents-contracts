#[starknet::contract]
pub mod EventNFT {
    use starknet::{ContractAddress, get_block_timestamp};
    use core::num::traits::zero::Zero;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc721::{ERC721Component, ERC721HooksEmptyImpl};

    use starknet::storage::{
        Map, StoragePointerWriteAccess, StoragePointerReadAccess, StorageMapReadAccess,
        StorageMapWriteAccess,
    };
    use chainevents_contracts::interfaces::IEventNFT::IEventNFT;
    use chainevents_contracts::base::errors::Errors::{
        ALREADY_MINTED, NOT_TOKEN_OWNER, TOKEN_DOES_NOT_EXIST,
    };

    // *************************************************************************
    //                             COMPONENTS
    // *************************************************************************
    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    // ERC721 Mixin
    impl ERC721MixinImpl = ERC721Component::ERC721MixinImpl<ContractState>;
    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;


    // *************************************************************************
    //                             EVENTS
    // *************************************************************************
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
    }

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        last_minted_id: u256,
        mint_timestamp: Map<u256, u64>,
        user_token_id: Map<ContractAddress, u256>,
        event_id: u256,
    }

    #[constructor]
    fn constructor(ref self: ContractState, event_id: u256) {
        self.event_id.write(event_id);
    }

    #[abi(embed_v0)]
    impl eventnft of IEventNFT<ContractState> {
        /// @notice mints an event NFT
        /// @param address address of user trying to mint the event NFT token
        fn mint_nft(ref self: ContractState, user_address: ContractAddress) -> u256 {
            let balance = self.erc721.balance_of(user_address);
            assert(balance.is_zero(), ALREADY_MINTED);

            let mut token_id = self.last_minted_id.read() + 1;
            self.erc721.mint(user_address, token_id);
            let timestamp: u64 = get_block_timestamp();
            self.user_token_id.write(user_address, token_id);

            self.last_minted_id.write(token_id);
            self.mint_timestamp.write(token_id, timestamp);
            self.last_minted_id.read()
        }

        fn get_user_token_id(self: @ContractState, user_address: ContractAddress) -> u256 {
            self.user_token_id.read(user_address)
        }

        fn name(self: @ContractState) -> ByteArray {
            self.erc721.name()
        }

        fn symbol(self: @ContractState) -> ByteArray {
            self.erc721.symbol()
        }

        fn token_uri(self: @ContractState, token_id: u256) -> ByteArray {
            self.erc721.token_uri(token_id)
        }

        /// @notice burns a community NFT
        /// @param address address of user trying to burn the community NFT token
        fn burn_nft(ref self: ContractState, user_address: ContractAddress, token_id: u256) {
            let user_token_id = self.user_token_id.read(user_address);
            assert(user_token_id == token_id, NOT_TOKEN_OWNER);
            // check the token exists
            assert(self.erc721.exists(token_id), TOKEN_DOES_NOT_EXIST);
            self.erc721.burn(token_id);
            self.user_token_id.write(user_address, 0);
        }
    }
}
