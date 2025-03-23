use starknet::ContractAddress;

#[starknet::contract]
mod TicketEventAccount {
    // *************************************************************************
    //                            IMPORT
    // *************************************************************************
    use core::traits::TryInto;
    use starknet::{
        ContractAddress, get_caller_address, get_block_timestamp, ClassHash, get_contract_address,
        syscalls::deploy_syscall, SyscallResultTrait, syscalls, class_hash::class_hash_const,
        storage::{Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess}
    };
    use chainevents_contracts::base::errors::Errors::{
        ZERO_ADDRESS_CALLER, NOT_OWNER, CLOSED_EVENT, ALREADY_REGISTERED, NOT_REGISTERED,
        ALREADY_RSVP, INVALID_EVENT, EVENT_CLOSED,
    };
    use chainevents_contracts::interfaces::ITicketEventAccount::ITicketEventAccount;

    use chainevents_contracts::interfaces::ITicketEventNft::ITicketEventNft::{
        ITicketEventNftDispatcher, ITicketEventNftDispatcherTrait
    };
    use tokengiver::interfaces::IRegistry::{
        IRegistryDispatcher, IRegistryDispatcherTrait, IRegistryLibraryDispatcher
    };
    use chainevents_contracts::base::types::TicketEventAccount;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use token_bound_accounts::interfaces::ILockable::{
        ILockableDispatcher, ILockableDispatcherTrait
    };

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    /// Upgradeable
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    // *************************************************************************
    //                              STORAGE
    // *************************************************************************
    #[storage]
    struct Storage {
        ticket_event_account: Map<ContractAddress, TicketEventAccount>,
        ticket_event_accounts: Map<u16, ContractAddress>, // (ticket_event_id, account_address)
        count: u256,
        ticket_event_account_nft_token: Map<
            ContractAddress, (ContractAddress, u256)
        >, // (recipient, (account_address, token_id))
        strk_address: ContractAddress,
        ticket_event_nft_contract_address: ContractAddress,
        ticket_event_nft_class_hash: ClassHash,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
    }

    // *************************************************************************
    //                            EVENT
    // *************************************************************************
    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        CreateCampaign: CreateCampaign,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
    }

    #[derive(Drop, starknet::Event)]
    pub struct CreateTicketEventAccout {
        #[key]
        owner: ContractAddress,
        #[key]
        ticket_event_account_address: ContractAddress,
        token_id: u256,
        ticket_event_account_id: u256,
        nft_token_uri: ByteArray,
        ticket_event_nft_contract_address: ContractAddress,
        block_timestamp: u64,
    }


    // *************************************************************************
    //                              CONSTRUCTOR
    // *************************************************************************
    #[constructor]
    fn constructor(
        ref self: ContractState,
        ticket_event_nft_class_hash: ClassHash,
        ticket_event_nft_contract_address: ContractAddress,
        strk_address: ContractAddress,
        owner: ContractAddress
    ) {
        self.ticket_event_nft_class_hash.write(ticket_event_nft_class_hash);
        self.ticket_event_nft_contract_address.write(ticket_event_nft_contract_address);
        self.strk_address.write(strk_address);
        self.ownable.initializer(owner);
    }


    // *************************************************************************
    //                            EXTERNAL FUNCTIONS
    // *************************************************************************
    #[abi(embed_v0)]
    impl TicketEventAccountImpl of ITicketEventAccount<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            // This function can only be called by the owner
            self.ownable.assert_only_owner();
            self.upgradeable.upgrade(new_class_hash);
        }
        fn create_ticket_event_account_address(
            ref self: ContractState,
            registry_hash: felt252,
            implementation_hash: felt252,
            salt: felt252,
            recipient: ContractAddress,
            ticket_event_id: u256,
        ) -> ContractAddress {
            // check if ticket_event_accounts has has an address  ticket_event_id
            let count: u16 = self.count.read() + 1;
            let ticket_event_nft_contract_address = self
                .ticket_event_nft_contract_address
                .read(); // read nft token giver contract address;

            //set dispatcher
            let ticket_event_nft_giver_dispatcher = ITicketEventNftDispatcher {
                contract_address: ticket_event_nft_contract_address
            };

            // mint the nft
            ticket_event_nft_giver_dispatcher.mint_token_giver_nft(get_caller_address());

            // get the token base on the user that nft was minted for

            let token_id = ticket_event_nft_giver_dispatcher
                .get_user_token_id(get_caller_address());

            let ticket_event_account_address = IRegistryLibraryDispatcher {
                class_hash: registry_hash.try_into().unwrap()
            }
                .create_account(
                    implementation_hash, token_giver_nft_contract_address, token_id.clone(), salt
                );

            let token_uri = token_giver_dispatcher.get_token_uri(token_id);

            let new_ticket_event_account = Campaign {
                ticket_event_account_address,
                ticket_event_owner: get_caller_address(),
                nft_token_uri: token_uri.clone(),
                token_id: token_id.clone(),
                ticket_event_id: ticket_event_id,
            };

            self.ticket_event_account.write(ticket_event_account_address, new_ticket_event_account);
            self.ticket_event_accounts.write(ticket_event_id, ticket_event_account_address);
            self
                .ticket_event_account_nft_token
                .write(recipient, (ticket_event_account_address, token_id));
            self.count.write(count);

            self
                .emit(
                    CreateTicketEventAccout {
                        owner: recipient,
                        ticket_event_account_address,
                        token_id,
                        ticket_event_id: ticket_event_id,
                        ticket_event_nft_contract_address: ticket_event_nft_contract_address,
                        nft_token_uri: token_uri,
                        block_timestamp: get_block_timestamp(),
                    }
                );

            ticket_event_account_address
        }


        fn update_token_giver_nft(
            ref self: ContractState,
            ticket_event_nft_class_hash: ClassHash,
            ticket_event_nft_contract_address: ContractAddress
        ) {
            // This function can only be called by the owner
            self.ownable.assert_only_owner();
            self.ticket_event_nft_class_hash.write(ticket_event_nft_class_hash);
            self.ticket_event_nft_contract_address.write(ticket_event_nft_contract_address);
        }
    }
}
